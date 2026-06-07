# Research: Firebase Push + PWA + Vercel for Flutter Web

- **Query**: Firebase Messaging for Flutter Web Push, Flutter Web PWA setup, Vercel deployment
- **Scope**: external (Flutter/Firebase/Vercel ecosystem knowledge) + internal (existing web/ files)
- **Date**: 2026-06-07

---

## Topic 1: Firebase Messaging for Flutter Web Push

### Package Setup

Add to `pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^3.x.x
  firebase_messaging: ^15.x.x
```

`firebase_messaging` supports Web natively since v9+. No separate web-only package needed.
`flutter_local_notifications` does **NOT** support Flutter Web — it must be replaced/guarded with `kIsWeb` checks.

### web/index.html Changes

Two things must be added:

**1. Firebase SDK scripts (before `flutter_bootstrap.js`):**
```html
<!-- Firebase App (the core Firebase SDK) -->
<script src="https://www.gstatic.com/firebasejs/10.x.x/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.x.x/firebase-messaging-compat.js"></script>
```

**2. Firebase initialization script:**
```html
<script>
  const firebaseConfig = {
    apiKey: "...",
    authDomain: "...",
    projectId: "...",
    storageBucket: "...",
    messagingSenderId: "...",
    appId: "...",
  };
  firebase.initializeApp(firebaseConfig);
</script>
```

Alternatively, use the modular SDK (v9+) — but compat SDK is simpler for FCM SW integration.

### firebase-messaging-sw.js (Service Worker)

Must be placed at `web/firebase-messaging-sw.js`. This file handles **background messages** when the browser tab is hidden/closed.

Minimal content:
```javascript
// Give the service worker access to Firebase Messaging.
importScripts('https://www.gstatic.com/firebasejs/10.x.x/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.x.x/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "...",
  authDomain: "...",
  projectId: "...",
  storageBucket: "...",
  messagingSenderId: "...",
  appId: "...",
});

const messaging = firebase.messaging();

// Optional: handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
```

**Important:** The SW file must be served from the root path (`/firebase-messaging-sw.js`). With `flutter build web`, the output goes to `build/web/` — the file must be at `build/web/firebase-messaging-sw.js`.

### VAPID Key Setup

VAPID (Voluntary Application Server Identification) keys are required for Web Push.

Steps:
1. In Firebase Console → Project Settings → Cloud Messaging → Web configuration
2. Generate a Web Push certificate (creates a VAPID key pair)
3. Copy the **public key** string

In Dart code, subscribe using:
```dart
final messaging = FirebaseMessaging.instance;

// Request permission
NotificationSettings settings = await messaging.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);

// Get token WITH vapid key (required for web)
String? token = await messaging.getToken(
  vapidKey: 'YOUR_VAPID_PUBLIC_KEY',
);
```

Without the `vapidKey` parameter, `getToken()` will throw on web.

### Replacing flutter_local_notifications on Web

`flutter_local_notifications` has no web support. The web notification is handled by FCM itself (via SW for background, via `onMessage` for foreground).

Pattern to use:
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

// Foreground message handler
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  if (kIsWeb) {
    // Use browser Notification API or a toast library
    // flutter_local_notifications is NOT available here
    showWebNotification(message); // custom impl using dart:html or js interop
  } else {
    // Use flutter_local_notifications as before
    flutterLocalNotificationsPlugin.show(...);
  }
});
```

For foreground web notifications, options are:
- **dart:html `Notification` class**: `html.Notification(title, body: body)`
- **js_interop**: call `window.Notification` via `dart:js_interop`
- **overlay/SnackBar**: show in-app UI instead of OS notification

Note: Browser `Notification` API requires user permission granted first (which `requestPermission()` handles).

---

## Topic 2: Flutter Web PWA Setup

### Current State of This Project

`web/manifest.json` already exists with:
- `name`, `short_name`: "Taskora"
- `display: "standalone"` — correct for PWA
- `icons`: 192, 512, maskable variants — complete set
- Missing: `scope`, `lang`, `categories`, `screenshots` (nice-to-have for store listings)

`web/index.html` already has `<link rel="manifest" href="manifest.json">` — connected.

### manifest.json Enhancements for Production PWA

```json
{
  "name": "Taskora",
  "short_name": "Taskora",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "background_color": "#0175C2",
  "theme_color": "#0175C2",
  "description": "Taskora task management app.",
  "orientation": "portrait-primary",
  "prefer_related_applications": false,
  "lang": "zh-CN",
  "icons": [...]
}
```

Key addition: `"scope": "/"` — needed when served from root. If deployed to a sub-path, scope must match.

### flutter_service_worker.js — Flutter's Built-in SW

Flutter Web **auto-generates** `flutter_service_worker.js` during `flutter build web`. It is **not manually edited**.

It caches all Flutter app assets (WASM, JS, fonts, etc.) for offline use.

**Configuration is done via `flutter build web` flags:**
- `--pwa-strategy=offline-first` (default) — caches everything, works offline
- `--pwa-strategy=none` — disables the service worker entirely
- `--base-href=/` — sets the base URL (important for Vercel root deployment)

The generated SW is registered automatically by `flutter_bootstrap.js` (present in this project's `web/index.html`).

### index.html Additions Needed for FCM

When adding FCM, `index.html` must load Firebase scripts **before** `flutter_bootstrap.js`. The FCM service worker registration is separate from Flutter's SW — they coexist.

Flutter's SW (`flutter_service_worker.js`) is at `/flutter_service_worker.js`.
FCM's SW (`firebase-messaging-sw.js`) is at `/firebase-messaging-sw.js`.
These are two different service workers and do not conflict.

### iOS PWA Caveats

For iOS Safari "Add to Home Screen":
- `web/index.html` already has `<meta name="apple-mobile-web-app-capable" content="yes">` — good.
- iOS does NOT support Web Push (FCM) in PWAs added to Home Screen prior to iOS 16.4. From iOS 16.4+, it is supported but requires the user to add the PWA to Home Screen first.

---

## Topic 3: Vercel Deployment of Flutter Web

### Build Output

```bash
flutter build web --release --base-href /
```

Output directory: `build/web/`

This directory contains:
- `index.html`
- `flutter_bootstrap.js`
- `flutter_service_worker.js`
- `main.dart.js` (or WASM files)
- `manifest.json`
- `firebase-messaging-sw.js` (if added manually)
- `assets/`, `icons/`, `canvaskit/` etc.

### Vercel Project Configuration

**Option A: Manual deploy via Vercel CLI**
```bash
npm i -g vercel
cd build/web
vercel --prod
```

**Option B: vercel.json at project root (for Git-connected deploy)**

Place `vercel.json` at the **repo root** (not inside `build/web`):
```json
{
  "buildCommand": null,
  "outputDirectory": "build/web",
  "installCommand": null,
  "framework": null
}
```

But Vercel cannot run `flutter build web` natively (no Flutter runtime on Vercel builders). The recommended approach is to **pre-build** and either:
1. Commit `build/web/` to the repo (not ideal)
2. Use GitHub Actions to build and deploy to Vercel

### SPA Routing (Critical)

Flutter Web is a Single Page Application. All routes must serve `index.html`.

`vercel.json` with SPA rewrite:
```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

