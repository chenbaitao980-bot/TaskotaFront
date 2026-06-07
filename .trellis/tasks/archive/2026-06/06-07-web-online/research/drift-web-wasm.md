# Research: Drift ORM Web Support (WASM SQLite) for Flutter Web

- **Query**: Drift v2.24.0 + Flutter Web — recommended approach, pubspec changes, code changes, limitations, sample conditional init
- **Scope**: mixed (internal codebase + external Drift docs knowledge)
- **Date**: 2026-06-07

---

## Findings

### 1. Recommended Approach in 2024/2025

Drift's official recommended approach for Flutter Web is **`drift/wasm.dart` + `package:drift/web/worker.dart`** using the built-in WASM executor introduced in Drift 2.x. This uses `sqlite3.wasm` compiled by the `sqlite3` package and runs SQLite entirely in the browser via WebAssembly.

There are three historical approaches; only one is current best practice:

| Approach | Status | Notes |
|---|---|---|
| `sqflite_common_ffi_web` | Deprecated / not recommended | Relied on IndexedDB bridges; poor perf |
| `drift/web.dart` (legacy JS) | Still works but legacy | Uses `sql.js` (JS-based SQLite), heavier, less maintained |
| `drift/wasm.dart` (WASM) | **Recommended** (Drift ≥ 2.11) | Uses `sqlite3.wasm`, fastest, official |

