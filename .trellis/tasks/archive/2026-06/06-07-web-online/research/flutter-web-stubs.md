# Research: Flutter Web Platform-Incompatible Package Stubs

- **Query**: How to handle platform-incompatible packages (system_tray, aliyun_push, flutter_local_notifications_windows, alarm, flutter_local_notifications) when adding Flutter Web support
- **Scope**: internal + external
- **Date**: 2026-06-07

---

## 1. The Core Problem

Flutter Web compiles ALL Dart files in `lib/`. Any `import 'dart:io'` at the top level causes a compile-time error on web — `dart:io` is not available in browsers. Similarly, packages like `system_tray`, `aliyun_push`, and `alarm` use `dart:io` / FFI / native plugins internally, so their symbols cannot exist in a web build.

**Root cause for this project**: `main.dart` unconditionally imports `dart:io`, `system_tray`, and calls `AliyunPushService`, `AlarmService`. These fail to compile for web.

---

## 2. Three Techniques (from simplest to most surgical)

### Technique A — `kIsWeb` runtime guard (NOT sufficient alone)

```dart
import 'package:flutter/foundation.dart';

if (!kIsWeb) {
  // safe to call platform code here
}
```

**Problem**: `kIsWeb` is a runtime value. The Dart compiler still parses every import at compile time. If a file has `import 'dart:io'` at the top, it fails to compile for web even if the call site is guarded by `kIsWeb`.

**When it works**: for packages that themselves compile on web (they guard their own `dart:io` internally) but have no-op or different behavior on web. `flutter_local_notifications` v17+ falls into this category — it compiles on web but does nothing.

**Already used in this project**: `fcm_service.dart` line 20 uses `kIsWeb` check — but this only works because `fcm_service.dart` doesn't import `firebase_messaging` at the top level.

### Technique B — `dart:io` conditional import at the file level

Replace all `import 'dart:io' show Platform, ...` with a conditional shim:

```dart
// platform_stub.dart  (web fallback)
class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static bool get isLinux => false;
}
```

```dart
// In the service file, instead of: import 'dart:io' show Platform;
import 'platform_stub.dart'
    if (dart.library.io) 'dart:io';
```

The `if (dart.library.io)` syntax means: on platforms where `dart:io` exists (Android/iOS/desktop), use `dart:io`; otherwise use `platform_stub.dart`. This is **compile-time conditional**, unlike `kIsWeb`.

### Technique C — Full stub file pattern (for entire services/packages)

This is the recommended pattern when a whole service or package must be absent on web.

**Step 1**: Create an abstract interface:
```dart
// lib/services/notification_service_interface.dart
abstract class NotificationServiceInterface {
  Future<void> init();
  Future<void> scheduleNotification({...});
  Future<void> cancelNotification(int id);
}
```

**Step 2**: Create the real implementation (imports native packages freely):
```dart
// lib/services/notification_service_io.dart
import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// ... real implementation
```

**Step 3**: Create a web stub:
```dart
// lib/services/notification_service_web.dart
// No dart:io imports here
class NotificationService implements NotificationServiceInterface {
  Future<void> init() async {}
  Future<void> scheduleNotification({...}) async {}
  Future<void> cancelNotification(int id) async {}
}
```

**Step 4**: Export the right one with conditional import:
```dart
// lib/services/notification_service.dart  (the file all callers import)
export 'notification_service_web.dart'
    if (dart.library.io) 'notification_service_io.dart';
```

---

## 3. Package-by-Package Analysis

### `system_tray` (desktop-only, Windows/macOS/Linux)

- **Web support**: None. Uses FFI + native win32/AppKit APIs.
- **Compilation**: Will fail on web because it transitively imports `dart:ffi`.
- **Strategy**: Wrap all `system_tray` code behind a conditional.

**In `main.dart`**: The import `import 'package:system_tray/system_tray.dart'` and `final SystemTray systemTray = SystemTray()` must be moved to a conditional import file.

```dart
// lib/platform/tray_service.dart  (stub for web + mobile)
void initTray() {}

// lib/platform/tray_service_desktop.dart  (real impl)
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
Future<void> initTray() async { /* existing _initSystemTray() logic */ }
```

```dart
// lib/platform/tray_service_interface.dart
export 'tray_service.dart'
    if (dart.library.io) 'tray_service_desktop.dart';
```

**`pubspec.yaml`**: `system_tray` can remain listed — Flutter's plugin system only links native code for supported platforms. The problem is purely at the Dart import/compile level.

### `aliyun_push` (mobile-only, Android/iOS)

- **Web support**: None. Uses native SDK via MethodChannel.
- **Compilation**: The package itself may or may not compile on web. The bigger issue is `aliyun_push_service.dart` imports `dart:io` directly.
- **Strategy**: Same stub pattern as above.

```dart
// lib/services/aliyun_push_service_web.dart
class AliyunPushService {
  static final AliyunPushService _instance = AliyunPushService._internal();
  factory AliyunPushService() => _instance;
  AliyunPushService._internal();
  Future<void> init() async {}
  Future<void> onUserLoggedIn() async {}
}
```

