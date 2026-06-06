## Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## Supabase / GoTrue
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

## Google Play Core (Flutter deferred components 引用，非 Play 分发也需 dontwarn)
-dontwarn com.google.android.play.core.**

## Alarm package
-keep class com.gdelataillade.alarm.** { *; }
