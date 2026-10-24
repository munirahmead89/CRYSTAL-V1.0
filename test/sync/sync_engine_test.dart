import 'dart:convert';
import '../support/noop_relay_store.dart';

import 'package:crystal_messenger/core/database/database.dart';
import 'package:crystal_messenger/core/database/local_store.dart';
import 'package:crystal_messenger/core/sync/outbox_sync.dart';
import 'package:crystal_messenger/core/sync/sync_service.dart';
import 'package:crystal_messenger/features/conversations/domain/repositories/chat_repositories.dart';
import 'package:crystal_messenger/shared/models/chat_message.dart';
import 'package:crystal_messenger/shared/models/conversation.dart';
import 'package:crystal_messenger/shared/models/user_profile.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeMessagesRepository implements MessagesRepository {
  final List<ChatMessage> drafts = [];
  final List<(String, String?)> reactionCalls = [];
  Object? failWith;
  bool failSending = false;
  List<ChatMessage> after = const [];

  /// Paged responses for `getMessagesAfter`, consumed one per call.
  ///
  /// When non-empty this replaces [after], so a test can drive the sync engine's
  /// pagination loop: one entry per server page, in order.
  List<List<ChatMessage>> pages = const [];

  /// Every `afterId` the server was asked for, in call order.
  final List<String?> cursorsUsed = [];

  void _failIfNeeded() {
    if (failWith != null) throw failWith!;
    if (failSending) throw Exception('network down');
  }

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    String? before,
    int limit = 50,
  }) async => [];

  @override
  Future<List<ChatMessage>> getMessagesAfter(
    String conversationId, {
    required String? afterId,
    int limit = 100,
  }) async {
    cursorsUsed.add(afterId);
    if (pages.isEmpty) return after;
    final index = cursorsUsed.length - 1;
    if (index >= pages.length) return const [];
    return pages[index];
  }

  @override
  Future<ChatMessage> send(ChatMessage draft) async {
    _failIfNeeded();
    drafts.add(draft);
    return ChatMessage(
      id: 'server-${drafts.length}',
      clientMessageId: draft.id,
      conversationId: draft.conversationId,
      senderId: draft.senderId,
      type: draft.type,
      body: draft.body,
      attachment: draft.attachment,
      reactions: draft.reactions,
      replyToId: draft.replyToId,
      forwarded: draft.forwarded,
      createdAt: draft.createdAt,
      outgoing: draft.outgoing,
      localState: MessageLocalState.sent,
    );
  }

  @override
  Future<List<MessageReaction>> setReaction({
    required String messageId,
    String? emoji,
  }) async {
    _failIfNeeded();
    reactionCalls.add((messageId, emoji));
    return [
      if (emoji != null)
        MessageReaction(
          userId: draftSender,
          emoji: emoji,
          createdAt: DateTime.now(),
        ),
    ];
  }

  String get draftSender => drafts.isNotEmpty ? drafts.first.senderId : 'me';

  final edits = <({String messageId, String body})>[];

  @override
  Future<void> editText({
    required String messageId,
    required String body,
  }) async {
    _failIfNeeded();
    edits.add((messageId: messageId, body: body));
  }
}

class FakeConversationsRepository implements ConversationsRepository {
  List<ConversationSummary> chats = const [];

  @override
  Future<String> getOrCreateDirectConversation({
    required String peerId,
  }) async => 'conv-1';

  @override
  Future<ConversationSummary> createGroup({
    required String name,
    required List<String> memberIds,
  }) async =>
      ConversationSummary(id: 'conv-1', isGroup: true, displayName: name);

  @override
  Future<List<ConversationSummary>> getChats() async => chats;

  @override
  Future<void> markChatRead({
    required String conversationId,
    String? upToMessageId,
  }) async {}

  @override
  Future<int> deleteConversationMessages(String conversationId) async => 0;

  @override
  Future<void> setDisappearingMessages(
    String conversationId,
    int seconds,
  ) async {}

  @override
  Future<int> getDisappearingSeconds(String conversationId) async => 0;

  @override
  Future<void> markDelivered(List<String> messageIds) async {}
}

/// A faithful in-memory [LocalStore] so sync behaviour can be asserted
/// without a device (or a native SQLite binary).
class InMemoryStore with NoopRelayStore implements LocalStore {
  @override
  Future<List<({String conversationId, int bytes, int fileCount})>>
  mediaBytesByConversation() async => const [];

