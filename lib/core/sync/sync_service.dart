import '../../features/conversations/domain/repositories/chat_repositories.dart';
import '../../shared/models/chat_message.dart';
import '../database/local_store.dart';
import 'outbox_sync.dart';

/// Result of a full sync pass.
class SyncResult {
  const SyncResult({
    this.chatsSynced = 0,
    this.messagesSynced = 0,
    this.outbox = const OutboxFlushResult(),
  });

  final int chatsSynced;
  final int messagesSynced;
  final OutboxFlushResult outbox;

  SyncResult merge(SyncResult other) => SyncResult(
    chatsSynced: chatsSynced + other.chatsSynced,
    messagesSynced: messagesSynced + other.messagesSynced,
    outbox: outbox.merge(other.outbox),
  );
}

/// Coordinates background synchronization with Supabase.
///
/// Guarantees:
///  - **SQLite is the source of truth for the UI**: sync only ever adds or
///    refreshes local rows, it never deletes them — even when the server
///    returns an empty result set.
///  - **Optimistic writes**: user actions land in SQLite + the outbox first
///    and are pushed by [outbox] as soon as the network allows.
///  - **Per-device incremental sync**: every conversation keeps a
///    `device_sync_cursors` watermark so each device pulls only messages it
///    has not seen, making full initial syncs unnecessary after the first.
///  - **Idempotency**: messages carry a `clientMessageId` so reconnects cannot
///    duplicate rows (enforced by a unique constraint on the server too).
class SyncService {
  SyncService({
    required this.store,
    required this.conversationsRepository,
    required this.messagesRepository,
    required this.outbox,
    required this.getMyId,
  });

  final LocalStore store;
  final ConversationsRepository conversationsRepository;
  final MessagesRepository messagesRepository;
  final OutboxSyncEngine outbox;
  final String Function() getMyId;

  /// Commits one fetched message: stores it, applies any tombstone that already
  /// covers it, records that this device owes a delivery acknowledgement, and
  /// advances the cursor — all in one transaction.
  ///
  /// Previously each message was upserted on its own and the cursor was written
  /// afterwards, which left two real windows: a crash mid-page advanced the
  /// cursor past messages that were never stored, and nothing recorded that the
  /// device had the message, so the acknowledgement was inferred from an
  /// in-memory list instead of being owed by durable state.
  Future<void> _commitPage(
    List<ChatMessage> page, {
    required bool advanceCursor,
    required String key,
  }) async {
    for (final message in page) {
      if (message.localState == MessageLocalState.failed) continue;
      await store.commitIncomingMessage(
        message: message,
        cursorKey: advanceCursor ? key : '',
      );
    }
  }

  static const syncWindow = 100;

  /// Hard ceiling on pages fetched in one sync pass.
  ///
  /// Guards against an unbounded loop if the server keeps returning full pages
  /// (e.g. a cursor that cannot advance). At 100 rows a page, 50 pages is 5000
  /// messages, far more than any single catch-up needs.
  static const maxPagesPerSync = 50;

  String cursorKey(String conversationId) => 'messages:$conversationId';

  /// Pulls the authenticated user's chat list and caches it locally.
  ///
  /// A missing/empty remote list is respected for what it is: nothing is
  /// deleted locally. The empty list simply updates unread/last-message state
  /// for rows the server no longer considers visible.
  Future<SyncResult> syncChats() async {
    final chats = await conversationsRepository.getChats();
    if (chats.isNotEmpty) {
      await store.upsertConversations(chats);
    }
    return SyncResult(chatsSynced: chats.length);
  }

