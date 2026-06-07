# overdue-notification-nav-and-frequency

## Goal

修复两个逾期提醒问题：
1. 点击逾期提醒通知后无法跳转到逾期任务列表
2. 逾期提醒频率过高（每次启动 App 都弹）

## Requirements

* 点击逾期通知 → 首页时间轴自动选中最早的逾期任务并定位
* 逾期通知改为固定间隔（默认 4 小时），间隔内不重复弹
* 设置页「通知」区块新增逾期提醒间隔选项（1h/2h/4h/8h/24h），桌面和移动端共用

## Acceptance Criteria

* [ ] Windows 桌面端点击逾期通知后，App 打开并定位到最早逾期任务
* [ ] Mobile 点击逾期通知后，App 打开并定位到最早逾期任务
* [ ] 连续打开 App 时，如果距上次逾期通知时间 < 设置的间隔，不重复弹
* [ ] 设置页可修改逾期提醒间隔，选项：1h/2h/4h/8h/24h，默认 4h

## Definition of Done

* Lint / typecheck 通过
* Windows 桌面和 Android 上行为验证

## Out of Scope

* 不做逾期提醒的开关（有任务就提醒）
* PowerShell 脚本通知的点击回调（无法实现，只能等原生 Windows plugin 路径）

## Technical Approach

### 1. LocalStorageService — 新增两个 key
```
overdueNotifIntervalHours: int  (default 4)
overdueLastNotifMs: int         (上次弹通知的 timestamp，毫秒)
```

### 2. NotificationService._showOverdueDigest 改造
- 从 `LocalStorageService` 读取间隔和上次通知时间
- 条件：`count > 0 && now - lastNotifTime >= intervalHours * 3600 * 1000`
- 弹通知时 payload 改为 `'overdue_navigate'`（区别于旧的 `'overdue_digest'`）
- 弹完后持久化 `overdueLastNotifMs = now`
- 去掉内存变量 `_lastShownOverdueCount`（改为时间窗口控制）

### 3. Windows 通知点击回调
- `_windowsPlugin!.initialize(settings, onNotificationReceived: callback)`
- callback 与移动端一致：`pendingTaskId = response.payload`，然后导航到 `/`

### 4. home_page.dart — _processPendingNotificationTask 扩展
- 当 `taskId == 'overdue_navigate'` 时，在 `_timelineTasks` 中找到最早的逾期任务（`!isCompleted && endDate != null && endDate.isBefore(now)`），调用 `_selectTask(task)` + `_scrollToTask(task)`

### 5. 设置页 — 逾期提醒间隔 row
- 位置：`app_settings_page.dart`，桌面「通知」卡片 + 移动端通知区块
- 用 `PopupMenuButton` 展示 1h/2h/4h/8h/24h 选项
- 读写 `LocalStorageService.overdueNotifIntervalHours`

## Decision (ADR-lite)

**Context**: 需要既支持 Windows 又支持 Mobile 的点击导航；间隔控制需跨重启持久化。

**Decision**: payload `'overdue_navigate'` 统一信号，`_processPendingNotificationTask` 扩展处理；时间窗口替换计数窗口，持久化到 SharedPreferences。

**Consequences**: PowerShell 脚本通知路径无点击回调，Windows 需要 `flutter_local_notifications_windows` native plugin 路径可用（大部分 Win10/11 设备支持）。

## Technical Notes

* `lib/services/notification_service.dart:617` — `_showOverdueDigest`
* `lib/services/local_storage_service.dart` — SharedPreferences 存储
* `lib/presentation/pages/home/home_page.dart:931` — `_processPendingNotificationTask`
* `lib/presentation/pages/profile/app_settings_page.dart:138` — 通知设置区块
