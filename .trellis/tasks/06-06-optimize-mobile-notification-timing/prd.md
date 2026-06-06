# 移动端提醒通知准时性优化

## Goal

提升 Android/iOS 端任务提醒的准时率和可靠性，解决因系统省电策略、权限不足、APP被杀/重启等场景导致的通知延迟、丢失、过期乱响问题。

## Requirements

### R1: 过期提醒合并摘要
- APP 启动时不再逐条触发过期提醒
- 合并为一条摘要通知："你有 N 个过期任务未完成"
- 清理积压的过期闹钟（AlarmService）

### R2: 重启后重新调度
- `BootReceiver` 触发后重新调度所有未来的提醒
- 需要在 native 层调用 Flutter 引擎重新初始化 NotificationService

### R3: 电池优化引导
- 首次启动弹出引导弹窗
- 引导用户关闭电池优化/加入白名单
- 品牌适配：小米(MIUI)、华为(EMUI/HarmonyOS)、OPPO(ColorOS)、vivo(OriginOS/FuntouchOS)
- 提供跳转到对应系统设置页的快捷入口
- 用户可选择"不再提示"

### R4: 微信推送兜底
- 所有开启提醒的任务，在本地通知调度的同时，通过 WxPusher 发送微信推送
- 复用现有 `WechatReminderService` + Supabase Edge Function
- 需要扩展 Edge Function 支持任务提醒推送（当前仅支持测试消息）

### R5: FCM 推送兜底
- 集成 Firebase Cloud Messaging
- 任务提醒同时触发 FCM 推送
- 需要 Supabase Edge Function 或后端服务调度 FCM 推送

## Acceptance Criteria

- [ ] APP 启动时过期提醒合并为一条摘要通知，不逐条触发
- [ ] AlarmService 过期闹钟在 APP 启动时被清理
- [ ] 手机重启后未来的提醒能正常触发
- [ ] 首次安装弹出电池优化引导弹窗（适配小米/华为/OPPO/vivo）
- [ ] 用户可"不再提示"关闭引导
- [ ] 任务提醒触发时同时发送微信推送
- [ ] 任务提醒触发时同时发送 FCM 推送
- [ ] 精确闹钟权限不可用时降级为 inexact 正常工作
- [ ] 已完成/已删除任务不触发任何提醒

## Definition of Done

* Tests added/updated (unit/integration where appropriate)
* Lint / typecheck / CI green
* Docs/notes updated if behavior changes
* ARCHITECTURE.md / CHANGELOG.md updated

## Out of Scope

* 前台服务保活
* 自定义提醒铃声/震动模式
* 智能推荐提醒时间
* 重复通知窗口扩展（保持现有 20次/24h）

## Decision (ADR-lite)

**Context**: 用户反馈通知延迟/丢失/过期乱响，多品牌 Android 省电策略导致本地通知不可靠
**Decision**: 三层保障策略 — 本地通知(精确闹钟+alarm备份) + 微信推送 + FCM推送；过期提醒合并摘要；首次启动电池优化引导
**Consequences**: 需要 Firebase 项目配置 + Supabase Edge Function 扩展；微信推送依赖用户已绑定微信

## Technical Notes

### 关键文件
* `lib/services/notification_service.dart` — 主通知服务，需修改 rescheduleTaskReminders
* `lib/services/alarm_service.dart` — 闹钟备份服务，需增加过期清理
* `lib/services/wechat_reminder_service.dart` — 微信推送，需扩展任务提醒接口
* `android/app/src/main/AndroidManifest.xml` — 权限 + BootReceiver
* `lib/main.dart` — APP 启动流程，需插入过期清理+引导弹窗

### 新增文件（预计）
* `lib/services/fcm_service.dart` — FCM 推送服务
* `lib/presentation/widgets/battery_optimization_guide.dart` — 电池优化引导弹窗
* `lib/services/device_brand_detector.dart` — 品牌检测+设置页跳转

### 依赖
* `firebase_messaging` — FCM
* `firebase_core` — Firebase 基础
* `device_info_plus` — 已有，用于品牌检测
* `disable_battery_optimization` 或 `optimization_battery` — 电池优化 API
