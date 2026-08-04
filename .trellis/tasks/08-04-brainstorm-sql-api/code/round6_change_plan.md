# 第六轮变更计划：三窗口症状修复（文件级改动，**编码前待确认**）

> 状态：docs-first 变更计划（**本计划确认前不写代码**）。
> 依据：`round6_diagnosis.md`（三根因 + 方案评估 Q1-Q4）+ 用户已确认（全部做 / R3-1 改正常窗口大小 / 文档暂存）。
> 涉及文件：**6 个**（Dart 4 + C++ runner 2），无公共签名变更，gitnexus impact 全部 LOW。

---

## 一、变更总览

| 组 | 症状 | 文件 | 改动要点 | 契约 |
|---|---|---|---|---|
| R1 | 退出慢 | `tray_service_desktop.dart` | 退出改 `destroy().timeout(1s)`+`exit(0)` | A |
| R2 | 便签消失 | `note_window_app.dart` + `desktop_floating_tab_controller.dart` + `window_manager_bridge_desktop.dart` | note 创建即保护 + 竞态 token + windowId 日志 | B/C |
| R3 | 启动重影 | `win32_window.cpp` + `main.cpp` + `desktop_floating_tab_controller.dart` | Show 改 SW_SHOW + 单实例改 SW_SHOW + isFocused 跳过 TOPMOST | D/E |

---

## 二、文件级改动明细（改前 → 改后）

### F1 `lib/platform/tray_service_desktop.dart`（R1 退出）
```dart
// 改前
MenuItem(label: '退出', onClicked: () async {
  await windowManager.destroy();   // 发 PostQuitMessage，Future 永不完成
  exit(0);                          // 死代码
}),

// 改后
MenuItem(label: '退出', onClicked: () async {
  flog('[Tray] 退出: 用户点击');
  try { await windowManager.destroy().timeout(const Duration(seconds: 1)); }
  catch (_) {}                      // destroy 有 1s 上限，不阻塞退出
  flog('[Tray] 退出: 进程 exit(0)');
  exit(0);                          // 保证实时退出
}),
```
- 新增 `import '../core/utils/file_logger.dart';`
- 注：`flog` 为 fire-and-forget 写文件（尽力而为，退出不等待 flush）。

### F2 `lib/presentation/pages/floating_note/note_window_app.dart`（R2-1 创建即保护）
```dart
// runNoteWindow 改后（关键：runApp 前先 setPreventClose，消除"创建→首帧"无保护窗口期）
Future<void> runNoteWindow() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _registerNoteChannelHandler();
  await _loadInitialSummary();
  // round6 R2-1：提前到 runApp 前。原 setPreventClose 在 _initNoteWindowChrome:114（首帧后才设），
  // 期间 WM_CLOSE 可击穿销毁本引擎 → 复用 note.show() 静默失败 → 便签消失。
  try {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
  } catch (e) { flog('[NoteWindow] 提前 setPreventClose 失败: $e'); }
  runApp(const NoteWindowApp());
  WidgetsBinding.instance.addPostFrameCallback((_) async { ... });  // 原样
}

// 新增：兜底只隐藏不销毁（双保险，即使 preventClose 未生效也绝不销毁引擎）
class _NoteWindowCloseListener extends WindowListener {
  @override
  void onWindowClose() {
    WindowController.fromCurrentEngine().then((c) => c.hide()).catchError((_) {});
  }
}
// runNoteWindow 内注册：windowManager.addListener(_NoteWindowCloseListener());
```
- `WindowController` 已 import（desktop_multi_window）。

### F3 `lib/core/desktop/desktop_floating_tab_controller.dart`（R2-2 竞态 token + R2-3 日志 + R3-2 TOPMOST）
```dart
// 新增字段
int _closeRequestId = 0;                                   // R2-2 关闭请求代际
DesktopFloatingTaskSummary? _lastSummary;                 // R2-4 上次摘要缓存

// handleCloseRequested 改后（捕获代际，恢复主窗可打断本次隐藏）
final myCloseId = ++_closeRequestId;
_isTransitioning = true;
try {
  await _showNoteWindow(candidate);
  if (myCloseId != _closeRequestId) return;               // 已被 restore 打断 → 不隐藏主窗
  await hideToTray();
} finally { _isTransitioning = false; }

// restoreFullWindow 改后（代际递增 + 竞态下主窗照常恢复 + isFocused 跳过 TOPMOST）
_closeRequestId++;                                        // 通知进行中的关闭请求放弃 hideToTray
if (!isWindows) return;
if (openTaskId != null && openTaskId.isNotEmpty) { ... }  // 原样
_dismissedUntilRestore = false;
if (!_isTransitioning) { await _hideNoteWindow(); }        // 竞态时跳过 note 交互，主窗照常 show
await windowManager.show();
if (isWindows) {
  try {
    final alreadyFocused = await windowManager.isFocused(); // R3-2
    if (!alreadyFocused) {                                 // 前台已就绪则跳过 TOPMOST，消 z 序连爆
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setAlwaysOnTop(false);
    }
  } catch (_) {}
}
await windowManager.focus();
desktopWindowVisible = true;
notifyListeners();

// _selectTaskForFloatingTab 改后（R2-4 无候选复用上次摘要）
final candidates = rankCandidates(activeTasks, now);
if (candidates.isEmpty) {
  flog('[FloatingTab] 无候选，复用上次摘要=${_lastSummary != null}');  // R2-4
  return _lastSummary;
}
final summary = DesktopFloatingTaskSummary(...);
_lastSummary = summary;                                    // 更新缓存
return summary;

// _showNoteWindow 改后（R2-3 windowId 日志）
try {
  await note.show();
  flog('[FloatingTab] 便签窗 show 成功 windowId=${note.windowId}');
} catch (e) {
  final code = e is PlatformException ? e.code : e.runtimeType.toString();
  flog('[FloatingTab] 便签窗 show 失败 code=$code windowId=${note.windowId}: $e');
}
```
- 新增 `import 'package:flutter/services.dart';`（PlatformException）。
- `_ensureNoteWindow` 创建后加 `flog('[FloatingTab] 便签窗已创建 windowId=${_noteWindow?.windowId}')`。

