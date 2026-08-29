# Firebase Setup (Push Notifications)

Flutter push notifications use Firebase Cloud Messaging (FCM). Follow these steps:

## 1. Create Firebase Project
- Go to https://console.firebase.google.com
- Create a new project (or use existing)

## 2. Add Android App
- Package name: `com.crystalmessenger`
- Download `google-services.json`
- Place at: `android/app/google-services.json`

Add to `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```

Add to `android/build.gradle` (buildscript dependencies):
```gradle
classpath 'com.google.gms:google-services:4.4.0'
```

## 3. Add iOS App
- Bundle ID: `com.crystalmessenger`
- Download `GoogleService-Info.plist`
- Place at: `ios/Runner/GoogleService-Info.plist`

Enable "Push Notifications" and "Background Modes > Remote notifications" in Xcode capabilities.

## 4. Generate firebase_options.dart
```bash
flutter pub add flutterfire_cli
flutterfire configure
```
This generates `lib/firebase_options.dart` and `firebase_options` based on your project.

## 5. Initialize Firebase
In `main.dart`, before `runApp`:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## 6. Supabase Edge Function
The existing `supabase/functions/send-message-push` works unchanged. Ensure FCM server key is set in Supabase dashboard → Edge Functions → Secrets:
- `FCM_SERVER_KEY`

## 7. Test
```bash
flutter run
# Send a message from another device → notification appears
```
