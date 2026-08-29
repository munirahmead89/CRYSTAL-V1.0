import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/supabase_provider.dart';
import '../../providers/shared_preferences_provider.dart';
import '../../core/utils/logger.dart';

class PushNotificationService {
  final SupabaseClient _supabase;
  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  PushNotificationService(this._supabase, this._prefs);

  Future<void> initialize() async {
    // Request permission
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _initLocalNotifications();
      await _registerToken();
      _setupHandlers();
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  Future<void> _registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _supabase.rpc('upsert_push_token', params: {
          'p_token': token,
          'p_platform': 'flutter',
        });
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await _supabase.rpc('upsert_push_token', params: {
          'p_token': newToken,
          'p_platform': 'flutter',
        });
      });
    } catch (e) {
      Logger.error('PushService', 'Token registration failed', e);
    }
  }

  void _setupHandlers() {
    FirebaseMessaging.onMessage.listen((message) {
      Logger.info('PushService', 'Foreground message received');
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      Logger.info('PushService', 'Notification tapped');
    });
  }

  void _onNotificationTapped(NotificationResponse response) {
    Logger.info('PushService', 'Local notification tapped: ${response.payload}');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'crystal_messages',
      'Messages',
      channelDescription: 'Incoming messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      color: Color(0xFF00A884),
    );
    const iosDetails = DarwinNotificationDetails(presentSound: true);
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      _prefs.getBool('message_preview') ?? true ? notification.title : 'New message',
      _prefs.getBool('message_preview') ?? true ? notification.body : '',
      details,
      payload: message.data['chat_id'],
    );
    _vibrateIfAllowed();
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'crystal_messages',
      'Messages',
      channelDescription: 'Incoming messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      color: Color(0xFF00A884),
    );
    const iosDetails = DarwinNotificationDetails(presentSound: true);
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch,
      _prefs.getBool('message_preview') ?? true ? title : 'New message',
      _prefs.getBool('message_preview') ?? true ? body : '',
      details,
      payload: payload,
    );
    _vibrateIfAllowed();
  }

  void _vibrateIfAllowed() {
    if (_prefs.getBool('vibration_enabled') ?? true) {
      try {
        Vibration.vibrate(duration: 200);
      } catch (_) {}
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return PushNotificationService(client, prefs);
});