The `dart:io` import in the real file is fine — it's only compiled on non-web.

### `flutter_local_notifications_windows` (Windows-only)

- **Web support**: None. Windows-specific.
- **Compilation**: Will fail on web.
- **Current usage**: `notification_service.dart` directly imports `flutter_local_notifications` (cross-platform) which is fine, but `FlutterLocalNotificationsWindows` is used inside Platform.isWindows checks.
- **Strategy**: The `flutter_local_notifications_windows` package exports `FlutterLocalNotificationsWindows` class. Since `notification_service.dart` already imports `dart:io`, the whole file needs to be split.

**Note**: `flutter_local_notifications` itself (the base package) added basic web support in v17. On web it compiles but `initialize()` / `show()` are no-ops. So you CAN import it on web if you just need it to compile without errors.

However `FlutterLocalNotificationsWindows` from the separate `_windows` package will NOT compile on web.

### `alarm` package (mobile-focused, Android/iOS)

- **Web support**: None for actual alarm functionality. The package uses native AlarmManager (Android) and AVFoundation (iOS).
- **Current usage**: `alarm_service.dart` already guards calls with `if (_isMobile)` and `if (!_isMobile || !_initialized) return`. But it still imports `package:alarm/alarm.dart` at the top level and imports `dart:io`.
- **Strategy**: Since `alarm` already has a `Platform.isAndroid || Platform.isIOS` guard in the service, only the file-level imports need fixing.

The `alarm` package itself has limited web support (stubs) in newer versions. Check: alarm 5.x does provide web stubs — `Alarm.init()` and `Alarm.set()` are no-ops on web. However the `dart:io` import in `alarm_service.dart` is still the blocker.

### `flutter_local_notifications` (limited web support)

- **Web support**: v17+ compiles on web. All methods are no-ops on web.
- **Strategy**: This one is actually safe to import on web. No special handling needed for the package itself.
- **Web push alternative**: For real web push notifications, use `firebase_messaging` with VAPID key + `flutter_local_notifications` for in-app display. Or use the browser's native Push API via `dart:html` / `web` package.

---

## 4. The `dart:io` Import Problem — Practical Solution

The root blocker is **`import 'dart:io' show Platform, ...`** appearing directly in service files. On web, this is a compile error.

**Best solution for this codebase** (minimizes refactor):

Create `lib/core/utils/platform_utils.dart`:

```dart
// platform_utils.dart — web-safe Platform wrapper
import 'package:flutter/foundation.dart';

// Import dart:io conditionally
import 'dart_io_stub.dart'
    if (dart.library.io) 'dart_io_real.dart';

bool get isAndroid => kIsWeb ? false : platformIsAndroid;
bool get isIOS => kIsWeb ? false : platformIsIOS;
bool get isWindows => kIsWeb ? false : platformIsWindows;
bool get isMacOS => kIsWeb ? false : platformIsMacOS;
bool get isLinux => kIsWeb ? false : platformIsLinux;
bool get isMobile => isAndroid || isIOS;
bool get isDesktop => isWindows || isMacOS || isLinux;
```

```dart
// dart_io_stub.dart
bool get platformIsAndroid => false;
bool get platformIsIOS => false;
bool get platformIsWindows => false;
bool get platformIsMacOS => false;
bool get platformIsLinux => false;
```

```dart
// dart_io_real.dart
import 'dart:io' show Platform;
bool get platformIsAndroid => Platform.isAndroid;
bool get platformIsIOS => Platform.isIOS;
bool get platformIsWindows => Platform.isWindows;
bool get platformIsMacOS => Platform.isMacOS;
bool get platformIsLinux => Platform.isLinux;
```

Then in all service files, replace:
```dart
import 'dart:io' show Platform;
// Platform.isAndroid  →  isAndroid (from platform_utils.dart)
```

---

## 5. Concrete Stub Pattern — Full Example

The cleanest approach used by Flutter ecosystem packages (e.g., `url_launcher`, `path_provider`):

```
lib/services/
  notification_service.dart        ← conditional export (callers import this)
  notification_service_io.dart     ← real implementation (dart:io, native packages)
  notification_service_web.dart    ← web stub (no dart:io)
```

**`notification_service.dart`** (the facade):
```dart
export 'notification_service_web.dart'
    if (dart.library.io) 'notification_service_io.dart';
```

**`notification_service_web.dart`** (web stub):
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

class NotificationService {
  static final _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  static String? pendingTaskId;

  Future<void> init() async {}

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {}

  Future<void> cancelNotification(int id) async {}
  Future<void> cancelAll() async {}

  // ... all public methods as no-ops
}
```

**`notification_service_io.dart`**:
```dart
// Move the ENTIRE current notification_service.dart here
import 'dart:io' show Platform, Directory, File, Process;
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// ... all existing code
```

---

## 6. `main.dart` Specific Changes Required

Current `main.dart` has these web-breaking patterns:

```dart
import 'dart:io' show Platform, exit;           // ← breaks web compile
import 'package:system_tray/system_tray.dart';  // ← breaks web compile
final SystemTray systemTray = SystemTray();     // ← top-level, web-fatal

// In main():
if (Platform.isWindows || ...) { ... }          // ← safe if dart:io is fixed
await _initSystemTray();                        // ← must be conditional
```

Fix approach:
1. Move `system_tray` usage to `lib/platform/tray_service_desktop.dart`
2. Create `lib/platform/tray_service.dart` with `export` conditional
3. Replace `import 'dart:io'` in main.dart with platform_utils.dart
4. Replace `exit(0)` in tray menu with `dart:html` window.close() on web (or just remove it)

---

## 7. `pubspec.yaml` Considerations

For packages with no web support at all (system_tray, aliyun_push), you can optionally restrict them in pubspec using `platforms:` — but this is not required; Flutter's build system will only link native plugins for supported platforms. The real blocker is always Dart-level imports.

Optionally, for `flutter_local_notifications_windows`, you can restrict it:
```yaml
# This doesn't exist as a pubspec feature for dependencies,
# but you can use dependency_overrides for web builds if needed.
```

There is NO `pubspec.yaml` mechanism to conditionally include a dependency by platform for Dart packages. Only the Dart-level conditional imports matter for compilation.

---

## 8. Web Push Notification Alternative

Since `alarm` and `aliyun_push` won't work on web, the web notification strategy should be:

1. **In-app (foreground)**: Use `flutter_local_notifications` which compiles on web (no-ops) + add web-specific implementation using `dart:js_interop` / `web` package to call `Notification.requestPermission()` and `new Notification(...)`.

2. **Background/push**: Use Firebase Cloud Messaging (FCM) which supports web via `firebase_messaging` package. On web, FCM uses Service Workers. The `fcm_service.dart` already has the structure but currently returns null — adding Firebase web support would complete this.

3. **Fallback**: Supabase Realtime (already in the project via `supabase_flutter`) can serve as a real-time channel for in-app notifications when the app is open.

---

## 9. Files That Need Modification

| File | Problem | Fix Required |
|---|---|---|
| `lib/main.dart` | `import 'dart:io'`, `import 'system_tray'`, top-level `SystemTray` | Conditional import for system_tray; replace dart:io with platform_utils |
| `lib/services/notification_service.dart` | `import 'dart:io'`, uses `FlutterLocalNotificationsWindows` | Split into `_io` / `_web` files |
| `lib/services/alarm_service.dart` | `import 'dart:io'`, `import 'package:alarm/alarm.dart'` | Split or use platform_utils |
| `lib/services/aliyun_push_service.dart` | `import 'dart:io'`, `package:aliyun_push` | Split into `_io` / `_web` files |
| `lib/services/battery_optimization_service.dart` | `import 'dart:io'` | Replace with platform_utils |
| `lib/services/permission_service.dart` | (likely `dart:io`) | Replace with platform_utils |
| `lib/core/utils/file_logger.dart` | (likely `dart:io` for file writing) | Split or stub |
| `lib/data/database/app_database.dart` | `sqlite3_flutter_libs`, `drift` with sqlite3 | drift has web support via `drift/web.dart` + sql.js |

---

## 10. Packages With Web Support in This Project

| Package | Web Status |
|---|---|
| `flutter_bloc` | Full web support |
| `supabase_flutter` | Full web support |
| `shared_preferences` | Full web support (localStorage) |
| `dio` | Full web support |
| `flutter_local_notifications` | Compiles, no-op on web (v17+) |
| `drift` | Web support via `drift/web.dart` + sql.js WASM |
| `path_provider` | Web support (limited, returns empty paths) |
| `speech_to_text` | Web support via browser Web Speech API |
| `table_calendar` | Full web support (pure Dart UI) |
| `flutter_markdown` | Full web support |
| `system_tray` | NO web support |
| `window_manager` | NO web support |
| `alarm` | NO web support |
| `aliyun_push` | NO web support |
| `flutter_local_notifications_windows` | NO web support |
| `flutter_timezone` | NO web support (use `DateTime` timezone on web) |
| `sqlite3_flutter_libs` | NO web support (use drift web instead) |
| `desktop_drop` | NO web support |
| `super_clipboard` | Partial web support |

---

## Caveats / Not Found

- `alarm` package v5.x web stub behavior was not verified locally — need to check if `Alarm.init()` on web throws or silently no-ops.
- `flutter_timezone` on web: `FlutterTimezone.getLocalTimezone()` will throw. Must guard with `kIsWeb` and use `DateTime.now().timeZoneName` instead.
- `drift` web migration (sqlite3 → sql.js WASM) is a significant separate task — the `app_database.dart` needs a conditional database factory.
- `file_logger.dart` writes to the filesystem using `dart:io` File — on web this must be stubbed (log to console only, or use IndexedDB).
- `open_filex` and `file_picker` both have web support but behavior differs (no filesystem paths on web).
