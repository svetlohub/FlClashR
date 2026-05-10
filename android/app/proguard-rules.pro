# ── Raketa — ProGuard / R8 rules ─────────────────────────────────────────────

# Keep all Raketa app classes
-keep class com.follow.clashx.** { *; }

# Flutter embedding — keep everything
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Play Store split-install classes are optional (we don't use Play Store).
# R8 complains they are missing — suppress all warnings for them.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# VPN / Android system classes — never strip
-keep class * extends android.app.Service
-keep class * extends android.app.Application
-keep class * extends android.net.VpnService
-keep class * extends android.service.quicksettings.TileService

# Gson / JSON serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Kotlin coroutines
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Suppress all other missing-class warnings from third-party libs
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
