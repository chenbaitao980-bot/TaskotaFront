# Server Push Notifications (WxPusher + Aliyun)

> 服务端推送的完整合约、调试工具链和设计决策

---

## Pipeline Contract

```
Flutter 端
  NotificationService.scheduleReminderForSchedule()
    → WechatReminderService.scheduleServerPush()
    → POST /functions/v1/schedule-push
        body: { task_id, title, body, scheduled_at, channels }
        写入 scheduled_pushes (sent_at = null)

Supabase pg_cron (每分钟)
  scan-wechat-reminders
    → SELECT scheduled_pushes WHERE sent_at IS NULL AND scheduled_at IN window
    → SELECT wechat_bindings WHERE user_id IN (...) AND enabled = true
    → sendWxPusherMessage(uid, title, body)
    → UPDATE scheduled_pushes SET sent_at = now()
```

---

## Scenario: Server Push Scheduling + WxPusher Delivery

### 1. Scope / Trigger
- 任务/日程提醒时间到期，需要通过微信推送提醒
- 触发 code-spec 深度：跨层合约（Flutter → Edge Function → DB → cron → WxPusher API）

### 2. Signatures

**Flutter 调用端** (`notification_service_io.dart`):
```dart
WechatReminderService().scheduleServerPush(
  taskId: scheduleId,   // task.id or schedule.id
  title: title,
  body: description ?? '距开始还有 $remindBeforeMinutes 分钟',  // 必须中文默认值
  scheduledAt: remindAt, // startTime - remindBeforeMinutes
);
```

**schedule-push Edge Function** (`POST /functions/v1/schedule-push`):
```json
Request:  { "task_id": "uuid", "title": "str", "body": "str", "scheduled_at": "ISO8601" }
Response: { "success": true, "aliyun_msg_id": "str|null" }
```

**scheduled_pushes 表**:
```sql
(user_id, task_id)   -- UNIQUE 约束，upsert 键
title, body          -- 推送内容
scheduled_at         -- 触发时间（UTC）
sent_at              -- NULL=待发, 非NULL=已发（去重用）
aliyun_message_id    -- 用于取消阿里云推送
```

**scan-wechat-reminders** (cron, 每分钟):
- 窗口：`scheduled_at BETWEEN now()-24h AND now()+2min`
- 查 `wechat_bindings` WHERE `enabled = true`
- 调 WxPusher API：`POST https://wxpusher.zjiecode.com/api/send/message`

### 3. Contracts

**环境变量（Edge Function Secrets）**:
| Key | 用途 | 必须 |
|-----|------|------|
| `WXPUSHER_APP_TOKEN` | WxPusher 应用 Token | ✅ |
| `SUPABASE_SERVICE_ROLE_KEY` | scan 函数访问 DB | ✅ (自动注入) |
| `ALIYUN_ACCESS_KEY_ID/SECRET/PUSH_APP_KEY` | 阿里云推送（可选） | 可选 |

**WxPusher API 响应**:
```json
{ "code": 1000, ... }   // code=1000 → 成功，否则失败
```

**pg_cron 配置**:
```sql
SELECT cron.schedule(
  'scan-wechat-reminders',
  '* * * * *',
  $$ SELECT net.http_post(
    url := 'https://<ref>.supabase.co/functions/v1/scan-wechat-reminders',
    headers := '{"Authorization": "Bearer <service_role_key>"}'::jsonb,
    body := '{}'::jsonb
  ); $$
);
```

### 4. Validation & Error Matrix

| 条件 | 结果 |
|------|------|
| `WXPUSHER_APP_TOKEN` 未设置 | 函数返回 false，`sent_at` 不更新 |
| 用户无 `wechat_bindings` 记录 | 跳过，记录 warn 日志 |
| `wechat_bindings.enabled = false` | 跳过，不发送 |
| WxPusher API `code != 1000` | 记录 error 日志，`sent_at` 不更新 |
| 推送已发（`sent_at` 非 null） | 不会被窗口查询命中（去重） |
| cron 运行期间 WxPusher 瞬时失败 | **下次 cron 仍能补发**（24h 窗口） |

### 5. Good/Base/Bad Cases

**Good**: 任务提醒 5min 前，Flutter 调 schedule-push → 写入 scheduled_pushes → cron 在时间到时发送 → WxPusher 推送到用户微信