Drift 2.24.0 (this project's version) fully supports the WASM path.

**Storage backend** (how data persists in browser):
- `WasmStorageImplementation.opfsShared` — Origin Private File System, best performance, requires `SharedArrayBuffer` (needs COOP/COEP headers)
- `WasmStorageImplementation.opfsLocks` — OPFS without shared memory, good fallback
- `WasmStorageImplementation.inMemory` — no persistence (reset on reload, dev/test only)
- Drift's `WasmDatabase.open()` auto-selects the best available backend.

### 2. pubspec.yaml Changes Required

Add `drift` web worker dependency. No new top-level package is needed — `drift` already bundles the WASM support. However, you need the `sqlite3` WASM binary accessible in the web build:

```yaml
dependencies:
  # existing — keep as-is:
  drift: ^2.24.0
  sqlite3: ^2.9.0
  sqlite3_flutter_libs: ^0.5.28   # only used on native; harmless on web
  path_provider: ^2.1.5
  path: ^1.9.1

  # no new packages needed for web WASM
```

**Critical**: `sqlite3_flutter_libs` only ships `.so`/`.dll`/`.dylib` for native. It has no effect on web. The browser uses the `sqlite3.wasm` file shipped by the `sqlite3` Dart package itself.

### 3. Web Asset Setup (index.html / web/sqlite3.wasm)

You must copy `sqlite3.wasm` into the `web/` folder OR serve it from a CDN. The easiest way:

```bash
# Copy from the sqlite3 package's built-in asset (run from project root):
cp "$(flutter pub cache dir)/hosted/pub.dev/sqlite3-2.9.0/example/web/sqlite3.wasm" web/sqlite3.wasm
```

Or let Drift fetch it automatically — `WasmDatabase.open()` accepts a `wasmUri` parameter pointing to any URL.

**Required HTTP headers** for OPFS (SharedArrayBuffer):
```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```
Without these headers, Drift falls back to a slower OPFS variant or in-memory storage. For production, set these headers in your hosting config (Firebase Hosting, Nginx, etc.).

### 4. Code Changes — database_config.dart / app_database.dart

The current `_openConnection()` in `app_database.dart` uses `dart:io` via `LocalDataService.databaseFile()`, which crashes on web (`dart:io` is unavailable). 

**Pattern: conditional import + platform factory**

Create two files:

**`lib/data/database/connection/connection_native.dart`**
```dart
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import '../../services/local_data_service.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final file = await LocalDataService().databaseFile();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return NativeDatabase(file);
  });
}
```

**`lib/data/database/connection/connection_web.dart`**
```dart
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final db = await WasmDatabase.open(
      databaseName: 'smart_assistant',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );
    return db.resolvedExecutor;
  });
}
```

**`lib/data/database/connection/connection.dart`** (conditional export)
```dart
export 'connection_native.dart'
    if (dart.library.html) 'connection_web.dart';
```

**`lib/data/database/app_database.dart`** — change the import and `_openConnection` call:
```dart
// Replace:
import 'package:drift/native.dart';
// With:
import 'connection/connection.dart';

// Replace _openConnection() body with:
QueryExecutor _openConnection() => openConnection();
```

### 5. Drift Web Worker (drift_worker.dart.js)

For the WASM path with shared access, Drift requires a compiled web worker. Create:

**`web/drift_worker.dart`**
```dart
import 'package:drift/web/worker.dart';

void main() {
  driftWorkerMain();
}
```

Then compile it (add to your build process):
```bash
dart compile js -O2 web/drift_worker.dart -o web/drift_worker.dart.js
```

If you skip the worker, Drift 2.x will still work but falls back to single-tab mode (no SharedWorker cross-tab sync). For a web app that only needs single-tab, you can pass `driftWorkerUri: null` (or omit the worker) and it degrades gracefully.

### 6. LocalDataService — dart:io Incompatibility

`lib/services/local_data_service.dart` uses `dart:io` (`Platform`, `File`, `Directory`). This entire service is incompatible with web. The database connection is the only part consumed by `app_database.dart`; after moving to the conditional-import pattern above, `local_data_service.dart` is no longer called from web code.

**However**, if `LocalDataService` is imported elsewhere without a guard, it will still crash. Audit all import sites:
```
grep -r "local_data_service" lib/
```

### 7. Known Limitations & Gotchas

| Issue | Detail |
|---|---|
| **No file system access** | `dart:io` File/Directory unavailable on web. DB stored in OPFS (browser storage, not user-visible). |
| **OPFS headers required** | SharedArrayBuffer needs COOP/COEP headers. Many simple static hosts (GitHub Pages) don't support this. Firebase Hosting supports custom headers. |
| **WAL checkpoint** | `PRAGMA wal_checkpoint(TRUNCATE)` in `checkpointForBackup()` is a no-op on WASM (OPFS uses VFS, not WAL by default). Won't crash, just does nothing useful. |
| **Attachments** | `TaskAttachments.localPath` stores native file paths — meaningless on web. Attachment upload/download logic needs web-specific handling (e.g., `dart:html` Blob). |
| **flutter_local_notifications** | No web support. Must be guarded behind `kIsWeb` checks. |
| **alarm package** | No web support. Guard with `kIsWeb`. |
| **aliyun_push** | No web support. Guard with `kIsWeb`. |
| **speech_to_text** | Has web support via browser SpeechRecognition API — works. |
| **system_tray / window_manager** | Desktop only. Guard with `kIsWeb || Platform.isAndroid || ...`. |
| **desktop_drop / super_clipboard** | No web support in current versions. |
| **sqlite3_flutter_libs** | Harmless on web (no native libs linked), but generates build warnings. |
| **drift schema version** | WASM and native share the same migration logic — migrations run fine on web. |

### 8. Sample: Full Conditional Initialization

```dart
// lib/data/database/app_database.dart

import 'package:drift/drift.dart';
import 'connection/connection.dart';   // ← conditional import

part 'app_database.g.dart';

// ... table definitions unchanged ...

@DriftDatabase(tables: [ ... ])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 10;

  // ... migration unchanged ...
}
```

```dart
// lib/data/database/connection/connection_web.dart

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'smart_assistant',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      // Worker is optional; if file doesn't exist, Drift degrades gracefully:
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );

    if (result.missingFeatures.isNotEmpty) {
      // Log which OPFS features are unavailable (informational only):
      // e.g., MissingBrowserFeature.sharedArrayBuffers
      print('Drift web: degraded mode: ${result.missingFeatures}');
    }

    return result.resolvedExecutor;
  });
}
```

### 9. Relevant Internal Files

| File | Relevance |
|---|---|
| `lib/data/database/app_database.dart` | Contains `_openConnection()` using `dart:io` — must be refactored |
| `lib/data/database/database_config.dart` | References `NativeDatabase` directly — needs web guard or deletion |
| `lib/services/local_data_service.dart` | Uses `dart:io` throughout — must not be imported on web path |
| `web/index.html` | Standard Flutter web entry — needs no COOP/COEP changes for dev; add for production |
| `pubspec.yaml` | No new packages needed; `sqlite3_flutter_libs` stays |

### 10. External References

- [Drift Web documentation (official)](https://drift.simonbinder.eu/web/) — covers WasmDatabase, worker setup, OPFS
- [Drift 2.x changelog](https://pub.dev/packages/drift/changelog) — WASM support landed in 2.11, stabilized by 2.17
- [sqlite3 pub.dev](https://pub.dev/packages/sqlite3) — ships `sqlite3.wasm` binary under `example/web/`
- [Flutter Web SharedArrayBuffer guide](https://developer.chrome.com/blog/enabling-shared-array-buffer/) — COOP/COEP header requirements

---

## Caveats / Not Found

- The `driftWorkerUri` parameter is required in some Drift versions to avoid a console error, even if you don't care about cross-tab sync. If the `.js` file is missing, Drift logs a warning but continues.
- `WasmDatabase.open()` API signature may differ slightly between Drift 2.11 and 2.24. The `resolvedExecutor` property on the returned `WasmDatabaseResult` is the stable API since ~2.17. Verify against the installed version's source.
- The `connection_web.dart` approach above skips the worker for simplicity. If the app ever needs multiple browser tabs reading the same DB simultaneously, the worker is mandatory.
- `checkpointForBackup()` will silently succeed on web but do nothing — not a bug, just dead code on web.
