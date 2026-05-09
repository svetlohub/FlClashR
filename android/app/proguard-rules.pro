# Raketa — ProGuard rules for release build
# Keep all model classes (used for JSON serialization via Gson)
-keep class com.follow.clashx.models.** { *; }

# Keep Flutter and Dart FFI bridge (required for Go core FFI)
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep all classes referenced from Dart via platform channels
-keep class com.follow.clashx.** { *; }

# Keep Gson serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep VPN service and notification classes
-keep class * extends android.app.Service
-keep class * extends android.app.Application
-keep class * extends android.net.VpnService

# Suppress warnings for missing classes in dependencies
-dontwarn com.google.android.gms.**
-dontwarn org.bouncycastle.**