**Base**: WxPusher API 短暂 5xx → cron 下一分钟重试 → 补发成功（因为 24h 窗口）

**Bad**: `WXPUSHER_APP_TOKEN` 未配置 → 函数静默失败 → `sent_at` 永远 null → 无法触发任何推送

### 6. Tests Required

- [ ] 插入 scheduled_at = now()-10min 的记录，调用 scan 函数，验证 `sent=1` 且 `sent_at` 非 null（补发测试）
- [ ] 验证 `sent_at` 非 null 的记录不会被重复发送（幂等测试）
- [ ] 无 wechat_binding 的用户推送被跳过且有 warn 日志

### 7. Wrong vs Correct

#### Wrong: 5min 窗口（会导致永久丢失）
```ts
// ❌ 一旦 WxPusher 在那一分钟失败，该推送永久丢失
const windowStart = new Date(now.getTime() - 5 * 60 * 1000);
```

#### Correct: 24h 窗口（允许补发）
```ts
// ✅ WxPusher 短暂失败后，下次 cron 仍能补发（24h 内）
const windowStart = new Date(now.getTime() - 24 * 60 * 60 * 1000);
```

---

## Debug Toolchain

当遇到"推送没收到"时，按以下顺序排查：

### Step 1: 检查 cron 是否在跑
```sql
SELECT jobname, schedule, active FROM cron.job WHERE jobname = 'scan-wechat-reminders';
SELECT status, return_message, start_time FROM cron.job_run_details
  WHERE jobid = 1 ORDER BY start_time DESC LIMIT 10;
```
预期：`status=succeeded`, `return_message='1 row'`

### Step 2: 检查 HTTP 响应
```sql
SELECT status_code, content, created FROM net._http_response ORDER BY created DESC LIMIT 5;
```
- `{"sent":N,"checked":M}` → 正常（N=发送数，M=找到数）
- `{"sent":0,"checked":1}` → **找到记录但发送失败**（binding 查询失败或 WxPusher API 错误）
- `{"sent":0,"reason":"no pending pushes"}` → 时间窗口内无记录

### Step 3: 确认 scheduled_pushes 有记录
```sql
SELECT task_id, scheduled_at, sent_at FROM scheduled_pushes
  WHERE sent_at IS NULL ORDER BY scheduled_at;
```

### Step 4: 确认 wechat_bindings 有效
```sql
SELECT user_id, wxpusher_uid, enabled FROM wechat_bindings WHERE enabled = true;
```

### Step 5: 确认 Secrets 已配置
- Supabase Dashboard → Settings → Secrets → 确认 `WXPUSHER_APP_TOKEN` 存在

---

## Design Decisions

### 决策：24h 时间窗口 vs 严格时间窗口

**背景**: scan 函数需要一个时间窗口来决定哪些推送"该发了"

**被否决的方案**:
- `now()-5min` 到 `now()+2min`：看起来合理，但一旦 WxPusher API 在那一分钟失败，该推送永久丢失，无法重试

**选定方案**: `now()-24h` 到 `now()+2min`
- WxPusher 短暂失败 → 下次 cron 补发
- 24h 内的漏发都能补救
- 超过 24h 的漏发不再重试（避免发送太旧的提醒）

### 决策：UNIQUE(user_id, task_id) + upsert

**背景**: Flutter 在 rescheduleTaskReminders 时会为每个任务重新调用 scheduleServerPush

**方案**: `scheduled_pushes` 表用 `(user_id, task_id)` 做 UNIQUE 约束，upsert 时重置 `sent_at = null`
- 任务提醒更新 → 自动覆盖旧记录，更新 scheduled_at 和 sent_at

---

## Common Mistakes

### 推送 body 使用英文
```dart
// ❌ 错误：用英文默认值
final pushBody = description ?? 'Your schedule starts in $remindBeforeMinutes minutes';

// ✅ 正确：用中文
final pushBody = description ?? '距开始还有 $remindBeforeMinutes 分钟';
```

### 漏查 binding 失败日志
```ts
// ❌ 错误：静默忽略查询错误
const { data: bindings } = await supabase.from("wechat_bindings")...;

// ✅ 正确：记录错误
const { data: bindings, error: bindErr } = await supabase.from("wechat_bindings")...;
if (bindErr) console.error("[scan] wechat_bindings query error:", bindErr);
```
