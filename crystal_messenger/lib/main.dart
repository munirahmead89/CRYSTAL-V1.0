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
import 'services/encryption/encryption_service.dart';
import 'firebase_options.dart';
import 'core/constants/api_constants.dart';
import 'core/utils/logger.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Logger.info('Main', 'Handling a background message: ${message.messageId}');
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

  final prefs = await SharedPreferences.getInstance();

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

  try {
    final bg = BackgroundSyncService();
    await bg.initialize();
  } catch (e) {
    Logger.error('Main', 'Background sync init failed', e);
  }

  try {
    final push = PushNotificationService(Supabase.instance.client, prefs);
    await push.initialize();
  } catch (e) {
    Logger.error('Main', 'Push init failed', e);
  }

  // Initialize E2EE key registration
  try {
    final encryptionService = EncryptionService(Supabase.instance.client, prefs);
    await encryptionService.registerKeys();
    Logger.info('Main', 'E2EE keys initialized');
  } catch (e) {
    Logger.error('Main', 'E2EE init failed', e);
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
