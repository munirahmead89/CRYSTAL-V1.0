import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'database.dart';

/// The typed Drift database over the local SQLite cache.
///
/// The executor is lazily resolved so the database is only opened on first
/// use (avoids plugin calls during app startup and in widget tests).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(LazyDatabase(() async => openLocalDatabase()));
  ref.onDispose(db.close);
  return db;
});