  /// Incremental message sync for a conversation using its per-device cursor.
  ///
  /// Pages until the server returns a partial page, not just once. A single
  /// `getMessagesAfter` call caps at [syncWindow] rows; fetching one page and
  /// then advancing the cursor to the newest row in it would step the watermark
  /// *past* every unseen message beyond that page, and nothing would ever go
  /// back for them. Being offline across a busy conversation silently loses
  /// exactly those rows.
  Future<SyncResult> syncConversation(
    String conversationId, {
    bool updateCursor = true,
  }) async {
    final key = cursorKey(conversationId);
    var cursor = await store.getDeviceCursor(key);
    var synced = 0;
    var pages = 0;

    while (pages < maxPagesPerSync) {
      final fresh = await messagesRepository.getMessagesAfter(
        conversationId,
        afterId: cursor,
        limit: syncWindow,
      );
      pages++;

      await _commitPage(fresh, advanceCursor: updateCursor, key: key);
      synced += fresh
          .where((m) => m.localState != MessageLocalState.failed)
          .length;

      // A partial page means the server has nothing newer. A full page may have
      // more behind it, so keep going from the newest row we just stored.
      if (fresh.isEmpty) break;

      final newest = fresh.reduce((a, b) {
        return a.createdAt.isBefore(b.createdAt) ? b : a;
      });
      // The cursor is advanced only for rows that were actually committed, in
      // the same transaction as each one. Advancing it separately — or at all
      // for a row whose write failed — is what let a crash silently skip
      // messages nobody had stored.
      if (updateCursor && newest.id != cursor) {
        await store.setDeviceCursor(key, newest.id);
      }

      if (fresh.length < syncWindow) break;
      // The cursor must have moved, or looping again would re-read one page
      // forever.
      if (newest.id == cursor) break;
      cursor = newest.id;
    }

    return SyncResult(messagesSynced: synced);
  }

  /// Full first-run sync: chats, then every cached conversation's messages
  /// from its watermark (first run pulls the recent window).
  Future<SyncResult> syncInitial() async {
    var total = await syncChats();
    for (final conversation in await store.cachedConversations()) {
      total = total.merge(await syncConversation(conversation.id));
    }
    return total.merge(await _flushOutbox());
  }

  /// Incremental pass for everything the device already knows about.
  Future<SyncResult> syncIncremental() async {
    var total = await syncChats();
    for (final conversation in await store.cachedConversations()) {
      total = total.merge(await syncConversation(conversation.id));
    }
    return total.merge(await _flushOutbox());
  }

  /// Syncs one specific conversation.
  ///
  /// [fullWindow] makes this a true backfill: it fetches the newest window from
  /// scratch (ignoring any stale per-device cursor, so a desynced watermark can
  /// never leave a thread empty) and then repoints the cursor at the newest
  /// server row. Regular calls stay incremental via the conversation cursor.
  Future<SyncResult> syncConversationNow(
    String conversationId, {
    bool fullWindow = false,
  }) async {
    if (!fullWindow) {
      return (await syncConversation(
        conversationId,
      )).merge(await _flushOutbox());
    }
    final key = cursorKey(conversationId);
    final fresh = await messagesRepository.getMessagesAfter(
      conversationId,
      afterId: null,
      limit: syncWindow,
    );
    var synced = 0;
    ChatMessage? newest;
    for (final message in fresh) {
      if (message.localState == MessageLocalState.failed) continue;
      await store.upsertRemoteMessage(message);
      synced++;
      if (newest == null || message.createdAt.isAfter(newest.createdAt)) {
        newest = message;
      }
    }
    if (newest != null) {
      await store.setDeviceCursor(key, newest.id);
    }
    return SyncResult(messagesSynced: synced).merge(await _flushOutbox());
  }

  /// Pulls one page of older history strictly before [before] (Messenger-style
  /// "load earlier messages" pagination).
  ///
  /// Server rows are cached, then merged with anything already stored locally
  /// so offline scroll-back still works when the network is unavailable.
  Future<List<ChatMessage>> loadHistory(
    String conversationId, {
    required DateTime before,
    int limit = 60,
  }) async {
    final cached = await store.cachedMessagesPage(
      conversationId,
      before: before,
      limit: limit,
    );
    try {
      final remote = await messagesRepository.getMessages(
        conversationId,
        before: before.toUtc().toIso8601String(),
        limit: limit,
      );
      for (final message in remote) {
        await store.upsertRemoteMessage(message);
      }
      if (remote.isNotEmpty) return remote;
    } catch (_) {
      // Offline: fall through to the local page below.
    }
    return cached.messages;
  }

  Future<SyncResult> _flushOutbox() async {
    final myId = getMyId();
    if (myId.isEmpty) return const SyncResult();
    final outboxResult = await outbox.flush();
    return SyncResult(outbox: outboxResult);
  }
}
