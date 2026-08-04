# Research: Track1 — 点便签→主窗恢复→首页 tab0 定位 白屏好几秒 根因定位

- **Query**: 点击便签 → 主窗恢复 → 首页 tab0 定位任务，为什么白屏好几秒才显示（用户要求秒级跳转）
- **Scope**: internal（全部代码实读 + 复用 flog 日志实证，未修改任何代码）
- **Date**: 2026-08-04
- **任务**: `.trellis/tasks/08-04-brainstorm-sql-api/`

---

## 0. 结论先行

**白屏"好几秒"不是首帧渲染成本，也不是网络残留，而是 `restoreFullWindow` 的 show/setAlwaysOnTop/focus 触发了 `AppLifecycleListener.onResume`（home_page.dart:119），`_onAppResume`（131-143）里的 `await _rescheduleTaskReminders()`（233-266）在 Windows 平台线程上串行执行约 8000~20000 次 Toast 取消通道调用，把首帧呈现拖住数秒。**

关键链路（全部 file:line 实证）：

```
点便签 → note_window_app.dart:164 invoke showMain
  → controller:259-265 handler → restoreFullWindow(openTaskId)
  → controller:158-161 写 pendingFocusTaskId
  → controller:165 show() / 172-174 setAlwaysOnTop(true/false) / 176 focus()
      └─ 窗口激活 → Flutter lifecycle resumed → home_page.dart:119 onResume
          └─ home_page.dart:141 await _rescheduleTaskReminders()   ← 秒级黑洞
              ├─ 250-252: 全量任务 for 循环 × cancelReminderForSchedule(id)
              │    └─ notification_service_io.dart:885-894: 每任务 24 次 cancelNotification
              │         (2 + 21 次 repeat 循环 + 1) × _windowsPlugin.cancel() 平台通道
              └─ 260: rescheduleTaskReminders(dbTasks) → 再取消一遍（949）
  → controller:180 notifyListeners()
      └─ home_page.dart:853-860 _onDesktopTabNotify → postFrame _processFloatingTabFocusTask
          → 1147 _selectTask + _scrollToTask（内存遍历+drift get，毫秒级，非瓶颈）
```

定位本身（`_processFloatingTabFocusTask`）已经是快路径；拖时间的只有 resume 副作用里的 `_rescheduleTaskReminders`。

---

## 1. 关键路径 await 清单表（restore 后到任务可见）

| # | 环节 | file:line | await / 工作 | 量级 | 性质 |
|---|---|---|---|---|---|
| A | 便签自隐 | note_window_app.dart:160-162 | `controller.hide()` | ~1ms | 通道 |
| B | 跨引擎唤主窗 | note_window_app.dart:164 | `invokeMethod('showMain')` | ~1ms | 通道 |
| C | 隐藏便签窗 | controller:163 → 235-244 | `invokeMethod('hideNote')` + `note.hide()` | ~1-5ms | 通道 |
| D | show 主窗 | controller:165 | `windowManager.show()` | ~1-10ms | 平台 |
| E | 置顶双切 | controller:172-174 | `setAlwaysOnTop(true/false)` ×2 | ~1-5ms | 平台（激活型 SetWindowPos） |
| F | focus | controller:176 | `windowManager.focus()` | ~1-10ms | 平台 |
| G | **resume 副作用** | home_page.dart:141 | **`await _rescheduleTaskReminders()`** | **数秒（实测 115 任务 6.4s）** | **平台通道 8000~20000 次** |
| H | resume 副作用 | home_page.dart:146-159 → task_bloc.dart:292 | `_debounceLoadTasks()` 500ms 后 `LoadTasks()` → drift 全表 | ~100-200ms | 本地 drift（快） |
| I | bloc→首页 reload | home_page.dart:1488-1511 → 889-1070 | BlocListener `_loadData()` 全量重载 | ~100-300ms | 本地 drift + setState 重建 |
| J | 定位消费 | home_page.dart:853-860 → 1104-1149 | `_processFloatingTabFocusTask`（内存遍历，未命中才 `get(id)`） | ~1-10ms | 本地 |
| K | 选中+滚动 | home_page.dart:1147 → 1323-1363, 1268-1295 | `_selectTask` + `_scrollToTask` animateTo 300ms | ~300ms | 动画 |

**瓶颈 = G。** H/I/K 均为本地、毫秒~百毫秒级；E/F 的激活是 G 的触发源，不是白屏本身。

