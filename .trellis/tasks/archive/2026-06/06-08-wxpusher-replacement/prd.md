# remove-wxpusher-server-push

## Goal

WxPusher 推送功能已无法在微信收到消息，决定**删除所有 WxPusher / 微信推送相关代码**，彻底清理。
Android 用户继续靠 Aliyun 移动推送；Desktop/Web 用户无服务端推送（本地通知仍保留）。

## Decision (ADR-lite)

**Context**: WxPusher 被微信封禁，推送不到达。备选 PushPlus 同为微信生态风险；Email 推送对"5分钟提醒"体验差。

**Decision**: 方案 B — 删除所有 WxPusher/微信推送功能

**Consequences**: 代码更简洁（-700行），无微信生态风险；代价是 Desktop/Web 无服务端推送（但这些用户目前本身没有 Aliyun 推送，损失可接受）

## Requirements

* [ ] 删除 Flutter 端：`wechat_reminder_service.dart`、`wechat_binding_page.dart`
* [ ] 从 `notification_service_io.dart` 移除 `scheduleServerPush` / `cancelServerPush` 调用（共 2 处）及 import
* [ ] 从 `profile_page.dart` 移除"微信提醒"菜单项及 import
* [ ] 从 `app_settings_page.dart` 移除微信绑定入口及 import（若有）
* [ ] 从 `home_page.dart` 移除微信引导弹窗逻辑及相关 import
* [ ] 禁用/删除 Edge Functions：`scan-wechat-reminders`、`wechat-binding`、`wechat-qr`、`wxpusher-callback`、`_shared/wxpusher.ts`
* [ ] `schedule-push` Edge Function：移除 WxPusher channels 相关（`channels` 参数 + `wechat` 分支），保留 Aliyun 推送逻辑
* [ ] `scheduled_pushes` 表保留（aliyun 仍用），`wechat_bindings` 表停用（不删，数据保留，不再写入）
* [ ] `notification_service_web.dart` 确认无 WxPusher 引用（stub 文件）

## Acceptance Criteria

* [ ] `flutter analyze` 无 WxPusher/wechat_reminder 相关报错
* [ ] App 编译通过（`flutter build`）
* [ ] 任务提醒仍正常触发本地通知（未破坏 NotificationService 核心逻辑）
* [ ] Profile 页面不再显示"微信提醒"入口
* [ ] Home 页面不再弹出微信引导

## Definition of Done

* `flutter analyze` 通过
* 相关 Edge Functions 从 Supabase 删除或标记废弃
* 无悬空 import

## Out of Scope

* 删除 `scheduled_pushes` 数据库表（aliyun 仍用）
* 删除 `wechat_bindings` 数据库表（保留历史数据）
* `schedule-push` Edge Function 本身（aliyun 仍用，只移除 wechat 分支）
* iOS 推送、Email 推送（此次不做）

## Technical Notes

### 受影响文件清单

**Flutter (删除或修改)**:
- `lib/services/wechat_reminder_service.dart` → **整文件删除**
- `lib/presentation/pages/profile/wechat_binding_page.dart` → **整文件删除**
- `lib/services/notification_service_io.dart` → 移除 import + 2处调用（scheduleServerPush, cancelServerPush）
- `lib/presentation/pages/profile/profile_page.dart` → 移除微信菜单项 + import
- `lib/presentation/pages/profile/app_settings_page.dart` → 移除微信绑定入口 + import
- `lib/presentation/pages/home/home_page.dart` → 移除微信引导弹窗 + import + `_prefKeyWechatGuideShown` 常量

**Edge Functions (删除)**:
- `supabase/functions/scan-wechat-reminders/` → 整目录删除
- `supabase/functions/wechat-binding/` → 整目录删除
- `supabase/functions/wechat-qr/` → 整目录删除
- `supabase/functions/wxpusher-callback/` → 整目录删除
- `supabase/functions/_shared/wxpusher.ts` → 删除

**Edge Functions (保留但修改)**:
- `supabase/functions/schedule-push/index.ts` → 移除 `channels` 参数处理（保留 aliyun 推送逻辑，保留 scheduled_pushes 写入）

**DB**:
- `wechat_bindings` 表：保留，不再写入（不删）
- `scheduled_pushes` 表：完整保留（aliyun 使用）

### 注意事项

- `notification_service_io.dart` 第 606 行 `scheduleServerPush` 调用需删除（含 unawaited 模式）
- `notification_service_io.dart` 第 625 行 `cancelServerPush` 调用需删除
- `home_page.dart` 有一个微信引导弹窗（`_prefKeyWechatGuideShown` 常量 + 弹窗逻辑），整段移除
- `schedule-push` 中的 `channels` 参数和 `wechat` 分支虽然不发消息，但代码上 channels 字段根本没被使用（只写入 scheduled_pushes），所以实际上只需删除 `scan-wechat-reminders` 就够了——schedule-push 无需改动
