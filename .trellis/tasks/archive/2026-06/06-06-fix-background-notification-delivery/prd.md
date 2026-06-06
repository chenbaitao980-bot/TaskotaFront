# fix-background-notification-delivery

## Goal

App 被完全杀死后，到点不触发提醒；只有重新打开 App 才会调度并触发。需要让提醒在 App 进程不存在时也能可靠送达。

## What I already know

**根本原因**：`flutter_local_notifications.zonedSchedule()` 底层用的是 `AlarmManager.setExactAndAllowWhileIdle()`。国产 ROM（小米 MIUI、华为 EMUI、OPPO ColorOS、Vivo）在杀掉 App 进程时，会一并清除 AlarmManager 队列，导致通知再也不会触发。

**现有机制分析**：
- `flutter_local_notifications`（`setExactAndAllowWhileIdle`）：App 被杀即失效
- `alarm` 包（`setAlarmClock`）：更高优先级，显示在系统"闹钟"列表，大部分国产 ROM 不会轻易清除 → 我们上次改 loopAudio: false 但移除了此调用
- `BatteryOptimizationGuide`：品牌引导已实现（小米/华为/OPPO/vivo），但依赖用户主动操作
- `BatteryOptimizationService`：可以请求/检测豁免，已有 MethodChannel 实现
- `FcmService`：仅有桩代码，`firebase_messaging` 未加入 pubspec，完全未集成
- `WxPusher` scan 函数：`scan-wechat-reminders` 已有 Supabase Edge Function，但没有 cron 触发；需要用户绑定微信
- `schedule-push` 边缘函数：被 Dart 代码调用，但 **Supabase 侧尚未实现**，调用会静默失败

## Approaches

### Approach A：重新接入 alarm 包（快速修复）
- 在 `scheduleNotification` 里恢复 `AlarmService().scheduleAlarm()` 调用（loopAudio 已改 false）
- alarm 包使用 `AlarmManager.setAlarmClock()`，在大多数国产 ROM 上能在 App 被杀后继续触发
- **优点**：1 行改动，无需后端；对 80% 国产 ROM 有效
- **缺点**：Xiaomi/华为最新版本仍可能清除；会出现两条通知（flutter_local_notifications + alarm 包各一条）；根本上不如服务端可靠

### Approach B：FCM 服务端推送（一劳永逸）
- 集成 `firebase_messaging`：pubspec + google-services.json + Firebase 控制台配置
- 实现 `schedule-push` Supabase Edge Function（存储计划推送 + cron 扫描发送 FCM）
- **优点**：100% 可靠，App 被杀/无网络缓存/重启均可触发；行业标准方案
- **缺点**：需要 Firebase 项目配置（1-2天），需要新 Edge Function + DB 表

### Approach C：WxPusher cron（已有后端，补齐最后一步）
- 在 Supabase 用 `pg_cron` 或外部 cron 每分钟调用 `scan-wechat-reminders`
- **优点**：后端逻辑已实现，只需配一条 cron，成本极低
- **缺点**：依赖用户绑定微信；不覆盖未绑定用户

## Decision (ADR-lite)

**Context**: App 被杀后 AlarmManager 被清，flutter_local_notifications 不能后台触达  
**Decision**: Approach A — 重接 alarm 包（setAlarmClock）作为后台兜底，接受双通知 UX  
**Consequences**: App 运行时出现 2 条通知（alarm + flutter_local_notifications）；系统默认铃声通过 volume: 0.0 实现；后续可升级 FCM 彻底替代

## Technical Notes

- `lib/services/fcm_service.dart` — stub，需实现
- `lib/services/alarm_service.dart:39` — `loopAudio: false` 已修改
- `lib/services/notification_service.dart:270` — AlarmService 调用已移除（上次改动）
- `lib/presentation/widgets/battery_optimization_guide.dart` — 品牌引导完整，但触发时机只在首次
- `supabase/functions/scan-wechat-reminders/index.ts` — 逻辑完整，只需 cron
- `schedule-push` edge function — 不存在，需新建