### F4 `lib/platform/window_manager_bridge_desktop.dart`（R2-2 onWindowClose await）
```dart
@override
Future<void> onWindowClose() async {          // void → Future<void>（Dart 允许 covariant override）
  final handler = handleDesktopWindowCloseRequested;
  if (handler != null) { await handler(); return; }
  desktopWindowVisible = false;
  await windowManager.hide();
}
```

### F5 `windows/runner/win32_window.cpp`（R3-1 Show 改 SW_SHOW）
```cpp
bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOW);   // 原 SW_MAXIMIZE → 正常窗口大小（用户已确认）
}
```
- **产品影响明示**：启动窗口为 `main.cpp:40-41` 初始尺寸 1280×860（非全屏），消除 DWM 最大化缩放残影；后续需手动最大化（或后续在 Dart 侧数据就绪后控制）。

### F6 `windows/runner/main.cpp`（R3-3 单实例唤醒改 SW_SHOW）
```cpp
if (::GetLastError() == ERROR_ALREADY_EXISTS) {
  HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Taskora");
  if (existing) {
    ::ShowWindow(existing, SW_SHOW);          // 原 SW_MAXIMIZE → 消除二实例最大化跳变
    ::SetForegroundWindow(existing);           // 保留尽力置前台（前台锁失败则用户点一下）
  }
  ...
}
```

---

## 三、行为契约（编码后语义验证 + 实机）
| 契约 | 输入 | 预期 | 层级 |
|---|---|---|---|
| A | 托盘点"退出" | 进程 ≤1.5s 退出 | L4 实机计时 |
| B | note 窗口任意阶段收 WM_CLOSE | 只隐藏不销毁（setPreventClose 提前生效） | L4 实机 |
| C | `_isTransitioning` 时 showMain | 主窗照常 show + 清 `_dismissedUntilRestore` | L2 单测 + L4 |
| D | 窗口已聚焦时 restoreFullWindow | 不触发 TOPMOST 双切 | L2 结构 + L4 |
| E | 第二实例启动 | 首实例 SW_SHOW 非最大化唤醒 | L4 实机 |

## 四、连锁影响（Phase 2 Q2）
- 代码：F1-F6（6 文件）
- 测试：`test/floating_tab_controller_test.dart`（R2 改动影响候选/定位）；`test/single_instance_test.dart`（F6 不触碰 Dart 单实例逻辑，仅 C++ 显示方式，测试不受影响）
- 配置/文档：`CHANGELOG.md`、`prd.md`、`round6_diagnosis.md`
- 类型定义：无

## 五、L4 实机验证（阻塞，重建后逐条实测）
1. 退出延迟 flog 计时 + 确认用户点的是托盘"退出"还是任务栏"关闭"（H4）
2. 复现便签消失：关主窗→点便签→再关主窗，读日志「便签窗 show 失败 code=...」（`failed to find target window` ⇒ H1 已销毁 / 无候选 ⇒ H3）
3. 重影录屏慢放：区分 A 缩放残影（R3-1 消除）/ B z序闪烁（R3-2 消除）/ C 二实例（R3-3 消除）

## 六、风险与取舍
- **R2-4 副作用**：完成任务后仍可能弹旧便签摘要（`_lastSummary` 复用）。若实机确认 H3 不成立，回滚 R2-4（保留 R2-1/2/3）。**本项是否实施需用户确认。**
- **F5 产品影响**：启动窗口 1280×860 非全屏（用户已选"改为正常窗口大小"，此表确认）。
- **不回归第五轮**：R3-2 冷启动（未聚焦）仍走 TOPMOST，保留 P1-B 可靠置前台；R1 不影响 P0-A~F。
