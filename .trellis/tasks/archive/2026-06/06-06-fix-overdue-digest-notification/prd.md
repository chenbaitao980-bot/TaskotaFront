# 修复过期任务通知弹窗问题

## 问题描述

用户打开应用后提示「你有 7 个过期任务未完成」，有三个关联 bug：

1. **点击通知无反应** — `onDidReceiveNotificationResponse` 回调为空，点击不跳转
2. **通知反复弹出** — 每次 sync/resume 都重新弹，没有去重
3. **导致卡顿** — `_clearOverdueAlarms` 对已 cancel 的 task 重复操作，产生大量 OS 调用

## 根因

- `notification_service.dart:121` — `onDidReceiveNotificationResponse: (response) {}` 空回调
- `rescheduleTaskReminders()` 每调用一次就执行一次 `_showOverdueDigest()`，被多处触发
- `_clearOverdueAlarms()` 在循环顶部已 cancel 每个 task 的提醒后再次遍历 cancel，重复工作

## 修复方案

1. **点击导航**：通知携带 `payload: 'overdue_digest'`，回调中通过 `AppRouter.navigatorKey` 跳转到首页
2. **防重复**：缓存 `_lastShownOverdueCount`，过期数量不变不弹
3. **去冗余**：移除 `rescheduleTaskReminders` 中的 `_clearOverdueAlarms(overdueTaskIds)` 调用（保留方法定义，其他调用点仍需使用）

## 已完成

- [x] `lib/core/router/app_router.dart` — 新增全局 `navigatorKey`
- [x] `lib/main.dart` — 两个 MaterialApp 接入 `navigatorKey`
- [x] `lib/services/notification_service.dart` — 三项修复
- [x] 编译检查通过（0 error）