  @override
  Future<({Set<String> fileNames, Map<String, int> referenceCounts})>
  mediaFilesForConversation(String conversationId) async =>
      (fileNames: <String>{}, referenceCounts: <String, int>{});

  final Map<String, ChatMessage> messages = {};
  final Map<String, OutboxMessage> outbox = {};
  final Map<String, MessageReactionsOutboxData> reactions = {};
  final Map<String, String> cursors = {};
  final Map<String, String> syncState = {};
  final Map<String, ConversationSummary> conversations = {};
  final Map<String, UserProfile> profiles = {};
  final Map<String, String> userSettings = {};

  int _reactionAttempts(String messageId, String emoji) =>
      reactions['$messageId:$emoji']?.attemptCount ?? 0;

  @override
  Future<int> upsertWithTarget<T extends Table, D>(
    InsertStatement<T, D> statement,
    Insertable<D> entity,
    List<Column> target,
  ) => Future.value(0);

  @override
  Future<void> cacheUserSettings(String userId, String settingsJson) async {
    userSettings[userId] = settingsJson;
  }

  @override
  Future<String?> cachedUserSettings(String userId) async =>
      userSettings[userId];

  @override
  Future<String?> findDirectConversationWith(String peerId) async {
    for (final c in conversations.values) {
      if (!c.isGroup && c.peer?.id == peerId) return c.id;
    }
    return null;
  }

  @override
  Future<void> upsertProfile(UserProfile p) async {
    profiles[p.id] = p;
  }

  @override
  Future<UserProfile?> cachedProfile(String id) async => profiles[id];

  @override
  Future<List<UserProfile>> allCachedProfiles() async =>
      profiles.values.toList();

  @override
  Future<List<UserProfile>> cacheProfileByPhone(String phone) async =>
      profiles.values.where((p) => p.phone == phone.trim()).toList();

  @override
  Future<void> upsertConversation(ConversationSummary c) async {
    conversations[c.id] = c;
  }

  @override
  Future<void> upsertConversations(List<ConversationSummary> chats) async {
    for (final c in chats) {
      await upsertConversation(c);
    }
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    final c = conversations[conversationId];
    if (c != null) conversations[conversationId] = c.copyWith(unreadCount: 0);
  }

  @override
  Future<void> markMessagesRead(String conversationId) async {
    final now = DateTime.now();
    final updated = <String, ChatMessage>{};
    for (final entry in messages.entries) {
      final m = entry.value;
      updated[entry.key] =
          (!m.outgoing &&
              m.readAt == null &&
              m.conversationId == conversationId)
          ? m.copyWith(readAt: now, remoteStatus: RemoteStatus.seen)
          : m;
    }
    messages
      ..clear()
      ..addAll(updated);
  }

  @override
  Future<int> countUnreadIncoming(String conversationId) async {
    return messages.values
        .where(
          (m) =>
              m.conversationId == conversationId &&
              !m.outgoing &&
              m.readAt == null,
        )
        .length;
  }

  @override
  Future<Map<String, int>> countUnreadIncomingFor(
    List<String> conversationIds,
  ) async {
    final ids = conversationIds.toSet();
    final result = <String, int>{};
    for (final m in messages.values) {
      if (!ids.contains(m.conversationId) || m.outgoing || m.readAt != null) {
        continue;
      }
      result[m.conversationId] = (result[m.conversationId] ?? 0) + 1;
    }
    return result;
  }

