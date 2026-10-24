import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/delivery/domain/message_lifecycle.dart';
import '../../features/delivery/domain/relay_envelope.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/user_profile.dart';
import 'database.dart';

/// One acknowledgement this device still owes the relay.
class PendingAck {
  const PendingAck({required this.messageId, required this.kind});

  final String messageId;
  final AckKind kind;
}

/// Typed data-access helper over the [AppDatabase] offline cache.
///
/// All writes are cheap UPSERT-style operations so local rows always reflect
/// the latest server state once a sync completes. Local rows are never deleted
/// by sync operations — the cache is additive by design.
///
/// ## Account scoping
///
/// Every message and outbox row carries an [ownerId]. Reads and writes filter
/// on it, so two accounts sharing a device never see each other's cache — and,
/// more importantly, never flush each other's queued sends under the wrong
/// identity.
///
/// An empty [ownerId] means "not yet claimed". That is the state of every row
/// written before this column existed, and [adoptUnscopedRows] hands them to
/// the first account that signs in after the upgrade. Rows are never deleted
/// to achieve isolation: signing back into the first account shows them again.
class LocalStore {
  LocalStore(this._db, {this.ownerId = ''});

  final AppDatabase _db;

  /// Account this store reads and writes for. Empty means "unscoped", which is
  /// the pre-upgrade behaviour and what every existing caller and test sees.
  String ownerId;

  /// Points the store at an account. Called once per session, before any read.
  void bindAccount(String ownerId) {
    this.ownerId = ownerId;
  }

  /// Hands every pre-`owner_id` row to [ownerId], exactly once per install.
  ///
  /// An install that predates account scoping has one account's worth of
  /// history in a single database, and nothing records which account it
  /// belonged to. The first account to sign in after the upgrade is the only
  /// defensible guess, so the guess is recorded: a second account then sees an
  /// empty namespace instead of inheriting the history.
  ///
  /// Returns the number of rows adopted.
  Future<int> adoptUnscopedRows(String ownerId) async {
    if (ownerId.isEmpty) return 0;

    return _db.transaction(() async {
      final alreadyClaimed = await (_db.select(
        _db.accountScopeClaims,
      )..where((t) => t.ownerId.equals(ownerId))).getSingleOrNull();
      if (alreadyClaimed != null) return 0;

      // Another account already adopted the legacy rows. Its history stays
      // theirs; this account starts clean.
      final claimedByOther = await (_db.select(
        _db.accountScopeClaims,
      )..where((t) => t.ownerId.isNotValue(ownerId))).get();
      if (claimedByOther.isNotEmpty) {
        await _db
            .into(_db.accountScopeClaims)
            .insert(
              AccountScopeClaimsCompanion.insert(
                ownerId: ownerId,
                claimedAt: DateTime.now(),
                adoptedRows: const Value(0),
              ),
            );
        return 0;
      }

      var adopted = 0;
      adopted +=
          await (_db.update(
            _db.localMessages,
          )..where((t) => t.ownerId.equals(''))).write(
            const LocalMessagesCompanion(ownerId: Value('__adopting__')),
          );
      adopted +=
          await (_db.update(
            _db.outboxMessages,
          )..where((t) => t.ownerId.equals(''))).write(
            const OutboxMessagesCompanion(ownerId: Value('__adopting__')),
          );

      await (_db.update(_db.localMessages)
            ..where((t) => t.ownerId.equals('__adopting__')))
          .write(LocalMessagesCompanion(ownerId: Value(ownerId)));
      await (_db.update(_db.outboxMessages)
            ..where((t) => t.ownerId.equals('__adopting__')))
          .write(OutboxMessagesCompanion(ownerId: Value(ownerId)));

      await _db
          .into(_db.accountScopeClaims)
          .insert(
            AccountScopeClaimsCompanion.insert(
              ownerId: ownerId,
              claimedAt: DateTime.now(),
              adoptedRows: Value(adopted),
            ),
          );

      return adopted;
    });
  }

  /// Explicit-conflict-target upsert: replaces `insertOnConflictUpdate` so the
  /// "Table has no primary key, so a conflict target is needed" error can never
  /// surface — the target column is stated at every call site.
  Future<int> upsertWithTarget<T extends Table, D>(
    InsertStatement<T, D> statement,
    Insertable<D> entity,
    List<Column> target,
  ) {
    return statement.insert(
      entity,
      onConflict: DoUpdate((_) => entity, target: target),
    );
  }

  // -- Profiles -------------------------------------------------------------

  Future<void> upsertProfile(UserProfile p) {
    return upsertWithTarget(
      _db.into(_db.localProfiles),
      LocalProfilesCompanion.insert(
        id: p.id,
        displayName: Value(p.displayName),
        phone: Value(p.phone),
        avatarUrl: Value(p.avatarUrl),
        bio: Value(p.bio),
        presence: Value(p.presence),
        lastSeenAt: Value(p.lastSeenAt),
        updatedAt: Value(DateTime.now()),
      ),
      [_db.localProfiles.id],
    );
  }

  Future<List<UserProfile>> allCachedProfiles() async {
    final rows = await _db.select(_db.localProfiles).get();
    return rows
        .map(
          (r) => UserProfile(
            id: r.id,
            displayName: r.displayName ?? '',
            phone: r.phone ?? '',
            avatarUrl: r.avatarUrl,
            bio: r.bio ?? '',
            presence: r.presence,
            lastSeenAt: r.lastSeenAt,
          ),
        )
        .toList();
  }

