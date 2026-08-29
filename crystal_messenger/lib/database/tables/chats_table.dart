import 'package:drift/drift.dart';

class ChatsTable extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get createdBy => text().nullable()();
  BoolColumn get isEncrypted => boolean().withDefault(const Constant(false))();
  IntColumn get disappearingTimer => integer().withDefault(const Constant(0))();
  TextColumn get name => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get lastMessageContent => text().nullable()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
