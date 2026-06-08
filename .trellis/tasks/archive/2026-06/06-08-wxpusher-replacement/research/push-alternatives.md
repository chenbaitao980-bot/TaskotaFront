# Research: Server-Side Push Notification Alternatives to WxPusher

- **Query**: Push notification alternatives for Flutter task app (Android + Windows + Web), China users, Supabase backend
- **Scope**: external (service research) + internal (codebase integration patterns)
- **Date**: 2026-06-08

---

## Current Architecture (Internal Findings)

| File | Role |
|---|---|
| `supabase/functions/_shared/wxpusher.ts` | WxPusher HTTP API wrapper — `sendWxPusherMessage(uid, title, content)` |
| `supabase/functions/scan-wechat-reminders/index.ts` | pg_cron job: queries `scheduled_pushes`, looks up `wechat_bindings`, calls wxpusher |
| `supabase/functions/wechat-binding/index.ts` | GET/PUT binding status endpoint |
| `supabase/functions/wechat-qr/index.ts` | QR code generation for WeChat follow flow |
| `supabase/functions/wxpusher-callback/index.ts` | OAuth callback after user follows WxPusher official account |
| `lib/services/wechat_reminder_service.dart` | Flutter service calling `wechat-binding` Edge Function |
| `lib/presentation/pages/profile/wechat_binding_page.dart` | UI for WeChat bind/unbind |

**Key DB tables**: `scheduled_pushes` (id, user_id, task_id, title, body, scheduled_at, sent_at), `wechat_bindings` (user_id, wxpusher_uid, enabled)

The entire WeChat push stack is a **5-layer chain**: pg_cron → scan-wechat-reminders → wxpusher.ts → WxPusher API → WeChat message. Replacing WxPusher only requires touching `wxpusher.ts` and `wechat_bindings.wxpusher_uid` (the per-user token column). The `scheduled_pushes` table and cron infrastructure are **provider-agnostic**.

---

## Candidate Analysis

### 1. PushPlus (pushplus.plus / plus.plusplus.plus)

**What it is**: WeChat-based push service that delivers messages via WeChat service account template messages. Users follow the "PushPlus推送" public account and get a personal token.

**Current status (2026)**:
- PushPlus is still operational. Unlike WxPusher which relies on a WeChat subscription account (smaller quota), PushPlus uses a **service account** with template messages — a different API tier that WeChat has not blocked in the same way.
- Risk: It is still subject to WeChat's content policy. Template message delivery through service accounts is more stable than subscription account messages but can still be rate-limited or suspended for individual accounts.
- The crackdown that killed WxPusher was specifically about third-party subscription account message forwarding. PushPlus using the template message API is structurally different and has survived multiple rounds of crackdowns that killed competitors.

**Viability in China**: HIGH — service accounts + template messages are a stable WeChat API tier used by commercial apps.

**User friction**:
1. User opens `http://www.pushplus.plus` in WeChat
2. Clicks "立即使用" → scans QR or follows official account
3. Copies their token from the dashboard
4. Pastes token into your app settings

4 steps, token is a plain string (no OAuth QR flow needed on your backend). Slightly higher friction than WxPusher's QR-scan flow but much simpler to implement.

**Reliability**: The service has been running since ~2020 and maintained consistent uptime. Free tier: 50 messages/day per token. Paid plans available (200/day free for authenticated users).

**Cost**: Free tier covers typical reminder usage. No per-message fee for free tier.

**Implementation complexity**: LOW
- Replace `wxpusher.ts` with a `pushplus.ts` that POSTs to `http://www.pushplus.plus/send`
- Body: `{ token, title, content, template: "html" }`
- Rename `wechat_bindings.wxpusher_uid` → `wechat_bindings.provider_token` (migration needed)
- Remove WxPusher QR/OAuth flow; replace with a simple text-input field for the token in `wechat_binding_page.dart`

```typescript
// pushplus.ts — drop-in replacement for wxpusher.ts
export async function sendPushPlus(token: string, title: string, content: string): Promise<boolean> {
  const resp = await fetch("http://www.pushplus.plus/send", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token, title, content, template: "txt" }),
  });
  const data = await resp.json();
  return data.code === 200;
}
```

