import 'dart:io';

import 'package:crystal_messenger/core/database/database.dart';
import 'package:crystal_messenger/core/database/local_store.dart';
import 'package:crystal_messenger/shared/models/conversation.dart';
import 'package:crystal_messenger/shared/models/user_profile.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test(
    'v5 migration repairs a legacy local_conversations whose id had no PRIMARY KEY',
    () async {
      final dir = Directory.systemTemp.createTempSync('crystal_migration_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}legacy.db';

      try {
        // Stage the exact broken state that shipped before the fix:
        // local_conversations exists but `id` is NOT a primary key, so
        // `ON CONFLICT("id")` upserts threw
        // "clause does not match any PRIMARY KEY or UNIQUE constraint".
        final legacy = sqlite3.sqlite3.open(path);
        legacy.execute(
          'CREATE TABLE local_conversations ('
          'id TEXT NOT NULL, '
          'is_group INTEGER NOT NULL DEFAULT 0)',
        );
        legacy.execute('PRAGMA user_version = 1');
        legacy.dispose();
      } catch (e) {
        markTestSkipped('sqlite native library unavailable: $e');
        return;
      }

      // Opening the app database runs the v5 self-healing migration.
      final db = AppDatabase(NativeDatabase(File(path)));
      addTearDown(db.close);
      final store = LocalStore(db);

      final peer = UserProfile(
        id: 'peer-1',
        displayName: 'Peer One',
        phone: '+15550001001',
      );

      // INSERT path — this is the query that used to crash.
      await store.upsertConversation(
        ConversationSummary(
          id: 'conv-1',
          isGroup: false,
          peer: peer,
          peers: [peer],
          displayName: peer.displayName,
          lastMessageType: 'text',
        ),
      );

      // UPDATE path (ON CONFLICT DO UPDATE) — used to crash in exactly the
      // same way.
      await store.upsertConversation(
        ConversationSummary(
          id: 'conv-1',
          isGroup: false,
          peer: peer,
          peers: [peer],
          displayName: 'Peer One (renamed)',
          lastMessageType: 'text',
        ),
      );

      // The recreated table now has id as the real PRIMARY KEY and the
      // conversation is findable by peer.
      final rows = await db
          .customSelect('PRAGMA table_info("local_conversations")')
          .get();
      final idInfo = rows.singleWhere((r) => r.data['name'] == 'id');
      expect(idInfo.data['pk'], greaterThan(0));

      expect(await store.findDirectConversationWith('peer-1'), 'conv-1');
    },
  );

  test('a freshly created database already has the primary keys', () async {
    try {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final rows = await db
          .customSelect('PRAGMA table_info("local_conversations")')
          .get();
      final idInfo = rows.singleWhere((r) => r.data['name'] == 'id');
      expect(idInfo.data['pk'], greaterThan(0));
    } catch (e) {
      markTestSkipped('sqlite native library unavailable: $e');
    }
  });

  test(
    'v6 migration drops the local_calls table left behind by older builds',
    () async {
      final dir = Directory.systemTemp.createTempSync('crystal_v6_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}v5.db';

      try {
        // Stage a v5 database that still carries the call log.
        final legacy = sqlite3.sqlite3.open(path);
        legacy.execute(
          'CREATE TABLE local_calls ('
          'id TEXT NOT NULL PRIMARY KEY, '
          'peer_id TEXT, '
          'direction TEXT NOT NULL, '
          'duration_seconds INTEGER NOT NULL DEFAULT 0)',
        );
        legacy.execute('PRAGMA user_version = 5');
        legacy.dispose();
      } catch (e) {
        markTestSkipped('sqlite native library unavailable: $e');
        return;
      }

      final db = AppDatabase(NativeDatabase(File(path)));
      addTearDown(db.close);

      final names = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
          .get();
      expect(
        names.map((r) => r.data['name']),
        isNot(contains('local_calls')),
        reason: 'calls were removed from the app, so the call log must go',
      );
    },
  );

  test('v6 migration is a no-op when local_calls was never created', () async {
    final dir = Directory.systemTemp.createTempSync('crystal_v6b_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}nocalls.db';

    try {
      final legacy = sqlite3.sqlite3.open(path);
      legacy.execute('PRAGMA user_version = 5');
      legacy.dispose();
    } catch (e) {
      markTestSkipped('sqlite native library unavailable: $e');
      return;
    }

    // A v2 -> v6 upgrade never created local_calls (the v3 step no longer does),
    // so an unguarded DROP TABLE here would throw and brick the upgrade.
    final db = AppDatabase(NativeDatabase(File(path)));
    addTearDown(db.close);

    final names = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    expect(names.map((r) => r.data['name']), isNot(contains('local_calls')));
  });
}
