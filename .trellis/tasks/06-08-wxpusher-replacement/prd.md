# replace-or-remove-wxpusher-push

## Goal

WxPusher 推送功能已无法在微信接收消息（可能因微信封禁第三方推送服务），需要决定：
A) 删除该功能，或
B) 替换为可靠的替代方案

## What I already know

* WxPusher API 调用本身成功（`checked=1, sent=1`），但消息不到达微信 — 说明 WxPusher 的公众号被封或微信策略变更
* 现有 aliyun 推送**已覆盖** Android 移动端（App 被杀后仍能推送），这是主要用户群
* WxPusher 的原始价值：给 Desktop/Web 用户 + Android 推送的双重兜底
* 涉及文件：
  - Flutter: `wechat_reminder_service.dart`, `wechat_binding_page.dart`, `notification_service_io.dart` (2处调用), `profile_page.dart`, `home_page.dart`
  - Edge Functions: `scan-wechat-reminders`, `schedule-push`, `wechat-binding`, `wechat-qr`, `wxpusher-callback`, `_shared/wxpusher.ts`
  - DB: `wechat_bindings` 表, `scheduled_pushes` 表（与 aliyun 共用）
* `scheduled_pushes` 表同时服务 aliyun 推送记录，不能随意删除

## Open Questions

* 用户是否有大量 iOS 用户？（影响替代方案选择）
* 用户愿意接受让用户安装额外 App 的替代方案吗？

## Research References

* [`research/push-alternatives.md`](research/push-alternatives.md) — 各替代方案对比（进行中）

## Feasible Approaches

**方案 A: 直接删除 WxPusher** (Recommended 初步)

* How: 删除 6 个 Edge Functions，移除 Flutter 绑定页面和调用，保留 `scheduled_pushes` 表（aliyun 仍用）
* Pros: 代码清晰，无维护负担，aliyun 覆盖主要移动端场景
* Cons: Desktop/Web 用户失去服务端推送兜底

**方案 B: 替换为 Email 推送**

* How: 用 Resend.com 或 Supabase Auth 内置邮件，scheduled_pushes 到期时发邮件
* Pros: 无需用户安装任何 App，普适性最强，不受微信政策影响
* Cons: 邮件易被忽略/进垃圾箱，延迟高，不适合"5分钟提醒"这类即时通知

**方案 C: 替换为 PushPlus/Server酱（同类 WeChat 服务）**

* How: 类似 WxPusher 的绑定流程，换一个服务商
* Pros: 用户体验与现在类似（还是微信）
* Cons: 同样面临微信封禁风险，治标不治本

## Acceptance Criteria

* TBD（等方向确认后填写）

## Out of Scope

* iOS APNs 推送（Bark 方案，iOS 用户未知）
* 实时 WebSocket 推送

## Technical Notes

* `scheduled_pushes` 表的 `aliyun_message_id` 字段属于 aliyun 推送，即使删除 WxPusher 功能也不能删这个表
* 若选方案 A：只需删 WxPusher 相关 Edge Functions + Flutter 代码，保留 `schedule-push` 函数中写 scheduled_pushes 的逻辑（给 aliyun 用）
* Supabase 项目: `wlehkvsxftyxmxelcaps.supabase.co`
