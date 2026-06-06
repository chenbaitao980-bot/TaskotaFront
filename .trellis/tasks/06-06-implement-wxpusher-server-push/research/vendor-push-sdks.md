# Research: Chinese Vendor Push SDK Integration for Flutter

- **Query**: Vendor push SDK options for Flutter targeting Chinese Android ROMs (Xiaomi/Huawei/OPPO/Vivo) without FCM
- **Scope**: external (pub.dev + official docs + GitHub)
- **Date**: 2026-06-06

---

## Project Context

- Flutter app: Taskora (smart_assistant), Dart SDK `^3.11.5`
- Backend: Supabase only, no Firebase/FCM
- Current notification: `flutter_local_notifications` + AlarmManager — killed by Chinese ROM battery optimization
- Goal: system-level push that survives app kill

---

## 1. Direct Vendor SDK Flutter Plugins

### 1.1 Huawei HMS Push (`huawei_push`)

| Field | Value |
|---|---|
| pub.dev package | `huawei_push` |
| Latest version | `6.15.0+300` (published 2026-06-01) |
| Dart SDK | `>=2.12.0 <4.0.0` |
| Flutter SDK | `>=1.20.0` |
| Maintainer | HMS-Core (official Huawei) |
| GitHub | https://github.com/HMS-Core/hms-flutter-plugin |
| Total versions | 24 (actively maintained) |

**Notes:**
- Official plugin, maintained by Huawei's HMS Core team
- Requires Huawei Developer account registration
- App must be submitted to AppGallery Connect for HMS configuration
- Requires `agconnect-services.json` in the Android project (similar to `google-services.json`)
- Does NOT require Google Play Services — pure HMS stack
- Works only on Huawei/Honor devices with HMS Core installed
- Registration: https://developer.huawei.com — free developer account; push service is **free** with quota
- **Free tier**: 1,000,000 pushes/month for standard notifications
- Pricing beyond free: pay-per-use, very low cost (CNY 0.001/message above quota)

### 1.2 Xiaomi Push

| Field | Value |
|---|---|
| pub.dev package | `mi_push` |
| Latest version | `0.0.2` |
| Maintainer | Community (meetleev, not official) |
| Status | Minimal — 0.0.2, extremely thin wrapper |

**Alternative community packages found:**
- `flutter_push_plugin_xiaomi` — also community
- No official Xiaomi Flutter plugin exists

**Notes:**
- Xiaomi has no official Flutter plugin. Xiaomi Push SDK is Java/Kotlin only.
- Integration requires writing a Flutter MethodChannel bridge to the native Android SDK
- Developer registration: https://dev.mi.com/distribute/doc/details?pId=1502 — requires Chinese business registration or individual developer account
- **Pricing**: Free up to 5,000,000 pushes/day for non-commercial; commercial apps require Enterprise account
- Enterprise account requires Chinese business license (营业执照) — **barrier for foreign/solo devs**
- Complexity: HIGH for a small team — must write native bridge code

### 1.3 OPPO Push (`oppo_push` / `flutter_push_plugin_oppo`)

| Field | Value |
|---|---|
| pub.dev package | `oppo_push` v0.0.2 |
| Maintainer | Community (meetleev) |
| Status | Minimal community wrapper |

**Notes:**
- OPPO renamed push service to "OnePlus/OPPO Cloud Messaging" 
- No official Flutter plugin from OPPO
- Requires application at https://open.oppomobile.com
- Business license (营业执照) required for registration
- **Pricing**: Free for certified apps; certification requires Chinese app store listing
- Complexity: HIGH — native bridge + corporate registration required

### 1.4 Vivo Push (`vivo_push` / `flutter_push_plugin_vivo`)

| Field | Value |
|---|---|
| pub.dev package | `vivo_push` — community only |
| Status | Minimal wrapper |

**Notes:**
- No official Flutter plugin from Vivo
- Requires application at https://dev.vivo.com.cn
- Chinese business license required
- **Pricing**: Free with daily quotas per app
- Complexity: HIGH — same as Xiaomi/OPPO

---

## 2. Third-Party Aggregator SDKs

### 2.1 JPush 极光推送 (`jpush_flutter` — OFFICIAL)

| Field | Value |
|---|---|
| pub.dev package | `jpush_flutter` |
| Latest version | `3.4.5` (published 2026-05-12) |
| Dart SDK constraint | `>=2.19.6 <3.0.0` ← **CRITICAL ISSUE** |
| Maintained by | Jiguang (极光) officially |
| Total pub.dev versions | 127 (very actively maintained) |
| Homepage | https://www.jiguang.cn |

**CRITICAL: Dart 3 Incompatibility**
`jpush_flutter` v3.4.5 requires Dart `>=2.19.6 <3.0.0`. This project uses Dart `^3.11.5`. The official package **will not resolve** in this project without a `dependency_overrides` hack, which is risky.

**Alternative: `fl_jpush` (community wrapper)**

