# Platform Compatibility — Flutter Web / Native Split

> Patterns for writing code that compiles on Flutter Web **and** native (Android/Windows) without breaking either.

---

## The Core Problem

Flutter Web cannot compile files that import `dart:io` or platform-only packages (e.g. `system_tray`, `aliyun_push`, `alarm`). Even if the code is wrapped in `if (!kIsWeb)`, the **compiler still parses the import** and fails.

`kIsWeb` is a **runtime** check — it does NOT prevent compile-time errors from invalid imports.

---

## Pattern 1: Conditional Export (compile-time split) ✅

The correct approach for services or utilities with platform-specific implementations.

### Structure

```
lib/services/
├── notification_service.dart        ← hub (public import)
├── notification_service_io.dart     ← native implementation
└── notification_service_web.dart    ← web stub
```

### Hub file (`notification_service.dart`)

```dart
// Compile-time selection — NOT runtime kIsWeb
export 'notification_service_io.dart'
    if (dart.library.html) 'notification_service_web.dart';
```

### Native file (`notification_service_io.dart`)

```dart
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  Future<void> show(String title, String body) async { /* real impl */ }
}
```

### Web stub (`notification_service_web.dart`)

```dart
// No dart:io, no platform packages
class NotificationService {
  Future<void> show(String title, String body) async {
    // Web: no-op or use dart:html Notification API
  }
}
```

### Key rule

- **`if (dart.library.io)`** selects native (has dart:io).
- **`if (dart.library.html)`** selects web (has dart:html).
- Both cannot coexist in the same file — the conditional export chooses one at compile time.

---

## Pattern 2: Platform Utils (centralized platform detection)

Never scatter `Platform.isAndroid` / `Platform.isWindows` across the codebase — `dart:io Platform` crashes on web even inside `if (!kIsWeb)` blocks in some contexts.

### Solution: `lib/core/utils/platform_utils.dart`

```dart
// Hub — web-safe platform detection
export 'platform_utils_io.dart'
    if (dart.library.html) 'platform_utils_stub.dart';
```

```dart
// platform_utils_io.dart
import 'dart:io';
bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
bool get isWindows => Platform.isWindows;
bool get isMacOS => Platform.isMacOS;
bool get isLinux => Platform.isLinux;
bool get isDesktop => isWindows || isMacOS || isLinux;
```

```dart
// platform_utils_stub.dart (web)
bool get isAndroid => false;
bool get isIOS => false;
bool get isWindows => false;
bool get isMacOS => false;
bool get isLinux => false;
bool get isDesktop => false;
```

### Usage

```dart
import 'package:smart_assistant/core/utils/platform_utils.dart';

if (isAndroid) { /* safe on all platforms */ }
```

---

## Pattern 3: Drift Web WASM (database on web)

Drift ORM supports web via WASM SQLite. The connection factory must be split.

### Structure

```
lib/data/database/
├── app_database.dart
└── connection/
    ├── connection.dart          ← hub
    ├── connection_native.dart   ← NativeDatabase
    └── connection_web.dart      ← WasmDatabase
```

### Hub (`connection.dart`)

```dart
import 'package:drift/drift.dart';

DatabaseConnection connect(String dbName) =>
    connectImpl(dbName);  // resolved by conditional export below

export 'connection_native.dart'
    if (dart.library.html) 'connection_web.dart';
```

### Web (`connection_web.dart`)

```dart
import 'package:drift/wasm.dart';

Future<DatabaseConnection> connectImpl(String dbName) async {
  final db = await WasmDatabase.open(
    databaseName: dbName,
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.dart.js'),
  );
  return db.resolvedExecutor;
}
```

### Native (`connection_native.dart`)

```dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

DatabaseConnection connectImpl(String dbName) {
  final dbFolder = getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, dbName));
  return NativeDatabase.createInBackground(file);
}
```

### OPFS headers (production hosting requirement)

WASM SQLite with OPFS requires these HTTP headers on the hosting server:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

For Vercel, add to `vercel.json`:

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

---

## Packages requiring stubs in this project

| Package | Status | Approach |
|---|---|---|
| `system_tray` | Desktop only | `tray_service.dart` conditional export |
| `aliyun_push` | Mobile only | `aliyun_push_service_io.dart` / `_web.dart` |
| `alarm` | Mobile/desktop | `alarm_service_io.dart` / `_web.dart` |
| `flutter_local_notifications_windows` | Windows only | Included in notification stub |
| `flutter_timezone` | Native only | Guard with `kIsWeb`, fallback to `DateTime.now().timeZoneName` |
| `sqlite3_flutter_libs` | Native only | Handled by Drift connection abstraction |
| `window_manager` | Desktop only | `window_manager_bridge.dart` conditional export |
| `desktop_drop` | Desktop only | Guard call sites with `kIsWeb` |

---

## Vercel deployment

`flutter build web --release` outputs to `build/web/`. Vercel cannot run Flutter builds — use GitHub Actions.

### `vercel.json` (minimum)

```json
{
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }],
  "headers": [
    {
      "source": "/flutter_service_worker.js",
      "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
    },
    {
      "source": "/firebase-messaging-sw.js",
      "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
    }
  ]
}
```

### GitHub Actions (`.github/workflows/deploy-web.yml`)

```yaml
- uses: subosito/flutter-action@v2
  with: { flutter-version: '3.x', channel: stable }
- run: flutter build web --release --web-renderer canvaskit
- uses: amondnet/vercel-action@v25
  with:
    vercel-token: ${{ secrets.VERCEL_TOKEN }}
    vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
    vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
    working-directory: build/web
```

---

## Common Mistakes

### ❌ Using `kIsWeb` to guard a `dart:io` import

```dart
// WRONG — compiler still sees dart:io, fails on web
import 'dart:io';

void foo() {
  if (!kIsWeb) {
    File('x').writeAsString('y'); // compile error on web
  }
}
```

### ✅ Use conditional export instead

```dart
// file.dart (hub)
export 'file_io.dart' if (dart.library.html) 'file_web.dart';
```

---

### ❌ Throwing UnimplementedError in web stubs

```dart
// WRONG — crashes at runtime if called
class AlarmService {
  Future<void> set(DateTime time) => throw UnimplementedError();
}
```

### ✅ Return no-op / safe default

```dart
class AlarmService {
  Future<void> set(DateTime time) async {} // silent no-op on web
}
```