Without this, direct URL navigation (e.g. `https://app.com/tasks/123`) returns 404.

**Note:** The `rewrites` rule must NOT match static asset paths. Vercel handles this correctly — static files are served before rewrites are applied, so `/(.*)`  is safe.

### Headers for Service Worker

Service workers require specific MIME type and security headers. Vercel serves JS with correct MIME type by default.

For Firebase Messaging SW and Flutter SW, no special headers are needed beyond defaults on Vercel.

If using SharedArrayBuffer (WASM threads), add COOP/COEP headers:
```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "Cross-Origin-Opener-Policy", "value": "same-origin" },
        { "key": "Cross-Origin-Embedder-Policy", "value": "require-corp" }
      ]
    }
  ]
}
```
Only needed if Flutter WASM with threads is used.

### Full vercel.json (Recommended)

```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ],
  "headers": [
    {
      "source": "/flutter_service_worker.js",
      "headers": [
        { "key": "Cache-Control", "value": "no-cache" }
      ]
    },
    {
      "source": "/firebase-messaging-sw.js",
      "headers": [
        { "key": "Cache-Control", "value": "no-cache" }
      ]
    }
  ]
}
```

Service worker files must **not be cached** by CDN — `no-cache` ensures the browser always re-validates them.

### CI/CD with GitHub Actions

Since Vercel cannot build Flutter, use GitHub Actions:

```yaml
# .github/workflows/deploy-web.yml
name: Deploy Flutter Web to Vercel

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: stable

      - name: Install dependencies
        run: flutter pub get

      - name: Build web
        run: flutter build web --release --base-href /

      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: ./build/web
          vercel-args: '--prod'
```

Required GitHub Secrets:
- `VERCEL_TOKEN` — from Vercel account settings
- `VERCEL_ORG_ID` — from `.vercel/project.json` after first `vercel link`
- `VERCEL_PROJECT_ID` — from `.vercel/project.json`

### Vercel Project Settings

In Vercel dashboard → Project Settings:
- **Root Directory**: leave blank (or set to `build/web` if committing build output)
- **Build Command**: None (build happens in GitHub Actions)
- **Output Directory**: `build/web`
- **Framework Preset**: Other

---

## Caveats / Not Found

1. **firebase_messaging version**: Latest compatible version with this project's Flutter SDK (^3.11.5) needs verification — check pub.dev at time of implementation for `firebase_core` + `firebase_messaging` compatible pair.

2. **aliyun_push on web**: The project uses `aliyun_push: ^1.2.0` for mobile push. This package has **no web support**. All aliyun_push calls must be guarded with `if (!kIsWeb)` before adding web support.

3. **flutter_local_notifications on web**: Confirmed not supported. The package's `flutter_local_notifications_windows` plugin also won't be registered on web — but any direct calls to `flutterLocalNotificationsPlugin` without `kIsWeb` guards will cause runtime errors on web.

4. **alarm package on web**: `alarm: ^5.4.1` also has no web support. Must be guarded.

5. **drift + sqlite3 on web**: `drift` and `sqlite3_flutter_libs` require WASM sqlite on web — this is a separate setup (using `drift`'s web backend with `sqflite_common_ffi` or `sql.js`). This may require significant additional work.

6. **desktop_drop, system_tray, window_manager**: These are desktop-only packages. They will need platform guards on web.

7. **Vercel free tier**: Vercel's Hobby plan supports 100GB bandwidth/month and unlimited deployments — suitable for most early-stage apps.