| Field | Value |
|---|---|
| pub.dev package | `fl_jpush` |
| Latest version | `5.7.0` (published 2025-05-26) |
| Dart SDK | `>=3.0.0 <4.0.0` |
| Flutter | `>=3.24.0` |
| Maintained by | Wayaer (community) |
| Total versions | 38 |

`fl_jpush` is a community re-wrap of JPush that supports Dart 3. **This is the practical choice for this project.**

**JPush Features:**
- Single SDK integrates: Xiaomi, Huawei, OPPO, Vivo, Meizu, Honor push channels
- Fallback to JPush own channel when vendor channel unavailable
- Handles routing through each vendor's system process → survives app kill
- **Scheduled push**: YES — JPush console and REST API support `send_no` with `time_to_send` for future scheduling
- **Backend console**: Full web dashboard at https://www.jiguang.cn/push — no custom backend needed for basic scheduling
- **REST API**: Can call from Supabase Edge Function to trigger pushes with scheduled time

**JPush Pricing (2025-2026):**
- **Free tier**: Up to 1,000 registered devices, unlimited pushes — suitable for development/testing
- **Startup plan**: CNY 0/month for ≤10,000 MAU (Monthly Active Users) — effectively free for small apps
- **Growth plan**: CNY 99–499/month depending on MAU (10k–100k)
- **Enterprise**: Custom pricing above 100k MAU
- Vendor channel passthrough (Xiaomi/Huawei etc.) requires app to have vendor channel configured — JPush handles the routing but you still need to register apps with each vendor (though JPush simplifies this process significantly vs. raw SDK)

**JPush Scheduled Push API:**
```json
POST https://api.jpush.cn/v3/push
{
  "platform": "android",
  "audience": { "registration_id": ["<device_id>"] },
  "notification": { "android": { "title": "Task Due", "alert": "Meeting in 30 minutes" } },
  "options": {
    "time_to_send": "2026-06-07 09:00:00"  // scheduled delivery time
  }
}
```
This REST API call can be made from a Supabase Edge Function — no custom cron backend required.

### 2.2 Umeng Push 友盟+ (`umeng_analytics_push`)

| Field | Value |
|---|---|
| pub.dev package | `umeng_analytics_push` |
| Latest version | `2.1.8` (published 2022-09-08) |
| Dart SDK | Not checked (v2.1.8 likely Dart 2) |
| Maintained by | Community (zileyuan) |
| Status | **STALE** — last update September 2022, no Dart 3 support |

**Verdict: AVOID** — not maintained, Dart 2 only, package is essentially dead.

Umeng push itself (product) is still active but the Flutter plugin is unmaintained. Would require forking.

### 2.3 阿里云移动推送 Aliyun Push (`aliyun_push`)

| Field | Value |
|---|---|
| pub.dev package | `aliyun_push` |
| Latest version | `1.2.0` (published 2026-05-07) |
| Dart SDK | `>=2.18.5 <4.0.0` (Dart 3 compatible) |
| Flutter | `>=2.5.0` |
| Homepage | https://help.aliyun.com/document_detail/434552.html |
| Total versions | 26 (actively maintained) |

**Aliyun Push Features:**
- Official Alibaba Cloud plugin, actively maintained in 2026
- Integrates with Aliyun Mobile Push service (EMAS)
- Supports vendor channels: Xiaomi, Huawei, OPPO, Vivo, FCM (optional)
- Full scheduled push support via Aliyun console
- REST API available

**Aliyun Push Pricing (2025-2026):**
- **Free tier**: 1 million pushes/month (for apps with < 100k devices)
- **Pay-as-you-go**: CNY 1.68 per 10,000 pushes beyond free tier
- Requires Alibaba Cloud account (international accounts supported)
- No Chinese business license required for individual developers

### 2.4 个推 Getui (`getuiflut`)

| Field | Value |
|---|---|
| pub.dev package | `getuiflut` |
| Latest version | `0.2.41` (published 2026-05-11) |
| Dart SDK | check needed |
| Status | Community maintained, active |

**Getui Notes:**
- 个推 is a popular Chinese push service, acquired by A-share company
- Supports all major vendor channels
- Scheduled push via REST API available
- Pricing: similar to JPush — free tier up to 100k MAU

### 2.5 MobPush (`mobpush_plugin`)

| Field | Value |
|---|---|
| pub.dev package | `mobpush_plugin` |
| Latest version | `1.3.2` (published 2026-01-09) |
| Homepage | http://www.mob.com/mobService/mobpush |

**MobPush Notes:**
- Mob.com aggregator product
- Supports vendor channels
- Free for basic usage
- Less commonly used vs JPush/Getui

---

## 3. Comparison: Direct Vendor SDK vs Aggregator

