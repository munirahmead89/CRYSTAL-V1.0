// lib/firebase_options.dart
// Firebase options are provided via --dart-define. Firestore/Cloud Messaging
// is optional: if FIREBASE_APP_ID is not provided, currentPlatform returns null
// and push notifications are skipped rather than blocking app startup.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const String? webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const String? androidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const String? iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');

  static const String? projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String? messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String? appId = String.fromEnvironment('FIREBASE_APP_ID');

  static FirebaseOptions? get currentPlatform {
    if (appId == null || projectId == null || messagingSenderId == null) {
      return null;
    }
    return FirebaseOptions(
      apiKey: androidApiKey ?? '',
      appId: appId!,
      messagingSenderId: messagingSenderId!,
      projectId: projectId!,
      storageBucket: '${projectId}.appspot.com',
    );
  }
}
