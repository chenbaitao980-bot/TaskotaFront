# mobile-push-aliyun

## Goal

App 被杀死后到点不触发提醒。已确认根本原因是国产 ROM 清除 AlarmManager，本地通知方案无法解决。
选定方案：**阿里云移动推送（服务端定时推送）**，到点由阿里云系统级推送到设备，不依赖 App 进程。

## 历史背景（已归档的失败尝试）

| 方案 | 结果 | 原因 |
|------|------|------|
| `flutter_local_notifications` zonedSchedule | ❌ 无效 | 国产 ROM 杀 App 时清除 AlarmManager |
| `alarm` 包 loopAudio+全屏 | ❌ 铃声循环关不掉，点击无响应 | loopAudio:true + 无 tap handler |
| `alarm` 包修复版（loopAudio:false）| ❌ 部分有效 | App 被杀后 setAlarmClock 仍可能被清 |
| 本地 + alarm 双引擎 | ❌ 仍不可靠 | 底层问题未解决 |

## 已完成的实现

### Supabase 后端（已部署 ✅）
- **`user_devices` 表**：存储阿里云 deviceId（每用户一条）
- **`scheduled_pushes` 表**：定时推送队列（含 aliyun_message_id 用于取消）
- **`register-device` Edge Function**：Flutter 上传 deviceId
- **`schedule-push` Edge Function**：调阿里云 Push API（PushTime 定时）+ 写队列
- **Secrets**：`ALIYUN_ACCESS_KEY_ID` / `ALIYUN_ACCESS_KEY_SECRET` / `ALIYUN_PUSH_APP_KEY`

### Flutter 客户端（代码已完成 ✅）
- **`AliyunPushService`**：初始化 SDK、获取 deviceId、登录后上传
- **`aliyun_push: ^1.2.0`** 已加入 pubspec
- **AndroidManifest.xml**：AppKey/AppSecret meta-data 已配置
- **`main.dart`**：`AliyunPushService().init()` 已接入
- **`home_page.dart`**：登录检测到用户时调 `onUserLoggedIn()`
- **`wechat_reminder_service.dart`**：channels 改为 `['aliyun', 'wechat']`
- **ProGuard 规则**：anet、华为 HMS、bouncycastle 的 dontwarn 已加

### 构建问题（已修复 ✅）
- `Unable to establish loopback connection`：系统环境变量 `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:/Temp` 永久生效
- R8 missing class（anet/HMS）：ProGuard dontwarn 规则已加
- APK 成功构建：`build\app\outputs\flutter-apk\app-release.apk`（79.8MB）

## 已验证

- [x] 阿里云控制台能看到设备注册（deviceId: `c6099bbca366424da63ef5580e612a48`）
- [x] 服务端推送 API 调用成功（两次测试 msgId 均正常返回）
- [x] 通知栏状态从「关闭」修复为「打开」（通道改为 `schedule_reminders`）

## 当前状态（2026-06-06）

**非小米手机**：流程应正常工作 ✅
**小米手机**：推送到达设备但不弹通知 ❌ — 需要 MiPush 厂商通道

## 已修复

1. 服务端 `schedule-push` — 添加 `AndroidNotificationChannel: "schedule_reminders"` + `AndroidNotifyType: "BOTH"` ✅ 已部署
2. Flutter 客户端 — 复用 `schedule_reminders` 通道 ✅

## 阻塞项 — 需小米开发者账号

- [ ] 注册小米开发者账号，获取 MiPush AppID / AppKey
- [ ] 在 AndroidManifest.xml 添加 meta-data（`com.xiaomi.push.id` / `com.xiaomi.push.key`）
- [ ] Flutter 端调用 `_plugin.initThirdPush()` 注册 MiPush
- [ ] 推送测试验证

## 下一步（可选）

1. **MiPush 厂商通道**（阻塞中，缺小米开发者账号）
2. **华为 HMS 厂商通道**：需华为开发者账号 + HMS SDK 配置
3. **WxPusher cron**：Supabase pg_cron 每分钟调 `scan-wechat-reminders`，给绑定微信用户多一条兜底

## Technical Notes

- AppKey: `2fc267edc1b1424ea61952c0f13fb124`
- Supabase 项目: `wlehkvsxftyxmxelcaps.supabase.co`
- `lib/services/aliyun_push_service.dart`
- `lib/services/notification_service.dart` — alarm 包已保留作本地兜底
- `supabase/functions/schedule-push/index.ts`
- `supabase/functions/register-device/index.ts`
- `supabase/functions/_shared/aliyun.ts`
- `android/app/proguard-rules.pro`