**Verdict**: Best direct replacement for WxPusher. Same delivery channel (WeChat), simpler integration, actively maintained.

---

### 2. Server酱 (ftqq.com / sct.ftqq.com)

**What it is**: "Server Chan" — push service by developer fangtangquan. Delivers via WeChat (following official account) and also supports Feishu/DingTalk/Telegram/email as fallback channels.

**Current status (2026)**:
- Server酱 Turbo (SCT, the paid version at sct.ftqq.com) is still operational.
- Free tier (Server酱3/方糖) was deprecated in 2023. The free tier now only allows 5 messages/day.
- The Turbo paid plan is ¥9.9/month for 500 messages/day.
- **Structural risk**: Server酱 uses the same WeChat service account template message pathway as PushPlus. However, it is **developer-branded** and less widely adopted commercially, so its WeChat account has historically had more suspensions.

**Viability in China**: MEDIUM — works but paid-only for useful quotas, higher suspension history.

**User friction**:
1. Visit sct.ftqq.com, login with WeChat
2. Follow the "方糖" WeChat official account  
3. Copy the SCKey token from dashboard
4. Enter in app

Same 4-step flow as PushPlus but requires a paid subscription for production use.

**Reliability**: Good when account is not suspended. Outages occur ~2-3x per year.

**Cost**: ¥9.9/month for 500 msg/day. Free tier is too limited (5/day).

**Implementation complexity**: LOW — same HTTP POST pattern as PushPlus. `https://sctapi.ftqq.com/{SendKey}.send` with `title` + `desp` params.

**Verdict**: Not recommended over PushPlus. Higher cost, worse reliability, no meaningful advantage.

---

### 3. Email Push via Supabase/SMTP (Resend.com)

**What it is**: Send task reminder notifications as emails from a Supabase Edge Function using Resend.com's SMTP API (or any SMTP provider).

**Viability in China**: HIGH for user receipt — email (QQ Mail, 163, Outlook) works without VPN. **Resend.com's API endpoint is reachable from Supabase Edge Functions** (which run on Deno Deploy, outside China), so no GFW issue on the sending side.

**User friction**: ZERO extra setup — user already has email (used for Supabase auth login). No separate app install, no token copy.

**Reliability**: Email delivery is highly reliable for @qq.com, @163.com. Resend.com has a 99.9% uptime SLA.

**Cost**: Resend.com free tier = 100 emails/day, 3,000/month. Paid: $20/month for 50,000/month. Very affordable.

**Implementation complexity**: LOW-MEDIUM
- Add `RESEND_API_KEY` to Supabase Edge Function secrets
- Create `supabase/functions/_shared/email.ts`:

```typescript
export async function sendEmail(to: string, subject: string, html: string): Promise<boolean> {
  const resp = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "Taskora <reminders@yourdomain.com>",
      to,
      subject,
      html,
    }),
  });
  return resp.ok;
}
```

