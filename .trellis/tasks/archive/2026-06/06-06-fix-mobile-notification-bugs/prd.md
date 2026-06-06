# fix-mobile-notification-bugs

## Goal

修复移动端推送通知的三个严重 Bug：
1. 未知来源的"测试"任务通知大量弹出
2. 通知铃声无法关闭（一直响）且点击无响应
3. 每次打开 App 都会重复触发通知

## What I already know

- 通知截图显示：3 个"测试"任务 × 2 条（Starting + Upcoming）= 6 条同时触发
- 还有"模板功能开发"任务的通知
- 通知是 flutter_local_notifications (zonedSchedule) + AlarmService (alarm 包) **双引擎**调度的
- AlarmService 配置了 `loopAudio: true`，永久循环播放直到显式关闭
- `onDidReceiveNotificationResponse` 只处理 `overdue_digest` payload，点击普通任务通知**无任何反应**
- `_rescheduleTaskReminders()` 在 `_initStorage`（启动）、`_onAppResume`（每次回前台）、`runSyncAll`（同步完成）三处被调用
- 每次 reschedule 都会重新调用 `AlarmService().scheduleAlarm()`，注册新的 alarm

## Root Cause Analysis

### Bug 2：铃声停不掉 + 点击无响应

| 位置 | 问题 |
|------|------|
| `alarm_service.dart:39` | `loopAudio: true` — alarm 永久循环 |
| `alarm_service.dart:35` | `assetAudioPath: 'assets/audio/alarm.wav'` — 自定义铃声，非系统默认 |
| `notification_service.dart:122-128` | tap handler 只处理 `overdue_digest`，普通任务通知点击=无效 |
| `notification_service.dart:270-277` | `scheduleNotification` **每次都**调用 `AlarmService().scheduleAlarm()`，把普通 reminder 升级为 alarm 级别 |

用户看到 flutter_local_notifications 通知 → 点击 → 无响应；与此同时 alarm 包在后台/全屏响铃 → 没有按 alarm 包的"关闭"按钮 → 铃声持续

### Bug 3：打开 App 就触发

`_onAppResume` → `_rescheduleTaskReminders()` → 对每个 `reminderEnabled > 0` 的未完成任务调 `scheduleReminderForSchedule` → 调 `scheduleNotification` → 调 `AlarmService().scheduleAlarm()`。只要有临近时间的任务，每次回前台就注册一次 alarm。

### Bug 1："测试"任务从哪来

- 任务通过 Supabase 云同步拉取（`TaskSyncService.instance.syncAll()`）
- `sbp_858eaa7085fed566e9af94cc74218a1bb27cac30` 是 Supabase Personal Access Token 格式（`sbp_` 前缀），**不是** UUID user_id
- 无法从本地代码确认这些任务的来源；需要查 Supabase `user_tasks` 表
- 猜测：这些是之前测试时创建的任务（title="测试"，`reminder_enabled=1`，start_date 在今天附近）

## Requirements

1. **点击通知立即停止铃声**：`onDidReceiveNotificationResponse` 调 `AlarmService().cancelAlarm(response.id)` 停止对应 alarm
2. **铃声响一次即停**：`loopAudio: false`，不再永久循环
3. **改为系统默认铃声**：去掉 `assetAudioPath`（alarm 包默认用系统铃声）
4. **点击通知能导航**：tap 后跳转首页（任务列表），便于用户查看/完成任务
5. **调查"测试"任务**：需要 Supabase 数据库访问，查 `user_tasks` 表找到这些任务并删除/禁用提醒

## Decision (ADR-lite)

**Context**: AlarmService (`alarm` 包，`loopAudio: true`) 被套用于所有普通 reminder，导致铃声无法停止  
**Decision**: 保留 AlarmService 作为备份通道，但改为 `loopAudio: false` + 系统默认音，并在通知 tap 时主动 cancel alarm  
**Consequences**: 铃声只响一次；历史任务 alarm 触发后自行停止；不影响 flutter_local_notifications 的调度逻辑

## Acceptance Criteria

- [x] 点击通知能关闭/响应（tap handler → cancelAlarm + navigate）
- [x] 通知铃声不再循环（移除 AlarmService 双触发；alarm 包兜底改 loopAudio: false）
- [x] 铃声走系统默认（flutter_local_notifications 不指定 sound → Android 系统默认）
- [x] 打开 App 不会立即触发铃声（AlarmService 不再在 scheduleNotification 中调用）
- [x] 点击通知跳首页并定位到时间轴任务
- [ ] "测试"类测试任务已清理或提醒已禁用（需 Supabase 控制台操作）

## Definition of Done

- Lint / typecheck 绿
- Android 真机测试通知流程
- CHANGELOG 更新

## Out of Scope

- 完整重构通知调度逻辑
- iOS 适配（此次只修 Android 主路径）
- AlarmService 用于"闹钟模式"任务（保留但不在普通 reminder 中调用）

## Technical Notes

- `lib/services/notification_service.dart:270-277` — 移除 AlarmService.scheduleAlarm 调用
- `lib/services/alarm_service.dart:39` — `loopAudio: true` → `false`
- `lib/services/alarm_service.dart:35` — 去掉 assetAudioPath 或设为 null
- `notification_service.dart:122-128` — 扩展 tap handler
- `sbp_858eaa7085fed566e9af94cc74218a1bb27cac30` 是 Supabase PAT，不是 user_id；需在 Supabase 控制台手动查任务
