import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/conversations/data/supabase_chat_repositories.dart';
import '../../features/delivery/data/supabase_relay_repository.dart';
import '../../features/delivery/services/delivery_acknowledgement_service.dart';
import '../../features/delivery/services/relay_sync_recovery_service.dart';
import '../config/app_config.dart';
import '../config/remote_app_config.dart';
import '../database/app_database.dart';
import '../database/database.dart';
import '../database/local_store.dart';
import '../observability/crash_reporter.dart';
import '../security/device_identity.dart';
import '../security/secure_storage_service.dart';
import '../security/supabase_secure_storage.dart';
import '../sync/outbox_sync.dart';
import '../sync/sync_service.dart';

/// Workmanager task name — every batch is coalesced into the same task so a
/// periodic run + a push-triggered run never double-sync.
const backgroundSyncTask = 'crystal.background.sync';

/// Entry point invoked by Workmanager inside its background isolate.
///
/// The isolate is fresh: Flutter widgets don't exist, the SQLite cache is
/// reopened directly, and Supabase is re-initialized from [AppConfig].
@pragma('vm:entry-point')
void crystalBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != backgroundSyncTask) return true;
    try {
      await _runBackgroundSync();
    } catch (e, st) {
      CrashReporter.log('Background sync failed: $e');
      CrashReporter.report(e, st, reason: 'Workmanager background sync');
    }
    return true;
  });
}

/// Registers the periodic background sync (min 15-minute cadence on Android).
Future<void> initializeBackgroundSync() async {
  try {
    await Workmanager().initialize(crystalBackgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      backgroundSyncTask,
      backgroundSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  } catch (_) {
    // Workmanager is only available on real platforms.
  }
}

Future<void> _runBackgroundSync() async {
  final config = AppConfig.fromEnvironment();
  final secure = await RemoteAppConfig.resolve(
    config,
    SecureStorageServiceImpl(const FlutterSecureStorage()),
  );
  final supabaseUrl = secure?.supabaseUrl ?? config.supabaseUrl;
  final supabaseAnonKey = secure?.supabaseAnonKey ?? config.supabaseAnonKey;
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return;

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    // Without this the background isolate has no persisted session, so
    // `auth.currentUser` is null and every run returned at the guard below.
    // The job was registered and silently did nothing on every single tick.
    authOptions: const FlutterAuthClientOptions(
      persistSession: true,
      localStorage: SecureSupabaseLocalStorage(),
    ),
  );
  final client = Supabase.instance.client;
  final myId = client.auth.currentUser?.id;
  if (myId == null || myId.isEmpty) return;

  final db = AppDatabase(LazyDatabase(() => openLocalDatabase()));
  // Bind the account before anything reads, exactly as the foreground store
  // does, so the background pass cannot act on another account's rows.
  final store = LocalStore(db, ownerId: myId);
  try {
    await store.adoptUnscopedRows(myId);

    final relay = SupabaseRelayRepository(client);
    final deviceId = await DeviceIdentity.getOrCreate();

    final outbox = OutboxSyncEngine(
      store: store,
      messagesRepository: SupabaseMessagesRepository(client),
      relay: relay,
      getMyId: () => myId,
      // Workmanager only runs this task under a `connected` constraint, so the
      // engine may treat the device as online. Passing nothing left the engine
      // at its always-online default anyway, which is correct here.
    );

    // Deletions first: a message fetched before its tombstone is known must not
    // be stored, and applying deletions ahead of the message catch-up makes
    // that the default rather than a race.
    await RelaySyncRecoveryService(store: store, repository: relay).recover();

    // Then the acknowledgements this device owes from the previous session,
    // which is the whole point of keeping them in SQLite rather than memory.
    await DeliveryAcknowledgementService(
      store: store,
      repository: relay,
      deviceId: deviceId,
    ).flushPending();

    await SyncService(
      store: store,
      conversationsRepository: SupabaseConversationsRepository(client),
      messagesRepository: SupabaseMessagesRepository(client),
      outbox: outbox,
      getMyId: () => myId,
    ).syncIncremental();
  } finally {
    await db.close();
  }
}
