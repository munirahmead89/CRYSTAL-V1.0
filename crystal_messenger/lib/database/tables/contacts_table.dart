import 'package:drift/drift.dart';

class ContactsTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get contactId => text()();
  TextColumn get displayName => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