### G 的内部成本拆解（秒级黑洞的精确构成）

- `_rescheduleTaskReminders`（home_page.dart:233-266）：
  - 250-252：`for (id in allIds) await cancelReminderForSchedule(id)` —— 先全量取消一遍
  - 260：`rescheduleTaskReminders(dbTasks)` → notification_service_io.dart:948-949 每个任务**再** `cancelReminderForSchedule(task.id)`
- `cancelReminderForSchedule`（notification_service_io.dart:885-894）：每个任务 **24 次** `cancelNotification`：
  - 886：base id
  - 887：offset 1
  - 890-892：`for (i=0; i<=_maxRepeatOccurrences(=20); i++)` → 21 次 repeat-offset 取消
  - 893：base(offset 1000)
- `cancelNotification`（notification_service_io.dart:1050-1059）：Windows 上 = `_windowsPlugin!.cancel(id)` 平台通道调用（`AlarmService.cancelAlarm` 桌面端 no-op：alarm_service_io.dart:92-107 `_isMobile=false` 直接 return；`_plugin` 移动端实例为 null 跳过）。
- **合计：每任务 ≥48 次 `_windowsPlugin.cancel()`**（250-252 一遍 + 949 一遍）。若 484 任务全部参与 → ~23,000 次；即使按 `getAll()`（deleted=0 && archived==0，PRD 显示约 170 存活）→ **~8,000~16,000 次**。
- **实测标定**：flog 日志 `11:27:08.563 rescheduleTaskReminders: 115 tasks` 且启动 6.4s 才完成（track3-evidence.md）→ 115×24≈2760 次 ≈ 6.4s ≈ **2.3ms/次**。当前数据量 → **数秒到 20s+**，与"好几秒"吻合。
- Windows 上**调度**是进程内 Timer（notification_service_io.dart:304-310，快）；**取消**走 FlutterLocalNotificationsWindows 原生通道（慢）——不对称是黑洞根因。

---

## 2. 触发源证实：restore 必触 resume（非猜测）

- `_onAppResume` 挂 `AppLifecycleListener(onResume:)`（home_page.dart:119）。
- `setAlwaysOnTop` 的 `SetWindowPos` **无 SWP_NOACTIVATE，切换即激活窗口**（window_manager-0.5.1 cpp:877-882，track3-evidence.md §3）→ 激活 → Flutter Windows 引擎发 lifecycle `resumed` → `_onAppResume`。
- flog 已有 RC4 实证：**reschedule+LoadTasks 每 6-12s 成对出现，触发源 = onResume 被频繁触发**（prd.md RC4 行）。
- 因此每次点便签恢复，只要距上次 >2s（home_page.dart:235-239 节流阈值，实际远大于），`_rescheduleTaskReminders` 全量重跑。

---

## 3. 排除项（避免再次误修，均带证据）

| 怀疑点 | 结论 | 证据 |
|---|---|---|
| 网络残留阻塞 | 排除。数据全 drift；`fetchPreferences` 被 `DataBackendConfig.current==cloud` 守卫跳过（home_page.dart:997，main.dart:202 设 local）；TaskNewBloc `_syncCloudPrefsAfterLoad` 是 `unawaited`（task_bloc.dart:342）；`syncPreferences` 不 await（507） | home_page.dart:994-1024, main.dart:202 |
| `_loadData` 全量重载慢 | 排除为秒级主因。getActive/getAll/getAll 全 drift（task_repository.dart:17-35 纯 select），484 行毫秒级 | home_page.dart:899-912 |
| 首帧 5 页 IndexedStack 重建 | 排除。`_pages` 是 `late final` 缓存实例（home_page.dart:106, 177-214）；restore 只改 IndexedStack index（556-559），子页面不重建 | home_page.dart:553-560 |
| main.dart ListenableBuilder 重建 MaterialApp | 排除为秒级。notifyListeners→ListenableBuilder 重建（main.dart:323-327），但 HomePage 同类型 → Element 复用，State 保留，`_pages` 缓存 → 仅 reconciliation | main.dart:323-368 |
| `_timelineRenderItems`/484 任务渲染 | 排除为秒级。O(n) 纯计算，每次 build 调 3 次（3225/3347/3785），n≈484，几百微秒~毫秒 | home_page.dart:3678-3711, 3784-3786 |
| `_processFloatingTabFocusTask` 慢 | 排除。内存遍历 + 兜底一次 drift `get(id)`（home_page.dart:1112-1121） | home_page.dart:1104-1149 |