| Criterion | Direct Vendor SDK | Aggregator (JPush/Aliyun) |
|---|---|---|
| Coverage | Per-device: only works on that vendor's ROM | All ROMs with one integration |
| Flutter support | Minimal community plugins only (except Huawei) | Official/near-official plugins |
| Registration effort | 4 separate developer accounts | 1 account |
| Business license req. | Xiaomi/OPPO/Vivo require it | Not required (individual dev OK) |
| Backend complexity | Must build push dispatch logic per vendor | One REST API call handles all |
| Scheduled push | Manual implementation needed | Built-in console + REST API |
| Maintenance burden | 4 SDKs to update | 1 SDK to update |
| Dart 3 support | Huawei: yes; others: community only | JPush: use fl_jpush; Aliyun: yes |
| Cost | Free (with quotas) | Free tier available |
| Time to integrate | 2-4 weeks per vendor | 2-3 days for one aggregator |

**Verdict: Aggregator is strongly preferable for a small team.**

---

## 4. Backend Integration with Supabase (No Firebase)

For aggregators, the backend flow is:

```
Supabase DB (task deadline approaching)
    ↓
Supabase Edge Function (pg_cron trigger or realtime)
    ↓  HTTP POST
JPush REST API / Aliyun Push REST API
    ↓  vendor routing
Device system-level push (survives app kill)
```

**No Firebase needed at all.** The aggregator's REST API is the push gateway.

### JPush REST API (from Supabase Edge Function):
```typescript
// supabase/functions/send-push/index.ts
const response = await fetch('https://api.jpush.cn/v3/push', {
  method: 'POST',
  headers: {
    'Authorization': 'Basic ' + btoa(`${appKey}:${masterSecret}`),
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    platform: 'android',
    audience: { registration_id: [deviceRegId] },
    notification: {
      android: { title: taskTitle, alert: taskBody }
    },
    options: {
      time_to_send: scheduledTimeISO  // "2026-06-07 09:00:00"
    }
  })
});
```

### Aliyun Push REST API:
Similar pattern — call Aliyun Push OpenAPI from Supabase Edge Function.

---

## 5. Scheduled Push Support

### JPush Scheduled Push
- **Supported**: YES, via `options.time_to_send` in push payload
- Time zone: UTC+8 by default (configurable)
- Max future scheduling: 30 days ahead
- Can create, update, cancel scheduled pushes via REST API
- Console UI also supports scheduling

### Aliyun Push Scheduled Push
- **Supported**: YES, via `PushTime` parameter in API call
- Full CRUD for scheduled pushes

### Implication for Taskora:
- Store task deadline in Supabase
- When task is created/updated, call JPush/Aliyun API to schedule a push at `deadline - 30min`
- If task is modified/deleted, cancel and reschedule
- This **eliminates the need for a custom cron backend** — the push service holds the schedule

---

## 6. Recommended Approach for Taskora

**Recommended: `fl_jpush` (Dart 3 compatible JPush wrapper)**

Reasoning:
1. `jpush_flutter` official package is Dart 2 only — blocked
2. `fl_jpush` v5.7.0 supports Dart `>=3.0.0` and Flutter `>=3.24.0` — compatible with this project
3. JPush is the most established aggregator (127 pub.dev versions, actively maintained as of 2026)
4. Single account, one SDK, covers all major Chinese ROMs
5. Built-in scheduled push via REST API — Supabase Edge Function can call it directly
6. Free tier sufficient for early-stage app

**Runner-up: `aliyun_push`**
- Official package maintained by Alibaba Cloud
- Dart 3 compatible
- May be preferred if already using Alibaba Cloud services

**Avoid:**
- `umeng_analytics_push` — stale (2022), not Dart 3 compatible
- Direct per-vendor SDKs — require Chinese business license (Xiaomi/OPPO/Vivo), multiple integrations
- Raw `jpush_flutter` — Dart 2 constraint blocks resolution with `sdk: ^3.11.5`

---

## Caveats / Open Questions

1. **fl_jpush maintainer reliability**: `fl_jpush` is a community package (Wayaer), not the official JPush team. The official `jpush_flutter` has not released a Dart 3 compatible version as of 2026-05-12. Risk: community package could lag behind JPush SDK updates.

2. **Vendor channel still requires registration**: Even with JPush aggregator, to use Xiaomi/OPPO/Vivo system channels, you must still register apps on their developer portals. JPush simplifies this but does not eliminate it. Xiaomi/OPPO/Vivo portals require Chinese business license for commercial apps.

3. **Huawei HMS is separate**: Huawei HMS Push (`huawei_push`) has its own official Flutter plugin and does NOT need JPush. For Huawei devices, consider integrating `huawei_push` separately alongside JPush for other brands.

4. **Free tier limits**: JPush free tier is 1,000 devices (not pushes). For a production app with more devices, paid plan needed (CNY 99+/month).

5. **Aliyun Push does not require business license** for individual developer accounts — this is an advantage over direct Xiaomi/OPPO/Vivo registration.

6. **Dart SDK constraint of `jpush_flutter`**: The `<3.0.0` upper bound means it will never install alongside `sdk: ^3.11.5` without `dependency_overrides`. This is a hard blocker.