  @override
  Future<List<ConversationSummary>> cachedConversations() async {
    final list = conversations.values.toList()
      ..sort((a, b) {
        final at = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final byTime = bt.compareTo(at);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return list;
  }

  @override
  Future<void> upsertLocalMessage(ChatMessage m) async {
    messages[m.id] = m;
  }

  @override
  Future<void> upsertRemoteMessage(ChatMessage m) async {
    final existing = messages[m.id] ?? messages[m.clientMessageId];
    if (existing == null) {
      await upsertLocalMessage(m);
      return;
    }
    final deliveredAt = existing.deliveredAt ?? m.deliveredAt;
    final readAt = existing.readAt ?? m.readAt;
    final remoteStatus = readAt != null
        ? RemoteStatus.seen
        : (deliveredAt != null ? RemoteStatus.delivered : m.remoteStatus);
    final keepLocalState =
        existing.localState == MessageLocalState.failed ||
        existing.localState == MessageLocalState.sending;
    await upsertLocalMessage(
      m.copyWith(
        deliveredAt: deliveredAt,
        readAt: readAt,
        remoteStatus: remoteStatus,
        reactions: m.reactions.isNotEmpty ? m.reactions : existing.reactions,
        localState: keepLocalState ? existing.localState : m.localState,
      ),
    );
  }

  @override
  Future<void> replaceLocalMessage(
    String clientMessageId,
    ChatMessage serverMessage,
  ) async {
    messages.remove(clientMessageId);
    await upsertLocalMessage(serverMessage);
  }

  @override
  Future<void> markLocalFailed(String clientMessageId) async {
    final m = messages[clientMessageId];
    if (m != null) {
      messages[clientMessageId] = m.copyWith(
        localState: MessageLocalState.failed,
      );
    }
  }

  @override
  Future<LocalMessage?> findLocal(String id) async {
    final m = messages[id];
    return m == null ? null : _toLocalMessage(m);
  }

  @override
  Future<List<ChatMessage>> cachedMessages(String conversationId) async {
    final list =
        messages.values
            .where((m) => m.conversationId == conversationId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<({List<ChatMessage> messages, bool hasMore})> cachedMessagesPage(
    String conversationId, {
    int limit = 60,
    DateTime? before,
  }) async {
    final all =
        messages.values
            .where((m) => m.conversationId == conversationId)
            .where((m) => before == null || m.createdAt.isBefore(before))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final hasMore = all.length > limit;
    final page = all.take(limit).toList().reversed.toList();
    return (messages: page, hasMore: hasMore);
  }

  @override
  Future<ChatMessage?> newestOutgoing(String conversationId) async {
    final outgoing =
        messages.values
            .where((m) => m.conversationId == conversationId && m.outgoing)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return outgoing.isEmpty ? null : outgoing.first;
  }

  @override
  Future<void> deleteConversationLocally(String conversationId) async {
    messages.removeWhere((_, m) => m.conversationId == conversationId);
  }

  @override
  Future<List<ChatMessage>> appLocalMessages({int limit = 500}) async =>
      messages.values.take(limit).toList();

  @override
  Future<void> deleteLocal(String clientMessageId) async {
    messages.remove(clientMessageId);
  }

  @override
  Future<void> updateReceipt({
    required String serverId,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) async {
    final m = messages[serverId];
    if (m == null) return;
    final remoteStatus = readAt != null
        ? RemoteStatus.seen
        : (deliveredAt != null ? RemoteStatus.delivered : m.remoteStatus);
    messages[serverId] = m.copyWith(
      deliveredAt: deliveredAt ?? m.deliveredAt,
      readAt: readAt ?? m.readAt,
      remoteStatus: remoteStatus,
    );
  }

  @override
  Future<void> updateReactions(
    String messageId,
    List<MessageReaction> reactions,
  ) async {
    final m = messages[messageId];
    if (m == null) return;
    messages[messageId] = m.copyWith(reactions: reactions);
  }

  @override
  Future<void> enqueueReaction({
    required String messageId,
    required String emoji,
  }) async {
    final key = '$messageId:$emoji';
    reactions[key] = MessageReactionsOutboxData(
      messageId: messageId,
      emoji: emoji,
      attemptCount: _reactionAttempts(messageId, emoji),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> removeReactionFromOutbox(String messageId, String emoji) async {
    reactions.remove('$messageId:$emoji');
  }

  @override
  Future<List<MessageReactionsOutboxData>> pendingReactions() async =>
      reactions.values.toList();

  @override
  Future<void> markReactionAttempted(
    String messageId,
    String emoji,
    int attempt,
  ) async {
    final key = '$messageId:$emoji';
    final row = reactions[key];
    if (row != null) {
      reactions[key] = MessageReactionsOutboxData(
        messageId: row.messageId,
        emoji: row.emoji,
        attemptCount: attempt,
        createdAt: row.createdAt,
      );
    }
  }

  @override
  Future<void> enqueueOutbox(ChatMessage m) async {
    outbox[m.clientMessageId] = OutboxMessage(
      id: m.clientMessageId,
      ownerId: '',
      clientMessageId: m.clientMessageId,
      conversationId: m.conversationId,
      type: m.type,
      body: m.body,
      mediaJson: m.attachment == null
          ? null
          : jsonEncode(m.attachment!.toJson()),
      forwarded: m.forwarded,
      attemptCount: 0,
      status: 0,
      createdAt: m.createdAt,
    );
  }

  @override
  Future<List<OutboxMessage>> pendingOutbox() async {
    final list = outbox.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<void> removeFromOutbox(String id) async {
    outbox.remove(id);
  }

  @override
  Future<int> pendingOutboxCount() async => outbox.length;

  @override
  Future<void> updateOutboxMedia(String id, String? mediaJson) async {
    final row = outbox[id];
    if (row == null) return;
    outbox[id] = row.copyWith(mediaJson: Value(mediaJson), attemptCount: 0);
  }

  @override
  Future<void> markOutboxAttempted(String id, int attempt) async {
    final row = outbox[id];
    if (row != null) {
      outbox[id] = OutboxMessage(
        id: row.id,
        ownerId: '',
        clientMessageId: row.clientMessageId,
        conversationId: row.conversationId,
        type: row.type,
        body: row.body,
        mediaJson: row.mediaJson,
        forwarded: row.forwarded,
        attemptCount: attempt,
        status: row.status,
        createdAt: row.createdAt,
      );
    }
  }

  @override
  Future<String?> getDeviceCursor(String key) async => cursors[key];

  @override
  Future<void> setDeviceCursor(String key, String? cursor) async {
    if (cursor == null) {
      cursors.remove(key);
    } else {
      cursors[key] = cursor;
    }
  }

  @override
  Future<String?> getSyncValue(String key) async => syncState[key];

  @override
  Future<void> setSyncValue(String key, String value) async {
    syncState[key] = value;
  }

  LocalMessage _toLocalMessage(ChatMessage m) => LocalMessage(
    id: m.id,
    ownerId: '',
    clientMessageId: m.clientMessageId,
    conversationId: m.conversationId,
    senderId: m.senderId,
    type: m.type,
    body: m.body,
    mediaJson: m.attachment == null ? null : jsonEncode(m.attachment!.toJson()),
    reactionsJson: m.reactions.isEmpty
        ? null
        : jsonEncode(m.reactions.map((r) => r.toJson()).toList()),
    replyToId: m.replyToId,
    forwarded: m.forwarded,
    retentionState: 'retained',
    schemaVersion: 1,
    encryptionVersion: 0,
    serverCreatedAt: null,
    deletedAt: null,
    localState: m.localState.name,
    remoteStatus: m.remoteStatus.name,
    createdAt: m.createdAt,
    updatedAt: null,
    outgoing: m.outgoing,
    deleted: m.deleted,
    deliveredAt: m.deliveredAt,
    readAt: m.readAt,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ChatMessage _draft({String id = 'local-1'}) => ChatMessage(
  id: id,
  clientMessageId: id,
  conversationId: 'c1',
  senderId: 'me',
  body: 'hello',
  createdAt: DateTime.now(),
  outgoing: true,
  localState: MessageLocalState.queued,
);

ChatMessage _serverMessage({String id = 'server-1', DateTime? createdAt}) =>
    ChatMessage(
      id: id,
      clientMessageId: id,
      conversationId: 'c1',
      senderId: 'them',
      body: 'hi',
      createdAt: createdAt ?? DateTime.now(),
      outgoing: false,
    );

InMemoryStore _store() => InMemoryStore();

OutboxSyncEngine _outbox(InMemoryStore store, FakeMessagesRepository repo) =>
    OutboxSyncEngine(
      store: store,
      messagesRepository: repo,
      getMyId: () => 'me',
    );

SyncService _sync(
  InMemoryStore store,
  FakeMessagesRepository messages,
  FakeConversationsRepository conversations,
) => SyncService(
  store: store,
  conversationsRepository: conversations,
  messagesRepository: messages,
  outbox: _outbox(store, messages),
  getMyId: () => 'me',
);

void main() {
  group('OutboxSyncEngine', () {
    test(
      'pushes a queued message to the server and replaces it locally',
      () async {
        final store = _store();
        final repo = FakeMessagesRepository();
        final draft = _draft();
        await store.upsertLocalMessage(draft);
        await store.enqueueOutbox(draft);

        final result = await _outbox(store, repo).flush();

        expect(result.pushedMessages, 1);
        expect(result.pendingMessages, isFalse);
        expect(repo.drafts.single.body, 'hello');
        expect(await store.pendingOutbox(), isEmpty);
        final cached = await store.cachedMessages('c1');
        expect(cached.single.id, 'server-1');
        expect(cached.single.localState, MessageLocalState.sent);
      },
    );

    test('keeps the row queued after the cap so nothing is ever lost', () async {
      final store = _store();
      final repo = FakeMessagesRepository()..failSending = true;
      final draft = _draft();
      await store.upsertLocalMessage(draft);
      await store.enqueueOutbox(draft);

      for (var i = 0; i < OutboxSyncEngine.maxAttempts; i++) {
        await _outbox(store, repo).flush();
      }

      // The row is RETAINED. Deleting it here is what used to strand a message
      // permanently: the user could see it in the thread, but no future pass
      // would ever send it. A message already shown to the user is a promise.
      expect(await store.pendingOutbox(), hasLength(1));
      expect(repo.drafts, isEmpty);

      // The UI still gets its retry affordance.
      final cached = await store.cachedMessages('c1');
      expect(cached.single.localState, MessageLocalState.failed);

      // And it goes out as soon as the server is reachable again.
      repo.failSending = false;
      await _outbox(store, repo).flush();
      expect(repo.drafts.single.body, 'hello');
      expect(await store.pendingOutbox(), isEmpty);
    });

    test('a permanently failing row does not block later messages', () async {
      final store = _store();
      final repo = FakeMessagesRepository();
      final doomed = _draft();
      await store.upsertLocalMessage(doomed);
      await store.enqueueOutbox(doomed);

      repo.failSending = true;
      for (var i = 0; i < OutboxSyncEngine.maxAttempts; i++) {
        await _outbox(store, repo).flush();
      }

      // A second message must still get out even though an earlier one is
      // stuck: the stuck row is a permanent no-op, not a head-of-line block.
      repo.failSending = false;
      final next = ChatMessage(
        id: 'm-2',
        clientMessageId: 'm-2',
        conversationId: 'c1',
        senderId: 'u1',
        body: 'second',
        createdAt: DateTime.now(),
        outgoing: true,
        localState: MessageLocalState.queued,
      );
      await store.upsertLocalMessage(next);
      await store.enqueueOutbox(next);

      await _outbox(store, repo).flush();
      expect(repo.drafts.map((d) => d.body), contains('second'));
    });

    test('flushes reactions once the server is reachable', () async {
      final store = _store();
      final repo = FakeMessagesRepository();
      await store.upsertLocalMessage(_serverMessage());
      await store.enqueueReaction(messageId: 'server-1', emoji: '\u2764\ufe0f');

      final result = await _outbox(store, repo).flush();

      expect(result.pushedReactions, 1);
      expect(repo.reactionCalls.single, ('server-1', '\u2764\ufe0f'));
      expect(await store.pendingReactions(), isEmpty);
    });
  });

  group('SyncService', () {
    test(
      'never deletes local rows when the server returns an empty list',
      () async {
        final store = _store();
        await store.upsertConversation(
          const ConversationSummary(
            id: 'c1',
            displayName: 'Sam',
            lastMessageType: 'text',
          ),
        );
        await store.upsertLocalMessage(_serverMessage());
        await store.enqueueOutbox(_draft());

        final result = await _sync(
          store,
          FakeMessagesRepository(),
          FakeConversationsRepository(),
        ).syncIncremental();

        expect(result.messagesSynced, 0);
        expect((await store.cachedConversations()).length, 1);
        expect((await store.cachedMessages('c1')).length, 1);
        // The queued message was STILL flushed — the cache was never cleared.
        expect(await store.pendingOutbox(), isEmpty);
      },
    );

    test(
      'advances the per-device cursor only when fresh rows arrive',
      () async {
        final store = _store();
        final now = DateTime.now();
        final messages = FakeMessagesRepository()
          ..after = [
            _serverMessage(
              id: 'srv-a',
              createdAt: now.subtract(const Duration(minutes: 2)),
            ),
            _serverMessage(id: 'srv-b', createdAt: now),
          ];

        await _sync(
          store,
          messages,
          FakeConversationsRepository(),
        ).syncConversation('c1');

        expect(await store.getDeviceCursor('messages:c1'), 'srv-b');
        expect((await store.cachedMessages('c1')).length, 2);

        messages.after = [];
        final second = await _sync(
          store,
          messages,
          FakeConversationsRepository(),
        ).syncConversation('c1');
        expect(second.messagesSynced, 0);
        expect(await store.getDeviceCursor('messages:c1'), 'srv-b');
        expect((await store.cachedMessages('c1')).length, 2);
      },
    );

    test(
      'never stores a cursor ahead of the server row it is based on',
      () async {
        final store = _store();
        final messages = FakeMessagesRepository()..after = const [];
        await _sync(
          store,
          messages,
          FakeConversationsRepository(),
        ).syncConversation('c1');
        expect(await store.getDeviceCursor('messages:c1'), isNull);
      },
    );

    // --- pagination ---------------------------------------------------------
    //
    // The original implementation fetched ONE page capped at syncWindow and
    // then moved the cursor to the newest row in that page. Anything beyond the
    // window was skipped by every future sync, so going offline across a busy
    // conversation silently lost exactly those messages.

    List<ChatMessage> serverPage(int count, {int startAt = 0}) => List.generate(
      count,
      (i) => _serverMessage(
        id: 'id-${(startAt + i).toString().padLeft(4, '0')}',
        createdAt: DateTime.utc(2026, 1, 1, 12, startAt + i),
      ),
    );

    test('keeps fetching until the server returns a partial page', () async {
      final store = _store();
      final messages = FakeMessagesRepository()
        ..pages = [
          serverPage(SyncService.syncWindow),
          serverPage(3, startAt: 900),
        ];

      final result = await _sync(
        store,
        messages,
        FakeConversationsRepository(),
      ).syncConversation('c1');

      expect(messages.cursorsUsed.length, 2);
      expect(messages.cursorsUsed.first, isNull);
      expect(
        messages.cursorsUsed[1],
        'id-${(SyncService.syncWindow - 1).toString().padLeft(4, '0')}',
        reason: 'page two must resume from the newest row of page one',
      );
      expect(result.messagesSynced, SyncService.syncWindow + 3);
    });

    test('a backlog larger than one window is fully drained', () async {
      final store = _store();
      final overflow = SyncService.syncWindow + 25;
      final messages = FakeMessagesRepository()
        ..pages = [
          serverPage(SyncService.syncWindow),
          serverPage(25, startAt: SyncService.syncWindow),
        ];

      await _sync(
        store,
        messages,
        FakeConversationsRepository(),
      ).syncConversation('c1');

      expect(
        await store.getDeviceCursor('messages:c1'),
        'id-${(overflow - 1).toString().padLeft(4, '0')}',
        reason: 'the watermark must land past every row, not just page one',
      );
    });

    test('a short backlog still advances the cursor', () async {
      // Regression guard for the pagination change itself: advancing only on a
      // FULL page left the watermark behind whenever fewer than syncWindow rows
      // were pending, so every later sync re-read the same rows.
      final store = _store();
      final messages = FakeMessagesRepository()
        ..pages = [
          [
            _serverMessage(id: 'srv-a', createdAt: DateTime.utc(2026, 1, 1)),
            _serverMessage(
              id: 'srv-b',
              createdAt: DateTime.utc(2026, 1, 1, 0, 1),
            ),
          ],
        ];

      final result = await _sync(
        store,
        messages,
        FakeConversationsRepository(),
      ).syncConversation('c1');

      expect(result.messagesSynced, 2);
      expect(await store.getDeviceCursor('messages:c1'), 'srv-b');
    });

    test(
      'paging stops at maxPagesPerSync rather than looping forever',
      () async {
        // A server that keeps returning full pages would spin indefinitely.
        final store = _store();
        final messages = FakeMessagesRepository()
          ..pages = [
            for (var i = 0; i < 200; i++)
              serverPage(
                SyncService.syncWindow,
                startAt: i * SyncService.syncWindow,
              ),
          ];

        final result = await _sync(
          store,
          messages,
          FakeConversationsRepository(),
        ).syncConversation('c1');

        expect(messages.cursorsUsed.length, SyncService.maxPagesPerSync);
        expect(result.messagesSynced, greaterThan(0));
      },
    );

    test('a cursor that cannot advance stops the loop', () async {
      // The same newest id on every page: the watermark would never move, so
      // without the guard the loop would re-read one page forever.
      final store = _store();
      final stuck = serverPage(SyncService.syncWindow);
      final messages = FakeMessagesRepository()
        ..pages = [for (var i = 0; i < 20; i++) stuck];

      final result = await _sync(
        store,
        messages,
        FakeConversationsRepository(),
      ).syncConversation('c1');

      // messagesSynced counts upserts, not distinct rows, and page two repeats
      // page one's ids, so two full pages report 200.
      expect(result.messagesSynced, SyncService.syncWindow * 2);
      expect(
        messages.cursorsUsed.length,
        2,
        reason:
            'page one sets the cursor, page two finds it unchanged and stops',
      );
    });
  });
}
