# Crystal Messenger ProGuard / R8 rules (release). Flutter Dart code is already
# AOT-compiled; these rules protect the thin Java/Kotlin host layer and the
# Pigeon-generated host APIs from aggressive shrinking/obfuscation.

# Flutter embedding.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Pigeon-generated host API surface (registered by name from Dart).
-keep class dev.flutter.pigeon.** { *; }

# App host entry point (pigeon DeviceInfoApi, MainActivity).
-keep class com.munirwaheed.crystal_messenger.** { *; }

# We never use a JVM persistent HTTP stack beyond OkHttp (bundled by plugins).
-dontwarn okhttp3.internal.platform.**
-dontwarn javax.annotation.**

# Flutter engine's optional Play Store deferred-components support is unused
# (this APK ships as a monolith); the referenced classes don't exist in the
# dependency closure, so silence those missing-class diagnostics.
-dontwarn com.google.android.play.core.**