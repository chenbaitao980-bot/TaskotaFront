# Research: Track 3 硬证据 — 便签白屏 / 启动慢 / 模块卡死

- **Query**: 为 Taskora 症状采集硬证据：①点便签白屏好几秒 ②打开软件慢、窗口需点两下才出现 ③模块点击无反应卡住
- **Scope**: 混合（二进制/日志/注册表/进程/第三方源码）
- **Date**: 2026-08-04（采集时间 11:27–11:32）
- **任务**: `.trellis/tasks/08-04-brainstorm-sql-api/`

---

## Findings

### 1. 运行二进制新鲜度 —— 结论：用户不是在跑旧代码（二进制是新的）

| 文件 | mtime | 说明 |
|---|---|---|
| `Taskora_windows_release/data/app.so` | 2026-08-04 11:22 | 发布二进制，13,779,856 字节 |
| `build/windows/x64/runner/Release/data/app.so` | 2026-08-04 11:22 | 构建产物与发布副本 mtime/大小一致，未二次修改 |
| `Taskora_windows_release/Taskora.exe` | 2026-08-03 16:24 | 68KB 启动器（Dart AOT 在 app.so，此 mtime 无意义） |
| `lib/platform/single_instance.dart` | 2026-08-04 11:15 | 最新源码 |
| `lib/main.dart` | 2026-08-04 11:13 | |
| `lib/core/desktop/desktop_floating_tab_controller.dart` | 2026-08-04 11:12 | |
| `lib/presentation/pages/home/home_page.dart` | 2026-08-04 10:24 | |

- `find lib/ assets/ -newermt 2026-08-04 11:22` 结果为空 → **无任何源文件晚于 app.so**。发布二进制包含截至 11:15 的全部工作区改动（含 git status 中所有 M 文件）。
- 全盘无其他 `Taskora.exe` 副本。
- **进程**：`tasklist | grep taskora` 与 `Get-Process Taskora` 均无结果 → 采集时**无 Taskora.exe 在运行**。

### 2. 应用日志（C:/Users/Administrator/Documents/logs/task_2026-08-04.log，2800 字节全读）

本次 SESSION 11:27:02（与二进制 mtime 11:22 后的首次启动吻合）：

| 时间 | 事件 |
|---|---|
| 11:27:02.134 | `[App] ===== 应用启动 =====` |
| 11:27:02.213 | MemberConfig cache 3 types / AppConfig cache 27 keys |
| 11:27:08.563 | 首次 `rescheduleTaskReminders: 115 tasks`（**启动后 ~6.4s**） |
| 11:27:10.388 | `MemberConfig refresh failed: TimeoutException 3s` + `AppConfig refresh failed: TimeoutException 3s`（**两处 3 秒网络超时**） |
| 11:27:15.146/.147 | `LoadTasks filter=all tasks=115/115`（**双次调用**） |
| **11:27:27.272 / .503** | **`[UncaughtError] Null check operator used on a null value`** ×2：`State.setState (framework.dart:1219)` ← `_HomeContentState._selectTask (home_page.dart:1324)` ← `_HomeContentState._loadData.<anonymous closure> (home_page.dart:1064)` |
| 11:27:56 | 最后一条 reschedule，之后无输出（会话约 55s 终止） |

- **无** `[单实例] 检测到已运行实例` 日志 → 本次为主实例，未走第二实例退出路径。
- **无** `[NoteWindow]` 日志 → **本次会话未创建/打开便签窗**，症状①在本会话无直接日志证据（note_window_app.dart:115 注释确认便签窗是"首帧渲染完成后才显示"以避免白屏，白屏与否取决于首帧耗时，本次未触发）。
- **无** `setAlwaysOnTop` / `setOpacity` / `WS_EX_LAYERED` 相关日志。

昨日 08-03 尾部 100 行：
- 17:59:24–17:59:49 连续**数十条** `PGRST204: Could not find the 'archived' column of 'user_tasks' in the schema cache`（任务推送批量失败，DB 列缺失）。
- `syncAll completed: remote=354, local=476`。
- `RealtimeSubscribeStatus.channelError` → subscribed 反复抖动（长连接不稳）。

