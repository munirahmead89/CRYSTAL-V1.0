import 'package:drift/drift.dart';

part 'database.g.dart';

/// One index the relay's hot paths depend on, with the table it belongs to.
///
/// The table name is carried explicitly because an index cannot be created
/// before its table exists. An install upgrading from v5 never had
/// `message_reactions_outbox`, so the v10 step runs while that table is still
/// absent — `createAll()` only happens afterwards, in `beforeOpen`.
class RelayIndex {
  const RelayIndex(this.table, this.sql);

  final String table;
  final String sql;
}

/// Indexes the relay's hot paths depend on.
///
/// Declared as raw SQL rather than Drift index builders because every one of
/// them is partial or composite over columns the Drift `indexes` DSL cannot
/// express, and because the relay needs them to be `IF NOT EXISTS`-idempotent
/// on an install that already created some of them.
const List<RelayIndex> relayIndexes = <RelayIndex>[
  // The chat screen: one account, one conversation, chronological.
  RelayIndex(
    'local_messages',
    'CREATE INDEX IF NOT EXISTS idx_local_messages_owner_conversation'
        ' ON local_messages (owner_id, conversation_id, created_at)',
  ),
  // Outbox flush and the retry banner.
  RelayIndex(
    'outbox_messages',
    'CREATE INDEX IF NOT EXISTS idx_outbox_owner'
        ' ON outbox_messages (owner_id, created_at)',
  ),
  // Acknowledgement replay: only unreported rows.
  RelayIndex(
    'delivery_ack_ledger',
    'CREATE INDEX IF NOT EXISTS idx_ack_ledger_pending'
        ' ON delivery_ack_ledger (owner_id, kind, reported)',
  ),
  // Resurrection guard: one lookup per incoming message.
  RelayIndex(
    'message_tombstones',
    'CREATE INDEX IF NOT EXISTS idx_tombstones_owner_message'
        ' ON message_tombstones (owner_id, message_id)',
  ),
  // Deletion-cursor advance and conversation cleanup.
  RelayIndex(
    'message_tombstones',
    'CREATE INDEX IF NOT EXISTS idx_tombstones_owner_conversation'
        ' ON message_tombstones (owner_id, conversation_id, deleted_at)',
  ),
  // Reconcile maps a fetched server row back to its local row.
  RelayIndex(
    'local_messages',
    'CREATE INDEX IF NOT EXISTS idx_local_messages_owner_server'
        ' ON local_messages (owner_id, server_id)',
  ),
  // Chat-list preview query.
  RelayIndex(
    'local_messages',
    'CREATE INDEX IF NOT EXISTS idx_local_messages_owner_outgoing'
        ' ON local_messages (owner_id, conversation_id, outgoing, created_at)',
  ),
  // Reactions and per-conversation sync cursors.
  RelayIndex(
    'message_reactions_outbox',
    'CREATE INDEX IF NOT EXISTS idx_reactions_outbox_message'
        ' ON message_reactions_outbox (message_id)',
  ),
  RelayIndex(
    'device_sync_cursors',
    'CREATE INDEX IF NOT EXISTS idx_device_cursors_key'
        ' ON device_sync_cursors (key)',
  ),
];

class LocalProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get bio => text().nullable()();
  TextColumn get presence => text().withDefault(const Constant('offline'))();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalStatuses extends Table {
  TextColumn get id => text()();
  TextColumn get authorId => text()();
  TextColumn get content => text().nullable()();
  TextColumn get mediaUrl => text().nullable()();
  TextColumn get mediaType => text().nullable()();
  TextColumn get caption => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  IntColumn get viewCount => integer().withDefault(const Constant(0))();
  BoolColumn get viewedByMe => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalStatusViews extends Table {
  TextColumn get id => text()();
  TextColumn get statusId => text()();
  TextColumn get viewerId => text()();
  TextColumn get viewerName => text().nullable()();
  DateTimeColumn get viewedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalConversations extends Table {
  TextColumn get id => text()();
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();
  TextColumn get peerId => text().nullable()();
  TextColumn get peerDisplayName => text().nullable()();
  TextColumn get peerAvatarUrl => text().nullable()();
  TextColumn get peerPresence => text().nullable()();
  DateTimeColumn get peerLastSeenAt => dateTime().nullable()();
  // Group-facing denormalization: display name override + member snapshot.
  TextColumn get displayName => text().nullable()();
  TextColumn get memberJson => text().nullable()();
  TextColumn get lastMessageId => text().nullable()();
  TextColumn get lastMessagePreview => text().nullable()();
  TextColumn get lastMessageType => text().nullable()();
  TextColumn get lastMessageSenderId => text().nullable()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalMessages extends Table {
  TextColumn get id => text()();
  TextColumn get clientMessageId => text()();

  /// Account this row belongs to.
  ///
  /// Empty string means "not yet claimed": every install created before this
  /// column existed has rows in that state, and the first account to sign in
  /// after the upgrade adopts them. Without an owner column a second account
  /// signing in on the same device sees the first account's messages AND
  /// flushes its queued outbox under its own identity.
  TextColumn get ownerId => text().withDefault(const Constant(''))();

  /// Server-assigned row id, recorded once the relay accepts the message.
  ///
  /// Stored alongside [id] (the client id) so a reconcile can map a fetched
  /// row back to the local row that is still keyed by the client id, without
  /// a delete-then-insert that would lose the row on a crash.
  TextColumn get serverId => text().nullable()();
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  TextColumn get type => text().withDefault(const Constant('text'))();
  TextColumn get body => text().nullable()();
  TextColumn get mediaJson => text().nullable()();
  TextColumn get reactionsJson => text().nullable()();
  TextColumn get replyToId => text().nullable()();

  /// Marks a forwarded message, so the "Forwarded" label survives an app
  /// restart and an offline flush instead of being a transient UI flag.
  BoolColumn get forwarded => boolean().withDefault(const Constant(false))();
  TextColumn get localState => text().withDefault(const Constant('local'))();
  TextColumn get remoteStatus => text().withDefault(const Constant('sent'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get outgoing => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();

  /// Server receipt time. Authoritative for ordering; the local clock is not
  /// trusted for it.
  DateTimeColumn get serverCreatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Relay payload lifecycle, mirrored from the server row so a purged message
  /// still renders as "deleted" rather than as an empty bubble.
  TextColumn get retentionState =>
      text().withDefault(const Constant('retained'))();

  /// Envelope versions, carried through so a row written by a newer build is
  /// interpretable rather than best-effort.
  IntColumn get schemaVersion => integer().withDefault(const Constant(1))();
  IntColumn get encryptionVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Durable record that a message was deleted, so a later sync can never
/// resurrect it.
///
/// This is the local half of the resurrection guard. The server half is a
/// tombstone row it retains past payload cleanup; between them, a stale cache
/// and a fresh pull both lose.
class MessageTombstones extends Table {
  TextColumn get ownerId => text().withDefault(const Constant(''))();
  TextColumn get messageId => text()();
  TextColumn get conversationId => text()();
  TextColumn get scope => text().withDefault(const Constant('everyone'))();
  DateTimeColumn get deletedAt => dateTime()();
  IntColumn get payloadVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {ownerId, messageId};
}

/// What THIS device has already reported to the relay.
///
/// An acknowledgement is only meaningful if it survives process death between
/// "I committed the message" and "the server told me it recorded my
/// acknowledgement". This table closes that window: `reported = false` means
/// the ack still has to go out (or be retried), `reported = true` means the
/// server has it.
class DeliveryAckLedger extends Table {
  TextColumn get ownerId => text().withDefault(const Constant(''))();

  /// Server message id. A device acknowledgement is about a relay row, not
  /// about a local draft, so this is the server id specifically.
  TextColumn get messageId => text()();

  /// 'delivered' | 'read' — the two receipts are tracked independently.
  TextColumn get kind => text()();
  BoolColumn get reported => boolean().withDefault(const Constant(false))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {ownerId, messageId, kind};
}

/// Highest deletion-event timestamp applied per conversation.
///
/// Deletions are recovered by timestamp, not by message id: an id-ordered pull
/// cannot observe a removal, so this cursor is what lets a device that was
/// offline for a week learn what disappeared.
class DeletionCursors extends Table {
  TextColumn get ownerId => text().withDefault(const Constant(''))();
  TextColumn get conversationId => text()();
  DateTimeColumn get lastDeletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {ownerId, conversationId};
}

/// One-time record that the pre-`owner_id` rows were adopted by an account.
///
/// Without it, a second account to sign in would also try to adopt the same
/// rows and the legacy history would end up visible to both.
class AccountScopeClaims extends Table {
  TextColumn get ownerId => text()();
  DateTimeColumn get claimedAt => dateTime()();
  IntColumn get adoptedRows => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {ownerId};
}

class OutboxMessages extends Table {
  TextColumn get id => text()();

  /// Account this queued send belongs to.
  ///
  /// Without it, an unsent message composed by one account is flushed by the
  /// next account to sign in — sent under their identity, into the first
  /// account's conversation.
  TextColumn get ownerId => text().withDefault(const Constant(''))();
  TextColumn get clientMessageId => text().unique()();
  TextColumn get conversationId => text()();
  TextColumn get type => text().withDefault(const Constant('text'))();
  TextColumn get body => text().nullable()();
  TextColumn get mediaJson => text().nullable()();

  /// Message this one replies to.
  ///
  /// Has to survive the queue: the reply target is chosen in the UI and the
  /// message is written to the outbox before the network call, so a column is
  /// the only place it can live in between. Without it a reply sent while
  /// offline reached the other side as an unanchored message.
  TextColumn get replyToId => text().nullable()();

  /// Forwarded marker, carried through the queue for the same reason as
  /// [replyToId]: the value is decided in the UI and the row is written before
  /// the network call.
  BoolColumn get forwarded => boolean().withDefault(const Constant(false))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  IntColumn get status => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Queue of reactions that still need to reach the server. Idempotent via
/// the (message_id, emoji) primary key.
class MessageReactionsOutbox extends Table {
  TextColumn get messageId => text()();
  TextColumn get emoji => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {messageId, emoji};
}

/// Per-device incremental sync watermark. Seeding the key as the device id
/// means multiple devices can advance their own cursor independently.
class DeviceSyncCursors extends Table {
  TextColumn get key =>
      text()(); // e.g. 'chats' or 'messages:<conversation_id>'
  TextColumn get cursor => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Per-user settings payload cache: the JSON blob mirrored from the server-side
/// `user_settings` table so every toggle survives offline restarts and the
/// realtime subscription can merge cross-device changes into it.


class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Schema v2: identity goes phone-only, group support arrives, and
      // reactions + device cursors get local backing stores. (Legacy
      // `username`/`peer_username` columns are simply tolerated — Drift
      // ignores columns that are not part of the table definition.)
      if (from < 2) {
        await m.createTable(deviceSyncCursors);
        await m.createTable(messageReactionsOutbox);
      }
      // Schema v3: WhatsApp-style Updates (statuses w/ text+image posts,
      // views) arrives, with offline-first local backing tables.
      if (from < 3) {
        await m.createTable(localStatuses);
        await m.createTable(localStatusViews);
      }
      // Schema v4: the per-user settings payload cache.
      if (from < 4) {
        await m.createTable(userSettings);
      }
      // Schema v5: self-heal legacy databases. Very old builds created the
      // local cache tables WITHOUT a PRIMARY KEY on `id`, so every
      // `ON CONFLICT("id")` upsert crashed with "clause does not match any
      // PRIMARY KEY or UNIQUE constraint" — and Drift's createAll() never
      // repairs an existing table's constraints. These tables mirror
      // server state, so dropping and re-creating them with the declared
      // schema is safe: the sync engine re-hydrates them from Supabase.
      if (from < 5) {
        await m.createAll();
        final tables = <TableInfo>[
          localProfiles,
          localConversations,
          localMessages,
          outboxMessages,
        ];
        for (final table in tables) {
          final name = table.actualTableName;
          if (!await _tableExists(name)) {
            await m.createTable(table);
            continue;
          }
          if (!await _hasIdPrimaryKey(name)) {
            await m.drop(table);
            await m.createTable(table);
          }
        }
      }
      // Schema v6: calls were removed from the app, so the local call log
      // goes too. Guarded on existence because a v2->v6 upgrade never
      // created it (the v3 step above no longer does) and dropping a
      // missing table throws.
      if (from < 6) {
        const name = 'local_calls';
        if (await _tableExists(name)) {
          await m.database.customStatement('drop table if exists $name');
        }
      }
      // Schema v7: replies. `outbox_messages` gains `reply_to_id` so a
      // reply composed while offline keeps its target through the queue.
      //
      // Added with `addColumn` rather than a table recreate so pending
      // messages are not lost, and guarded on existence because a database
      // that never had an outbox would make this throw.
      if (from < 7) {
        const name = 'outbox_messages';
        if (await _tableExists(name)) {
          final columns = await m.database
              .customSelect('PRAGMA table_info($name)')
              .get();
          final hasReplyTo = columns.any(
            (c) => c.data['name'] == 'reply_to_id',
          );
          if (!hasReplyTo) {
            await m.addColumn(outboxMessages, outboxMessages.replyToId);
          }
        }
      }
      // Schema v8: the "Forwarded" marker. Additive boolean columns on both
      // the cached-message table and the outbox, so a forwarded message
      // keeps its label across a restart and an offline flush.
      if (from < 8) {
        if (await _tableExists(localMessages.actualTableName)) {
          final columns = await m.database
              .customSelect(
                'PRAGMA table_info(${localMessages.actualTableName})',
              )
              .get();
          if (!columns.any((c) => c.data['name'] == 'forwarded')) {
            await m.addColumn(localMessages, localMessages.forwarded);
          }
        }
        if (await _tableExists(outboxMessages.actualTableName)) {
          final columns = await m.database
              .customSelect(
                'PRAGMA table_info(${outboxMessages.actualTableName})',
              )
              .get();
          if (!columns.any((c) => c.data['name'] == 'forwarded')) {
            await m.addColumn(outboxMessages, outboxMessages.forwarded);
          }
        }
      }

      // Schema v9: account isolation, deletion tombstones and the delivery
      // acknowledgement ledger. Every step is additive — no table is
      // recreated and no row is dropped, so an install holding real
      // message history upgrades in place.
      if (from < 9) {
        await _addColumnIfMissing(
          m,
          localMessages,
          localMessages.ownerId,
          'owner_id',
        );
        await _addColumnIfMissing(
          m,
          localMessages,
          localMessages.serverId,
          'server_id',
        );
        await _addColumnIfMissing(
          m,
          localMessages,
          localMessages.serverCreatedAt,
          'server_created_at',
        );
        await _addColumnIfMissing(
          m,
          localMessages,
          localMessages.deletedAt,
          'deleted_at',
        );
        await _addColumnIfMissing(
          m,
          localMessages,
          localMessages.retentionState,
          'retention_state',
        );
        await _addColumnIfMissing(
          m,
          localMessages,
          localMessages.schemaVersion,
          'schema_version',
        );
        await _addColumnIfMissing(
          m,
          localMessages,
          localMessages.encryptionVersion,
          'encryption_version',
        );
        await _addColumnIfMissing(
          m,
          outboxMessages,
          outboxMessages.ownerId,
          'owner_id',
        );

        for (final table in <TableInfo>[
          messageTombstones,
          deliveryAckLedger,
          deletionCursors,
          accountScopeClaims,
        ]) {
          final name = table.actualTableName;
          if (!await _tableExists(name)) {
            await m.createTable(table);
          }
        }
      }

      // Schema v10: the indexes the relay's hot paths need. Every query
      // below was previously a table scan:
      //   - the chat screen: rows for one account, one conversation, ordered
      //   - the outbox: pending rows for one account
      //   - the ack replay: unreported rows for one account and kind
      //   - the resurrection guard: is this message tombstoned?
      //   - the deletion cursor: latest event for one account+conversation
      if (from < 10) {
        await _applyRelayIndexes();
      }
    },
    beforeOpen: (details) async {
      // Drift's migrator handles the whole "make sure the schema matches"
      // step: it creates missing tables/columns declaratively and always
      // checks the real schema first, so it can never fail with a
      // "duplicate column name" SqliteException — no raw ALTER TABLE SQL.
      final migrator = Migrator(this);
      await migrator.createAll();

      // Indexes are applied here as well as in the v10 upgrade step.
      //
      // `beforeOpen` runs on every open, including for a database created
      // fresh at the current version (which never runs `onUpgrade`), so a
      // new install gets the indexes too. Every statement is
      // `IF NOT EXISTS`, which makes the repeat free.
      await _applyRelayIndexes();
    },
  );

  /// Creates every relay index whose table currently exists.
  ///
  /// Skipping a missing table rather than failing is deliberate and bounded:
  /// the same method runs in `onUpgrade`, where a table from a later schema
  /// version has not been created yet, and in `beforeOpen`, where it has. Any
  /// table that exists eventually gets its index on the next open.
  Future<void> _applyRelayIndexes() async {
    for (final index in relayIndexes) {
      if (!await _tableExists(index.table)) continue;
      await customStatement(index.sql);
    }
  }

  /// True when SQLite already has a table named [tableName].
  Future<bool> _tableExists(String tableName) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(tableName)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Adds [column] to [table] only when it is not already there.
  ///
  /// `Migrator.addColumn` throws on a duplicate column, and an install can
  /// reach a given schema version by more than one route, so every additive
  /// column is probed rather than assumed.
  Future<void> _addColumnIfMissing(
    Migrator migrator,
    TableInfo table,
    GeneratedColumn column,
    String columnName,
  ) async {
    final tableName = table.actualTableName;
    if (!await _tableExists(tableName)) {
      await migrator.createTable(table);
      return;
    }
    final columns = await customSelect('PRAGMA table_info("$tableName")').get();
    if (columns.any((c) => c.data['name'] == columnName)) return;
    await migrator.addColumn(table, column);
  }

  /// True when [tableName] has an `id` column declared `PRIMARY KEY`.
  ///
  /// Legacy (pre-v5) builds created the local cache tables without any primary
  /// key, which made every `ON CONFLICT("id")` upsert throw "clause does not
  /// match any PRIMARY KEY or UNIQUE constraint".
  Future<bool> _hasIdPrimaryKey(String tableName) async {
    final rows = await customSelect('PRAGMA table_info("$tableName")').get();
    for (final row in rows) {
      if (row.data['name'] == 'id') {
        final pk = row.data['pk'];
        if (pk is int && pk > 0) return true;
      }
    }
    return false;
  }
}
