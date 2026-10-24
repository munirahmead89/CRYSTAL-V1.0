import 'package:crystal_messenger/app/app.dart';
import 'package:crystal_messenger/app/unconfigured_app.dart';
import 'package:crystal_messenger/core/background/background_sync.dart';
import 'package:crystal_messenger/core/config/app_config.dart';
import 'package:crystal_messenger/core/config/remote_app_config.dart';
import 'package:crystal_messenger/core/errors/error_handler.dart';
import 'package:crystal_messenger/core/observability/crash_reporter.dart';
import 'package:crystal_messenger/core/security/app_lock.dart';
import 'package:crystal_messenger/core/security/secure_storage_service.dart';
import 'package:crystal_messenger/core/security/supabase_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Error Handling (logs + on-device crash recording)
  ErrorHandler.initialize();
  CrashReporter.enable();
  CrashReporter.wireGlobalHooks();

  // Initialize Configuration
  final config = AppConfig.fromEnvironment();

  // Resolve Supabase configuration at runtime (secure endpoint first, then
  // dev/staging dart-defines). No credentials are compiled into the binary.
  final secure = await RemoteAppConfig.resolve(
    config,
    SecureStorageServiceImpl(const FlutterSecureStorage()),
  );
  final supabaseUrl = secure?.supabaseUrl ?? config.supabaseUrl;
  final supabaseAnonKey = secure?.supabaseAnonKey ?? config.supabaseAnonKey;
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    // No credentials in this build (secrets.env missing). Surface the problem
    // in the UI instead of crashing so wiring failures are self-explanatory.
    runApp(const UnconfiguredApp());
    return;
  }

  // Initialize Supabase. Sessions (anonymous AND email/password) are persisted
  // through the encrypted flutter_secure_storage-backed LocalStorage, so a
  // previously-signed-in user is granted entry to the main app on cold start
  // even when offline (Supabase restores the session from local storage).
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      persistSession: true,
      localStorage: SecureSupabaseLocalStorage(),
    ),
  );

  // Log the cold-start session state for debuggability (e.g. restored guest).
  if (kDebugMode) {
    final restored = Supabase.instance.client.auth.currentSession != null;
    // ignore: avoid_print
    print('[crystal] Supabase ready; persisted session restored: $restored');
  }

  // Register the periodic background sync (15-minute cadence)
  await initializeBackgroundSync();

  // Load the app-lock controller's storage before the first frame. The lock has
  // to answer "is this within the grace period?" synchronously on a lifecycle
  // callback, so it cannot await a database read on demand.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        appLockControllerProvider.overrideWith(
          (ref) => AppLockController(prefs),
        ),
      ],
      child: const CrystalMessengerApp(),
    ),
  );
}
