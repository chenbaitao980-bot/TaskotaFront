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

## Windows 窗口生命周期模式（桌面端）

### Windows 前台锁：`SetForegroundWindow` 静默失败 → TOPMOST 双切

Windows 前台锁规则：进程**未被前台激活时**调用 `ShowWindow`/`SetForegroundWindow` 会**静默失败**（不抛错、不置顶）。表现：冷启动/自启/托盘恢复时窗口"在但需点任务栏一下才出来"。

```dart
// ✅ 正确：setAlwaysOnTop(true/false) HWND_TOPMOST 强制提升 z 序再解除，绕过前台锁
Future<void> restoreFullWindow() async {
  await windowManager.show();
  if (isWindows) {
    final alreadyFocused = await windowManager.isFocused();
    if (!alreadyFocused) {           // ← 前台已就绪跳过，避免 z 序连爆闪烁
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setAlwaysOnTop(false);
    }
  }
  await windowManager.focus();       // 前台权释放后再 focus 拿键盘焦点
}
```

**关键**：TOPMOST 双切 `SetWindowPos(HWND_TOPMOST)` **不碰 `WS_EX_LAYERED`**，安全。已就绪时跳过可消除 DWM 重合成闪烁（本任务 F3 启动重影诱因之一）。

### 禁止 `setOpacity` 强制重绘（WS_EX_LAYERED 病理）

`setOpacity` 走 `SetWindowLong(GWL_EXSTYLE|WS_EX_LAYERED)` + `SetLayeredWindowAttributes(alpha)`。alpha=0 整窗全透明 + 分层窗口渲染节流 → "不弹出 + 全窗卡顿"。详见 quality-guidelines.md「setOpacity(0) 强制重绘 → WS_EX_LAYERED 分层窗口病理」。

### note 窗防销毁：`setPreventClose(true)` 必须提前到首帧前

`desktop_multi_window` 子窗口引擎创建到首帧完成前**无 WM_CLOSE 保护**——此时用户/系统触发关闭会击穿销毁引擎，后续 `note.show()` 抛 `PlatformException` 被静默 catch（便签"消失"）。

```dart
// ✅ 正确：runApp 前就 setPreventClose，而非首帧后才设
await windowManager.setPreventClose(true);           // 创建即保护
windowManager.addListener(_NoteWindowCloseListener()); // 关闭兜底只 hide 不销毁
```

### 单实例锁：回环 socket 独占端口（非 pid 锁文件）

```dart
// 首实例：bind 成功 → 常驻 accept 握手；第二实例：bind 失败 → 发握手 → 收到 ack 返回 false（调用方 exit）
// 无关程序占端口：握手无 ack → 返回 true 放行（避免误杀用户应用）
static Future<bool> tryAcquire({void Function()? onActivate}) async {
  try {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen((client) => _handleHandshake(client, onActivate));
    return true;
  } on SocketException {
    return _notifyExistingInstance();
  }
}
```

**为什么用 socket 而非 pid 锁文件**：进程异常退出后端口由 OS 自动释放，无陈旧锁文件残留；握手协议能区分"同款应用"与"无关程序占端口"。固定端口 **49527**（`SingleInstance.port`）。

### 退出竞态：`destroy()` 后 `exit(0)` 是死代码

`windowManager.destroy()` 发 `PostQuitMessage` 后 Future **永不完成**——其后 `await destroy(); exit(0)` 的 `exit(0)` 是死代码，退出靠 `GetMessage→main() return→引擎 teardown` 兜底；WM_QUIT 被托盘模态循环吞掉则挂住数秒。退出直接 `exit(0)`（或 `destroy().timeout(1s)` 后 `exit(0)`）。

---

## Vercel deployment

`flutter build web --release` outputs to `build/web/`. **Vercel cannot run Flutter builds** — its build servers don't have Flutter installed. Two deployment patterns:

### Pattern A — Deploy-branch (no secrets required) ✅ Recommended

GitHub Actions builds Flutter web and force-pushes `build/web/` contents to a `deploy` branch. Vercel serves that branch as static files with no build step.

**Vercel project settings**:
- Framework Preset: **Other**
- Production Branch: **`deploy`**
- Build Command: **empty**
- Output Directory: **empty** (serves root)

**`vercel.json`** must live in `web/` (not project root) so Flutter copies it into `build/web/` during build:

```json
{
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "Cross-Origin-Opener-Policy", "value": "same-origin" },
        { "key": "Cross-Origin-Embedder-Policy", "value": "require-corp" }
      ]
    },
    {
      "source": "/flutter_service_worker.js",
      "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
    }
  ]
}
```

**`.github/workflows/deploy-web.yml`**:

```yaml
name: Deploy Flutter Web

on:
  push:
    branches: [main]

permissions:
  contents: write        # Required — without this, git push returns exit 128

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable  # Do NOT pin flutter-version; must match pubspec sdk constraint
      - run: flutter pub get
      - run: flutter build web --release --base-href /
      - name: Push to deploy branch
        run: |
          cd build/web
          git init
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add -A
          git commit -m "deploy: $(date +'%Y-%m-%d %H:%M:%S')"
          git push --force https://x-access-token:${{ secrets.GITHUB_TOKEN }}@github.com/<org>/<repo>.git HEAD:deploy
```

### Pattern B — Vercel CLI via GitHub Actions (requires 3 secrets)

Needs `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` in GitHub repo secrets. Use `amondnet/vercel-action@v25` with `working-directory: build/web`.

### Common Pitfalls

| Problem | Cause | Fix |
|---|---|---|
| `exit 128` on git push | Missing `permissions: contents: write` in workflow | Add `permissions: contents: write` at top level |
| `flutter pub get` fails on CI | Pinned `flutter-version` too old for pubspec `sdk:` constraint | Use `channel: stable` without pinning version |
| Large file rejected by GitHub | Binary build artifacts committed to history | Use `git filter-repo --path <dir> --invert-paths` to clean history; add dirs to `.gitignore` |
| Vercel shows 404 | Wrong production branch (showing `main` instead of `deploy`) | Vercel Settings → Git → Production Branch → `deploy` |

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

---

### ❌ Adding a static field to the native file but forgetting the web stub

When a service uses the conditional export pattern (`notification_service.dart` → `_io.dart` / `_web.dart`), any **static field** added to the native file must also be added to the web stub with a matching type and default value. Otherwise the project compiles on native but fails on web.

```dart
// WRONG — added to notification_service_io.dart only
class NotificationService {
  static String? pendingMarkDoneTaskId;
}
// notification_service_web.dart has no such field → web compilation error
```

```dart
// ✅ Correct — both files declare the field
// notification_service_io.dart
class NotificationService {
  static String? pendingMarkDoneTaskId;
}
// notification_service_web.dart
class NotificationService {
  static String? pendingMarkDoneTaskId;  // stub — same signature, same default
}
```

**Rule**: After adding any public static field or method to a native `_io.dart` service, immediately mirror it in the `_web.dart` stub.
