# Keep ML Kit classes
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep Flutter internals
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Hive
-keep class com.hive.** { *; }

# Flutter Play Store Split Application
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