- `scan-wechat-reminders` → rename to `scan-push-reminders`, add email branch
- `wechat_bindings` table → generalize to `push_channels` or add `email_push_enabled` column (user's auth email is already available from `auth.users`)
- No binding UI needed — just an on/off toggle since email is known

**Key advantage**: Works for ALL platforms (Android killed, Windows desktop, Web) since it's not device-dependent. This fills the gap that Aliyun push doesn't cover (desktop/web).

**Key limitation**: Email is not instant (1-30 second delay typical; can go to spam). Less "push-like" than WeChat messages. Users may miss time-sensitive reminders.

**Verdict**: Highly recommended as a **complementary channel** alongside a WeChat option. Specifically solves the desktop/web user problem that WxPusher never addressed. Low implementation effort.

---

### 4. Bark (bark.day.app)

**What it is**: iOS-only push notification app using Apple APNs. Users install the Bark app, get a device key, and receive pushes via `https://api.day.app/{key}/{title}/{body}`.

**Viability in China**: MEDIUM — APNs works in China. However, the Bark app must be installed from App Store, which requires an Apple ID. iOS App Store is accessible in China.

**Relevance for this app**: LOW
- This app targets **Android + Windows + Web** — no iOS mentioned anywhere in the codebase
- Even if some users have iPhones, making them install a third-party app just to receive reminders is high friction
- The iOS native app would need to be built (separate project) to use APNs natively

**Verdict**: Not relevant. Skip.

---

### 5. ntfy.sh (Self-hosted or cloud)

**What it is**: Open-source pub/sub notification service. Publishers POST to `https://ntfy.sh/{topic}`; subscribers receive via the ntfy mobile app or browser. Self-hostable.

**Viability in China**:
- `ntfy.sh` (the hosted service) is **blocked by the GFW**. Chinese users cannot access it without VPN.
- Self-hosted on a Chinese server (Aliyun, Tencent Cloud) would work. But then you're running your own push infrastructure.

**User friction**: HIGH
- User must install the ntfy Android/iOS app (separate from your task app)
- Subscribe to a unique topic per user
- If using ntfy.sh cloud: requires VPN → non-starter
- If self-hosted: significant infrastructure cost and maintenance

**Implementation complexity**: LOW on backend (simple HTTP POST), but HIGH for end-to-end user experience.

**Verdict**: Not viable for Chinese users on the hosted service. Self-hosting is over-engineered for this use case when simpler alternatives exist.

---

## Recommendation Matrix

| Solution | WeChat Deliver | Desktop/Web | China OK | User Friction | Cost | Impl Effort |
|---|---|---|---|---|---|---|
| **PushPlus** | YES | No | YES | Low (4 steps) | Free | Low |
| Server酱 | YES | No | YES | Low (4 steps) | ¥9.9/mo | Low |
| **Email (Resend)** | No | YES | YES | None | Free | Low-Med |
| Bark | No (iOS only) | No | Partial | High | Free | N/A |
| ntfy.sh cloud | No | Yes | **NO** | High | Free | Low |
| ntfy.sh self-host | No | Yes | YES | High | Hosting | Med |

**Recommended approach**: Dual-channel

1. **Primary replacement for WxPusher → PushPlus**: Drop-in replacement, same WeChat delivery, simpler token-based binding (no OAuth QR needed), free tier sufficient, actively maintained.

2. **New channel for desktop/web users → Email via Resend**: Zero user setup (email from auth), covers the gap Aliyun + WeChat don't cover, cheap, reliable.

---

## Migration Path (Minimal Diff)

### Phase 1: Replace WxPusher with PushPlus (WeChat users)

1. Add `supabase/functions/_shared/pushplus.ts` (10 lines)
2. Rename column: `wechat_bindings.wxpusher_uid` → `wechat_bindings.provider_token` (or keep name for zero migration, just interpret differently)
3. Update `scan-wechat-reminders/index.ts` to call `sendPushPlus` instead of `sendWxPusherMessage`
4. Replace `wechat_binding_page.dart` QR UI with a simple token input field + "how to get your token" link
5. Remove `wechat-qr/index.ts` and `wxpusher-callback/index.ts` Edge Functions (no longer needed)

**Net change**: ~5 files, ~100 lines net reduction (remove OAuth flow complexity).

### Phase 2: Add Email Channel (Desktop/Web users)

1. Add `supabase/functions/_shared/email.ts` (Resend wrapper, ~20 lines)
2. Add `RESEND_API_KEY` to Supabase secrets
3. Modify `scan-wechat-reminders/index.ts` (or rename to `scan-push-reminders`) to also check `auth.users.email` and send email if no WeChat binding
4. Add email toggle in `app_settings_page.dart`

**Net change**: ~3 files, ~50 lines.

---

## Caveats

- PushPlus API documentation is in Chinese; official docs at `https://www.pushplus.plus/doc/`
- PushPlus free tier (50/day per token) should be adequate for a task reminder app; heavy users may hit limits
- Email via Resend requires owning a domain and completing DNS verification (SPF/DKIM) — ~30 min one-time setup
- Neither PushPlus nor Resend requires changes to the `scheduled_pushes` table — the cron infrastructure is already provider-agnostic
- WxPusher's QR-based OAuth binding (user scans QR in WeChat) was the most frictionless UX; PushPlus token-copy is a step down but still acceptable for a developer-adjacent user base
- Server酱 is not worth the paid cost when PushPlus free tier covers the same use case
