# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Fix for R8 Missing Class Warnings (Play Core / Dynamic Features)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Flutter Background Service
-keep class id.flutter.flutter_background_service.** { *; }
-keep public class id.flutter.flutter_background_service.BackgroundService { *; }
