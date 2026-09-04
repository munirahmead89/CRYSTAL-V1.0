# Flutter-specific ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Supabase
-keep class io.github.jan-tennert.supabase.** { *; }

# Drift database
-keep class drift.** { *; }

# Freezed / JSON serialization
-keep class com.crystalmessenger.models.** { *; }

# WebRTC
-keep class org.webrtc.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }
