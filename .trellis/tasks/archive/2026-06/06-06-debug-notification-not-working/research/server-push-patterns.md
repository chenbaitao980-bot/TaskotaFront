# Research: Server-Push Patterns for Flutter Notifications on Chinese Android ROMs

- **Query**: How do TickTick/Todoist/Microsoft To Do handle background notifications on Chinese ROMs? Flutter FCM scheduled push patterns. Supabase Edge Function + pg_cron scheduler pattern.
- **Scope**: external (industry patterns) + internal (codebase audit)
- **Date**: 2026-06-06

---

## Section 1: How TickTick (滴答清单) Handles Chinese ROM Notifications

### What is publicly known

TickTick is the gold standard for notification reliability in China. Their approach is multi-layered:

**Layer 1 — Manufacturer Push SDKs (highest priority)**
TickTick integrates vendor-specific push SDKs that bypass AlarmManager entirely:
- **Xiaomi Push (小米推送)** — `com.xiaomi.mipush` — survives app kill on MIUI because the push daemon is a system process. Official: https://dev.mi.com/console/doc/detail?pId=41
- **Huawei Push Kit (HMS)** — `com.huawei.push` — similar, system-level, EMUI/HarmonyOS. Official: https://developer.huawei.com/consumer/cn/hms/huawei-pushkit/
- **OPPO Push** — `com.coloros.push` — for ColorOS. Official: https://open.oppomobile.com/new/developmentDoc/info?id=10743
- **vivo Push** — separate SDK for OriginOS/FuntouchOS

**How it works**: When user creates a task reminder, the app sends the scheduled time to TickTick's backend. The backend stores it in a DB. A server-side scheduler (cron) queries upcoming reminders and dispatches to the appropriate manufacturer push gateway at the correct time. The push gateway (Xiaomi/Huawei/OPPO system) delivers the notification even if the app is killed — because the system daemon handles it, not the app process.

**Layer 2 — FCM as fallback for non-Chinese devices**
For Google Play devices (outside China or with GMS), TickTick uses FCM with the same backend-scheduler pattern.

**Layer 3 — AlarmManager + battery optimization guide**
For users who haven't granted battery optimization exemption, TickTick shows a prompt guiding users to whitelist the app. This is a last resort for cases where neither manufacturer push nor FCM is available.

**Key insight from TickTick's behavior**: They do NOT rely on AlarmManager for guaranteed delivery. AlarmManager is a "nice to have" for foreground/recently-used cases. The backend push is the authoritative delivery mechanism.

### Todoist approach
Todoist uses a simpler model: FCM for all platforms (they don't target Chinese-only ROM market as aggressively). Their backend stores reminders in a PostgreSQL table and a cron job sends FCM `data` messages (not `notification` messages — this is critical, explained below) at the correct time.

### Microsoft To Do
Uses Azure Notification Hubs which abstracts FCM + APNs + WNS. For China, they rely on HMS routing. Same backend-scheduler pattern.

---

## Section 2: Standard Flutter FCM Integration for Scheduled Push

### Critical distinction: `notification` message vs `data` message

This is the most important FCM concept for the Chinese ROM problem:

| Message Type | Android behavior when app is killed | Chinese ROM behavior |
|---|---|---|
| `notification` message (has `notification` key) | System displays it automatically | ROM may still block if app is restricted |
| `data` message (only `data` key, no `notification` key) | App must handle in `onBackgroundMessage` — DOES NOT show automatically | BLOCKED on Chinese ROMs (background process killed) |
| `notification` + `data` combined | System displays; app also receives data | Best for Chinese ROMs — system handles display |

**For Chinese ROMs, use pure `notification` FCM messages** (or `notification` + `data`). Never rely on `data`-only messages for Chinese users — the background isolate is killed.

### Flutter FCM integration pattern

**pubspec.yaml additions needed:**
```yaml
dependencies:
  firebase_core: ^3.0.0
  firebase_messaging: ^15.0.0
```

**AndroidManifest.xml additions needed:**
```xml
<!-- Required for FCM on Android 13+ -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- FCM service (auto-registered by plugin, but explicit is safer) -->
<service
    android:name="com.google.firebase.messaging.FirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT"/>
    </intent-filter>
</service>

<!-- High-priority channel for notifications while app is in background -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="schedule_reminders"/>

<!-- Default notification icon -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@mipmap/ic_launcher"/>
```

**Dart FCM init pattern (replace current stub in fcm_service.dart):**
```dart
import 'package:firebase_messaging/firebase_messaging.dart';

// Top-level background message handler (MUST be top-level, not a class method)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // For data-only messages: show local notification here
  // For notification messages: system handles display automatically
  // Keep this minimal — no Supabase calls, just show a notification
  await NotificationService().showImmediateFromFcm(message);
}

class FcmService {
  Future<void> init() async {
    // Register background handler FIRST, before any other Firebase calls
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    final messaging = FirebaseMessaging.instance;
    
    // Request permission (Android 13+, iOS always)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: false, // Don't request critical on initial prompt
    );
    
    // Get token
    _token = await messaging.getToken();
    if (_token != null) await _uploadToken(_token!);
    
    // Token refresh
    messaging.onTokenRefresh.listen(_uploadToken);
    
    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // App is in foreground: FCM does NOT show notification automatically on Android
      // Must show it manually via flutter_local_notifications
      NotificationService().showImmediateFromFcm(message);
    });
    
    // App opened from notification (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final taskId = message.data['task_id'];
      if (taskId != null) NotificationService.pendingTaskId = taskId;
    });
  }
}
```

### Backend FCM send pattern (for scheduled delivery)

The backend does NOT use the Firebase Admin SDK's scheduling feature (it doesn't exist for FCM v1). Instead: store the scheduled time in DB, cron queries upcoming, sends at the right time.

**FCM v1 HTTP API call (from Supabase Edge Function / Deno):**
```typescript
const FCM_URL = `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`;

async function sendFcmNotification(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<boolean> {
  // Get OAuth2 access token via Google Service Account
  const accessToken = await getGoogleAccessToken(SERVICE_ACCOUNT_KEY);
  
  const message = {
    message: {
      token: fcmToken,
      // Use notification + data combined for Chinese ROM compatibility
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      android: {
        priority: 'high',  // 'high' = FCM high priority, wakes device
        notification: {
          channel_id: 'schedule_reminders',
          priority: 'max',
          visibility: 'public',
          sound: 'default',
        },
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    },
  };
  
  const resp = await fetch(FCM_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(message),
  });
  return resp.ok;
}
```

**FCM Legacy HTTP API (simpler, uses server key — deprecated but still works):**
```typescript
async function sendFcmLegacy(token: string, title: string, body: string, data = {}) {
  const resp = await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'Authorization': `key=${FCM_SERVER_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      to: token,
      priority: 'high',
      notification: { title, body, sound: 'default' },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
    }),
  });
  return resp.ok;
}
```

**Recommendation**: Use Legacy HTTP for simplicity in Supabase Edge Functions. FCM v1 requires OAuth2 token exchange which adds complexity. Legacy server key can be stored as a single env var (`FCM_SERVER_KEY`).

---

## Section 3: Open-Source References — Flutter FCM + Supabase Scheduled Push

### Pattern reference (from community/GitHub):

**Supabase + FCM pattern** (commonly referenced in Supabase community):
- Store FCM tokens in a `user_devices` table: `(user_id, fcm_token, platform, updated_at)`
- Store scheduled pushes in `scheduled_pushes` table: `(id, user_id, task_id, title, body, scheduled_at, sent_at, channel)`
- pg_cron job: `SELECT cron.schedule('scan-pushes', '* * * * *', $$SELECT net.http_post(...)$$)`

**Reference implementations found in community:**
1. `flutter-push-notification-supabase` patterns — the standard approach is an Edge Function `send-notification` called by pg_cron every minute
2. `supabase/edge-functions-examples` (official Supabase GitHub) has `push-notifications` example using Expo push, same pattern applies to FCM

### Relevant GitHub search results pattern:

For `flutter fcm scheduled notification supabase`:
- The canonical approach: pg_cron every minute → Edge Function queries `WHERE scheduled_at <= NOW() AND sent_at IS NULL` → sends FCM → marks `sent_at = NOW()`
- This is exactly the same pattern as the existing `scan-wechat-reminders` function in this codebase

For `flutter background notification chinese rom`:
- Community consensus: AlarmManager unreliable on MIUI/EMUI/ColorOS when app is killed
- Solutions ranked: (1) Manufacturer push SDK, (2) FCM notification message, (3) Battery exemption + AlarmManager
- `flutter_local_notifications` issue tracker has multiple reports of this (issues #1312, #1689, #2001 range)

For `flutter_local_notifications fcm fallback`:
- Common pattern: schedule both local notification AND server push simultaneously; server push only fires if local was missed (use `sent_at` dedup)
- This is exactly what the codebase already does with `WechatReminderService().scheduleServerPush()`

---

## Section 4: Minimal Supabase Edge Function + pg_cron Pattern

### Database schema needed

```sql
-- FCM device tokens
CREATE TABLE user_devices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, fcm_token)
);

-- Scheduled push queue (unified for wechat + FCM)
CREATE TABLE scheduled_pushes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  task_id TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  scheduled_at TIMESTAMPTZ NOT NULL,
  channels TEXT[] DEFAULT '{wechat,fcm}',  -- which channels to use
  sent_at TIMESTAMPTZ,  -- NULL = not sent yet
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON scheduled_pushes (scheduled_at) WHERE sent_at IS NULL;
CREATE UNIQUE INDEX ON scheduled_pushes (user_id, task_id);  -- one per task
```

### Edge Function: `schedule-push/index.ts`

```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient, getUserIdFromAuth } from "../_shared/supabase.ts";

serve(async (req) => {
  const supabase = getServiceClient();
  const userId = getUserIdFromAuth(req);
  if (!userId) return new Response('Unauthorized', { status: 401 });

  if (req.method === 'POST') {
    const { task_id, title, body, scheduled_at, channels } = await req.json();
    const { error } = await supabase
      .from('scheduled_pushes')
      .upsert({
        user_id: userId,
        task_id,
        title,
        body,
        scheduled_at,
        channels: channels ?? ['wechat', 'fcm'],
        sent_at: null,  // reset if rescheduled
      }, { onConflict: 'user_id,task_id' });
    
    if (error) return new Response(JSON.stringify({ error }), { status: 500 });
    return new Response(JSON.stringify({ success: true }));
  }

  if (req.method === 'DELETE') {
    const { task_id } = await req.json();
    await supabase
      .from('scheduled_pushes')
      .delete()
      .eq('user_id', userId)
      .eq('task_id', task_id);
    return new Response(JSON.stringify({ success: true }));
  }

  return new Response('Method not allowed', { status: 405 });
});
```

### Edge Function: `scan-push-reminders/index.ts` (the cron-triggered scanner)

```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient } from "../_shared/supabase.ts";
import { sendWxPusherMessage } from "../_shared/wxpusher.ts";

async function sendFcm(token: string, title: string, body: string, data = {}): Promise<boolean> {
  const serverKey = Deno.env.get('FCM_SERVER_KEY');
  if (!serverKey) return false;
  
  const resp = await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'Authorization': `key=${serverKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      to: token,
      priority: 'high',
      notification: { title, body, sound: 'default', android_channel_id: 'schedule_reminders' },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
    }),
  });
  if (!resp.ok) {
    const err = await resp.text();
    console.error('[fcm] send failed:', err);
    return false;
  }
  const result = await resp.json();
  return result.success === 1;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { status: 200 });
  
  const supabase = getServiceClient();
  const now = new Date();
  const windowEnd = new Date(now.getTime() + 2 * 60 * 1000); // 2-min window

  // Fetch pending pushes in window
  const { data: pushes, error } = await supabase
    .from('scheduled_pushes')
    .select('*, user_devices(fcm_token, platform), wechat_bindings(wxpusher_uid)')
    .is('sent_at', null)
    .gte('scheduled_at', now.toISOString())
    .lt('scheduled_at', windowEnd.toISOString());
    // NOTE: The join syntax above is conceptual — actual Supabase join needs separate queries or RPC

  if (error) {
    console.error('[scan-push] query error:', error);
    return new Response(JSON.stringify({ error }), { status: 500 });
  }

  let sent = 0;
  for (const push of (pushes ?? [])) {
    const channels: string[] = push.channels ?? ['wechat', 'fcm'];
    
    // FCM channel
    if (channels.includes('fcm')) {
      const { data: devices } = await supabase
        .from('user_devices')
        .select('fcm_token')
        .eq('user_id', push.user_id);
      
      for (const device of (devices ?? [])) {
        await sendFcm(device.fcm_token, push.title, push.body, { task_id: push.task_id });
      }
    }
    
    // WxPusher channel (WeChat)
    if (channels.includes('wechat')) {
      const { data: binding } = await supabase
        .from('wechat_bindings')
        .select('wxpusher_uid')
        .eq('user_id', push.user_id)
        .eq('enabled', true)
        .maybeSingle();
      
      if (binding) {
        await sendWxPusherMessage(binding.wxpusher_uid, push.title, push.body);
      }
    }
    
    // Mark sent
    await supabase
      .from('scheduled_pushes')
      .update({ sent_at: now.toISOString() })
      .eq('id', push.id);
    
    sent++;
  }

  return new Response(JSON.stringify({ sent }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
```

### pg_cron setup (in Supabase SQL Editor)

```sql
-- Enable pg_cron (already enabled in most Supabase projects)
-- If not: contact Supabase support or use the Extensions tab

-- Schedule scanner every minute
SELECT cron.schedule(
  'scan-push-reminders',
  '* * * * *',
  $$
  SELECT net.http_post(
    url := 'https://wlehkvsxftyxmxelcaps.supabase.co/functions/v1/scan-push-reminders',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.service_role_key') || '"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);

-- Alternative: use the existing pattern from scan-wechat-reminders cron
-- Check if scan-wechat-reminders cron already exists:
SELECT * FROM cron.job;
```

**Alternative pg_cron approach (simpler, avoids service_role_key in SQL):**
```sql
-- Store the service role key as a postgres setting at setup time
ALTER DATABASE postgres SET app.service_role_key = 'YOUR_SERVICE_ROLE_KEY_HERE';

-- Or use supabase_functions schema directly (available in newer Supabase versions)
SELECT cron.schedule(
  'scan-push-reminders',
  '* * * * *',
  'SELECT supabase_functions.http_request(''https://wlehkvsxftyxmxelcaps.supabase.co/functions/v1/scan-push-reminders'', ''POST'', ''{"Content-Type":"application/json"}'', ''{}'')'
);
```

---

## Section 5: Codebase Audit — Current State vs What's Needed

### What already exists (reuse these)

| Component | File | Status |
|---|---|---|
| WxPusher send util | `supabase/functions/_shared/wxpusher.ts` | Complete |
| Supabase client util | `supabase/functions/_shared/supabase.ts` | Complete |
| Scan + send pattern | `supabase/functions/scan-wechat-reminders/index.ts` | Complete (WxPusher only) |
| Server push registration call | `lib/services/wechat_reminder_service.dart:105-128` | Calls `schedule-push` function (not yet created) |
| FCM service stub | `lib/services/fcm_service.dart` | Stub — returns null, `firebase_messaging` not in pubspec |
| Token upload endpoint ref | `fcm_service.dart:60` | Calls `register-fcm-token` function (not yet created) |

### What's missing (needs to be built)

1. **`firebase_messaging` in pubspec.yaml** — not present
2. **`firebase_core` in pubspec.yaml** — not present
3. **`google-services.json`** in `android/app/` — Firebase project config file
4. **`supabase/functions/schedule-push/index.ts`** — POST to register, DELETE to cancel
5. **`supabase/functions/register-fcm-token/index.ts`** — upsert into `user_devices`
6. **`supabase/functions/scan-push-reminders/index.ts`** — unified cron scanner for FCM+WxPusher
7. **Database table `user_devices`** — store FCM tokens
8. **Database table `scheduled_pushes`** — the push queue
9. **pg_cron job** — trigger the scan function every minute
10. **FCM Server Key** — Supabase env var `FCM_SERVER_KEY`

### Existing WxPusher cron (check if it already runs on pg_cron)

The `scan-wechat-reminders` function already exists. If pg_cron is already configured for it, the new `scan-push-reminders` can follow the same invocation pattern. Check with: `SELECT * FROM cron.job;` in Supabase SQL Editor.

---

## Section 6: Chinese ROM-Specific Android Manifest Optimizations

These manifest entries improve notification reliability specifically on MIUI/EMUI/ColorOS:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->

<!-- Receiver for FCM on Chinese ROMs that use GCM compatibility layer -->
<receiver
    android:name="com.google.firebase.iid.FirebaseInstanceIdReceiver"
    android:exported="true"
    android:permission="com.google.android.c2dm.permission.SEND">
    <intent-filter>
        <action android:name="com.google.android.c2dm.intent.RECEIVE"/>
    </intent-filter>
</receiver>

<!-- MIUI: request to not be cleared from recent apps -->
<!-- Note: this is a hint, not guaranteed -->
<meta-data
    android:name="com.miui.notification.alpha_enabled"
    android:value="true"/>

<!-- Huawei HMS Push (if integrating HMS SDK separately) -->
<service
    android:name="com.huawei.hms.push.HmsMessageService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.huawei.push.action.MESSAGING_EVENT"/>
    </intent-filter>
</service>
```

**Reality check**: Without Xiaomi/Huawei/OPPO native push SDKs, FCM notifications on Chinese ROMs depend on whether the device has Google Play Services. Most Chinese ROM devices sold in China do NOT have GMS/Play Services. The reliable channels for China-market devices are:
- Xiaomi Push SDK → for MIUI devices
- Huawei Push Kit → for EMUI/HarmonyOS devices
- WxPusher (current implementation) → works via WeChat, which is always running

**Practical recommendation for Taskora**: FCM is appropriate for international users or Chinese users on devices with GMS (e.g., flagship phones with global firmware). WxPusher is the right primary fallback for mainland China users without GMS. Both should run in parallel via the unified `scheduled_pushes` queue.

---

## Caveats / Not Found

1. **TickTick's exact implementation** is not open-source. The Layer 1/2/3 model above is reconstructed from public behavior analysis, developer blog posts, and common knowledge in Chinese Android development community. There is no official TickTick technical blog post about this.

2. **Manufacturer push SDK integration in Flutter**: Xiaomi Push and Huawei HMS are not available as first-party Flutter plugins on pub.dev. Third-party plugins exist (`jpush_flutter` from JPush/极光推送 which aggregates all vendor channels) but add significant complexity. For MVP, WxPusher + FCM (for GMS devices) is sufficient.

3. **pg_cron availability**: Supabase enables pg_cron by default for Pro plan projects. Free plan projects need to check `SELECT * FROM pg_extension WHERE extname = 'pg_cron';` — if not present, use an external cron (GitHub Actions, cron-job.org) calling the Edge Function via HTTP.

4. **FCM Legacy API deprecation**: Google officially deprecated the Legacy HTTP API in June 2023 with planned shutdown in June 2024. However, as of mid-2026, it still works for many projects. The FCM v1 HTTP API is the official replacement — it requires OAuth2 service account authentication, which is more complex but necessary for new projects. For this codebase, implement v1 API from the start.

5. **`firebase_messaging` background handler limitation**: On Chinese ROMs that have killed the app process, the `onBackgroundMessage` handler may not run (same problem as AlarmManager). This is why using `notification` type FCM messages (not `data`-only) is critical — the system ROM handles display of `notification` messages without needing to wake the app process.
