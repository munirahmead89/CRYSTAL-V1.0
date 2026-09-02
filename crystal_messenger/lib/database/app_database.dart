import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/chats_table.dart';
import 'tables/messages_table.dart';
import 'tables/contacts_table.dart';
import 'tables/pending_actions_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [ChatsTable, MessagesTable, ContactsTable, PendingActionsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {},
      );

  // ─── Chat Operations ────────────────────────────────
  Future<List<ChatsTableData>> getAllChats() => (select(chatsTable)
        ..orderBy([(t) => OrderingTerm.desc(t.lastMessageAt)]))
      .get();

  Stream<List<ChatsTableData>> watchAllChats() => (select(chatsTable)
        ..orderBy([(t) => OrderingTerm.desc(t.isPinned),
                    (t) => OrderingTerm.desc(t.lastMessageAt)]))
      .watch();

  Future<ChatsTableData?> getChat(String id) =>
      (select(chatsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertChat(ChatsTableCompanion chat) =>
      into(chatsTable).insertOnConflictUpdate(chat);

  Future<void> deleteChat(String id) =>
      (delete(chatsTable)..where((t) => t.id.equals(id))).go();

  Future<void> updateChatUnread(String chatId, int count) =>
      (update(chatsTable)..where((t) => t.id.equals(chatId)))
          .write(ChatsTableCompanion(unreadCount: Value(count)));

  Future<void> clearChatMessages(String chatId) =>
      (delete(messagesTable)..where((t) => t.chatId.equals(chatId))).go();

  // ─── Message Operations ─────────────────────────────
  Future<List<MessagesTableData>> getMessagesForChat(
    String chatId, {
    int limit = 50,
    int offset = 0,
  }) =>
      (select(messagesTable)
            ..where((t) => t.chatId.equals(chatId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit, offset: offset))
          .get();

  Stream<List<MessagesTableData>> watchMessagesForChat(String chatId) =>
      (select(messagesTable)
            ..where((t) => t.chatId.equals(chatId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<void> insertMessage(MessagesTableCompanion message) =>
      into(messagesTable).insertOnConflictUpdate(message);

  Future<void> updateMessageDelivery(String messageId, DateTime deliveredAt) =>
      (update(messagesTable)..where((t) => t.id.equals(messageId)))
          .write(MessagesTableCompanion(deliveredAt: Value(deliveredAt)));

  Future<void> updateMessageRead(String messageId, DateTime readAt) =>
      (update(messagesTable)..where((t) => t.id.equals(messageId)))
          .write(MessagesTableCompanion(readAt: Value(readAt)));

  Future<void> deleteMessage(String messageId) =>
      (update(messagesTable)..where((t) => t.id.equals(messageId)))
          .write(MessagesTableCompanion(isDeleted: const Value(true)));

  // ─── Contact Operations ─────────────────────────────
  Future<List<ContactsTableData>> getAllContacts() =>
      (select(contactsTable)..orderBy([(t) => OrderingTerm.asc(t.displayName)]))
          .get();

  Stream<List<ContactsTableData>> watchAllContacts() =>
      (select(contactsTable)..orderBy([(t) => OrderingTerm.asc(t.displayName)]))
          .watch();

  Future<void> upsertContact(ContactsTableCompanion contact) =>
      into(contactsTable).insertOnConflictUpdate(contact);

  Future<void> deleteContact(String id) =>
      (delete(contactsTable)..where((t) => t.id.equals(id))).go();

  // ─── Pending Actions (Offline Queue) ────────────────
  Future<List<PendingActionsTableData>> getPendingActions() =>
      (select(pendingActionsTable)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<int> addPendingAction(String type, String payload) =>
      into(pendingActionsTable).insert(PendingActionsTableCompanion.insert(
        actionType: type,
        payload: payload,
        createdAt: DateTime.now(),
      ));

  Future<void> removePendingAction(int id) =>
      (delete(pendingActionsTable)..where((t) => t.id.equals(id))).go();

  Future<void> incrementRetryCount(int id) async {
    final current = (select(pendingActionsTable)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    final row = await current;
    await (update(pendingActionsTable)..where((t) => t.id.equals(id))).write(
      PendingActionsTableCompanion(retryCount: Value(row.retryCount + 1)),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(dir.path, 'crystal_messenger'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    final file = File(p.join(dbDir.path, 'crystal.db'));
    return NativeDatabase.createInBackground(file);
  });
}
