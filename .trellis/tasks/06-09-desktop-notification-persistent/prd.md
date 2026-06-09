# 桌面端提醒需等用户确认才消失

## Goal

桌面端（Windows/macOS/Linux）的任务提醒目前使用 OS 级别的 Toast 通知，会在几秒内自动消失。用户希望提醒弹出后必须等用户主动确认才会消失，防止错过重要提醒。

## What I already know

* **当前桌面通知路径**：Timer 到期 → `_showDesktopNativeNotification` → 两条分支：
  1. Windows native plugin (`FlutterLocalNotificationsWindows`) → `WindowsNotificationDuration.short`（约5秒自动消失）
  2. PowerShell Toast 脚本 → 也是自动消失
* **非桌面**（Android/iOS）使用系统通知，不受此需求影响
* **现有 dialog 组件**：`upgrade_dialog.dart`、`task_conflict_dialog.dart` 等，均通过 `AppRouter.navigatorKey` 弹出
* **当前触发点**：`notification_service_io.dart` 的 `_showDesktopNativeNotification()`

## Assumptions (temporary)

* 主要场景：应用在前台运行时（即用户正在使用 app），提醒弹出
* 应用在后台/最小化时 OS Toast 仍可保留作为兜底

## Open Questions

（已全部解决）

## Decisions

* **展示形式（最终）**：统一走 Windows 系统 Toast（右下角），不区分窗口是否打开，移除应用内 Overlay 路径
* **Toast 按钮（最终）**：稍后提醒 / 标记完成 / 查看详情 / 知道了（任务类）；稍后提醒 / 知道了（非任务类）
* **稍后提醒技术方案**：`WindowsSelectionInput` 内建下拉选择（5/15/30/60 min），通过 `response.data['snoozeTime']` 可靠读取
* **前台激活限制**：Windows 只有 `foreground` 和 `protocol` 激活类型；点按钮会短暂唤起窗口。若通知发出时窗口是隐藏的，非"查看详情"操作处理完后立即重新隐藏窗口（接受短暂闪烁）

## Requirements

* Windows 桌面端提醒统一走系统 Toast，不论窗口当前是否可见
* Toast 使用 `WindowsNotificationScenario.reminder`，不会自动消失
* 稍后提醒：内建下拉 5/15/30/60 分钟，选择后可靠重新调度
* 标记完成：设置 `pendingMarkDoneTaskId`，首页消费
* 查看详情：设置 `pendingTaskId` + 导航到首页
* 知道了：关闭 Toast，若窗口之前是隐藏的则重新隐藏
* macOS/Linux：保持原来的前台 Overlay + 后台 OS 通知行为不变

## Acceptance Criteria

* [ ] Windows 上任务提醒触发后，在系统右下角出现 Toast（不论窗口是否打开）
* [ ] Toast 包含稍后提醒下拉选择 + 标记完成/查看详情/知道了按钮
* [ ] 点"稍后提醒"后选择延迟时长，按对应时间重新弹出 Toast
* [ ] 点"标记完成"后，首页自动将该任务标记为完成
* [ ] 点"查看详情"后，应用窗口出现并导航到对应任务
* [ ] 点"知道了"后，Toast 关闭；若之前窗口是隐藏的则重新隐藏
* [ ] 多个提醒同时触发时，各自作为独立 Toast 显示

## Definition of Done

* Lint / typecheck 通过
* 桌面端手动验证：提醒弹出后不自动消失，点击确认后消失
* 已有通知相关逻辑（Android/iOS）不受影响

## Out of Scope (explicit)

* Android/iOS 通知行为不变

## Technical Notes

* 入口：`notification_service_io.dart:_showDesktopNativeNotification()`
* Navigator key：`AppRouter.navigatorKey`
* 可参考 `upgrade_dialog.dart` / `task_conflict_dialog.dart` 的弹窗模式
