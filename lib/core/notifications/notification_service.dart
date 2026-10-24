import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-app notification surface.
///
/// ## No remote push provider
///
/// This app has no FCM/APNs dependency. Nothing delivers a notification while
/// the process is dead: message delivery goes through Supabase Realtime while
/// the app is running, and the app renders the notification itself from that
/// event. The tradeoff is deliberate — a remote push provider needs a hosted
/// credential file, and a build without one has an SDK present but inert, which
/// fails silently at exactly the moment it matters.
///
/// What still works, without any provider:
///  - a message arriving while the app is in the foreground or background
///  - media transfer progress
///
/// What does not, and is not pretended otherwise: waking a fully terminated app.
/// If that is required later, it means adding a provider back and accepting a
/// `google-services.json` in the tree.
///
/// [token] therefore always returns null. It stays on the API because device
/// registration passes it to the `register_device` RPC, and a null token is the
/// correct value for a device that cannot receive remote push.
class NotificationService {
  NotificationService();

  /// Master switch. Set false to disable every notification call.
  static const bool enabled = true;

  static const String channelMessages = 'messages';

  /// Channel that carries an inline reply action. Kept separate from
  /// [channelMessages] so the capability set never changes under a channel
  /// Android has already created for the user.
  static const String channelReplies = 'messages_replies';

  /// Action id for the inline reply button.
  static const String actionIdInlineReply = 'reply_inline';

  /// `SharedPreferencesAsync` rather than the cached `SharedPreferences`
  /// instance: this is read from a background isolate, which has no plugin
  /// registration and so cannot use the legacy cached API at all.
  static const String _pendingRepliesKey =
      'notifications.pending_inline_replies';

  /// True once Android has confirmed `POST_NOTIFICATIONS`.
  ///
  /// False is the normal state on iOS and on Android 12-, where the permission
  /// does not exist and needs no request — the settings screen uses this to
  /// distinguish "user switched notifications off" from "this platform has no
  /// such permission".
  bool hasAndroidPermission = false;

  /// Invoked when the user types a reply in the notification shade.
  ///
  /// Runs from a background isolate (Android delivers inline-reply text without
  /// launching the UI), so the app may not be running. It receives the reply
  /// text and the route the notification pointed at; see [onInlineReply].
  ValueChanged<InlineReply>? onInlineReply;

  /// Invoked when the user taps a notification. Receives the route descriptor,
  /// e.g. `open_chat/<conversationId>`.
  ValueChanged<String>? onNotificationTap;

  bool _initialized = false;
  FlutterLocalNotificationsPlugin? _local;

