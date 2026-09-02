import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app/app.dart';
import 'providers/shared_preferences_provider.dart';
import 'services/push/push_notification_service.dart';
import 'services/push/background_refresh.dart';
import 'firebase_options.dart';
import 'core/constants/api_constants.dart';
import 'core/utils/logger.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Logger.info('Main', 'Handling a background message: ${message.messageId}');
  // Note: Local notifications for background messages are handled natively or through the plugin
}

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

  // 1. Supabase MUST initialize first — other services depend on it.
  try {
    await Supabase.initialize(
      url: ApiConstants.supabaseUrl,
      anonKey: ApiConstants.supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 2),
    );
    Logger.info('Main', 'Supabase initialized');
  } catch (e) {
    Logger.error('Main', 'Supabase init failed', e);
  }

  // 2. SharedPreferences (needed by providers)
  final prefs = await SharedPreferences.getInstance();

  // 3. Firebase (optional — push notifications won't block app if unavailable)
  try {
    if (DefaultFirebaseOptions.projectId != null) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      Logger.info('Main', 'Firebase initialized');
    }
  } catch (e) {
    Logger.error('Main', 'Firebase init skipped', e);
  }

  // 4. Background sync (Workmanager) — optional
  try {
    final bg = BackgroundSyncService();
    await bg.initialize();
  } catch (e) {
    Logger.error('Main', 'Background sync init failed', e);
  }

  // 5. Push notifications — optional
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
