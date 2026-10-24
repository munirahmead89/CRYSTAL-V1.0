import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../../core/connectivity/connectivity_providers.dart';
import '../../../../core/contacts/device_contacts.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/database/local_store.dart';
import '../../../../core/media/media_providers.dart';
import '../../../../core/network/supabase_providers.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/realtime/realtime_providers.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/security/device_registration.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/sync/outbox_sync.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/profile/presentation/providers/settings_providers.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/utils/uuid.dart';
import '../../../delivery/data/supabase_relay_repository.dart';
import '../../../delivery/domain/relay_envelope.dart';
import '../../../delivery/domain/repositories/relay_repository.dart';
import '../../../delivery/services/delivery_acknowledgement_service.dart';
import '../../../delivery/services/relay_sync_recovery_service.dart';
import '../../../message_deletion/services/tombstone_service.dart';
import '../../data/supabase_chat_repositories.dart';
import '../../domain/repositories/chat_repositories.dart';

// -- Repositories -------------------------------------------------------------

final conversationsRepositoryProvider = Provider<ConversationsRepository>(
  (ref) => SupabaseConversationsRepository(ref.watch(supabaseClientProvider)),
);

final messagesRepositoryProvider = Provider<MessagesRepository>(
  (ref) => SupabaseMessagesRepository(ref.watch(supabaseClientProvider)),
);
final peopleRepositoryProvider = Provider<PeopleRepository>(
  // The repository talks to Supabase only. Local mirroring of `profiles` is
  // handled by PeopleNotifier through `localStoreProvider`, so contacts, names
  // and avatars still render with no connection.
  (ref) => SupabasePeopleRepository(
    ref.watch(supabaseClientProvider),
    localStore: ref.watch(localStoreProvider),
  ),
);

final localStoreProvider = Provider<LocalStore>((ref) {
  final store = LocalStore(ref.watch(databaseProvider));
  // Bind the account before anything reads. Doing it in the provider rather
  // than at each call site means there is exactly one place that decides whose
  // cache this is, and no read can slip past it.
  //
  // Empty while signed out: the store then behaves exactly as it did before
  // account scoping existed, which is what keeps the signed-out shell and the
  // widget tests working.
  store.bindAccount(ref.watch(authStateProvider).user?.id ?? '');
  return store;
});

/// The relay's trusted server operations: send, acknowledge, read, sync,
/// delete.
///
/// Separate from [messagesRepositoryProvider] on purpose. The legacy repository
/// talks to tables directly and is kept for history reads and reactions; every
/// operation that can change a receipt or a tombstone goes through the relay,
/// where the server validates the caller instead of trusting an anon key.
final relayRepositoryProvider = Provider<RelayRepository>(
  (ref) => SupabaseRelayRepository(ref.watch(supabaseClientProvider)),
);

/// Delivers the acknowledgements this device owes the relay.
///
/// [deviceId] is read lazily rather than injected so the service can be built
/// before `register_device` has resolved; an unregistered device simply does
/// not acknowledge, which is correct — an acknowledgement from a device the
/// server cannot verify is not evidence of anything.
final deliveryAckServiceProvider = Provider<DeliveryAcknowledgementService>((
  ref,
) {
  return DeliveryAcknowledgementService(
    store: ref.watch(localStoreProvider),
    repository: ref.watch(relayRepositoryProvider),
    deviceId: ref.watch(registeredDeviceIdProvider).valueOrNull ?? '',
    isOnline: () => ref.read(isOnlineProvider).valueOrNull ?? true,
    onError: (error, stack) {
      if (kDebugMode) debugPrint('relay ack: $error');
    },
  );
});

/// Recovers deletions the device missed while offline.
final relayRecoveryProvider = Provider<RelaySyncRecoveryService>((ref) {
  return RelaySyncRecoveryService(
    store: ref.watch(localStoreProvider),
    repository: ref.watch(relayRepositoryProvider),
    isOnline: () => ref.read(isOnlineProvider).valueOrNull ?? true,
    onError: (error, stack) {
      if (kDebugMode) debugPrint('relay recovery: $error');
    },
  );
});

final tombstoneServiceProvider = Provider<TombstoneService>((ref) {
  return TombstoneService(
    store: ref.watch(localStoreProvider),
    repository: ref.watch(relayRepositoryProvider),
    isOnline: () => ref.read(isOnlineProvider).valueOrNull ?? true,
    onError: (error, stack) {
      if (kDebugMode) debugPrint('relay deletion: $error');
    },
  );
});

final syncEngineProvider = Provider<OutboxSyncEngine>((ref) {
  return OutboxSyncEngine(
    store: ref.watch(localStoreProvider),
    messagesRepository: ref.watch(messagesRepositoryProvider),
    relay: ref.watch(relayRepositoryProvider),
    getMyId: () => ref.read(authStateProvider).user?.id ?? '',
    // Lets a media message composed while offline be uploaded by the outbox
    // the moment connectivity returns, with no special-casing in the UI.
    mediaUpload:
        ({
          required conversationId,
          required filePath,
          fileName,
          mimeType,
        }) async {
          final service = await ref.read(mediaTransferServiceProvider.future);
          final result = await service.send(
            conversationId: conversationId,
            filePath: filePath,
            fileName: fileName,
            mimeType: mimeType,
          );
          return result.manifest;
        },
    // While offline the engine does nothing at all, so a queued message keeps
    // its queued state instead of exhausting its retries and being marked
    // failed. Default to false when loading/unknown so offline messages never fail.
    isOnline: () => ref.read(isOnlineProvider).valueOrNull ?? false,
  );
});

