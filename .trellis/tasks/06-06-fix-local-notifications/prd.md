# fix: 系统本地通知修复（声音/后台存活/分类混乱）

## Goal

修复 Android 本地通知系统的三个问题，在无需阿里云推送（营业执照未办妥）的情况下，确保本地提醒通知：
1. 使用系统默认通知音效，而非自定义 WAV 生成的奇怪声音
2. App 进程被系统杀死后仍能弹出通知（侧边栏可见）
3. 系统设置中通知分类清晰、命名规范

## What I already know

### 现有架构（3层叠加）

| 层级 | 组件 | 用途 |
|------|------|------|
| Layer 1 | `flutter_local_notifications` `zonedSchedule` | App 存活时的准时通知 |
| Layer 2 | `alarm` 包 (`AlarmService`) | App 被杀死后的兜底闹钟 |
| Layer 3 | `WechatReminderService` 服务端推送 | 微信通道兜底 |

### 问题 1 根因：声音奇怪，非系统默认音
- `alarm_service.dart` 的 `scheduleAlarm()` 中：
  - `assetAudioPath: 'assets/audio/alarm.wav'` — 播放一个自定义 WAV 文件
  - `volume: 0.0` — 但 alarm 包的 AlarmSettings 中 volume 可能控制的是媒体音量，通知通道另有自己的音量
  - `loopAudio: false` — 但 playback 一次奇怪的 WAV 声音
- `flutter_local_notifications` 的 `_createNotificationChannels()` 创建了通道但删除了旧通道再重建，可能导致某些 ROM 上通道配置异常
- 实际用户听到的是 `alarm.wav` 这个自定义音效，而不是系统的 `notification_sound`

### 问题 2 根因：App 被杀后无通知
- `flutter_local_notifications` 的 `zonedSchedule` 在 Android 12+ 依赖 `SCHEDULE_EXACT_ALARM`，但即使 fallback 到 `inexactAllowWhileIdle`，**进程被杀死后 OS 可能丢弃或无限延迟这些定时任务**
- `AlarmService` 作为兜底，但：
  - `alarm` 包使用 `AlarmManager.setAlarmClock()` 或 `setExact()`，理论上能存活于进程死亡
  - 但 `AlarmSettings` 中配置：`volume: 0.0`、`androidFullScreenIntent: false` — **即使 Alarm 触发也无声无通知**
  - 而且 `NotificationSettings` 可能不依赖系统通知通道，而是 Alarm 包自己创建通道
- 用户已确认关闭了电池优化 → 问题出在实现本身

### 问题 3 根因：4 个通知分类
- **alarm notification** — 由 `alarm` 包（`com.gdelataillade.alarm`）自动创建，channel ID 为 `alarm_notification`
- **schedule reminders** — `flutter_local_notifications` 创建，channel ID `schedule_reminders`
- **repeat reminds** — `flutter_local_notifications` 创建，channel ID `repeating_reminders`
- **task reminders** — 可能来自阿里云推送（`aliyun_push` 包自动创建）或 `flutter_local_notifications` 其他通道

## Decision (ADR-lite)

**Context**: 阿里云推送因营业执照问题暂停。现有通知存在 3 个问题：声音异常（alarm.wav）、App 被杀后无通知、4 个混杂通知分类。

**Decision**:
- 问题 1: 删除 `assets/audio/alarm.wav` 自定义音效，通知使用系统默认通知音
- 问题 2: 原生方案优先 — 用 Kotlin `BroadcastReceiver` + `AlarmManager.setAlarmClock()` 替代 `alarm` 包做兜底。保留旧代码路径通过 `useNativeAlarm` 标志切换回滚。
- 问题 3: 合并为 1 个通道 `taskora_reminders`（任务提醒），原生和 flutter_local_notifications 共用

**Consequences**:
- 原生方案：App 进程被杀后 `AlarmManager.setAlarmClock()` 最可靠
- 回滚开关：`AlarmService.useNativeAlarm = false` 切回 alarm 包（需保留依赖）
- 删除旧通道后，系统设置会保留历史通道条目，但不再产生新通知

## Requirements

- [x] 通知使用 Android 系统默认通知音效（`Settings.System.DEFAULT_NOTIFICATION_URI`）
- [x] App 进程被系统杀死后，已调度的提醒仍能按时弹出通知（侧边栏可见，有声音）
- [x] 系统设置中通知分类精简为 1 个，命名清晰中文「任务提醒」

## Acceptance Criteria

- [ ] 收到通知时播放的是系统默认通知声，而非自定义 WAV 音效
- [ ] 杀掉 App 进程（强制停止），等待已调度的提醒时间 → 通知正常弹出，有声音
- [ ] 进入 系统设置 > 应用 > Taskora > 通知，分类只剩「任务提醒」

## Technical Approach

### 架构变化

```
改前：
App 存活 → flutter_local_notifications zonedSchedule
App 被杀 → alarm 包 (volume=0, silent) ❌

改后：
App 存活 → flutter_local_notifications zonedSchedule
App 被杀 → AlarmManager.setAlarmClock() → BroadcastReceiver → 系统通知 ✅
```

### 改动清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `NotificationAlarmReceiver.kt` | **新建** | BroadcastReceiver，触发时创建系统通知 |
| `NotificationAlarmHelper.kt` | **新建** | AlarmManager 调度助手，setAlarmClock |
| `MainActivity.kt` | **修改** | 添加 MethodChannel `com.taskora/native_alarm` |
| `AndroidManifest.xml` | **修改** | 注册 NotificationAlarmReceiver |
| `alarm_service.dart` | **修改** | 添加原生路径 + useNativeAlarm 开关 |
| `notification_service.dart` | **修改** | 通道合并为 taskora_reminders，去掉旧通道 |
| `assets/audio/alarm.wav` | **删除** | 不再使用自定义音效 |

### 回滚方案

修改 `lib/services/alarm_service.dart` 第 27 行：
```dart
static bool useNativeAlarm = false;  // 改为 false 回滚
```

## Out of Scope

- 阿里云推送集成（营业执照未办妥，暂停）

## Technical Notes

### 关键文件
- `lib/services/notification_service.dart` — 主通知服务，flutter_local_notifications
- `lib/services/alarm_service.dart` — Alarm 兜底，alarm 包
- `lib/models/entities/schedule.dart` — Schedule 实体，含 remindBeforeMinutes、reminderType 等
- `android/app/src/main/AndroidManifest.xml` — 权限声明
- `lib/presentation/pages/profile/app_settings_page.dart` — 设置页通知状态展示

### 相关依赖
- `flutter_local_notifications: ^19.5.0`
- `alarm: ^5.4.1`

### 国产 ROM 注意事项
- 小米/华为/荣耀/Oppo/Vivo 对后台进程有额外限制
- 即使关闭电池优化，`flutter_local_notifications` 的 zonedSchedule 在进程被杀死后仍可能不触发
- `AlarmManager.setAlarmClock()` 是 Android 上最可靠的方案，但 `alarm` 包 v5.4.1 的实现需要验证
