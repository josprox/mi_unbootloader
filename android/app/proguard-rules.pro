# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Background Service
-keep class id.flutter.flutter_background_service.** { *; }
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep our service classes to be safe, though Dart obfuscation is separate from R8 usually,
# R8 mainly affects the Android side plugins and JNI bridges.
# But sometimes if we use reflection or if plugins use it, we need keeps.

# General Flutter keeps
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class androidx.** { *; }
-keep class android.support.** { *; }
-keep class **.R$* { *; }

# Prevent warnings
-dontwarn io.flutter.embedding.**