### 3. window_manager-0.5.1 源码（pub 缓存 `C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/window_manager-0.5.1`）

- **setAlwaysOnTop**（`windows/window_manager.cpp:877-882`）：
  ```cpp
  SetWindowPos(GetMainWindow(), isAlwaysOnTop ? HWND_TOPMOST : HWND_NOTOPMOST,
               0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
  ```
  - **无 `SWP_NOACTIVATE`** → 切换会激活窗口，这正是 app 用它绕过前台锁的原理。
  - **不触碰 WS_EX_LAYERED** → `setAlwaysOnTop(true)→(false)` 双切换本身**安全**，不引入分层窗口白屏病理（setOpacity 已在 desktop_floating_tab_controller.dart:191 移除）。
  - 风险：TOPMOST→NOTOPMOST 背靠背两次激活型 SetWindowPos，理论上可致闪屏/焦点跳动，但属轻微 UI 副作用，非白屏根因。
- **show()**（cpp:276-287）：`ShowWindowAsync(SW_SHOW)` + `SetForegroundWindow`；**focus()**（cpp:250-258）：`SetWindowPos(HWND_TOP)` + `SetForegroundWindow`。
- **前台锁限制确认仍在**：SetForegroundWindow 对无前台权限进程（登录自启、被抢焦点）静默失败 → 窗口不置前，需再点一次 → **直接解释症状②"点两下才出现"**。
- 方法映射：`window_manager_plugin.cpp:499`（`setAlwaysOnTop` → 原生 `SetAlwaysOnTop`）。
- app 侧绕行逻辑：`lib/core/desktop/desktop_floating_tab_controller.dart:170-175`（`setAlwaysOnTop(true)` 后 `setAlwaysOnTop(false)` + `focus()`），`restoreFullWindow` 在 156-181。

### 4. 注册表自启

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Run
    Taskora  REG_SZ  E:\claude\project2\smart_assistant\Taskora_windows_release\Taskora.exe
```
- **自启已启用**（登录时静默启动 → 进程无前台权，配合证据 3 解释"打开慢/点两下"）。

### 5. 单实例现状

- `netstat -ano | grep 49527` **无结果** → 端口 49527 未被占用；叠加证据 1 无 Taskora.exe 进程 → **首实例当前不在存活**。
- `single_instance.dart` 逻辑：主实例 bind 49527，第二实例 bind 失败 → 握手 `taskora-ok` 触发首实例 `restoreFullWindow`（main.dart:85-94）。

---

## 症状对应关系（证据结论）

1. **① 点便签白屏好几秒**：本会话无 `[NoteWindow]` 日志（未开便签窗），无直接日志证据。可排除"旧二进制/WS_EX_LAYERED 残留"；白屏若发生，只能来自便签窗独立引擎首帧渲染慢或 home_page:1324 崩溃连带，需用户在触发时复现取证。
2. **② 打开软件慢、需点两下**：证据充分 —— 启动 6.4s 才首调度、两处 3s 配置刷新超时、LoadTasks 双调；自启静默启动 + SetForegroundWindow 前台锁 → 需手动再点。
3. **③ 模块点击无反应卡住**：**硬证据** —— 11:27:27 两次 `[UncaughtError] Null check`（_selectTask→setState 在 State 已 dispose 时调用，home_page.dart:1064→1324），启动后 25s 抛异常；昨日另有批量 PGRST204 推送失败与 Realtime 抖动干扰。

## Caveats / Not Found

- 症状①的便签白屏：本次会话未创建便签窗，无日志；需现场触发采集。
- 日志无 `[单实例]`/置顶/透明度任何痕迹 → 本会话主窗未做 restore 置顶操作（说明 11:27:02 是冷启动直接可见，未走便签恢复路径）。
- 04 日志编码正常；03 日志 sync 消息 GBK 乱码，但 PGRST204 内容可辨识。
