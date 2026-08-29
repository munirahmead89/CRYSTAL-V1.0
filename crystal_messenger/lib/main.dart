import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';
import 'providers/shared_preferences_provider.dart';
import 'services/push/push_notification_service.dart';
import 'services/push/background_refresh.dart';
import 'firebase_options.dart';
import 'core/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Supabase
  try {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 2),
    );
    Logger.info('Main', 'Supabase initialized');
  } catch (e) {
    Logger.error('Main', 'Supabase init failed', e);
  }

  // Firebase (push notifications) — optional, won't block app if unavailable
  try {
    if (DefaultFirebaseOptions.projectId != null) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      Logger.info('Main', 'Firebase initialized');
    }
  } catch (e) {
    Logger.error('Main', 'Firebase init skipped', e);
  }

  final prefs = await SharedPreferences.getInstance();

  // Background sync (Workmanager)
  try {
    final bg = BackgroundSyncService();
    await bg.initialize();
  } catch (e) {
    Logger.error('Main', 'Background sync init failed', e);
  }

  // Push notifications
  try {
    final push = PushNotificationService(Supabase.instance.client, prefs);
    await push.initialize();
  } catch (e) {
    Logger.error('Main', 'Push init failed', e);
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const CrystalMessengerApp(),
    ),
  );
}
