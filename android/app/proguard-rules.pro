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

## 阿里云移动推送
-keep class com.alibaba.sdk.android.** { *; }
-keep class com.ut.device.** { *; }
-keep class com.ta.utdid2.** { *; }
-keep class anet.channel.** { *; }
-keep class anetwork.channel.** { *; }
-keep class com.taobao.** { *; }
-keep class com.alicloud.** { *; }
-keep class com.aliyun.** { *; }

## 阿里云推送依赖的缺失类（仅告警，运行时不需要）
-dontwarn org.android.netutil.**
-dontwarn org.bouncycastle.**
-dontwarn anet.channel.**
-dontwarn anetwork.channel.**
-dontwarn com.huawei.secure.**

## 来自 aliyun-emas-services.json proguard_keeplist（官方要求）
-keep class org.android.spdy.**{*;}
-keep class org.android.agoo.**{*;}
-dontwarn org.android.spdy.**
-dontwarn org.android.agoo.**
-keep class com.taobao.sophix.**{*;}
-keep class com.ta.utdid2.device.**{*;}
## 防止 inline（热修复必需）
-dontoptimize

## 阿里云推送内置的华为 HMS 依赖（R8 自动生成）
-dontwarn com.huawei.android.os.BuildEx$VERSION
-dontwarn com.huawei.hianalytics.process.HiAnalyticsConfig$Builder
-dontwarn com.huawei.hianalytics.process.HiAnalyticsConfig
-dontwarn com.huawei.hianalytics.process.HiAnalyticsInstance$Builder
-dontwarn com.huawei.hianalytics.process.HiAnalyticsInstance
-dontwarn com.huawei.hianalytics.process.HiAnalyticsManager
-dontwarn com.huawei.hianalytics.util.HiAnalyticTools
-dontwarn com.huawei.hms.availableupdate.UpdateAdapterMgr
-dontwarn com.huawei.libcore.io.ExternalStorageFile
-dontwarn com.huawei.libcore.io.ExternalStorageFileInputStream
-dontwarn com.huawei.libcore.io.ExternalStorageFileOutputStream
-dontwarn com.huawei.libcore.io.ExternalStorageRandomAccessFile
