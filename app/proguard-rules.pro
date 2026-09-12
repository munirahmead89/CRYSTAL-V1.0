# Keep rules for Crystal Messenger
# Moshi uses reflection for some adapters
-keepclassmembers class **$$JsonAdapter { *; }
-keep @com.squareup.moshi.JsonClass class * { *; }

# Keep logs in debug but strip in release
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
}