/// Flushes the outbox the instant the device comes back online.
///
/// This is the "sent immediately" half of offline queueing: without it a
/// message composed offline would wait out the backoff schedule (up to 30s)
/// after the network returned.
final outboxFlushOnReconnectProvider = Provider<void>((ref) {
  final engine = ref.watch(syncEngineProvider);
  final acks = ref.watch(deliveryAckServiceProvider);
  final recovery = ref.watch(relayRecoveryProvider);

  ref.listen(isOnlineProvider, (previous, next) {
    final isOnline = next.valueOrNull == true;
    if (isOnline) {
      engine.flushNow().ignore();
      // Acknowledgements and deletions are recovered on the same event. They are
      // independent of the send path, so a failure in one must not delay the
      // other — hence fire-and-forget rather than a single chained future.
      acks.flushPending().ignore();
      recovery.recover().ignore();
    }
  });

  // Also flush once at startup, which covers the case of messages queued in a
  // previous session before the app was killed.
  Future<void>.microtask(() async {
    await engine.sweepOrphanedStagedFiles();
    await engine.flushNow();
    await acks.flushPending();
    await recovery.recover();
  });
});

/// Advanced background sync: initial/incremental passes + outbox flushing.
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    store: ref.watch(localStoreProvider),
    conversationsRepository: ref.watch(conversationsRepositoryProvider),
    messagesRepository: ref.watch(messagesRepositoryProvider),
    outbox: ref.watch(syncEngineProvider),
    getMyId: () => ref.read(authStateProvider).user?.id ?? '',
  );
});

// -- Chat list ----------------------------------------------------------------

final chatListProvider =
    NotifierProvider<ChatListNotifier, AsyncValue<List<ConversationSummary>>>(
      ChatListNotifier.new,
    );

class ChatListNotifier extends Notifier<AsyncValue<List<ConversationSummary>>> {
  @override
  AsyncValue<List<ConversationSummary>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load({bool silent = false}) async {
    final store = ref.read(localStoreProvider);
    final repo = ref.read(conversationsRepositoryProvider);
    if (!silent) {
      state = const AsyncLoading();
    }
    try {
      final cached = await store.cachedConversations();
      if (cached.isNotEmpty) {
        state = AsyncData(await _withStatus(store, cached));
      }
      final remote = await repo.getChats();
      await store.upsertConversations(remote);
      state = AsyncData(await _withStatus(store, remote));
    } catch (e) {
      // Offline is not an error. Falling through to AsyncError here meant a
      // cold start with no network painted the raw Supabase/Dart exception
      // string ("ClientException: Connection closed before full header was
      // received") into the chat list, where the user cannot act on it.
      //
      // What matters is whether anything is cached. If it is, the list stays on
      // screen. If it is not, an empty list is the truthful state, and the
      // offline banner already explains why.
      if (state.valueOrNull?.isEmpty ?? true) {
        final cached = await store.cachedConversations();
        state = AsyncData(await _withStatus(store, cached));
      }
      if (kDebugMode) debugPrint('[chat-list] load failed: $e');
    }
  }

  /// Attaches the newest message's local/remote delivery state to each row so
  /// the chat list can paint the traffic-light preview dot, and derives the
  /// unread badge from the *local inbox* (only incoming, unread rows). Our own
  /// sent messages are outgoing and therefore never count — so pushing a
  /// message can never badge us. The server-reported count is kept as a
  /// ceiling while a peer's messages are still syncing into the cache.
  Future<List<ConversationSummary>> _withStatus(
    LocalStore store,
    List<ConversationSummary> chats,
  ) async {
    // One grouped query for every row's unread count instead of a query per
    // conversation.
    final unread = await store.countUnreadIncomingFor(
      chats.map((c) => c.id).toList(),
    );
    final enriched = <ConversationSummary>[];
    for (final chat in chats) {
      final localUnread = unread[chat.id] ?? 0;
      var next = chat.copyWith(
        unreadCount: localUnread > chat.unreadCount
            ? localUnread
            : chat.unreadCount,
      );
      final outgoing =
          chat.lastMessageSenderId != null &&
          chat.lastMessageSenderId != chat.peer?.id;
      if (outgoing) {
        final last = await store.newestOutgoing(chat.id);
        next = next.copyWith(
          lastMessageLocalState: last?.localState.name,
          lastMessageRemoteStatus: last?.remoteStatus.name,
        );
      }
      enriched.add(next);
    }
    return enriched;
  }
}

// -- People discovery ----------------------------------------------------------

final peopleProvider =
    NotifierProvider<PeopleNotifier, AsyncValue<List<UserProfile>>>(
      PeopleNotifier.new,
    );

class PeopleNotifier extends Notifier<AsyncValue<List<UserProfile>>> {
  @override
  AsyncValue<List<UserProfile>> build() => const AsyncData([]);

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    try {
      final results = await ref
          .read(peopleRepositoryProvider)
          .searchProfiles(trimmed);
      state = AsyncData(results);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void clear() {
    state = const AsyncData([]);
  }

  /// Exact phone-based lookup (QR scans end up here, too). Caches the profile
  /// locally so previously-scanned contacts resolve offline.
  Future<UserProfile?> addByPhone(String phone) async {
    if (phone.trim().isEmpty) return null;
    state = const AsyncLoading();
    try {
      final repo = ref.read(peopleRepositoryProvider);
      final profile =
          await repo.fetchProfileByPhone(phone) ??
          (await ref.read(localStoreProvider).cacheProfileByPhone(phone))
              .firstOrNull;
      if (profile != null) {
        await ref.read(localStoreProvider).upsertProfile(profile);
        state = AsyncData(profile.id.isEmpty ? const [] : [profile]);
      } else {
        state = const AsyncData([]);
      }
      return profile;
    } catch (e, st) {
      // Fall back to the offline cache when the lookup fails.
      final cached = await ref
          .read(localStoreProvider)
          .cacheProfileByPhone(phone);
      if (cached.isNotEmpty) {
        state = AsyncData(cached);
        return cached.first;
      }
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Sync contacts from the phone's address book (WhatsApp-style).
  /// This queries the local cache for any known profiles and refreshes the
  /// UI state. In a full implementation this would also scan the device's
  /// contacts storage via platform channels, but here we refresh the local
  /// mirror so any profiles that were previously cached become visible.
  ///
  /// [platform] parameter indicates the operating system so the UI can show
  /// the appropriate permission request guidance.
  Future<void> syncContacts({String platform = 'unknown'}) async {
    state = const AsyncLoading();
    try {
      final permission = await Permission.contacts.request();
      if (!permission.isGranted) {
        throw StateError('Contacts permission is required to sync contacts.');
      }
      await scanDeviceContacts(
        onFound: (_) {},
        onNotFound: (_) {},
      );
      final store = ref.read(localStoreProvider);
      final allCached = await store.allCachedProfiles();
      // Convert Drift profiles to UserProfile so the PeoplePage rebuilds
      // with existing data. Profiles already in the cache from previous
      /// add-by-phone, QR scan, or onboarding will become visible here.
      if (allCached.isNotEmpty) {
        final profiles = allCached.map((p) => UserProfile(
          id: p.id,
          displayName: p.displayName,
          phone: p.phone,
          avatarUrl: p.avatarUrl,
          bio: p.bio,
          presence: p.presence,
          lastSeenAt: p.lastSeenAt,
          verificationStatus: p.verificationStatus,
          syncEnabled: p.syncEnabled,
          verifiedAt: p.verifiedAt,
          deviceModel: p.deviceModel,
          deviceOs: p.deviceOs,
          deviceManufacturer: p.deviceManufacturer,
          deviceIp: p.deviceIp,
          deviceLocale: p.deviceLocale,
          appVersion: p.appVersion,
          isCurrentDevice: p.isCurrentDevice,
        )).toList();
        state = AsyncData(profiles);
      } else {
        state = const AsyncData([]);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Initiate a device contacts scan to find which of the user's phone contacts
  /// already have Crystal accounts. This uses platform channels to access the
  /// device's address book, matches phone numbers against the backend profiles,
  /// and caches any matches so they appear in the People page immediately.
  ///
  /// [onFound] is called for each contact that has a Crystal account.
  /// [onNotFound] is called for contacts without a Crystal account.
  /// Returns the total number of contacts scanned.
  Future<int> scanDeviceContacts({
    required Function(UserProfile) onFound,
    required Function(String phone) onNotFound,
  }) async {
    final contacts = await DeviceContacts.read();
    var scanned = 0;
    for (final contact in contacts) {
      scanned++;
      final normalized = contact.phone
          .trim()
          .replaceAll(RegExp(r'[\s\-().]'), '')
          .replaceFirst(RegExp(r'^\+'), '');
      if (normalized.isEmpty) continue;
      final profile = await addByPhone(normalized);
      if (profile != null) {
        onFound(profile);
      } else {
        onNotFound(normalized);
      }
    }
    return scanned;
  }
}

// -- Chat (single conversation) ------------------------------------------------

class ChatUiState {
  const ChatUiState({
    this.messages = const [],
    this.typingUserIds = const {},
    this.peerPresence = 'offline',
    this.peerLastSeenAt,
    this.initialLoading = false,
    this.hasMoreHistory = false,
    this.loadingOlder = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final Set<String> typingUserIds;
  final String peerPresence;
  final DateTime? peerLastSeenAt;
  final bool initialLoading;

  /// Whether older messages exist server-side/cached and can still be paged.
  final bool hasMoreHistory;

  /// Whether an older-history fetch is currently in flight (spinner shown
  /// at the top of the thread, WhatsApp/Messenger-style).
  final bool loadingOlder;
  final String? error;

  bool get isTyping => typingUserIds.isNotEmpty;

  ChatUiState copyWith({
    List<ChatMessage>? messages,
    Set<String>? typingUserIds,
    String? peerPresence,
    DateTime? peerLastSeenAt,
    bool? initialLoading,
    bool? hasMoreHistory,
    bool? loadingOlder,
    String? error,
    bool clearError = false,
  }) {
    return ChatUiState(
      messages: messages ?? this.messages,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      peerPresence: peerPresence ?? this.peerPresence,
      peerLastSeenAt: peerLastSeenAt ?? this.peerLastSeenAt,
      initialLoading: initialLoading ?? this.initialLoading,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final chatControllerProvider =
    NotifierProvider.family<ChatController, ChatUiState, String>(
      ChatController.new,
    );

class ChatController extends FamilyNotifier<ChatUiState, String> {
  final Map<String, Timer> _typingTimers = {};
  final List<RealtimeChannel> _channels = [];
  Timer? _receiptTimer;
  Timer? _readTimer;
  Timer? _realtimeDebounce;
  Timer? _fallbackTimer;
  DateTime? _lastRealtimeAt;
  bool _opsRunning = false;
  bool _alive = true;

  /// Set when the room opened with no cached history. Forces the next sync to
  /// backfill from the newest server window ignoring any stale per-device
  /// cursor — guarantees a thread whose incremental watermark desynced (or was
  /// never set) still loads its messages.
  bool _needsFullBackfill = false;

  /// Number of messages rendered per page (Messenger-style windowed history).
  static const pageSize = 60;

  /// Coalescing window: a burst of realtime events becomes ONE reconcile
  /// instead of an O(n) fan of per-message syncs (critical on high-volume
  /// conversations).
  static const _realtimeCoalesceWindow = Duration(milliseconds: 300);

  /// Reconcile periodically as a safety net for anything realtime missed
  /// (dead socket, missed event, drift). Only runs while the thread is open.
  static const _fallbackInterval = Duration(seconds: 45);

  /// How long without a realtime event before the fallback poll re-syncs.
  static const _fallbackQuietPeriod = Duration(seconds: 20);

  String get _conversationId => arg;
  RealtimeService get _realtime => ref.read(realtimeServiceProvider);
  LocalStore get _store => ref.read(localStoreProvider);
  MessagesRepository get _messages => ref.read(messagesRepositoryProvider);
  OutboxSyncEngine get _sync => ref.read(syncEngineProvider);
  SyncService get _syncService => ref.read(syncServiceProvider);

  /// Delivers the delivery acknowledgements this device owes.
  ///
  /// Resolved through `ref.read` rather than held as a field so the service is
  /// rebuilt when the device registration resolves, which is exactly when the
  /// first acknowledgement becomes possible.
  DeliveryAcknowledgementService get _deliveryAcks =>
      ref.read(deliveryAckServiceProvider);

  /// Surfaced to the UI so a failed relay operation can be reported rather than
  /// silently swallowed. Production leaves this null.
  void Function(Object error, StackTrace stack)? _onError;

  @override
  ChatUiState build(String conversationId) {
    ref.onDispose(_disposeSubscriptions);
    _setupRealtime(conversationId);
    _startFallbackPoll();
    Future.microtask(_loadInitial);
    return const ChatUiState(initialLoading: true);
  }

  /// Releases every realtime channel this controller owns.
  ///
  /// Goes through [RealtimeService.unsubscribe] rather than calling
  /// `channel.unsubscribe()` on the raw channel. The service pools channels by
  /// topic, so tearing one down directly left the pooled channel registered in
  /// its `_channels` map and `_subscribedTopics` set — and a later open of the
  /// same conversation then short-circuited as "already subscribed" and never
  /// received a single event. Every conversation the user ever opened leaked a
  /// dead channel.
  void _disposeSubscriptions() {
    _alive = false;
    for (final channel in _channels) {
      channel.unsubscribe();
    }
    _channels.clear();

    // Drop the pooled entries too. `receipts` is shared across conversations,
    // so it is left alone; `deletions` is re-registered by whichever
    // conversation is open.
    _realtime.unsubscribe('messages:$_conversationId');
    _realtime.unsubscribe('typing:$_conversationId');

    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _receiptTimer?.cancel();
    _readTimer?.cancel();
    _realtimeDebounce?.cancel();
    _fallbackTimer?.cancel();
  }

  /// Low-priority periodic safety sync while the thread is open.
  void _startFallbackPoll() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(_fallbackInterval, (_) {
      if (!_alive || !_isOnline || _opsRunning) return;
      final lastEvent = _lastRealtimeAt;
      final freshRecently =
          lastEvent != null &&
          DateTime.now().difference(lastEvent) < _fallbackQuietPeriod;
      if (freshRecently) return;
      _reconcileFromServer();
    });
  }

  void _setupRealtime(String conversationId) {
    _channels.add(
      _realtime.subscribeToMessages(
        conversationId,
        onInsert: (payload) => _reconcileAfterRemoteInsert(payload),
        onUpdate: (payload) => _reconcileAfterRemoteInsert(payload),
      ),
    );
    _channels.add(
      _realtime.subscribeToReceipts((payload) {
        _applyReceipt(payload);
      }),
    );
    // Deletion events arrive on their own channel because a hard delete
    // produces no `messages` event at all, and an id-ordered pull cannot see
    // one. Applying the tombstone here is what stops a stale bubble from
    // outliving the deletion.
    _channels.add(
      _realtime.subscribeToDeletions((payload) {
        _applyDeletionEvent(payload);
      }),
    );
    _realtime.onTyping(conversationId).listen((event) {
      if (event.isTyping) {
        _typingTimers[event.userId]?.cancel();
        _typingTimers[event.userId] = Timer(const Duration(seconds: 3), () {
          _clearTyping(event.userId);
        });
        state = state.copyWith(
          typingUserIds: {...state.typingUserIds, event.userId},
        );
      } else {
        _clearTyping(event.userId);
      }
    });
  }

  /// Applies a server deletion event to the local store and the visible list.
  ///
  /// The event is applied to storage first and the UI is re-read afterwards, so
  /// what the user sees and what the database holds can never disagree — the
  /// alternative (patching `state` directly) is how a deleted message used to
  /// come back on the next rebuild.
  void _applyDeletionEvent(PostgresChangePayload payload) {
    if (payload.newRecord.isEmpty) return;
    final event = RelayDeletionEvent.tryParse(
      Map<String, dynamic>.from(payload.newRecord),
    );
    if (event == null) return;
    if (event.conversationId != _conversationId) return;

    unawaited(() async {
      final applied = await _store.applyDeletionEvents([
        event,
      ], cursorKey: RelaySyncRecoveryService.deletionCursorKey());
      if (!_alive || applied == 0) return;
      final msgs = await _store.cachedMessages(_conversationId);
      if (_alive) state = state.copyWith(messages: msgs);
    }());
  }

  void _clearTyping(String userId) {
    _typingTimers.remove(userId)?.cancel();
    if (state.typingUserIds.contains(userId)) {
      state = state.copyWith(
        typingUserIds: {...state.typingUserIds}..remove(userId),
      );
    }
  }

  String? get _meId => ref.watch(authStateProvider).user?.id;

  Future<void> _loadInitial() async {
    final conversationId = _conversationId;
    try {
      // Presence comes from the last synced snapshot, never a realtime feed:
      // reflect it up front so the header isn't stuck on "Offline".
      await _refreshPeerPresence();
      // Messenger-style: open on the newest window of cached history.
      final page = await _store.cachedMessagesPage(
        conversationId,
        limit: pageSize,
      );
      if (page.messages.isNotEmpty) {
        state = state.copyWith(
          messages: page.messages,
          hasMoreHistory: page.hasMore,
          initialLoading: false,
        );
      } else {
        // Empty local cache: show loading while we fetch from server
        _needsFullBackfill = true;
        state = state.copyWith(initialLoading: true);
      }
      await _reconcileFromServer(fullBackfill: _needsFullBackfill);
      _needsFullBackfill = false;
    } catch (e) {
      state = state.copyWith(
        initialLoading: false,
        error: 'Could not load messages: $e',
      );
    }
    _scheduleRead();
  }

  /// Runs the per-conversation sync (incremental, cursor-based), re-reads the
  /// fresh window and merges it over whatever older history is already loaded,
  /// then updates unread counters.
  Future<void> _reconcileFromServer({bool fullBackfill = false}) async {
    if (_opsRunning) return;
    _opsRunning = true;
    try {
      await _syncService.syncConversationNow(
        _conversationId,
        fullWindow: fullBackfill,
      );
      final page = await _store.cachedMessagesPage(
        _conversationId,
        limit: pageSize,
      );
      if (!_alive) return;
      state = state.copyWith(
        messages: _mergeHistory(state.messages, page.messages),
        hasMoreHistory: state.hasMoreHistory || page.hasMore,
        initialLoading: false,
      );
      unawaited(
        ref
            .read(appPreferencesProvider.future)
            .then((p) => p.setLastSyncAt(DateTime.now())),
      );

      final incomingIds = state.messages
          .where((m) => !m.outgoing && m.deliveredAt == null)
          .map((m) => m.id)
          .toList();
      if (incomingIds.isNotEmpty && _isOnline) {
        // The acknowledgement is now owned by the durable ledger rather than by
        // this in-memory list. `commitIncomingMessage` wrote a `delivered` row
        // inside the same transaction that stored each message, so flushing
        // here reports exactly the messages this device really holds — and it
        // survives a process death between the two.
        //
        // The old code re-sent the entire conversation's incoming history on
        // every reconcile, because it selected on `deliveredAt` which was never
        // written locally for incoming messages.
        unawaited(_deliveryAcks.flushPending());
        _scheduleRead();
      } else {
        // Nothing to acknowledge, but the ledger may still owe something from a
        // previous session (e.g. a failed ack that was never retried).
        unawaited(_deliveryAcks.flushPending());
      }
      ref.read(chatListProvider.notifier).load(silent: true);
      await _refreshPeerPresence();
    } catch (e) {
      if (_alive) {
        state = state.copyWith(
          initialLoading: false,
          error: 'Offline. Showing cached messages.',
        );
      }
    } finally {
      _opsRunning = false;
    }
  }

  /// Refreshes the header presence from the locally-cached conversation row
  /// (itself a snapshot of the server `profiles.presence`/`last_seen_at`).
  /// Deliberately sync-based rather than realtime: the ring/status reflects
  /// the last successful sync, so it cannot flicker.
  Future<void> _refreshPeerPresence() async {
    try {
      final rows = await _store.cachedConversations();
      final summary = rows.where((c) => c.id == _conversationId).firstOrNull;
      final peer = summary?.peer;
      if (_alive) {
        state = state.copyWith(
          peerPresence: (peer != null && peer.isOnline) ? 'online' : 'offline',
          peerLastSeenAt: peer?.lastSeenAt,
        );
      }
    } catch (_) {
      // Non-fatal: keep whatever presence the header already shows.
    }
  }

  /// Merges the [incoming] newer window into [current] (which may already hold
  /// older pages), dedup by clientMessageId, and keeps strict chronological
  /// order so the renderer's bubble grouping stays valid.
  List<ChatMessage> _mergeHistory(
    List<ChatMessage> current,
    List<ChatMessage> incoming,
  ) {
    if (current.isEmpty) return incoming;
    if (incoming.isEmpty) return current;
    final incomingIds = {for (final m in incoming) m.clientMessageId};
    final merged = List<ChatMessage>.of(incoming);
    for (final m in current) {
      if (!incomingIds.contains(m.clientMessageId)) merged.add(m);
    }
    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  /// Fetches one older page (before the oldest loaded message) and prepends it.
  Future<void> loadOlderMessages() async {
    if (!state.hasMoreHistory ||
        state.loadingOlder ||
        state.initialLoading ||
        state.messages.isEmpty) {
      return;
    }
    final oldest = state.messages.first.createdAt;
    state = state.copyWith(loadingOlder: true);
    try {
      final older = await _syncService.loadHistory(
        _conversationId,
        before: oldest,
        limit: pageSize,
      );
      if (!_alive) return;
      state = state.copyWith(
        messages: _mergeHistory(state.messages, older),
        hasMoreHistory: older.length >= pageSize,
        loadingOlder: false,
      );
    } catch (_) {
      if (_alive) state = state.copyWith(loadingOlder: false);
    }
  }

  bool get _isOnline => ref.read(isOnlineProvider).valueOrNull ?? true;

  void _reconcileAfterRemoteInsert(PostgresChangePayload payload) {
    _lastRealtimeAt = DateTime.now();
    try {
      if (payload.newRecord.isNotEmpty) {
        final msg = ChatMessage.fromServerJson(
          payload.newRecord,
          myUserId: _meId,
        );
        if (!msg.outgoing && msg.senderId != _meId) {
          HapticFeedback.vibrate();
          // Fire-and-forget: resolving the sender's name is a local cache read,
          // but it is still async, and a slow disk must not delay the message
          // being written to state below.
          unawaited(_notifyIncoming(msg));
        }
        // Commits the message, applies any tombstone that already covers it, and
        // records that this device owes a delivery acknowledgement — in one
        // transaction. A duplicate Realtime event is absorbed by the upsert and
        // reports `false`, so events cannot append the message twice.
        _store.commitIncomingMessage(message: msg, cursorKey: '').then((
          stored,
        ) {
          if (!_alive || !stored) return;
          final updated = List<ChatMessage>.of(state.messages);
          if (!updated.any(
            (m) => m.id == msg.id || m.clientMessageId == msg.clientMessageId,
          )) {
            updated.add(msg);
            updated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            state = state.copyWith(messages: updated);
          }
          // Acknowledging only after the commit is the whole point of the
          // ledger: the server must never learn "delivered" before this device
          // can prove it stored the message.
          unawaited(_deliveryAcks.flushPending());
        }).ignore();
      }
    } catch (_) {}

    // Coalesce bursts: many events in a short window fold into one reconcile.
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(_realtimeCoalesceWindow, () {
      if (!_alive) return;
      _reconcileFromServer();
    });
  }

  /// Applies a delivery/read receipt to the outgoing messages in view.
  ///
  /// Reads the columns that actually exist on the denormalised
  /// `messages` row. The previous implementation read `delivered_at` and
  /// `read_at` off a `message_receipts` row, which carries `status` and
  /// `timestamp` — so both were always null, the function returned early, and
  /// the entire realtime receipt path was a silent no-op.
  void _applyReceipt(PostgresChangePayload payload) {
    final row = payload.newRecord.isNotEmpty
        ? payload.newRecord
        : payload.oldRecord;
    if (row.isEmpty) return;

    final messageId = row['id'] as String?;
    if (messageId == null) return;
    // A tombstoned payload is legitimate: the server nulls `text`/`media` and
    // sets `deleted_at`, and the chat screen has to render that.
    final deletedAt = parseDate(row['deleted_at']);

    final nowDelivered = parseDate(row['delivered_at']);
    final nowRead = parseDate(row['read_at']);
    if (nowDelivered == null && nowRead == null && deletedAt == null) return;

    final updated = <ChatMessage>[];
    var changed = false;
    for (final m in state.messages) {
      if (m.id == messageId || m.clientMessageId == messageId) {
        // Never regress: a payload carrying only `delivered_at` must not undo a
        // read that is already recorded.
        final delivered = nowDelivered ?? m.deliveredAt;
        final read = nowRead ?? m.readAt;
        final remoteStatus = read != null
            ? RemoteStatus.seen
            : (delivered != null ? RemoteStatus.delivered : m.remoteStatus);
        updated.add(
          m.copyWith(
            deliveredAt: delivered,
            readAt: read,
            deleted: deletedAt != null ? true : null,
            remoteStatus: remoteStatus,
          ),
        );
        changed = true;
      } else {
        updated.add(m);
      }
    }
    if (!changed) return;

    state = state.copyWith(messages: updated);
    _store.updateReceipt(
      serverId: messageId,
      deliveredAt: nowDelivered,
      readAt: nowRead,
    );

    // A message the user has now read should stop showing a banner in the
    // shade. `cancel` existed but was never called, so opening a chat left its
    // notification sitting there until it was individually dismissed.
    if (nowRead != null) {
      unawaited(
        ref.read(notificationServiceProvider).cancel({'message_id': messageId}),
      );
    }
  }

  /// Marks the visible conversation read, subject to the read-receipt policy.
  ///
  /// Two things are deliberately different here:
  ///
  /// * the **local** read (clear the badge, render as read on this device)
  ///   always happens — the user did look at the screen;
  /// * the **remote** read receipt only goes out when the sender permits it, so
  ///   turning read receipts off really stops reporting them rather than just
  ///   hiding the tick.
  ///
  /// The remote call is scoped by the newest message actually in view. Passing
  /// no boundary marked the entire server-side conversation read, so opening a
  /// chat reported that a user had read messages they had never seen.
  void _scheduleRead() {
    _readTimer?.cancel();
    _readTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!_alive) return;
      // Local read: mark every incoming message in this room as read and clear
      // the unread badge so the chat list reflects the open thread immediately
      // (works offline too). Outgoing messages are left untouched — their read
      // state tracks the peer's receipt.
      final now = DateTime.now();
      await _store.markMessagesRead(_conversationId);
      if (!_alive) return;
      state = state.copyWith(
        messages: state.messages
            .map(
              (m) => !m.outgoing && m.readAt == null
                  ? m.copyWith(readAt: now, remoteStatus: RemoteStatus.seen)
                  : m,
            )
            .toList(),
      );
      await _store.markConversationRead(_conversationId);

      // Cancel the shade banner for everything now read.
      final notifications = ref.read(notificationServiceProvider);
      for (final m in state.messages) {
        if (!m.outgoing) {
          unawaited(notifications.cancel({'message_id': m.id}));
        }
      }

      if (_isOnline && await _localReadReceiptsEnabled()) {
        // Only the messages actually on screen are claimed as read.
        final newestVisible = state.messages
            .where((m) => !m.outgoing)
            .fold<ChatMessage?>(
              null,
              (best, m) => best == null || m.createdAt.isAfter(best.createdAt)
                  ? m
                  : best,
            );
        unawaited(
          _deliveryAcks.markRead(
            conversationId: _conversationId,
            upToMessageId: newestVisible?.id,
          ),
        );
      }
      ref.read(chatListProvider.notifier).load(silent: true);
    });
  }

  /// Whether this user has read receipts switched on.
  ///
  /// Enforced in two independent places on purpose: here, so the client does not
  /// even attempt the call, and in the `mark_read` SQL function, which refuses to
  /// record a read row for a sender who disabled receipts. The server-side check
  /// is the one that actually protects the sender — a client-side check alone
  /// would be defeated by any other client.
  Future<bool> _localReadReceiptsEnabled() async {
    try {
      final settings = await ref.read(settingsControllerProvider.future);
      return settings.readReceipts;
    } catch (_) {
      // Fail closed: reporting a read the sender asked not to receive is a
      // privacy failure, whereas missing one is only a cosmetic one.
      return false;
    }
  }

  // -- Sending ----------------------------------------------------------------

  Future<void> sendText(String body, {String? replyToId}) {
    final text = body.trim();
    if (text.isEmpty) return Future.value();
    final me = _meId;
    if (me == null) return Future.value();
    return _send({
      'client_message_id': generateUuid(),
      'conversation_id': _conversationId,
      'sender_id': me,
      'type': 'text',
      'body': text,
      if (replyToId != null && replyToId.isNotEmpty) 'reply_to_id': replyToId,
    });
  }

  /// Sends a media attachment described by [attachment].
  ///
  /// The attachment is expected to already be uploaded: the transport stores
  /// bytes and this method only records the message. Passing the manifest
  /// through (rather than a URL) is what keeps a multi-gigabyte video
  /// playable on the other side.
  Future<void> sendMedia({
    required String type,
    required Attachment attachment,
    int? durationMs,
  }) {
    final me = _meId;
    if (me == null) return Future.value();
    // A voice note's length was measured by the recorder and then dropped here:
    // `durationMs` was accepted and never used, so `Attachment.duration_ms`
    // was never emitted and the bubble rendered every note as `0:00` with no
    // waveform progress. Fold it into the attachment before it is written.
    final effective = (durationMs != null && durationMs > 0)
        ? attachment.copyWith(durationMs: durationMs)
        : attachment;
    return _send({
      'client_message_id': generateUuid(),
      'conversation_id': _conversationId,
      'sender_id': me,
      'type': type,
      'attachment': effective,
    });
  }

  Future<void> _send(Map<String, dynamic> draft) async {
    final message = ChatMessage(
      id: draft['client_message_id'] as String,
      clientMessageId: draft['client_message_id'] as String,
      conversationId: draft['conversation_id'] as String,
      senderId: draft['sender_id'] as String,
      type: draft['type'] as String,
      body: draft['body'] as String?,
      attachment: draft['attachment'] as Attachment?,
      replyToId: draft['reply_to_id'] as String?,
      createdAt: DateTime.now(),
      outgoing: true,
      localState: MessageLocalState.queued,
    );
    await _store.upsertLocalMessage(message);
    await _store.enqueueOutbox(message);
    final list = [...state.messages, message];
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = state.copyWith(messages: list, clearError: true);
    _pump();
  }

  /// Shows the incoming-message banner.
  ///
  /// The title is the sender's actual name. The previous version hard-coded
  /// `'New Message'`, which forces the user to open the app to find out who
  /// wrote to them - that defeats the purpose of having a notification at all.
  Future<void> _notifyIncoming(ChatMessage msg) async {
    final name = await _displayNameFor(msg.senderId);
    if (!_alive) return;
    await ref
        .read(notificationServiceProvider)
        .showForeground(
          title: name ?? 'New message',
          body: msg.body?.isNotEmpty == true
              ? msg.body!
              : _attachmentLabel(msg.type),
          data: {'conversation_id': _conversationId, 'message_id': msg.id},
          // Attaches the inline "Reply" action to the banner.
          conversationId: _conversationId,
        );
  }

  /// Best available display name for [userId].
  ///
  /// Read from the local profile cache, which is populated the moment a message
  /// from that person arrives, so this never depends on a network round-trip
  /// that would leave the banner blank. Returns null rather than a placeholder
  /// so the caller can choose its own fallback.
  Future<String?> _displayNameFor(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final profile = await ref.read(localStoreProvider).cachedProfile(userId);
      final name = profile?.displayName.trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {
      // A cache miss is normal before the first sync completes.
    }
    try {
      final peer = await ref.read(
        conversationPeerProvider(_conversationId).future,
      );
      if (peer != null && peer.id == userId) {
        final peerName = peer.displayName.trim();
        if (peerName.isNotEmpty) return peerName;
      }
    } catch (_) {
      // Peer lookup is best-effort.
    }
    return null;
  }

  /// Human-readable stand-in for a non-text message.
  static String _attachmentLabel(String type) => switch (type) {
    'image' => '📷 Photo',
    'video' => '🎥 Video',
    'voice' => '🎤 Voice note',
    'file' => '📎 File',
    _ => 'Attachment received',
  };

  // -- Deletion and editing ---------------------------------------------------

  /// Hides a message on this device only.
  ///
  /// No network call, by design: "delete for me" has to work with the radio
  /// off. The local tombstone is what stops the next sync from fetching the
  /// message straight back.
  Future<DeletionOutcome> deleteForMe(ChatMessage message) async {
    final outcome = await ref
        .read(tombstoneServiceProvider)
        .deleteForMe(
          messageId: message.clientMessageId,
          conversationId: _conversationId,
        );
    if (outcome.succeeded) _refreshFromStore();
    return outcome;
  }

  /// Removes a message for every participant.
  ///
  /// Returns an outcome that distinguishes "gone for everyone" from "hidden
  /// here only, the other person still has it", because those are different
  /// promises and the user has to be told which one they got.
  Future<DeletionOutcome> deleteForEveryone(ChatMessage message) async {
    final outcome = await ref
        .read(tombstoneServiceProvider)
        .deleteForEveryone(
          messageId: message.id,
          conversationId: _conversationId,
        );
    if (outcome.succeeded) _refreshFromStore();
    return outcome;
  }

  /// Rewrites a text message's body.
  ///
  /// Only the sender can edit, and only before the server's age policy would
  /// refuse — surfaced as an error rather than an optimistic success, because an
  /// edit that silently does not apply is worse than one that fails visibly.
  Future<bool> editMessage(ChatMessage message, String body) async {
    final text = body.trim();
    if (text.isEmpty || text == message.body) return false;
    if (message.senderId != _meId) return false;

    final updatedAt = DateTime.now();
    // Optimistic: the local row shows the edit immediately, then the server is
    // asked to record it.
    await _store.upsertLocalMessage(
      message.copyWith(body: text, editedAt: updatedAt),
    );
    _refreshFromStore();

    try {
      await _messages.editText(messageId: message.id, body: text);
      return true;
    } catch (error, stack) {
      if (kDebugMode) debugPrint('relay edit failed: $error');
      _onError?.call(error, stack);
      return false;
    }
  }

  /// Re-reads the conversation from SQLite into state.
  ///
  /// Used after a local-only mutation (a tombstone was written, a body was
  /// changed) where there is nothing to reconcile from the server.
  void _refreshFromStore() {
    if (!_alive) return;
    unawaited(() async {
      final msgs = await _store.cachedMessages(_conversationId);
      if (_alive) state = state.copyWith(messages: msgs);
    }());
  }

  Future<void> _pump() async {
    if (_isOnline) {
      await _sync.flush();
      await _reconcileFromServer();
    } else {
      final msgs = await _store.cachedMessages(_conversationId);
      state = state.copyWith(messages: msgs);
    }
  }

  /// Re-queues messages that failed to send and flushes the outbox.
  Future<void> retryFailed() async {
    final all = await _store.cachedMessages(_conversationId);
    final failed = all
        .where((m) => m.localState == MessageLocalState.failed)
        .toList();
    for (final m in failed) {
      await _store.upsertLocalMessage(
        m.copyWith(localState: MessageLocalState.queued),
      );
      await _store.enqueueOutbox(m);
    }
    if (failed.isNotEmpty) {
      state = state.copyWith(clearError: true);
      await _pump();
    }
  }

  /// Notifies the peer via broadcast that this user is typing.
  Future<void> sendTyping(bool isTyping) async {
    final me = _meId;
    if (me == null) return;
    await _realtime.sendTyping(_conversationId, userId: me, isTyping: isTyping);
  }

  // -- Reactions ---------------------------------------------------------------

  /// Places (or removes when [emoji] is null) my reaction on [messageId].
  ///
  /// Optimistic: the bubble updates instantly from SQLite while a copy waits
  /// in the reaction outbox for the next sync pass.
  Future<void> sendReaction({required String messageId, String? emoji}) async {
    final me = _meId;
    if (me == null) return;
    if (messageId.isEmpty) return;

    final next = <ChatMessage>[];
    List<MessageReaction>? targetReactions;
    for (final m in state.messages) {
      if (m.id == messageId || m.clientMessageId == messageId) {
        var reactions = List<MessageReaction>.from(m.reactions)
          ..removeWhere((r) => r.userId == me);
        if (emoji != null) {
          reactions.add(
            MessageReaction(
              userId: me,
              emoji: emoji,
              createdAt: DateTime.now(),
            ),
          );
        }
        final updated = m.copyWith(reactions: reactions);
        next.add(updated);
        targetReactions = reactions;
      } else {
        next.add(m);
      }
    }
    if (targetReactions != null) {
      state = state.copyWith(messages: next);
      await _store.updateReactions(messageId, targetReactions);
      await _store.enqueueReaction(messageId: messageId, emoji: emoji ?? '');
      _pump();
    }
  }
}

DateTime? parseDate(Object? value) {
  if (value == null || value is! String) return null;
  return DateTime.tryParse(value) ??
      DateTime.tryParse(value.replaceFirst(' ', 'T'));
}

final conversationPeerProvider = FutureProvider.family<UserProfile?, String>((
  ref,
  conversationId,
) async {
  final store = ref.read(localStoreProvider);
  final chats = await store.cachedConversations();
  final chat = chats.firstWhereOrNull((c) => c.id == conversationId);
  return chat?.peer ??
      (chat?.peers.isNotEmpty == true ? chat!.peers.first : null);
});