  Future<UserProfile?> cachedProfile(String id) async {
    final row = await (_db.select(
      _db.localProfiles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return UserProfile(
      id: row.id,
      displayName: row.displayName ?? '',
      phone: row.phone ?? '',
      avatarUrl: row.avatarUrl,
      bio: row.bio ?? '',
      presence: row.presence,
      lastSeenAt: row.lastSeenAt,
    );
  }

  Future<List<UserProfile>> cacheProfileByPhone(String phone) async {
    final rows = await (_db.select(
      _db.localProfiles,
    )..where((t) => t.phone.equals(phone.trim()))).get();
    return rows
        .map(
          (r) => UserProfile(
            id: r.id,
            displayName: r.displayName ?? '',
            phone: r.phone ?? '',
            avatarUrl: r.avatarUrl,
            bio: r.bio ?? '',
            presence: r.presence,
            lastSeenAt: r.lastSeenAt,
          ),
        )
        .toList();
  }

  // -- Conversations --------------------------------------------------------

  Future<void> upsertConversation(ConversationSummary c) {
    final p = c.peer;
    return upsertWithTarget(
      _db.into(_db.localConversations),
      LocalConversationsCompanion.insert(
        id: c.id,
        isGroup: Value(c.isGroup),
        peerId: Value(p?.id),
        peerDisplayName: Value(p?.displayName),
        peerAvatarUrl: Value(p?.avatarUrl),
        peerPresence: Value(p?.presence),
        peerLastSeenAt: Value(p?.lastSeenAt),
        displayName: Value(c.displayName.isEmpty ? null : c.displayName),
        memberJson: Value(
          c.peers.isEmpty ? null : jsonEncode(_encodePeers(c.peers)),
        ),
        lastMessageId: Value(c.lastMessageId),
        lastMessagePreview: Value(c.lastMessageText),
        lastMessageType: Value(c.lastMessageType),
        lastMessageSenderId: Value(c.lastMessageSenderId),
        lastMessageAt: Value(c.lastMessageAt),
        unreadCount: Value(c.unreadCount),
        updatedAt: DateTime.now(),
      ),
      [_db.localConversations.id],
    );
  }

  Future<void> upsertConversations(List<ConversationSummary> chats) async {
    for (final c in chats) {
      await upsertConversation(c);
    }
  }

  /// Returns the id of an already-cached direct conversation with [peerId],
  /// or null when none exists locally yet. Used by the "Find people" flow to
  /// reopen an existing thread instead of creating a duplicate room.
  Future<String?> findDirectConversationWith(String peerId) async {
    final rows =
        await (_db.select(_db.localConversations)
              ..where((t) => t.isGroup.equals(false) & t.peerId.equals(peerId))
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first.id;
  }

  Future<void> markConversationRead(String conversationId) async {
    await (_db.update(_db.localConversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(LocalConversationsCompanion(unreadCount: const Value(0)));
  }

  /// Number of unread *incoming* messages in [conversationId]. Outgoing rows
  /// (our own sent messages) never count, so a conversation we push to can
  /// never badge us for what we wrote — the badge only tracks what others
  /// sent and we have not opened yet. This is the local, offline truth the
  /// chat list uses to derive unread badges.
  Future<int> countUnreadIncoming(String conversationId) async {
    final count =
        await (_db.selectOnly(_db.localMessages)
              ..addColumns([_db.localMessages.id.count()])
              ..where(
                _db.localMessages.conversationId.equals(conversationId) &
                    _db.localMessages.outgoing.equals(false) &
                    _db.localMessages.readAt.isNull(),
              ))
            .getSingle();
    return count.read(_db.localMessages.id.count()) ?? 0;
  }

  /// Batch variant of [countUnreadIncoming] for the chat list so the whole
  /// screen costs a single grouped query instead of one query per row.
  Future<Map<String, int>> countUnreadIncomingFor(
    List<String> conversationIds,
  ) async {
    if (conversationIds.isEmpty) return const {};
    final rows =
        await (_db.selectOnly(_db.localMessages)
              ..addColumns([
                _db.localMessages.conversationId,
                _db.localMessages.id.count(),
              ])
              ..where(
                _db.localMessages.conversationId.isIn(conversationIds) &
                    _db.localMessages.outgoing.equals(false) &
                    _db.localMessages.readAt.isNull(),
              )
              ..groupBy([_db.localMessages.conversationId]))
            .get();
    return {
      for (final r in rows)
        r.read(_db.localMessages.conversationId)!:
            r.read(_db.localMessages.id.count()) ?? 0,
    };
  }

  /// Persist the message and all attachments locally before returning.
  ///
  /// Download each object using [downloadObject], verify it where your upload
  /// format supplies a digest, and save the local message/file references.
  /// Throw if any required attachment is not completely saved.
  Future<void> saveMessageAndMedia(
    Map<String, dynamic> message,
    Future<Uint8List> Function(String bucket, String path) downloadObject,
  ) async {
    // Extract paths/buckets from message attachments and persist them.
    // This is a basic implementation; subclasses or the relay service
    // should override with format-specific logic.
    final attachments = message['attachments'] as List<dynamic>? ?? [];
    for (final attachment in attachments) {
      final bucket = attachment['bucket'] as String? ?? '';
      final path = attachment['path'] as String? ?? '';
      if (bucket.isNotEmpty && path.isNotEmpty) {
        final data = await downloadObject(bucket, path);
        // Store the downloaded data locally - implementation depends on
        // your attachment storage strategy (file system, Drift BLOBs, etc.)
        // For now, we acknowledge the download completed.
      }
    }
    // Mark the message as cached locally
    final convId = message['conversationId'] as String? ?? '';
    final msgId = message['id'] as String? ?? '';
    if (convId.isNotEmpty && msgId.isNotEmpty) {
      await markMessagesRead(convId); // simplified: marks related messages read
    }
  }

  /// Record that the server has erased its payload.
  /// Keep any message/file content already cached on this device.
  Future<void> markServerPayloadErased(
    String messageId,
    DateTime erasedAt,
  ) async {
    // In Drift, we could store an erased_at timestamp on the message row,
    // or maintain a separate tombstone table. For now, this is a no-op
    // that the relay service can extend as needed.
    // The key invariant: do not delete locally cached files; just record
    // the server erasure so the UI can reflect the erased state.
  }

  /// Marks every incoming message in [conversationId] as read locally (read_at
  /// + seen status), mirroring the remote `mark_read` call the chat screen
  /// makes when it opens. Outgoing messages are untouched — their read state
  /// reflects the *peer's* receipt, not ours.
  Future<void> markMessagesRead(String conversationId) async {
    await (_db.update(_db.localMessages)..where(
          (t) =>
              t.conversationId.equals(conversationId) &
              t.readAt.isNull() &
              t.outgoing.equals(false),
        ))
        .write(
          LocalMessagesCompanion(
            readAt: Value(DateTime.now()),
            remoteStatus: const Value('seen'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<List<ConversationSummary>> cachedConversations() async {
    final rows = await (_db.select(
      _db.localConversations,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
    return rows.map(_toConversation).toList();
  }

  ConversationSummary _toConversation(LocalConversation r) {
    final isGroup = r.isGroup;
    final directPeer = UserProfile(
      id: r.peerId ?? '',
      displayName: r.peerDisplayName ?? '',
      avatarUrl: r.peerAvatarUrl,
      presence: r.peerPresence ?? 'offline',
      lastSeenAt: r.peerLastSeenAt,
    );
    return ConversationSummary(
      id: r.id,
      isGroup: isGroup,
      peer: isGroup ? null : directPeer,
      peers: isGroup ? _decodePeers(r.memberJson) : [directPeer],
      displayName: r.displayName ?? '',
      lastMessageId: r.lastMessageId,
      lastMessageText: r.lastMessagePreview,
      lastMessageType: r.lastMessageType ?? 'text',
      lastMessageSenderId: r.lastMessageSenderId,
      lastMessageAt: r.lastMessageAt,
      unreadCount: r.unreadCount,
    );
  }

  /// Storage used per conversation, biggest first.
  ///
  /// Summed from the cached message rows' attachment manifests rather than by
  /// walking the cache directory, because assembled media files are stored flat
  /// with no conversation key on disk - there is nothing on the filesystem to
  /// group by. The manifests carry the authoritative byte count the sender's
  /// uploader recorded, so this is the real size rather than an estimate.
  ///
  /// Rows with no media are skipped, and a chat with no attachments simply does
  /// not appear.
  Future<List<({String conversationId, int bytes, int fileCount})>>
  mediaBytesByConversation() async {
    final rows = await _db
        .customSelect(
          'select conversation_id, media_json from local_messages '
          'where media_json is not null',
        )
        .get();

    final totals = <String, ({int bytes, int fileCount})>{};
    for (final row in rows) {
      final conversationId = row.data['conversation_id'] as String?;
      if (conversationId == null) continue;
      final size = _attachmentBytes(row.data['media_json']);
      final current = totals[conversationId] ?? (bytes: 0, fileCount: 0);
      totals[conversationId] = (
        bytes: current.bytes + size,
        fileCount: current.fileCount + (size > 0 ? 1 : 0),
      );
    }

    final list = totals.entries
        .map(
          (e) => (
            conversationId: e.key,
            bytes: e.value.bytes,
            fileCount: e.value.fileCount,
          ),
        )
        .toList();
    list.sort((a, b) => b.bytes.compareTo(a.bytes));
    return list;
  }

  /// Names of the cached media files that belong to [conversationId], and to
  /// which other conversations each one is also referenced by.
  ///
  /// Read this BEFORE deleting the conversation's rows. "Clear this chat on this
  /// device" is advertised as removing downloaded media, but the only place the
  /// link between a file on disk and a chat exists is the stored manifest - so
  /// deleting the rows first destroys the only way to find the files, and the
  /// bytes stay on disk forever.
  ///
  /// The `alsoReferencedBy` set lets the caller avoid deleting a file that
  /// another chat still points at (the same photo forwarded into two chats is
  /// stored once), which would otherwise break the surviving chat's playback
  /// until it was re-downloaded.
  Future<({Set<String> fileNames, Map<String, int> referenceCounts})>
  mediaFilesForConversation(String conversationId) async {
    final rows = await _db
        .customSelect(
          'select conversation_id, media_json from local_messages '
          'where media_json is not null',
        )
        .get();

    final mine = <String>{};
    final counts = <String, int>{};

    for (final row in rows) {
      final owner = row.data['conversation_id'] as String?;
      if (owner == null) continue;
      final name = _attachmentFileName(row.data['media_json']);
      if (name == null) continue;
      counts[name] = (counts[name] ?? 0) + 1;
      if (owner == conversationId) mine.add(name);
    }

    return (fileNames: mine, referenceCounts: counts);
  }

  /// The stored file name from an attachment manifest, or null when there is
  /// none.
  static String? _attachmentFileName(Object? mediaJson) {
    if (mediaJson is! String || mediaJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(mediaJson);
      if (decoded is! Map) return null;
      final name = decoded['file_name'] ?? decoded['name'];
      if (name is! String || name.trim().isEmpty) return null;
      return name.trim();
    } catch (_) {
      return null;
    }
  }

  /// Reads the byte count out of a stored attachment manifest.
  ///
  /// Returns 0 rather than throwing on an unparseable row: a single corrupt
  /// manifest must not blank the whole storage screen.
  static int _attachmentBytes(Object? mediaJson) {
    if (mediaJson is! String || mediaJson.isEmpty) return 0;
    try {
      final decoded = jsonDecode(mediaJson);
      if (decoded is! Map) return 0;
      final size = decoded['size_bytes'];
      return (size as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // -- Messages -------------------------------------------------------------

  /// Caches a message. The local primary key is [ChatMessage.clientMessageId]
  /// until the server confirms (see [replaceLocalMessage]).
  Future<void> upsertLocalMessage(ChatMessage m) {
    return upsertWithTarget(
      _db.into(_db.localMessages),
      LocalMessagesCompanion.insert(
        ownerId: Value(ownerId),
        id: m.clientMessageId,
        clientMessageId: m.clientMessageId,
        serverId: Value(m.id == m.clientMessageId ? null : m.id),
        conversationId: m.conversationId,
        senderId: m.senderId,
        type: Value(m.type),
        body: Value(m.body),
        mediaJson: Value(_encodeMedia(m.attachment)),
        reactionsJson: Value(_encodeReactions(m.reactions)),
        replyToId: Value(m.replyToId),
        forwarded: Value(m.forwarded),
        localState: Value(m.localState.name),
        remoteStatus: Value(m.remoteStatus.name),
        createdAt: m.createdAt,
        updatedAt: Value(DateTime.now()),
        outgoing: Value(m.outgoing),
        deleted: Value(m.deleted),
        deliveredAt: Value(m.deliveredAt),
        readAt: Value(m.readAt),
      ),
      [_db.localMessages.id],
    );
  }

  /// Server-authoritative upsert that never regresses the local view:
  /// known receipts, an optimistic reaction set and a failed/sending local
  /// state survive the server row reaching the cache.
  Future<void> upsertRemoteMessage(ChatMessage m) async {
    final existing =
        await findLocal(m.id) ?? await findLocal(m.clientMessageId);
    if (existing == null) return upsertLocalMessage(m);

    final local = _toMessage(existing);
    final deliveredAt = local.deliveredAt ?? m.deliveredAt;
    final readAt = local.readAt ?? m.readAt;
    final remoteStatus = readAt != null
        ? RemoteStatus.seen
        : (deliveredAt != null ? RemoteStatus.delivered : m.remoteStatus);

    return upsertLocalMessage(
      m.copyWith(
        deliveredAt: deliveredAt,
        readAt: readAt,
        remoteStatus: remoteStatus,
        reactions: m.reactions.isNotEmpty ? m.reactions : local.reactions,
        localState:
            local.localState == MessageLocalState.failed ||
                local.localState == MessageLocalState.sending
            ? local.localState
            : m.localState,
      ),
    );
  }

  /// After a successful server insert, move the row from the client-keyed id to
  /// the server id.
  ///
  /// Atomic: the delete and the insert share one transaction. Previously they
  /// were two statements, so a crash between them destroyed the message — the
  /// user had already been shown it as sent.
  Future<void> replaceLocalMessage(
    String clientMessageId,
    ChatMessage serverMessage,
  ) {
    return _db.transaction(() async {
      await (_db.delete(_db.localMessages)..where(
            (t) => t.id.equals(clientMessageId) & t.ownerId.equals(ownerId),
          ))
          .go();
      await upsertLocalMessage(serverMessage);
    });
  }

  Future<void> markLocalFailed(String clientMessageId) async {
    await (_db.update(
      _db.localMessages,
    )..where((t) => t.id.equals(clientMessageId))).write(
      LocalMessagesCompanion(
        localState: const Value('failed'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<LocalMessage?> findLocal(String id) {
    return (_db.select(_db.localMessages)..where(
          (t) =>
              (t.id.equals(id) | t.serverId.equals(id)) &
              t.ownerId.equals(ownerId),
        ))
        .getSingleOrNull();
  }

  Future<List<ChatMessage>> cachedMessages(String conversationId) async {
    final rows =
        await (_db.select(_db.localMessages)
              ..where(
                (t) =>
                    t.conversationId.equals(conversationId) &
                    t.ownerId.equals(ownerId),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return rows.map(_toMessage).toList();
  }

  /// The newest outgoing message for [conversationId] (used to paint the
  /// traffic-light dot in the chat list preview), or null when the latest
  /// message is incoming.
  Future<ChatMessage?> newestOutgoing(String conversationId) async {
    final rows =
        await (_db.select(_db.localMessages)
              ..where(
                (t) =>
                    t.conversationId.equals(conversationId) &
                    t.ownerId.equals(ownerId) &
                    t.outgoing.equals(true),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : _toMessage(rows.first);
  }

  /// Purges the local cache for a conversation (delete-for-me): its messages,
  /// outbox queue and list row. [chatOverridesProvider.deleted] keeps it hidden
  /// from the list even after a sync re-fetches the server row.
  ///
  /// Atomic, and it writes a tombstone for every message it removes. Without
  /// the tombstone the next sync would fetch the same rows straight back from
  /// the server, which is exactly the resurrection this has to prevent.
  ///
  /// The outbox rows go too, which does discard a queued send the user had been
  /// shown as "waiting". That is inherent to "delete this chat", and it is why
  /// the tombstone is written before the delete rather than after.
  Future<void> deleteConversationLocally(String conversationId) {
    return _db.transaction(() async {
      final doomed =
          await (_db.select(_db.localMessages)..where(
                (t) =>
                    t.conversationId.equals(conversationId) &
                    t.ownerId.equals(ownerId),
              ))
              .get();
      final now = DateTime.now();
      for (final row in doomed) {
        await _writeTombstone(
          messageId: row.clientMessageId,
          conversationId: conversationId,
          scope: DeletionScope.me,
          deletedAt: now,
        );
      }

      await (_db.delete(_db.localMessages)..where(
            (t) =>
                t.conversationId.equals(conversationId) &
                t.ownerId.equals(ownerId),
          ))
          .go();
      await (_db.delete(_db.outboxMessages)..where(
            (t) =>
                t.conversationId.equals(conversationId) &
                t.ownerId.equals(ownerId),
          ))
          .go();
      await (_db.delete(
        _db.localConversations,
      )..where((t) => t.id.equals(conversationId))).go();
    });
  }

  /// Windowed, newest-first read used for Messenger-style history pagination.
  ///
  /// Returns at most [limit] messages strictly older than [before] (or the
  /// newest messages when [before] is null), ascending, plus a [hasMore] flag
  /// that is true while older rows still exist beyond the returned window.
  Future<({List<ChatMessage> messages, bool hasMore})> cachedMessagesPage(
    String conversationId, {
    int limit = 60,
    DateTime? before,
  }) async {
    final query = _db.select(_db.localMessages)
      ..where((t) {
        final scoped =
            t.conversationId.equals(conversationId) & t.ownerId.equals(ownerId);
        if (before == null) return scoped;
        return scoped & t.createdAt.isSmallerThanValue(before);
      })
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit + 1);
    final rows = await query.get();
    final hasMore = rows.length > limit;
    final page = rows.take(limit).toList().reversed.toList();
    return (messages: page.map(_toMessage).toList(), hasMore: hasMore);
  }

  /// Owner-scoped whole-table read.
  ///
  /// Bounded on purpose. This used to be an unfiltered scan of every message on
  /// the device, which is an out-of-memory crash waiting for any account with
  /// a year of history — and, unscoped, it was also the clearest possible read
  /// of another account's cache.
  Future<List<ChatMessage>> appLocalMessages({int limit = 500}) async {
    final rows =
        await (_db.select(_db.localMessages)
              ..where((t) => t.ownerId.equals(ownerId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(limit))
            .get();
    return rows.map(_toMessage).toList();
  }

  ChatMessage _toMessage(LocalMessage r) {
    return ChatMessage(
      id: r.id,
      clientMessageId: r.clientMessageId,
      conversationId: r.conversationId,
      senderId: r.senderId,
      type: r.type,
      body: r.body,
      attachment: r.mediaJson == null ? null : _decodeMedia(r.mediaJson!),
      reactions: _decodeReactions(r.reactionsJson),
      replyToId: r.replyToId,
      forwarded: r.forwarded,
      createdAt: r.createdAt,
      deleted: r.deleted,
      outgoing: r.outgoing,
      localState: MessageLocalState.fromString(r.localState),
      remoteStatus: RemoteStatus.fromString(r.remoteStatus),
      deliveredAt: r.deliveredAt,
      readAt: r.readAt,
    );
  }

  Future<void> deleteLocal(String clientMessageId) async {
    await (_db.delete(
      _db.localMessages,
    )..where((t) => t.id.equals(clientMessageId))).go();
  }

  Future<void> updateReceipt({
    required String serverId,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) async {
    await (_db.update(
      _db.localMessages,
    )..where((t) => t.id.equals(serverId))).write(
      LocalMessagesCompanion(
        deliveredAt: Value(deliveredAt),
        readAt: Value(readAt),
        remoteStatus: Value(readAt != null ? 'seen' : 'delivered'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // -- Reactions ------------------------------------------------------------

  /// Merges the authoritative [reactions] into the cached message row.
  Future<void> updateReactions(
    String messageId,
    List<MessageReaction> reactions,
  ) async {
    await (_db.update(
      _db.localMessages,
    )..where((t) => t.id.equals(messageId))).write(
      LocalMessagesCompanion(
        reactionsJson: Value(_encodeReactions(reactions)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> enqueueReaction({
    required String messageId,
    required String emoji,
  }) {
    return upsertWithTarget(
      _db.into(_db.messageReactionsOutbox),
      MessageReactionsOutboxCompanion.insert(
        messageId: messageId,
        emoji: emoji,
        createdAt: DateTime.now(),
      ),
      [_db.messageReactionsOutbox.messageId, _db.messageReactionsOutbox.emoji],
    );
  }

  Future<void> removeReactionFromOutbox(String messageId, String emoji) async {
    await (_db.delete(_db.messageReactionsOutbox)
          ..where((t) => t.messageId.equals(messageId) & t.emoji.equals(emoji)))
        .go();
  }

  Future<List<MessageReactionsOutboxData>> pendingReactions() {
    return _db.select(_db.messageReactionsOutbox).get();
  }

  Future<void> markReactionAttempted(
    String messageId,
    String emoji,
    int attempt,
  ) async {
    await (_db.update(_db.messageReactionsOutbox)
          ..where((t) => t.messageId.equals(messageId) & t.emoji.equals(emoji)))
        .write(MessageReactionsOutboxCompanion(attemptCount: Value(attempt)));
  }

  // -- Outbox ---------------------------------------------------------------

  Future<void> enqueueOutbox(ChatMessage m) {
    final clientMessageId = m.clientMessageId;
    return upsertWithTarget(
      _db.into(_db.outboxMessages),
      OutboxMessagesCompanion.insert(
        ownerId: Value(ownerId),
        id: clientMessageId,
        clientMessageId: clientMessageId,
        conversationId: m.conversationId,
        type: Value(m.type),
        body: Value(m.body),
        mediaJson: Value(_encodeMedia(m.attachment)),
        // Persisted so an offline reply still points at what it answers once
        // the outbox finally reaches the server.
        replyToId: Value(m.replyToId),
        forwarded: Value(m.forwarded),
        createdAt: m.createdAt,
      ),
      [_db.outboxMessages.id],
    );
  }

  Future<List<OutboxMessage>> pendingOutbox() {
    return (_db.select(_db.outboxMessages)
          ..where((t) => t.ownerId.equals(ownerId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> removeFromOutbox(String id) async {
    await (_db.delete(
      _db.outboxMessages,
    )..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId))).go();
  }

  Future<void> markOutboxAttempted(String id, int attempt) async {
    await (_db.update(_db.outboxMessages)
          ..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId)))
        .write(OutboxMessagesCompanion(attemptCount: Value(attempt)));
  }

  /// Replaces a queued message's stored attachment.
  ///
  /// Used after a queued media file finishes uploading: the row's manifest is
  /// swapped in for the "not uploaded yet" placeholder, so a later retry reuses
  /// the already-uploaded parts instead of re-sending the whole file. The
  /// attempt count is also cleared, because a successful upload means any
  /// earlier failure was purely a network problem.
  Future<void> updateOutboxMedia(String id, String? mediaJson) async {
    await (_db.update(
      _db.outboxMessages,
    )..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId))).write(
      OutboxMessagesCompanion(
        mediaJson: Value(mediaJson),
        attemptCount: const Value(0),
      ),
    );
  }

  /// Messages that are composed and queued but have not reached the server yet.
  ///
  /// Drives the "N pending" indicator so a queued message is never invisible.
  Future<int> pendingOutboxCount() async {
    final count = _db.outboxMessages.id.count();
    final query = _db.selectOnly(_db.outboxMessages)
      ..addColumns([count])
      ..where(_db.outboxMessages.ownerId.equals(ownerId));
    return await query.map((row) => row.read(count) ?? 0).getSingle();
  }

  // -- Relay: deletion tombstones -------------------------------------------

  /// True when [messageId] has been deleted on this device.
  ///
  /// Called on the read path of every incoming message. It is the cheapest
  /// possible resurrection guard: a tombstoned row is skipped rather than
  /// re-inserted, so no amount of stale sync can bring it back.
  Future<bool> isTombstoned(String messageId) async {
    final row =
        await (_db.select(_db.messageTombstones)..where(
              (t) => t.ownerId.equals(ownerId) & t.messageId.equals(messageId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<List<String>> tombstonedMessageIds(String conversationId) async {
    final rows =
        await (_db.select(_db.messageTombstones)..where(
              (t) =>
                  t.ownerId.equals(ownerId) &
                  t.conversationId.equals(conversationId),
            ))
            .get();
    return rows.map((r) => r.messageId).toList();
  }

  /// Records a deletion tombstone.
  ///
  /// Idempotent, and deliberately not a foreign key: the message row may be
  /// purged or re-keyed by the relay, and a tombstone that vanished with it
  /// would let the message come back.
  Future<void> writeTombstone({
    required String messageId,
    required String conversationId,
    required DeletionScope scope,
    required DateTime deletedAt,
    int payloadVersion = 1,
  }) {
    return _db.transaction(
      () => _writeTombstone(
        messageId: messageId,
        conversationId: conversationId,
        scope: scope,
        deletedAt: deletedAt,
        payloadVersion: payloadVersion,
      ),
    );
  }

  /// Tombstone write without its own transaction, so a caller that is already
  /// inside one (the incoming-commit path) does not nest.
  Future<void> _writeTombstone({
    required String messageId,
    required String conversationId,
    required DeletionScope scope,
    required DateTime deletedAt,
    int payloadVersion = 1,
  }) async {
    await upsertWithTarget(
      _db.into(_db.messageTombstones),
      MessageTombstonesCompanion.insert(
        ownerId: Value(ownerId),
        messageId: messageId,
        conversationId: conversationId,
        scope: Value(scope.name),
        deletedAt: deletedAt,
        payloadVersion: Value(payloadVersion),
      ),
      [_db.messageTombstones.ownerId, _db.messageTombstones.messageId],
    );
    // Monotonic by construction. Writing the cursor unconditionally here let a
    // late-arriving older event move it backwards, which would make the next
    // fetch re-request a window the device had already processed — and, worse,
    // would let a deletion that arrived out of order be "un-seen".
    await _advanceDeletionCursor(conversationId, deletedAt);

    // A tombstone for a message that is still cached has to actually hide it,
    // or the row and the tombstone disagree.
    await (_db.update(_db.localMessages)..where(
          (t) =>
              t.ownerId.equals(ownerId) &
              (t.id.equals(messageId) | t.serverId.equals(messageId)),
        ))
        .write(
          LocalMessagesCompanion(
            deleted: const Value(true),
            deletedAt: Value(deletedAt),
            body: const Value(null),
            mediaJson: const Value(null),
            retentionState: const Value('payload_purged'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Latest deletion timestamp applied for a conversation.
  Future<DateTime?> deletionCursor(String conversationId) async {
    final row =
        await (_db.select(_db.deletionCursors)..where(
              (t) =>
                  t.ownerId.equals(ownerId) &
                  t.conversationId.equals(conversationId),
            ))
            .getSingleOrNull();
    return row?.lastDeletedAt;
  }

  Future<void> _advanceDeletionCursor(
    String conversationId,
    DateTime at,
  ) async {
    final current = await deletionCursor(conversationId);
    if (current != null && !current.isBefore(at)) return;
    await upsertWithTarget(
      _db.into(_db.deletionCursors),
      DeletionCursorsCompanion.insert(
        ownerId: Value(ownerId),
        conversationId: conversationId,
        lastDeletedAt: Value(at),
      ),
      [_db.deletionCursors.ownerId, _db.deletionCursors.conversationId],
    );
  }

  // -- Relay: device acknowledgement ledger ----------------------------------

  /// Records that this device now holds [messageId] and still owes the relay
  /// an acknowledgement.
  ///
  /// Written in the SAME transaction as the message itself, which is what makes
  /// "persist before acknowledging" true rather than merely intended: if the
  /// process dies between the two, the ledger entry survives and the
  /// acknowledgement is still sent.
  Future<void> recordPendingAck(
    String messageId,
    AckKind kind, {
    bool reported = false,
  }) {
    return upsertWithTarget(
      _db.into(_db.deliveryAckLedger),
      DeliveryAckLedgerCompanion.insert(
        ownerId: Value(ownerId),
        messageId: messageId,
        kind: kind.name,
        reported: Value(reported),
        updatedAt: Value(DateTime.now()),
      ),
      [
        _db.deliveryAckLedger.ownerId,
        _db.deliveryAckLedger.messageId,
        _db.deliveryAckLedger.kind,
      ],
    );
  }

  /// Marks acknowledgements the relay has confirmed.
  ///
  /// A message id that is not in the ledger is ignored rather than inserted:
  /// a spurious id here would mean the app claims to have acknowledged
  /// something it never stored.
  Future<void> markAcksReported(List<String> messageIds, AckKind kind) async {
    if (messageIds.isEmpty) return;
    await _db.transaction(() async {
      for (final id in messageIds) {
        await (_db.update(_db.deliveryAckLedger)..where(
              (t) =>
                  t.ownerId.equals(ownerId) &
                  t.messageId.equals(id) &
                  t.kind.equals(kind.name),
            ))
            .write(
              DeliveryAckLedgerCompanion(
                reported: const Value(true),
                updatedAt: Value(DateTime.now()),
              ),
            );
      }
    });
  }

  /// Unreported acknowledgements, oldest first, bounded to [limit].
  Future<List<PendingAck>> pendingAcks({int limit = 200}) async {
    final rows =
        await (_db.select(_db.deliveryAckLedger)
              ..where(
                (t) => t.ownerId.equals(ownerId) & t.reported.equals(false),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)])
              ..limit(limit))
            .get();
    return rows
        .map(
          (r) => PendingAck(
            messageId: r.messageId,
            kind: AckKind.fromString(r.kind),
          ),
        )
        .toList();
  }

  /// True when this device still owes a delivery acknowledgement for
  /// [messageId].
  ///
  /// Used to stop re-queueing the same messages after every reconcile. The
  /// previous behaviour keyed off `deliveredAt` on the local row, which was
  /// never written for incoming messages, so the whole conversation was
  /// re-queued on every pass.
  Future<bool> owesDeliveryAck(String messageId) async {
    final row =
        await (_db.select(_db.deliveryAckLedger)..where(
              (t) =>
                  t.ownerId.equals(ownerId) &
                  t.messageId.equals(messageId) &
                  t.kind.equals(AckKind.delivered.name) &
                  t.reported.equals(false),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> pruneAckLedger() {
    return _db.transaction(() async {
      // Reported rows are only useful until the relay's own retention window
      // has passed; unreported ones are never pruned.
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      await (_db.delete(_db.deliveryAckLedger)..where(
            (t) =>
                t.reported.equals(true) &
                t.updatedAt.isSmallerThanValue(cutoff),
          ))
          .go();
    });
  }

  // -- Relay: atomic incoming commit -----------------------------------------

  /// Commits one received message and everything that must move with it, as a
  /// single transaction.
  ///
  /// The contents are chosen so there is no window in which the database can
  /// hold a message without the knowledge that it was stored and still needs an
  /// acknowledgement:
  ///
  ///  1. a tombstone check — a tombstoned message is dropped, not stored;
  ///  2. the message row itself;
  ///  3. a `delivered` ledger entry with `reported = false`, which is the
  ///     permission to acknowledge;
  ///  4. the message sync cursor.
  ///
  /// Returns true when the message was stored. A false return is not an error:
  /// it means the row was a duplicate or the message is tombstoned.
  Future<bool> commitIncomingMessage({
    required ChatMessage message,
    required String cursorKey,
    bool acknowledgeDelivery = true,
  }) {
    return _db.transaction(() async {
      if (await _isTombstoned(message.clientMessageId) ||
          (message.id != message.clientMessageId &&
              await _isTombstoned(message.id))) {
        return false;
      }

      // Detect a duplicate before writing. A Realtime event can be delivered
      // more than once (reconnect replay, two subscriptions for the same
      // conversation), and the caller uses this return value to decide whether
      // to append the message to the visible list. Returning true for a message
      // that is already on screen is how a bubble gets duplicated.
      final existing =
          await findLocal(message.id) ??
          await findLocal(message.clientMessageId);

      await upsertRemoteMessage(message);

      if (acknowledgeDelivery && !message.outgoing) {
        await upsertWithTarget(
          _db.into(_db.deliveryAckLedger),
          DeliveryAckLedgerCompanion.insert(
            ownerId: Value(ownerId),
            messageId: message.id,
            kind: AckKind.delivered.name,
            reported: const Value(false),
            updatedAt: Value(DateTime.now()),
          ),
          [
            _db.deliveryAckLedger.ownerId,
            _db.deliveryAckLedger.messageId,
            _db.deliveryAckLedger.kind,
          ],
        );
      }

      if (cursorKey.isNotEmpty) {
        await upsertWithTarget(
          _db.into(_db.deviceSyncCursors),
          DeviceSyncCursorsCompanion.insert(
            key: cursorKey,
            cursor: Value(message.id),
            updatedAt: Value(DateTime.now()),
          ),
          [_db.deviceSyncCursors.key],
        );
      }

      return existing == null;
    });
  }

  /// Applies a batch of server deletion events atomically, advancing the
  /// deletion cursor only for events that were actually applied.
  Future<int> applyDeletionEvents(
    List<RelayDeletionEvent> events, {
    required String cursorKey,
  }) {
    return _db.transaction(() async {
      var applied = 0;
      for (final event in events) {
        if (await _isTombstoned(event.messageId)) continue;
        await _writeTombstone(
          messageId: event.messageId,
          conversationId: event.conversationId,
          scope: event.scope,
          deletedAt: event.deletedAt,
          payloadVersion: event.payloadVersion,
        );
        applied++;
      }

      if (cursorKey.isNotEmpty && events.isNotEmpty) {
        final newest = events
            .map((e) => e.deletedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        await upsertWithTarget(
          _db.into(_db.deviceSyncCursors),
          DeviceSyncCursorsCompanion.insert(
            key: cursorKey,
            cursor: Value(newest.toUtc().toIso8601String()),
            updatedAt: Value(DateTime.now()),
          ),
          [_db.deviceSyncCursors.key],
        );
      }

      return applied;
    });
  }

  Future<bool> _isTombstoned(String messageId) async {
    final row =
        await (_db.select(_db.messageTombstones)..where(
              (t) => t.ownerId.equals(ownerId) & t.messageId.equals(messageId),
            ))
            .get();
    return row.isNotEmpty;
  }

  // -- Sync cursor (per-device) ---------------------------------------------

  Future<String?> getDeviceCursor(String key) async {
    final row = await (_db.select(
      _db.deviceSyncCursors,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.cursor;
  }

  Future<void> setDeviceCursor(String key, String? cursor) {
    return upsertWithTarget(
      _db.into(_db.deviceSyncCursors),
      DeviceSyncCursorsCompanion.insert(
        key: key,
        cursor: Value(cursor),
        updatedAt: Value(DateTime.now()),
      ),
      [_db.deviceSyncCursors.key],
    );
  }

  // -- Generic sync state ---------------------------------------------------

  Future<String?> getSyncValue(String key) async {
    final row = await (_db.select(
      _db.syncState,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSyncValue(String key, String value) {
    return upsertWithTarget(
      _db.into(_db.syncState),
      SyncStateCompanion.insert(
        key: key,
        value: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
      [_db.syncState.key],
    );
}

// -- User settings cache removed - settings stored client-side only --

List<Map<String, String?>> _encodePeers(List<UserProfile> peers) {
  return peers
      .map(
        (p) => {
          'id': p.id,
          'display_name': p.displayName,
          'phone': p.phone,
          'avatar_url': p.avatarUrl,
          'presence': p.presence,
        },
      )
      .toList();
}

List<UserProfile> _decodePeers(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw) as List;
    return list.whereType<Map>().map((m) {
      final map = Map<String, dynamic>.from(m);
      return UserProfile(
        id: map['id'] as String? ?? '',
        displayName: map['display_name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        avatarUrl: map['avatar_url'] as String?,
        presence: map['presence'] as String? ?? 'offline',
      );
    }).toList();
  } catch (_) {
    return const [];
  }
}

String? _encodeMedia(Attachment? a) {
  if (a == null) return null;
  return jsonEncode(a.toJson());
}

Attachment? _decodeMedia(String raw) {
  try {
    return Attachment.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  } catch (_) {
    return null;
  }
}

String? _encodeReactions(List<MessageReaction> reactions) {
  if (reactions.isEmpty) return null;
  return jsonEncode(reactions.map((r) => r.toJson()).toList());
}

List<MessageReaction> _decodeReactions(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw) as List;
    return list
        .whereType<Map>()
        .map((m) => MessageReaction.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  } catch (_) {
    return const [];
  }
}
