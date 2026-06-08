# fix: wxpusher-reminder-not-firing

## Goal

用户绑定 WxPusher、为任务设置提前 N 分钟提醒，到时间后没有收到微信推送消息。需要定位根因并修复。

## What I already know

* Flutter 端：`scheduleReminderForSchedule()` → `WechatReminderService().scheduleServerPush()` → 调 `schedule-push` Edge Function ✅
* `schedule-push` 写入 `scheduled_pushes` 表（`sent_at = null`）✅
* `scan-wechat-reminders` Edge Function 已实现：查 `scheduled_pushes` → 查 `wechat_bindings` → 调 WxPusher ✅
* **`scan-wechat-reminders` 从未被配置为定时任务（pg_cron）** ❌ — 这是根因

## Root Cause（已确认）

在 `.trellis/tasks/06-06-mobile-push-aliyun/prd.md` 的"下一步（可选）"中明确写道：

> WxPusher cron：Supabase pg_cron 每分钟调 scan-wechat-reminders，给绑定微信用户多一条兜底

这个步骤被标记为可选，**从未实际执行**。`scheduled_pushes` 表里存有待发送记录，但没有任何机制去消费它们。

## 完整数据流（当前状态）

```
Flutter 创建提醒
  → scheduleReminderForSchedule()
  → WechatReminderService.scheduleServerPush()
  → POST schedule-push Edge Function
  → 写入 scheduled_pushes (sent_at = null)   ✅

scan-wechat-reminders Edge Function（每分钟执行）
  → 查 scheduled_pushes WHERE sent_at IS NULL AND scheduled_at IN window
  → 查 wechat_bindings WHERE enabled = true
  → 调 WxPusher API 发送消息
  → 更新 sent_at = now()                     ❌ 从未被调用
```

## 次要问题（已发现）

1. **推送 body 为英文**：`scheduleReminderForSchedule` 里 `pushBody = description ?? 'Your schedule starts in $remindBeforeMinutes minutes'` — 无 description 时推送英文内容给中文用户
2. **时间窗口**：`scan-wechat-reminders` 窗口为 `[now-5min, now+2min]`，每分钟运行一次时覆盖合理，但如果 cron 延迟超过 5min 则会漏发

## Requirements

* [ ] 在 Supabase 配置 pg_cron，每分钟触发 `scan-wechat-reminders`
* [ ] 推送消息 body 改为中文（无 description 时）
* [ ] 提供 SQL 迁移文件，可直接在 Supabase SQL Editor 执行

## Acceptance Criteria

* [ ] 用户绑定 WxPusher 后设置任务提醒，到时间能在微信收到推送
* [ ] 测试消息（sendTestMessage）仍然可用
* [ ] `scheduled_pushes` 表中记录在发送后 `sent_at` 被更新（非 null）

## Definition of Done

* SQL 迁移文件可直接执行
* Edge Function 日志能看到成功发送记录
* 人工测试：设置 2 分钟后的提醒，等待收到微信消息

## Out of Scope

* MiPush/华为 HMS 厂商通道配置
* pg_cron 运行失败的告警机制

## Technical Notes

* Supabase 项目：`wlehkvsxftyxmxelcaps.supabase.co`
* pg_cron 在 Supabase 上通过 `Database → Extensions` 启用
* 调用 Edge Function 需要 `service_role_key`（已在 Supabase Secrets 中）
* 相关文件：
  - `supabase/functions/scan-wechat-reminders/index.ts`
  - `supabase/functions/schedule-push/index.ts`
  - `lib/services/notification_service_io.dart` (scheduleReminderForSchedule)
  - `lib/services/wechat_reminder_service.dart`
  - `database/migration_wechat_reminder.sql`
  - `supabase/migrations/aliyun_push_tables.sql`
