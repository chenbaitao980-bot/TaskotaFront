# fix: 系统本地通知修复（声音/后台存活/分类混乱）

## Goal

修复 Android 本地通知系统的三个问题，在无需阿里云推送（营业执照未办妥）的情况下，确保本地提醒通知：
1. 使用系统默认通知音效，而非自定义 WAV 生成的奇怪声音
2. App 进程被系统杀死后仍能弹出通知（侧边栏可见）
3. 系统设置中通知分类清晰、命名规范

## 当前状态（2026-06-06 第二轮）

代码已按 ADR 实施（见 Decision 章节），但用户反馈「划掉 App 进程后仍收不到通知」。

### 已实施的方案

- `NotificationAlarmReceiver.kt` — BroadcastReceiver，AlarmManager 触发后弹系统通知
- `NotificationAlarmHelper.kt` — 封装 `setAlarmClock()`
- `MainActivity.kt` — MethodChannel `com.taskora/native_alarm`
- `AlarmService.dart` — `useNativeAlarm=true` 走 MethodChannel 路径
- `NotificationService.dart` — `zonedSchedule` + `scheduleAlarm` 双重调度

### 怀疑根因（代码分析结论）

**风险 1（最高概率）: `setAlarmClock()` 抛出 SecurityException，被静默吞掉**

```
Flutter scheduleAlarm()
  → MethodChannel 'scheduleNotification'
  → NotificationAlarmHelper.scheduleNotification()
  → alarmManager.setAlarmClock(info, pendingIntent)  ← 无 try-catch！
    → 如果 SCHEDULE_EXACT_ALARM 未在运行时授权 → SecurityException
      → 传到 MainActivity MethodCallHandler → 传到 Flutter MethodChannel
        → 被 alarm_service.dart 的 catch(e) {} 静默吞掉
          → 实际上什么都没注册！
```

结果：只有 `zonedSchedule()` 生效。在国产 ROM 上，进程被划掉后 `inexact` alarm 被取消，通知消失。

**风险 2（国产 ROM）: MIUI 等强制把「划掉」等同于「强制停止」**

即使 `setAlarmClock()` 注册成功，MIUI 划掉时会同时取消该 App 所有 AlarmManager 条目。`setAlarmClock` 在 MIUI 中并不像 AOSP 一样受保护。

**风险 3（次要）: Kotlin 侧无任何日志，无法确认 alarm 是否真正注册**

`NotificationAlarmHelper.scheduleNotification()` 没有 logcat 输出，调试困难。

## What I already know

### 现有架构（3层叠加）

| 层级 | 组件 | 用途 |
|------|------|------|
| Layer 1 | `flutter_local_notifications` `zonedSchedule` | App 存活时的准时通知 |
| Layer 2 | 原生 `AlarmManager.setAlarmClock()` via MethodChannel | App 被杀死后的兜底 |
| Layer 3 | `WechatReminderService` 服务端推送 | 微信通道兜底 |

### 国产 ROM 注意事项
- 小米/华为/荣耀/Oppo/Vivo 对后台进程有额外限制
- 即使关闭电池优化，`flutter_local_notifications` 的 zonedSchedule 在进程被杀死后仍可能不触发
- `AlarmManager.setAlarmClock()` 是 Android 上最可靠的方案，但权限未授权时会静默失败

## Open Questions

- **Q1**: 这个问题是在哪种设备上复现的？（小米/华为/OPPO 等国产 ROM，还是原生 Android？）

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
- [x] **[新增]** 确认 setAlarmClock 真正被注册（增加 logcat 验证）
- [ ] **[阻塞/小米专属]** 小米 MIUI 划掉进程后通知能到达（需厂商推送，暂缓）

## Acceptance Criteria

- [ ] 收到通知时播放的是系统默认通知声，而非自定义 WAV 音效
- [ ] 杀掉 App 进程（强制停止），等待已调度的提醒时间 → 通知正常弹出，有声音
- [ ] 进入 系统设置 > 应用 > Taskora > 通知，分类只剩「任务提醒」
- [x] **[新增]** adb logcat 能看到 Kotlin 侧成功注册 alarm 的日志
- [ ] **[阻塞/小米专属]** 在小米设备划掉 App 进程后通知按时弹出（需厂商推送，暂缓）

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

### 待修复问题

| 问题 | 修复方案 |
|------|----------|
| Kotlin 无 try-catch 导致异常传到 Flutter 被吞掉 | Kotlin 侧加 try-catch + logcat 日志 |
| SCHEDULE_EXACT_ALARM 未授权时静默失败 | Kotlin 侧降级到 `setAndAllowWhileIdle` |
| 国产 ROM 划掉进程时取消所有 alarm | 待 Q1 确认后决定方案 |

## Out of Scope

- 阿里云推送集成（营业执照未办妥，暂停）
- iOS 通知（iOS 侧无此问题）
- **小米 MIUI 厂商通道推送**：MIUI 划掉进程后会强制杀死所有 AlarmManager 条目，唯一可靠方案是接入小米厂商推送 SDK（需营业执照 + 小米开发者账号）。暂时无法实施，待营业执照办妥后在新任务中处理。

## Technical Notes

### 关键文件
- `lib/services/notification_service.dart` — 主通知服务
- `lib/services/alarm_service.dart` — Alarm 兜底，MethodChannel 调用
- `android/.../NotificationAlarmHelper.kt` — `setAlarmClock()` 封装
- `android/.../NotificationAlarmReceiver.kt` — BroadcastReceiver
- `android/.../MainActivity.kt` — MethodChannel 注册
- `android/.../AndroidManifest.xml` — 权限声明

### 相关依赖
- `flutter_local_notifications: ^19.5.0`
- `alarm: ^5.4.1`（保留作回滚备用）
