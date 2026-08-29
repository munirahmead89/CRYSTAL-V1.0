import 'package:drift/drift.dart';
import 'chats_table.dart';

class MessagesTable extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text().references(ChatsTable, #id)();
  TextColumn get senderId => text()();
  TextColumn get content => text().nullable()();
  TextColumn get messageType => text().withDefault(const Constant('text'))();
  TextColumn get replyToId => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();
  TextColumn get metadata => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