---

## Q1: restore 后关键路径有哪些 await/重建，哪个吃掉好几秒

见 §1 清单表。**吃掉"好几秒"的唯一秒级候选是 G：`_rescheduleTaskReminders()`**（home_page.dart:141），其内部约 8k~16k 次 `_windowsPlugin.cancel()` 平台通道串行调用（notification_service_io.dart:885-894, 1050-1059）把平台线程和首帧呈现拖住。其余环节（C/D/E/F/J/K）合计 <1s，H/I 为本地百毫秒级。

## Q2: 白屏原因 = 首帧重建慢 / 网络残留 / show 后未上屏？

**都不是单一原因，主因 = restore 的 resume 副作用把平台线程塞满，导致 show 之后"首个可用帧"迟迟出不来。**
- 机制：主窗 hide 期间（controller:189-194 `windowManager.hide()`）渲染节流/表面可能被丢弃；show 后需要重新呈现新帧。此时 `_onAppResume`（由 setAlwaysOnTop 激活触发）正把约 8k~16k 次 Toast 取消通道操作灌进平台线程；帧呈现/present 排在它们之后 → 窗口已显示但内容是空白/旧缓冲，直到通道队列排空（数秒）才有内容帧 + 定位动画。
- 网络：已排除（§3）。`_loadData` 重载、5 页 IndexedStack 重建：已排除为秒级（§3）。
- 即：**白屏时长 ≈ `_rescheduleTaskReminders` 的平台通道排空时间**。日志标定 115 任务 6.4s，当前数据量更大。

## Q3: 达到"秒级跳转"的最小改动路径（只描述，不改码）

**主修复（一处即可见效）：让 note-restore 不再触发秒级重调度。**
- 方案 A（最简）：`_onAppResume`（home_page.dart:131-143）删掉 `await _rescheduleTaskReminders()`（141）。该函数已在启动时跑过（home_page.dart:226 `_initStorage`），任务/日程变更后由写入路径维护提醒；每次窗口激活全量重调度没有必要性。
- 方案 B（保底节流，若需保留）：把 home_page.dart:235-239 的 2s 节流阈值放大（如 ≥5min 才重跑），至少每个会话只跑一次；或改 `unawaited(...)` 不阻塞。
- 两个方案都不碰 `_processFloatingTabFocusTask`/`_onDesktopTabNotify`（home_page.dart:853-860, 1104-1149）——定位已正确且是快路径。

**次修复（把任何残留 reschedule 的成本降一个量级，强烈建议）**：`cancelReminderForSchedule`（notification_service_io.dart:885-894）对每个任务盲目做 24 次取消（含 21 次 repeat-offset）。改为"仅当任务确实有重复提醒才循环 0..N"；无重复提醒时 2 次即可。48→~4 次/任务，未来任何 reschedule 都不再秒级。

**可选加固（降低 reload 干扰）**：`_onAppResume` 里 `_debounceLoadTasks()`（146-159）→ `LoadTasks` → `_loadData()` 全量重载是本地百毫秒级，非瓶颈；若追求极致可只在 `_needsRefresh`（home_page.dart:804, 867-869）时重载。非必需。

**改动面最小清单**：`lib/presentation/pages/home/home_page.dart` 一处（131-143 删/改 141）；可选 `lib/services/notification_service_io.dart` 一处（885-894 折叠 repeat 循环）。不动 controller、不动 main.dart、不动 note 窗口。

---

## Caveats / 待验证

- 未能静态证明"平台线程被 Toast 取消排满"这一帧延迟机制（需现场 + flog 时间戳验证：restore 打点 `[restore] show` 与首帧/`rescheduleTaskReminders` 完成时间的差值）。但"白屏时长与 reschedule 时长同量级"由 RC4 日志 + 115 任务 6.4s 标定支撑，方向明确。
- 若删掉 141 后白屏仍存，再排查 `windowManager.show()` 本身在 Flutter Windows 的 retained-surface 恢复问题（属引擎层，届时再取证）。
- `_rescheduleTaskReminders` 的 2s 节流（235-239）只在两次调用间隔 <2s 时拦；note-restore 距上次调用必然 >2s，节流无效——这是它每次都全量跑的原因。
