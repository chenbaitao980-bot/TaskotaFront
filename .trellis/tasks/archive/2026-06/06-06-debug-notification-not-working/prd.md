# debug-notification-not-working

## 根因诊断

### 问题 1：铃声还是 alarm.wav，不是系统默认

`volume: 0.0` 理论上会把 `STREAM_ALARM` 流量设为 0，静掉 MediaPlayer 对 alarm.wav 的播放。
但可能失效原因：
- APK 15:23 构建，代码 15:11 修改 → APK **是**包含了改动 ✓
- 更可能的原因：**手机上已注册的 alarm 是用旧版参数（volume: 0.8）调度的**，用户需要先打开 App 触发一次 `rescheduleTaskReminders` 把旧 alarm 替换掉才生效
- 或者：`AudioService` 用的是 `STREAM_MUSIC` 而非 `STREAM_ALARM`（需确认），导致 volume 对 alarm.wav 无效

### 问题 2：App 退出后无提醒（核心问题）

**最关键发现**：alarm 包 `AlarmApiImpl.kt:170` 用的是 `setExactAndAllowWhileIdle()`，**和 `flutter_local_notifications` 完全一样**！之前判断"alarm 包用 setAlarmClock，优先级更高"是错的。两者底层机制相同，alarm 包对后台触达**没有任何优势**。

```kotlin
// AlarmApiImpl.kt:170 — alarm 包实际代码
alarmManager.setExactAndAllowWhileIdle(RTC_WAKEUP, triggerTime, pendingIntent)
```

同时，alarm 包的 receiver 触发后还需要**启动 ForegroundService**，在 Android 12+ 后台限制下反而比 `flutter_local_notifications` 更容易失败（`ForegroundServiceStartNotAllowedException`）。

**根本原因**：国产 ROM（小米/华为/OPPO）在用户划掉 App 时**主动清除该 App 的所有 AlarmManager 条目**，这是系统级行为，任何 Flutter 本地方案都无法绕过，除非：
1. 用户手动豁免电池优化（引导已存在）
2. 服务端推送（FCM / WxPusher）— 服务器发起，完全不依赖 App 进程

## 结论

| 方案 | 是否能解决后台提醒 |
|------|-------------------|
| alarm 包（当前） | ❌ 和 flutter_local_notifications 一样 |
| 电池优化豁免（用户操作） | ✅ 豁免后 setExactAndAllowWhileIdle 生效 |
| WxPusher cron | ✅ 需微信绑定，后端已就绪 |
| FCM | ✅ 通用，需接入 Firebase |

## 下一步决策

1. **移除 alarm 包** from `scheduleNotification`（没有收益，只有副作用）
2. **WxPusher cron** — 快速实现服务端兜底（需要你在 Supabase 配 pg_cron）
3. **FCM** — 通用方案（需 Firebase 项目配置）