  /// Idempotently initializes the plugin and the Android notification
  /// channels. Never throws.
  Future<void> ensureInitialized() async {
    if (!enabled || _initialized) return;
    _initialized = true;

    try {
      _local = FlutterLocalNotificationsPlugin();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _local!.initialize(
        const InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: (response) =>
            _dispatchTap(response.payload),
        // Android runs this in a background isolate when the user replies
        // without opening the app, so it cannot reach a live [NotificationService].
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Channels are an API 26+ concept. Below that importance is a
      // per-notification field, so registering one would throw and there is
      // nothing to register. Android 6/7 callers rely on that instead.
      final androidImpl = _local!
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // High-importance, sound + vibration channel for chat traffic.
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelMessages,
          'Messages',
          description: 'Incoming chat messages',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Replies are a separate channel because Android compares the channel's
      // capability set against the action being attached: a RemoteInput action
      // added to the plain `messages` channel is silently dropped when the
      // channel was created without it. Identical user-visible settings.
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelReplies,
          'Messages with quick reply',
          description: 'Incoming chat messages that can be replied to inline',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      await _requestAndroidPermission(androidImpl);
    } catch (_) {
      // Plugin unavailable (web, unit test, headless): notifications stay inert
      // but the rest of the app is unaffected.
    }
  }

  /// Asks for `POST_NOTIFICATIONS`, which is a *runtime* permission from API 33.
  ///
  /// Declaring it in the manifest is not enough: without a runtime request the
  /// system drops every notification this app posts, which is why the app could
  /// look fully wired up and still be silent on a modern device. Pre-33 devices
  /// have no such permission, so the call is skipped there rather than made to
  /// throw and abort the rest of initialization.
  Future<void> _requestAndroidPermission(
    AndroidFlutterLocalNotificationsPlugin? impl,
  ) async {
    if (impl == null) return;
    try {
      if (!Platform.isAndroid) return;
      final granted = await impl.requestNotificationsPermission();
      hasAndroidPermission = granted ?? false;
    } catch (_) {
      hasAndroidPermission = false;
    }
  }

  /// Shows a notification with sound and vibration. Never throws.
  ///
  /// Pass a non-null [conversationId] to attach an inline "Reply" action, the
  /// way a chat app does. It is a separate channel because Android drops a
  /// RemoteInput action attached to a channel created without one.
  Future<void> showForeground({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
    String? conversationId,
  }) async {
    final local = _local;
    if (local == null) return;
    try {
      final route = routeForData(data);
      final android = AndroidNotificationDetails(
        conversationId == null ? channelMessages : channelReplies,
        conversationId == null ? 'Messages' : 'Messages with quick reply',
        channelDescription: 'Incoming chat messages',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.private,
        actions: conversationId == null
            ? null
            : <AndroidNotificationAction>[
                const AndroidNotificationAction(
                  actionIdInlineReply,
                  'Reply',
                  // Stays in the shade: the user answers without losing their
                  // place in whatever else they were doing.
                  showsUserInterface: false,
                  cancelNotification: true,
                  allowGeneratedReplies: true,
                  inputs: <AndroidNotificationActionInput>[
                    AndroidNotificationActionInput(
                      allowFreeFormInput: true,
                      label: 'Message',
                    ),
                  ],
                ),
              ],
      );
      await local.show(
        _notificationId(data),
        title,
        body,
        NotificationDetails(
          android: android,
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        payload: route,
      );
    } catch (_) {
      // Local notifications are best-effort.
    }
  }

  /// Dismisses a previously shown notification by its id.
  Future<void> cancel(Map<String, dynamic> data) async {
    final local = _local;
    if (local == null) return;
    try {
      await local.cancel(_notificationId(data));
    } catch (_) {
      // Best-effort.
    }
  }

  /// Always null: this build registers no remote push provider.
  ///
  /// Kept so the three `register_device` call sites stay unchanged; a null
  /// token is what the RPC expects for a device that cannot be woken remotely.
  Future<String?> token() async => null;

  String get platform {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
    } catch (_) {
      // Platform channel unavailable (e.g. tests).
    }
    return 'unknown';
  }

  /// Stable per-message id.
  ///
  /// Re-notifying the same message updates it in place instead of stacking a
  /// second banner; ids must therefore be derived from the message, not from a
  /// counter or `hashCode`, which is not stable across isolates.
  int _notificationId(Map<String, dynamic> data) {
    final stable =
        data['message_id'] ?? data['conversation_id'] ?? routeForData(data);
    int hash = 0;
    for (final unit in '$stable'.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  /// Maps notification data to a routable descriptor for taps/actions.
  static String routeForData(Map<String, dynamic> data) {
    final conversationId = data['conversation_id'];
    if (conversationId != null) {
      return 'open_chat/$conversationId';
    }
    return 'open_chats';
  }

  void _dispatchTap(String? route) {
    final tap = onNotificationTap;
    if (tap != null && route != null && route.isNotEmpty) {
      tap(route);
    }
  }

  /// Takes everything the background isolate captured and clears the queue.
  ///
  /// Called once at startup and again whenever the app returns to the
  /// foreground, because the user can reply from the shade at any point between
  /// two launches and the background isolate has no way to reach the network
  /// client or the auth session.
  ///
  /// Returns an empty list when nothing is pending, which is the common case.
  static Future<List<InlineReply>> takePendingReplies() async {
    try {
      final store = SharedPreferencesAsync();
      final raw = await store.getString(_pendingRepliesKey);
      if (raw == null || raw.isEmpty) return const [];
      // Cleared before returning: the caller owns these now. If the flush fails
      // the user can retype, which beats a reply being delivered twice on every
      // launch because the queue was never emptied.
      await store.remove(_pendingRepliesKey);
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(InlineReply.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

/// A reply typed in the notification shade.
///
/// Produced by [notificationTapBackground] on a background isolate, so it has
/// to survive as plain JSON until the app is next able to send it.
class InlineReply {
  const InlineReply({
    required this.conversationId,
    required this.text,
    required this.queuedAtMs,
  });

  factory InlineReply.fromJson(Map<String, dynamic> json) => InlineReply(
    conversationId: json['conversation_id'] as String? ?? '',
    text: json['text'] as String? ?? '',
    queuedAtMs: (json['queued_at_ms'] as num?)?.toInt() ?? 0,
  );

  final String conversationId;
  final String text;
  final int queuedAtMs;

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationId,
    'text': text,
    'queued_at_ms': queuedAtMs,
  };

  String get conversationIdFromRoute {
    final marker = 'open_chat/';
    return conversationId.startsWith(marker)
        ? conversationId.substring(marker.length)
        : conversationId;
  }
}

/// Background-isolate entry point for inline replies.
///
/// Android hands a shade reply to an isolate that has no access to the app's
/// Supabase client, auth session, or anything in the provider graph. Rather
/// than pretend otherwise, the reply is appended to a small durable queue that
/// [NotificationService.takePendingReplies] drains on the next foreground.
///
/// Must stay a top-level function with the `vm:entry-point` pragma: the plugin
/// looks the handler up by name from the background isolate.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  try {
    if (response.actionId != NotificationService.actionIdInlineReply) {
      return;
    }
    final text = response.input?.trim() ?? '';
    if (text.isEmpty) return;
    final route = response.payload ?? '';
    if (route.isEmpty) return;

    final store = SharedPreferencesAsync();
    final raw = await store.getString(NotificationService._pendingRepliesKey);
    final queue = <InlineReply>[];
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        queue.addAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(InlineReply.fromJson)
              .where((r) => r.text.trim().isNotEmpty),
        );
      }
    }
    queue.add(
      InlineReply(
        conversationId: route,
        text: text,
        queuedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    // Bounded so a user who never opens the app cannot grow preferences without
    // limit. The newest replies are the ones they still expect to be sent.
    if (queue.length > 50) {
      queue.removeRange(0, queue.length - 50);
    }
    await store.setString(
      NotificationService._pendingRepliesKey,
      jsonEncode(queue.map((r) => r.toJson()).toList()),
    );
  } catch (_) {
    // A reply that cannot even be queued is dropped; surfacing an error here
    // would crash a background isolate with no UI to show it on.
  }
}
