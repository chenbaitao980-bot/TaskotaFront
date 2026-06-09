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

* **展示形式（已定）**：方案 C——应用在前台时弹应用内 Flutter Dialog；应用最小化/后台时走 OS 持久通知（Windows `scenario="alarm"`）
* **弹窗按钮（已定）**：三个按钮——"稍后提醒" + "标记完成" + "知道了"
* **稍后提醒延迟（已定）**：弹窗内提供选项 5/15/30/60 分钟，由用户在弹窗中选择

## Requirements

* 桌面端提醒触发后，显示一个不会自动消失的提醒界面
* 用户主动点击确认按钮后提醒才消失
* "稍后提醒"按钮弹出时长选择器（5/15/30/60 分钟），选择后按对应时长重新调度通知

## Acceptance Criteria

* [ ] 桌面端提醒触发后，出现持久化提醒 UI（应用前台时为 Flutter Dialog）
* [ ] 提醒 UI 展示任务/日程标题与描述
* [ ] "知道了"按钮：关闭 Dialog
* [ ] "标记完成"按钮：将任务标记为完成 + 关闭 Dialog
* [ ] "稍后提醒"按钮：弹出时长选项（5/15/30/60 分钟），选择后按延迟重新调度并关闭 Dialog
* [ ] 多个提醒同时触发时，逐个展示（队列），不堆叠

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
