# brainstorm: 便签跳转定位缺陷修复 + 本地 SQL 替代远程 API 性能优化

## 实施状态（2026-08-04，Stage 1-4 已完成，P0-1/2/3 已编码；第五次报告＝五项性能根因已查实（Track1/2/3），P0-A/B/C + P1-A~F 方案待确认，L4 待实测）

- ⏳ **第六轮（2026-08-04 三窗口症状，F1-F6 已编码落地，待 L4 实机验证）**：任务栏退出慢 / 关主窗→点便签→再关→便签消失 / 启动一刹那重影——三症状根因已查实（`code/round6_diagnosis.md`），文件级方案 `code/round6_change_plan.md`（6 文件 R1/R2/R3）经用户确认后**全部编码落地**（`code/round6_change_report.md`），R2-4 用户确认实施。**L4 实机验证前不以完成态收尾**。find-skills：flutter-performance 技能不匹配 L4 窗口层，不安装。
- ✅ **Stage 1 立即止血**：级联软删注释 + 停云同步层调用（3 文件）
- ✅ **Stage 2 断连架构**：`CloudSyncGateway` 接口 + `LocalOnlyCloudSyncGateway`（7 表快照 round-trip）+ `DataBackendConfig` + WAL
- ✅ **Stage 3 断连执行**：6 sync_service ×22 守卫、日程云端写停用、`_initStorage` 停云端合并、Realtime 全停、VIP 本地判定
- ✅ **Stage 4 便签定位**：A1（restore notifyListeners + 监听消费）、A2（auth 门解耦）、A3（仓库兜底）、A4（四象限竖向回滚）、A5（bloc focusTaskId + 自动切 day/hour）
- ⚠️ **L4 实机验证（阻塞待办）**：新建任务关窗重开不消失、便签点击定位、四象限回滚、回前台不卡、WAL 生效（见 `code/change_report.md` 六项清单）
- ❌ **复发（2026-08-04 第三次报告）**：点便签主窗不弹出（需点任务栏）→ 弹出后全窗卡顿（点日历/缩小/关闭都卡，点软件任意处才恢复）。根因已查实 = **上一轮 setOpacity 白屏修复引入的分层窗口回归**（见下节），P0 待修，**未修复前不得宣称"已完成"**。
- ❌ **复发（2026-08-04 第四次报告·用户更新后实测）**：新增 4 症状——①打开软件慢 + 需点任务栏 + 首页仍慢（明明本地化）②小窗右键退出慢 ③无法关闭/切模块无响应/x 闪 ④便签已定位首页任务但窗口仍最小化不弹出。新增根因 **RC2 开机自启双实例** + **RC3 启动 7.8s** + **RC4 周期刷新**（见下节）。P0 三件方向已与用户确认，**文档先行、编码待办**。
- ⏳ **后续专项**：日程并入 drift 表（已 100% 本地）、旧 TaskBreakdown 双轨收敛

## ⚠️ 复发根因（2026-08-04 第三次报告 — 先调查后修复）

> 症状：点便签 → 跳转首页十分卡；主窗**不弹出**，需在任务栏点一下才出来；弹出后点日历/缩小/关闭都卡顿，**需点软件任意处才恢复**。
> 排查方式：直读 flog 日志 + 直读 window_manager-0.5.1 Windows 源码 + git 对比（**setOpacity 改动为本会话复发修复轮新增、未提交**，症状恰好在其后出现）。

**回归源（证据链，非假设）**：上一轮"白屏修复"加的 `setOpacity(0)`（hideToTray:191）+ `setOpacity(1)`（restoreFullWindow:170）**正是新症状的直接诱因**。

| 环节 | 证据 | 位置 |
|---|---|---|
| ① setOpacity 把主窗变分层窗口 | `SetWindowLong(GWL_EXSTYLE\|WS_EX_LAYERED)` + `SetLayeredWindowAttributes(alpha=255*opacity)`，alpha=0 时整窗全透明 | window_manager-0.5.1/windows/window_manager.cpp:1031-1038 |
| ② 时序缺陷：`show()` 在 opacity=0 时执行 | hideToTray 已置 0 → restoreFullWindow: `show()`(165) → `focus()`(166) → `setOpacity(1)`(170)；show 出的瞬间 alpha=0 不可见 | desktop_floating_tab_controller.dart:165-171, 185-195 |
| ③ 前台锁：`focus()`=SetForegroundWindow 静默失败 | 便签窗 `_openMainWindow` 先 `controller.hide()` 自隐、再 invoke showMain(164) → 该进程可能失去前台权 → `Show()`/`Focus()` 内 SetForegroundWindow 受限不置顶 → 主窗"不弹出" | note_window_app.dart:158-166；window_manager.cpp:256-257, 285-286 |
| ④ 全窗冻结 = 分层窗口 + 未聚焦渲染节流 | WS_EX_LAYERED 窗口不走正常 D3D 合成 + Windows 对后台未聚焦窗口降渲染优先级 → 所有操作卡顿，点任意处强制聚焦+重绘才恢复 | 行为观察（"点一下软件任意处才恢复"） |

**为什么上一轮白屏修复是过度修正**：白屏真因是 `_loadData` 的 `await fetchPreferences()` 网络阻塞首页首帧（home_page.dart:982，已另加 `DataBackendConfig.current==cloud` 守卫独立修复）。setOpacity 是为凑白屏补的"强制重绘"，却引入分层窗口病理 + show 顺序错误 → 新症状。**方向 = 回滚 setOpacity，换可靠置前台 + 依赖已修的网络守卫治白屏。**

## ⚠️ 新增根因（2026-08-04 第四次报告 — 用户更新后实测，先调查后修复）

> 症状：①打开慢 + 需点任务栏 + 首页仍慢 ②小窗右键退出慢 ③无法关闭/切模块无响应/x 闪 ④便签定位但窗口不弹。
> 排查方式：git diff 确认 setOpacity 仍在本轮未提交代码（RC1 未清）+ 读注册表（自启）+ 读 window_manager 源码 + 读 flog 时间戳。结论非假设。

| 根因 | 证据 | 位置 |
|---|---|---|
| **RC1（主）setOpacity 分层窗口回归（第三次报告的回归仍在代码）** | git diff 实证 `setOpacity(0)`/`setOpacity(1)` 未删；window_manager.cpp:1031-1038 setOpacity=WS_EX_LAYERED+alpha；restore 时序 `show()` 时 alpha=0 全透明不可见 → `focus()` 前台锁静默失败 → 用户点任务栏；分层 + 未聚焦渲染节流 → 全窗冻结直到点击强制重绘 | desktop_floating_tab_controller.dart:165-171（restore）/189-194（hide） |
| **RC2 开机自启 + 无单实例锁 → 双实例抢库** | 注册表实证 `HKCU\Software\...\CurrentVersion\Run\Taskora` 指向 Taskora.exe（自启已开）；lib 全库无 mutex/单实例；双进程抢同一 `smart_assistant.db`（WAL 锁竞争）+ 第二实例窗口无前台权 → 打开慢 + 需点任务栏 | main.dart；app_settings_page.dart:613；window_manager_bridge_desktop.dart:14-28 |
| **RC3 启动 ~7.8s** | flog 时间戳：10:49:40.163 `[App] 应用启动` → 10:49:47.967 首次提醒调度（7.8s）；关键路径网络已排除（AuthBloc `currentUser` 同步 getter、`recoverSession` 只读 `hasAccessToken`、`_loadData` 全本地）→ 疑首帧 5 页 IndexedStack 构建 + drift open | main.dart:82-92/182-230；home_page.dart:889-1024 |
| **RC4 周期 reschedule+LoadTasks（每 6-12s 成对）** | flog 实证；触发源 = `AppLifecycleListener.onResume` 被频繁触发（疑 RC1 分层窗口异常激活态相关，RC1 修复后可能自愈） | home_page.dart:119（listener）/131-143（_onAppResume） |

**排除项（避免再次误修）**：Supabase.initialize 联网（`recoverSession` 只读本地存储，非阻塞）、fetchPreferences 残留阻塞（home_page:997 `DataBackendConfig.current==cloud` 守卫已生效）、便签定位查询慢（`_processFloatingTabFocusTask` = 内存遍历 + 一次本地 `get(id)`，非查询问题）。

**方向（已与用户确认）**：P0-1 删 setOpacity + P0-2 可靠置前台（`setAlwaysOnTop(true/false)` HWND_TOPMOST 切换绕过前台锁）+ P0-3 单实例锁（本地回环 socket 互斥，纯 Dart）。白屏由 fetchPreferences 守卫保障，删 setOpacity 不复发。

## ⚠️ 第五次报告（2026-08-04 · 用户实测 P0 后）：便签定位已恢复，但四项性能——白屏秒级 / 启动慢+点两下 / 加载卡慢 / 模块点击无反应

> 症状（用户实测，P0 修复后）：① 点便签**能定位到首页任务了**，但白屏好几秒才显示（要求秒级跳转）② 打开软件要等很久，窗口需**再点一下（点两下）**才展示 ③ 数据加载很卡很慢（明明已本地化）④ 点进后模块无法点、点击无反应卡住。
> 排查方式：3 个并行 trellis-research agent（Track1 跳转路径耗时 / Track2 启动+冻结 / Track3 硬证据＝日志+二进制新鲜度+window_manager 源码），均带 file:line + flog 时间戳实证。结论非假设。

| 症状 | 根因（带证据） | 位置 |
|---|---|---|
| ① 白屏好几秒（便签定位） | **reschedule 黑洞**：restore 的 show/setAlwaysOnTop 激活窗口 → `AppLifecycleListener.onResume`(home_page:119) → `_onAppResume` `await _rescheduleTaskReminders()`(141) → Windows 平台线程串行 ~8000-16000 次 Toast 取消通道调用（notification_service_io:885-894 每任务 24 次 `cancelNotification`→`_windowsPlugin.cancel()` 平台通道）→ 首帧被拖住数秒。**实测标定**：flog「11:27:08.563 rescheduleTaskReminders: 115 tasks」+ 启动 6.4s → 每任务≈2.3ms；当前数据量 → 数秒~20s，白屏时长 ≈ 通道排空时间。**定位本身（_processFloatingTabFocusTask）已是毫秒级快路径，非瓶颈** | home_page.dart:131-143, 233-266；notification_service_io.dart:885-894, 1050-1059 |
| ② 打开慢 + 点两下 | **Supabase.initialize 无超时阻塞 runApp 前关键路径**（main:99-106 `Future.wait[theme,privacy,Supabase.initialize]`）：持久化会话过期 → refresh-token 网络 POST 无 timeout（gotrue_client.dart:1195-1205）→ 首帧白窗卡住。**冷启动无置前台兜底**：runApp 后无显式 show()+focus()，Windows 前台锁（SetForegroundWindow 静默失败，window_manager cpp:250-258/276-287）→ 窗口在但无焦点需再点一次；注册表自启静默启动更是无前台权 | main.dart:99-111；gotrue_client.dart:1114-1118；track3-evidence.md §3/§4 |
| ③ 加载卡慢 | 非 SQLite 慢（drift 后台 isolate + WAL 已生效，connection_native:15）：① `_loadData` 三查询**串行**（projects→groups→tasks，home_page:899-912）② 首帧 **5 页 IndexedStack 全构建**（home_page:554-560）③ **484 时间轴 overlay 每次 setState 全量重建**（home_page:3784→3678-3711，每任务 Positioned+GestureDetector+CustomPaint+AnimatedContainer）④ **加载路径残留网络**：task_bloc:342 `unawaited(_syncCloudPrefsAfterLoad)` → fetchPreferences() **无 DataBackend 守卫无超时**（本地模式仍发 Supabase REST，弱网悬挂堆积 socket） | home_page.dart:899-912, 554-560, 3678-3711, 3784；task_bloc.dart:342；supabase_service.dart:268-280 |
| ④ 模块点击无反应 | 三重叠加：**（a）崩溃实锤**：home_page:1064 `_loadData` 闭包 → `_selectTask`(1324) setState 在 State 已 dispose 时触发 → 2× `[UncaughtError] Null check`（flog **11:27:27.272/.503**，启动后 25s 抛异常）**（b）UI 构建风暴**（上述 484 overlay + 5 页全构建）**（c）RC4 周期重载**：onResume 被 setAlwaysOnTop 切换/便签第二引擎抢焦点反复触发 → 每 6-12s 成对 reschedule+LoadTasks，2s 节流挡不住 → 每次全量重查+重建+全量 reschedule | home_page.dart:1064, 1324, 119, 131-143, 146-159 |

**排除项（避免再次误修，均带证据）**：旧 WS_EX_LAYERED 分层窗口回归**已确认删除**（controller:191 无 setOpacity；setAlwaysOnTop cpp:877-882 用 SetWindowPos(HWND_TOPMOST) **不碰 WS_EX_LAYERED**，双切安全）；无 SynchronousFuture/同步 IO/SQLite 主线程同步调用（grep 实证）；首帧 `_pages` 是 late final 缓存（restore 只改 index 不重建子页）；`_loadData` 全 drift 毫秒级（排除为秒级主因）；网络残留仅剩 task_bloc:342 一处（fetchPreferences 已守卫、syncPreferences 不 await）。

### 方案（按性价比排序，供确认后编码）

**P0（秒级跳转 + 不卡死，先做）**
- **P0-A 移除 resume 秒级重调度**（home_page.dart:131-143）：删 `_onAppResume` 里的 `await _rescheduleTaskReminders()`(141)——启动 `_initStorage`(226) 已跑过，任务/日程变更由写入路径维护提醒，窗口每次激活全量重调度无必要性。直接消灭 ①白屏数秒 + ④RC4 周期重载一半。**行为契约：restore 后首帧 <1s**
- **P0-B 修崩溃**（home_page.dart:1064→1324）：`_loadData` 闭包调 `_selectTask` 前加 `if (!mounted) return;`（`_selectTask` 入口 setState 前判 mounted 兜底）——修 ④ 模块无反应的崩溃实锤
- **P0-C 残留网络守卫**（task_bloc.dart:342）：`_syncCloudPrefsAfterLoad` 加 `DataBackendConfig.current == cloud` 守卫 + timeout——本地模式彻底断网

**P1（启动快 + 加载丝滑，次做）**
- **P1-A Supabase.initialize 移出关键路径/加超时**（main.dart:96-106）：包 `timeout(1.5s)`；或改不 await，runApp 先走本地 auth（LocalAuthenticated 已支持），AuthBloc 懒初始化——消灭 ②"打开等很久"
- **P1-B 冷启动置前台**（main.dart）：runApp 后 postFrame 显式 `windowManager.show()+focus()`（或 TOPMOST 双切）；`onActivate`（main:87）等首帧后再 restore——修 ②"点两下才出现"
- **P1-C 首帧轻量化**（home_page.dart）：IndexedStack 非首页懒构建 + 时间轴 overlay 视口内渲染——削减 5 页全构建 + 484 节点风暴
- **P1-D `_loadData` 并行**（home_page.dart:899-912）：projects/groups/tasks 三查询 `Future.wait`
- **P1-E resume 节流**（home_page.dart:131-143）：`_onAppResume` 最小间隔 ≥30s 或仅 hidden→visible 真切换——断掉 6-12s 成对重载
- **P1-F reschedule 降量（可选）**（notification_service_io.dart:885-894）：折叠 21 次 repeat 取消循环（无重复提醒 2 次即可），48→~4 次/任务，未来任何 reschedule 都不再秒级

### 实施方案（文件级，2026-08-04 定案 — 文档先行，编码待确认）

| # | 文件 | 改动 | 对应 | 影响风险 |
|---|---|---|---|---|
| 1 | `home_page.dart` | `_onAppResume`：删 `await _rescheduleTaskReminders()`(141) + 加 `_lastResumeLoadTime` ≥30s 节流（reload 不重调度提醒） | P0-A + P1-E | LOW（私方法） |
| 2 | `home_page.dart` | `_loadData` postFrame 闭包(1055) 入口 `if (!mounted) return;`；`_selectTask`(1323) 入口 mounted 守卫 | P0-B（崩溃实锤） | LOW |
| 3 | `home_page.dart` | `_loadData`(898-912) projects/groups/tasks 三查询 `Future.wait` 并行（drift 毫秒级但消除串行堆积） | P1-D | LOW |
| 4 | `home_page.dart` | `_buildPages`(177-214)：tab2/3/4（日历/助手/我的）改 `_LazyIndexedPage` 懒构建，首帧只建 0/1；tab0/1 保持即时（`_jumpToMindMap` 直驱 tab1） | P1-C | LOW（新增包装器，仅改构建时机） |
| 5 | `task_bloc.dart` | `_syncCloudPrefsAfterLoad`(342/511) 调用点+方法体加 `DataBackendConfig.current == cloud` 守卫 + import data_backend | P0-C | LOW（1 调用者） |
| 6 | `main.dart` | `Supabase.initialize` 抽 `_initSupabase()` 带 `.timeout(2s)`，超时不阻塞首帧 | P1-A | LOW |
| 7 | `main.dart` | runApp 后 postFrame 调 `restoreFullWindow()`（show→TOPMOST→focus）冷启动置前台，修"点两下" | P1-B | LOW |
| 8 | `supabase_service.dart` | `_client` 字段初始化→getter（避免 2s 超时未完成时构造崩溃）；`currentUser` try/catch 返回 null | P1-A 兜底 | LOW（getter 语义等价） |
| 9 | `notification_service_io.dart` | `cancelReminderForSchedule` 加 `{bool cancelRepeats=true}`，折叠 21 次 repeat 取消；任务侧调用传 `false`（每任务 24→2 次通道调用） | P1-F | LOW（4 调用者） |

**行为契约（可执行断言）**：
- 契约1：`_onAppResume` 30s 内第二次触发 → return，不触发 `_debounceLoadTasks`
- 契约2：`_selectTask` 在 `mounted==false` 时调用 → 不抛异常（先 return）
- 契约3：`_syncCloudPrefsAfterLoad` 在 `DataBackend.local` → 直接 return，不调 `fetchPreferences`
- 契约4：`cancelReminderForSchedule('x', cancelRepeats:false)` → 仅 2 次 `cancelNotification`（base+offset1）
- 契约5：`currentUser` 在 Supabase 未初始化 → 返回 null，不抛
- 契约6：`_initSupabase()` 网络挂起 → 2s 内返回（timeout 生效）

**L4 实机验证（阻塞，用户实测）**：⑤ 便签点击秒级跳转无白屏 ⑥ 启动明显变快 + 窗口直接弹出无需点两下 ⑦ 数据加载丝滑 + 模块点击即时响应 ⑧ 便签定位仍正确 ⑨ 白屏不复发

**已暂存（本会话）**：`home_page.dart` 已加 `_lastResumeLoadTime` 字段（P1-E 第一步）；其余待方案确认后编码。

**范围说明**：时间轴 overlay 视口渲染（P1-Cb）因视觉回归风险延后——被 P0-A/P1-E 消除 reload 频率后非必要；不改便签窗 UI、认证/支付/AI、`_rescheduleTaskReminders` 启动调用（`_initStorage` 保留一次）。

## 待办（更新 2026-08-04 第五次：五项根因已查实，P0-A/B/C + P1-A~F 方案定案待确认）

- [x] **P0-1 回滚 setOpacity 回归**（编码 ✅ 08-04）：已删 `hideToTray` 的 `setOpacity(0)` 与 `restoreFullWindow` 的 `setOpacity(1)`（controller:165-193）；白屏由已修的 fetchPreferences 守卫保障（不复发）。待 L4 实测
- [x] **P0-2 可靠置前台**（编码 ✅ 08-04）：`restoreFullWindow` 改 `show()` → `setAlwaysOnTop(true)` → `setAlwaysOnTop(false)` → `focus()`（HWND_TOPMOST 强制置顶再解除，window_manager 既有 API，controller:172-176）。待 L4 实测确认主窗立即置顶、无需点任务栏
- [x] **P0-3 单实例锁**（编码 ✅ 08-04·本地回环 socket）：`lib/platform/single_instance.dart`（端口 49527 + taskora-show/ok 握手），main.dart `_initWindowManager` 后接入；第二实例 bind 失败 → 握手唤起首实例主窗 → exit(0)；无关程序占端口 → 放行。待 L4 实测
- [ ] **P1 启动提速**：定位启动 7.8s 归属（首帧 5 页 IndexedStack 构建 / drift open）；评估 `Supabase.initialize` 移出 runApp 前关键路径或加超时
- [ ] **P1 周期刷新收敛**：RC1 修复后观察 `_onAppResume` 是否停止频繁触发；必要时加节流
- [x] **第五次排查**（Track1/2/3，证据已入 `research/track{1,2,3}-*.md`）
- [ ] **P0-A 移除 resume 秒级重调度**（home_page:131-143 删 `await _rescheduleTaskReminders`）——便签白屏数秒 + RC4 周期重载减半（最大收益）
- [ ] **P0-B 修崩溃**（home_page:1064→1324 加 `mounted` 守卫）——模块无反应崩溃实锤
- [ ] **P0-C 残留网络守卫**（task_bloc:342 `_syncCloudPrefsAfterLoad` 加 DataBackend 守卫+超时）——本地模式彻底断网
- [ ] **P1-A Supabase.initialize 移出关键路径/加超时**（main:96-106）——启动"等很久"
- [ ] **P1-B 冷启动置前台**（runApp 后 postFrame show+focus；onActivate 等首帧）——"点两下才出现"
- [ ] **P1-C 首帧轻量化**（非首页懒构建 + 时间轴 overlay 视口内渲染）——加载丝滑
- [ ] **P1-D `_loadData` 三查询 Future.wait 并行**（home_page:899-912）
- [ ] **P1-E resume 节流**（≥30s 或仅 hidden→visible 真切换）——断 6-12s 成对重载
- [ ] **P1-F reschedule 降量**（notification_service_io:885-894 折叠 21 次 repeat 取消）——未来任何 reschedule 不再秒级
- [ ] **L4 实机验证（阻塞，本轮五项）**：⑤ 便签跳转秒级无白屏 ⑥ 启动快 + 窗口直接弹出无需点两下 ⑦ 数据加载丝滑 + 模块点击即时响应 ⑧ 便签定位正确 + 白屏不复发 ⑨ 前几轮五项/六项清单继续有效
- [ ] 原 L4 六项清单（`code/change_report.md`）继续有效

## Goal

1. 修复桌面便签点击 → 主窗恢复 → 首页 tab0 时间轴定位该任务的完整链路（当前完全不定位、停在任务视图、任务"消失"）。
2. 解决"联网太卡"：评估并实施"所有数据查询走本地 SQL"以优化交互性能。

## What I already know（来自 3 个并行 research agent，2026-08-04）

### Issue 1 — 便签定位链路（`research/issue1a-*.md` + `issue1b-*.md`）

**核心根因**：8-03 重构（V3 独立便签窗）后，关闭主窗 = `windowManager.hide()`（OS 级隐藏，widget 树存活）。点便签 → `restoreFullWindow`（desktop_floating_tab_controller.dart:156-168）只 show/focus，**不重建 HomePage、不触发 `_loadData`**。`pendingFocusTaskId` 的**唯一消费点**在 `_loadData` postFrame（home_page.dart:1008-1012 → 1047-1065）。唯一旁路 `_onAppResume`（home_page.dart:115-126）被 `auth.currentUser == null`（本地登录用户）直接 return 挡住（116-117）。→ **便签定位完全不触发**。8-03 归档 research"restore 时 HomePage 全新重建"前提在 V3 失效。

子缺陷（均有 file:line 证据）：
| 缺陷 | 根因 | 关键位置 |
|---|---|---|
| 1 停在任务视图 | restore 保留旧 tab 索引 + Navigator 栈；tab0 恒有选中任务 → 显示任务详情面板 | home_page.dart:82-85, 528-531；controller:156-168 |
| 2 任务"消失" | 便签候选（getAllRaw 无过滤）vs 时间轴（excludedProjectIds+首页筛选）口径不一致 → focus 未命中 → pending 被清 + `_scrollToNow` 兜底 | controller:262-294 vs home_page.dart:869-872/938-977/1107-1132；home_page.dart:1049-1061, 1011 |
| 3 四象限不定位 | onTap 已接 `_selectTask`（会切模式+横向滚动），但时间轴在页面顶、四象限在底，**竖向视口没拉回时间轴**，横向滚动在不可见区域执行 | home_page.dart:5397-5401, 1164-1191, 1416/1420 |
| 4 不自动切 day/hour | 自动切换逻辑只在用户主动 `_selectTask` 执行；加载路径 `_applyProjectFilter` 自动选 `_nearestTask` 只赋值不切模式不滚动；hour 视图非今天任务不渲染 | home_page.dart:750, 1123-1131, 3591-3592, 1231-1258 |
| 5 非跨天创建失败 | **基本排除真失败**：创建链路无单日/跨天差异分支（git 实证便签提交未触碰创建链路）；更可能是"创建成功但 hour 视图不可见+未定位"叠加，或单日专属冲突弹窗取消静默 return | task_create_sheet.dart:917-918, 934-956；task_bloc.dart:673-762 |

### Issue 2 — 本地 SQL 替代远程 API（`research/issue2-local-sql-feasibility.md`）

**关键澄清**：读路径**已经 100% 走本地 drift**（7 张表 schemaVersion=13：Projects/Tasks/ChecklistItems/ProjectGroups/TaskAttachments/NodeTemplates/LazyLogDrafts），写路径是"本地优先 + fire-and-forget push + LWW 全量对账（含墓碑）"。"联网卡"瓶颈**不在读层，而在同步层**：
1. 回前台/登录串行 await 全表拉取，无超时、无增量游标（home_page.dart:119-125 / 252-260）。
2. 6 条常驻 Realtime WebSocket。
3. 日程 schedules / 旧任务 TaskBreakdown 走 SharedPreferences+远程双轨。
4. `database/` 下全为 Supabase DDL，`data.db` 是 0 字节占位；本地库实为 `smart_assistant.db`（drift，database_config.dart:5）。

## ⚠️ 任务"消失"真根因（2026-08-04 运行时实证，优先级最高）

> 排查方式：任务"测试"关窗重开丢失 → 复制/直读活库 `Documents/smart_assistant.db`（482 任务）+ 实读日志 `Documents/logs/task_2026-08-04.log` + 实读 project_sync_service.dart。结论非假设。

**Bug A — ProjectSync 级联软删摧毁本地任务（"任务消失"的真根因）**
- 云端 `projects` 表有 16 个墓碑项目（`deleted=1`），含 `inbox`（本地名"未命名"，墓碑 `updated_at=1781079861486`≈6-10）。
- `_upsertProjectFromRow`（project_sync_service.dart:284-346）：本地项目存活但 `updatedAt < 云端墓碑` → **接受墓碑**（296-306）→ `remoteDeleted==1 && (本地缺失||本地已删)` → **无条件级联软删该项目下所有 tasks**（325-344，`cascadeSeed`=云端墓碑 updated_at）。
- **时间线（日志实证）**：08:36:28 `[CreateTask] local commit id=67412eba 测试 projectId=inbox` → 08:36:32 `[ProjectSync] 级联软删项目 inbox 下的任务`（创建后 4 秒）→ 任务 `deleted=1` → UI 过滤 → "任务没了"。
- **受损范围（活库实证）**：483 任务中 **313 个 `deleted=1`（65%）**；其中 **≥136 个为级联哨兵受害者**（`deleted=1 && updatedAt==1781079861486`=inbox 墓碑），含**今天创建的全部 7 个"测试"任务**。项目 31 个中 16 个墓碑。
- **持续出血**：云端墓碑未除，每次项目同步（forcePullAll/syncAll/realtime）都重新级联软删这些项目下新建任务。

**Bug B — 任务推送整体失败（PGRST204 schema 缺口）**
- `taskToSyncRow`（task_sync_service.dart:286-309）发 `archived` 字段，但云端 `user_tasks` 表**无 `archived` 列** → 每次 `push()` 都 `PostgrestException PGRST204`（日志反复出现）。
- 后果：任务**无法推送云端**，只存本地 → 更易受 Bug A 误删。**云同步实际上完全失效。**

**与便签定位的关系**：用户以为"便签功能导致任务消失"——实为 Bug A 级联软删。便签定位缺陷（BP1-BP5）真实但**独立**，属次要。

**紧急处置建议（与"断掉远程库"决策一致）**：① 立即停用 ProjectSync 级联/同步，止住出血；② 恢复级联误删任务（≥136 个，`deleted=1→0`，判据=哨兵 updatedAt）；③ 再做本地化迁移。

## Root Cause — 便签定位链路（2026-08-04 逐条核实，非假设）

> 核实方法：全库 grep 写入/消费点 + 逐段实读 home_page.dart / main.dart / controller。以下每条均有 file:line 实证。

**BP1（核心）— 消费点只在 `_loadData` postFrame，而窗口恢复不触发 `_loadData`。便签定位 100% 不触发（本地用户）/ 非确定（云端用户）。**
- 写入（唯一）：`restoreFullWindow` 写 `pendingFocusTaskId`+token —— desktop_floating_tab_controller.dart:159-160
- 读取+清空（唯一）：`_processFloatingTabFocusTask` —— home_page.dart:1047-1052，仅被 home_page.dart:1010（`_loadData` postFrame）调用
- `_loadData` 触发源：① initState postFrame（home_page.dart:816）——**只在 State 重建时跑**；② `_onVisibleTabChanged`（819-828）——需 tab0 由不可见变可见且 `_needsRefresh`；③ BlocListener TaskNewLoaded（1375-1387）——需先有 LoadTasks 事件
- `_loadData` 闸门：`if (!_visible) return;`（848-851）
- 恢复不触发：`restoreFullWindow` 全文（156-168）无 `notifyListeners()`/无 mode 切换/无 `_loadData`；主窗 `home:` 恒为 `HomePage`（main.dart:328-337），同类型 → Element 保留 → State 不重建（**即使 notifyListeners 也只重建 MaterialApp，不会重跑 `_loadData`**）
- 唯一旁路 `_onAppResume`（home_page.dart:112-126）：**本地用户被 `auth.currentUser == null` 直接 return（117）**；云端用户还依赖 forcePullAll→syncAll→debounce→LoadTasks→BlocListener 多异步 hop + 2s 节流，非确定

**BP2 — restore 不重置 tab 索引 / Navigator 栈 → 停在"任务视图"。**
- `_tabIndex`/`_visibleTabIndex` 初始化 0（82-85）但恢复不重置；`IndexedStack(index, _pages)` 保留全部页面（528-531）；hide 不弹 Navigator 路由 → 关主窗前的 tab/详情页原样保留
- tab0 恒有选中任务：`_applyProjectFilter` 无选中自动选 `_nearestTask`（1123-1131）+ `_buildTaskDetail` 选中必渲染（1418）→ 观感"跳到任务视图"

**BP3 — 便签候选 vs 时间轴过滤口径不一致 → focus 未命中 → 任务"消失"。**
- 便签候选：`getAllRaw()` 无过滤（desktop_floating_tab_controller.dart:262-294）
- 时间轴：excludedProjectIds（home_page.dart:869-872）+ 首页筛选恢复（938-977）+ `_applyProjectFilter`（1107-1132）+ nodeType 过滤（1094-1105）
- focus 未命中 → pending 已被清（1051-1052）→ `_scrollToNow(animated:false)`（1011）→ 任务滚出视口 = "消失"

**BP4 — 四象限点击 onTap 已接 `_selectTask`，但横向滚动发生在不可见区域。**
- onTap → `_selectTask`（home_page.dart:5400-5401）正确；`_scrollToTask` 只滚横向 `_timelineController`（1164-1181）
- 布局：时间轴在 Column 顶部（1416）、四象限底部（1420）同一竖向 ScrollView；**无代码把竖向视口拉回时间轴**；IndexedStack 使 `hasClients` 恒 true（1165）→ 滚动照跑但看不见

**BP5 — 自动切 day/hour 只在用户主动 `_selectTask` 时执行。**
- `_selectTask` 内置自动切换（home_page.dart:1232-1258，跨天/全天→day、今天内→hour、否则滚动）
- 但加载路径 `_applyProjectFilter` 只赋值不切模式不滚动（1123-1131）；hour 视图非今天任务不渲染（`_timelinePositionForTask` 3591-3592 直接 return null）；postFrame 无 pending 时 `_scrollToNow`（1011）滚到今天 → 非今天 nearest 被"选中但不可见"

**BP6 — "非跨天任务创建不出来"：高度怀疑非真失败，待手动复现（A7）。**
- 创建链路无单日/跨天差异分支（task_create_sheet.dart:897-978 → task_bloc.dart:673-762 → task_repository.dart:386-457 全通用）；便签提交未触碰创建链路（git 实证 a2e44eb/b411e13）
- 候选解释：① 创建成功但 hour 视图不可见+未定位（BP1+BP5 叠加，单日未来任务最易触发）；② 单日专属冲突弹窗取消 → 静默 `return`（task_create_sheet.dart:917-918, 934-956）
- 结论：先手动复现定论，勿直接按"创建失败"修

## 本地化性能方案（2026-08-04 已核实活库实况）

> 直读 `Documents/smart_assistant.db`（journal_mode/user_version/索引/行数）+ 实读仓储查询。

**当前实况**：
- `journal_mode = delete`（**未启用 WAL**）—— 唯一实质缺口。
- 索引已全：14 个（tasks 的 project_id/parent_id/deleted/status/due_date/archived，checklist_items 的 task_id/deleted，task_attachments 的 task_id，projects 的 deleted/group_id，lazy_log_drafts 3 个）。**无需补建**。
- 行数极小：tasks 484 / projects 31 / groups 12 / checklist 63 / attachments 9 / lazy_log 90 → 全表扫也快，DB 非瓶颈。

**性能措施（按价值排序）**：
1. **启用 WAL**（P0）：`connection_native.dart` 连接后 `PRAGMA journal_mode=WAL` + `synchronous=NORMAL`。收益：drift 后台 isolate 写 + UI 读并发，弱网/写多场景减少 `database is locked`。Web 端不启用（Wasm 无文件 WAL）。
2. **查询微调**（P1，可选）：home `_loadData` 用 `getAll()` 全表再内存过滤，484 行无感；若数据到 10k+，加 SQL 端 `startDate/dueDate` 区间过滤下推。
3. **并行化**（P1，可选）：`_emitTaskSnapshot`/`_loadData` 的 projects/tasks/groups 串行 await → `Future.wait`。
4. **备份**（P2）：`CloudSyncGateway.exportSnapshot()` 兼作备份（见 Final Architecture）。

**最大性能收益不来自 DB**：来自**断掉同步层**（回前台全表对账、Realtime、每次写 push）——即"断连"工作本身。DB 调优只是锦上添花。

## 立即止血方案（待批准，先不改码）

> 目标：停住"云端墓碑 → 级联软删本地任务"的持续出血 + 停用云同步（与"断连"一致）。共 4 处改动，改完重启应用生效。**恢复数据：用户决定不恢复，保持现状。**

| # | 文件 | 位置 | 改动 | 作用 |
|---|---|---|---|---|
| 1 | `lib/services/project_sync_service.dart` | `_upsertProjectFromRow` 的级联块（323-344） | **注释掉级联软删**（含清楚注释 + "重启云同步前须加任务 updatedAt>墓碑 保护"警告） | Bug A 直接修复：云墓碑不再软删本地任务 |
| 2 | `lib/presentation/pages/home/home_page.dart` | `_onAppResume`（119-125） | 注释掉 `forcePullAll()` + `syncAll()`，保留 `_debounceLoadTasks()` + `_rescheduleTaskReminders()` | 停回前台全表对账（兼治弱网悬挂） |
| 3 | `lib/presentation/pages/home/home_page.dart` | `_setupProjectSyncOnAuth`/`startIfReady`（248-311） | 注释掉 `runSyncAll` 函数、`subscribe()`×5、`startRealtime()`、`runSyncAll(...)` 调用；保留 `onUserLoggedIn`、`refresh()`、changes 监听（无事件不触发） | 停登录全量对账 + 停 Realtime |
| 4 | `lib/presentation/blocs/task_new/task_bloc.dart` | `_onSyncFromCloud`(541) + `_runOptimisticTaskChange` 后台 syncAll(572) | 注释掉 `TaskSyncService.syncAll()` 调用 | 停任务变更后乐观同步 |

**不改动的部分**：任务写入的本地提交（drift）全部保留；`push()` 推送保持现状（本就 PGRST204 失败、非破坏性，随断连 PR 一并处理）；认证/支付/AI/推送仍远程。

**验证（改完后）**：① `flutter analyze` 通过（注意 #3 移除 runSyncAll 后 `isFirstSync` 变量需一并注释，避免 unused 告警）；② 重新构建运行，复测"新建任务→关窗重开"不再消失；③ 观察日志无 `[ProjectSync] 级联软删` 与新的 PGRST204 刷屏。

**后续（本次不做）**：CloudSyncGateway 口子 + 全同步层移除（PR3-PR6）+ 便签定位修复（PR1-PR2）。见下文 Final Architecture 与提交粒度。

## Requirements（evolving）

- R1 便签点击 → 主窗恢复到 tab0 + 时间轴选中并滚动到该任务（含自动切 day/hour）。
- R2 恢复后不残留旧 tab/路由，不被本地用户 `auth.currentUser==null` 门挡住。
- R3 四象限点击 → 竖向滚回时间轴 + 横向定位。
- R4 首页加载/创建任务后定位自动切 day/hour。
- R5 非跨天任务创建：**先手动复现**（用户已确认走此路），确认真因后再修（若为冲突弹窗取消 → 给 SnackBar 提示）。
- R6 同步层优化（**①+② 都做**）：全量拉取加超时 + 增量游标 + Realtime 降级为按需 + 回前台 unawaited/限流 + 日程并入 drift。

## Decisions（用户已拍板，2026-08-04）

0. **【新增·最高优先】止住数据丢失 + 恢复数据**：① 立即停用 ProjectSync 级联软删（或整条云同步，与断连决策一致）；② 恢复 ≥136 个级联误删任务（`deleted=1→0`，哨兵 updatedAt 判据）；③ 评估是否回滚其它 177 个可疑 deleted 任务（需人工确认）。
1. **便签定位先不急**：根因已查实（BP1-BP5 + Bug A/B），待"任务消失"数据问题处理后再定实施顺序。
2. **彻底断掉远程业务库，数据只走本地 drift**：除 AI（LLM）外全部本地化——业务数据、认证、支付/VIP、附件文件。
3. **留"口子"**：`CloudSyncGateway` 同步网关接口 + 导出/导入快照（JSON/SQL）；当前 `LocalOnlyCloudSyncGateway`（同步 no-op + 快照可用），将来 `AliyunCloudSyncGateway` 实现同一接口，业务零改动。
4. **支持云端切换**：运行时 `DataBackend`（local|cloud）开关，默认 local。
5. **本地数据库高性能**：**已核实**——索引已很全（14 个），数据量小（484 任务）；唯一实质缺口是 **journal_mode=delete（未启用 WAL）**。性能方案：启用 WAL + 查询微调；大头收益来自断掉同步层（网络），而非 DB 调优。见下"本地化性能方案"。
6. **非跨天任务创建**：已证实非创建失败（Bug A 级联误删 + 推送失败）；无需复现，直接按恢复+修复处理。

## Final Architecture（Issue 2 数据层）

```
UI / Bloc / Repository（只依赖接口）
        │
        ▼
AppDatabase (drift, 唯一业务真源)
  - 7 现有表 + 新增 Schedules + 索引/WAL
        │  dirty ops / query
        ▼
CloudSyncGateway（抽象口子）
  ├─ LocalOnlyCloudSyncGateway（当前：push/pull/subscribe = no-op，
  │                              exportSnapshot/importSnapshot = JSON/SQL 快照）
  └─ AliyunCloudSyncGateway（将来：同一接口 → 阿里云 RDS/Tablestore+OSS+FC）
        ▲
DataBackend switch（local | cloud，默认 local；export 快照即迁移桥）
```

**断连清单（除 AI 外全断）**：6 条 Realtime 停用；`forcePullAll/syncAll/push` 从 UI 流程移除；Supabase 业务表读/写/订阅全撤；认证改纯本地（`LocalAuthenticated` 已支持）；支付 Edge Function 切断、VIP 改本地判定；附件改本地文件；日程并入 drift；旧 TaskBreakdown 双轨收敛。
**保留远程**：AI（LLM，用户配置 endpoint）、节假日 API（可缓存）。

**性能（已核实，见下"本地化性能方案"）**：WAL 未启用（journal_mode=delete）→ 启用 WAL+NORMAL；索引已全无需大动；查询微调 + 并行化。

## Acceptance Criteria（evolving）

- [ ] 便签点击后主窗回到首页 tab0，时间轴选中该任务并滚动（跨天切 day / 今天内切 hour）。
- [ ] 本地登录用户（无 Supabase session）同样可触发定位。
- [ ] 四象限点击任务后竖向视口回到时间轴且横向滚动到位。
- [ ] 日历创建任务后返回首页能定位（消费 bloc focusTaskId）。
- [ ] 复测"非跨天任务创建"，确认可正常创建（若冲突弹窗取消则给明确提示）。
- [ ] 同步：回前台全量拉取加超时；`syncAll/forcePullAll` 增量游标；Realtime 可关/按需。
- [ ] 回归测试补端到端（现有 test_regr_*.dart 仅为字符串结构断言）。

## Definition of Done

- 改动前 `gitnexus impact` 查 blast radius，HIGH/CRITICAL 先报告。
- 每项改动过 `trellis-check`；提交前 `detect_changes`。
- CHANGELOG / 文档同步。
- Windows 桌面端 + Web 端冒烟验证（便签功能仅 Windows）。

## Out of Scope

- 不本地化：认证、支付/订阅权威、AI（LLM）、推送注册、附件文件本体。
- 不改便签窗 UI（DesktopFloatingTaskTab）本身。
- 不做全量数据迁移（旧 TaskBreakdown 双轨收敛单独排期）。

## Technical Notes

- research 索引：`research/issue1a-sticky-restore-chain.md`、`research/issue1b-home-locate-creation.md`、`research/issue2-local-sql-feasibility.md`
- 关键文件：`lib/core/desktop/desktop_floating_tab_controller.dart`、`lib/presentation/pages/home/home_page.dart`、`lib/main.dart`、`lib/presentation/pages/tasks/task_bloc.dart`、`lib/presentation/widgets/task_create_sheet.dart`、`lib/services/*_sync_service.dart`、`lib/data/database/app_database.dart`
- 8-03 归档：`.trellis/tasks/archive/2026-08/08-03-sticky-note-redesign/`（home-focus-mechanism.md 前提已失效）

## ✅ 第六轮修复（2026-08-04 三窗口症状 — F1-F6 已编码落地，待 L4 实机验证）

> 症状：① 任务栏图标右键"退出"不是实时退出要等很久 ② 关闭主窗→有便签→点便签→再关主窗→便签不再显示（任务栏"显示"无此 bug）③ 打开很快但一刹那有重影。
> 排查方式：3 个并行子 agent（codegraph/gitnexus 全链路 + window_manager 0.5.1 / desktop_multi_window 0.3.0 / runner 原生源码比对）+ 主 agent 逐条代码复核。三症状均为 **L4 窗口生命周期/时序/原生渲染类**，未实机验证不宣称修复。

| 症状 | 根因（代码实证） | 关键位置 | 修复方向 |
|---|---|---|---|
| ① 退出慢 | **`await windowManager.destroy(); exit(0)` 竞态死代码**：destroy 发 PostQuitMessage 后 Future 永不完成 → exit(0) 死代码，退出靠 GetMessage→main()return→引擎 teardown 兜底；WM_QUIT 被托盘模态循环吞掉则挂住数秒。H4：X 关闭=隐藏到托盘（flutter_window.cpp:75-78），需确认用户入口 | tray_service_desktop.dart:40-41 | R1-1 `destroy().timeout(1s)`+`exit(0)`；R1-2 退出加 flog；R1-3 确认用户入口 |
| ② 便签消失 | **H1（主）note 窗被销毁**：`setPreventClose(true)` 在 `_initNoteWindowChrome:114`（首帧后才设）→ 创建到首帧无保护 → WM_CLOSE 击穿销毁引擎 → `note.show()` 抛 PlatformException 被静默 catch（controller:227-230）；**H2（次）竞态**：`restoreFullWindow` `_isTransitioning` 早退（:157）+ `onWindowClose` 不 await（bridge:50）→ 便签自隐主窗不恢复 | note_window_app.dart:114；desktop_floating_tab_controller.dart:157/227-230；window_manager_bridge_desktop.dart:50 | R2-1（主）note 创建即 setPreventClose(true)+onWindowClose 兜底只隐藏；R2-2 竞态 await+主窗照常 show；R2-3 windowId flog；R2-4 无候选复用 lastSummary |
| ③ 启动重影 | **A（高）首帧即最大化+无背景刷**：`Show()=SW_MAXIMIZE`（win32_window.cpp:152-154）+`hbrBackground=0`（:100）→ DWM 缩放动画残影；**B（高）restoreFullWindow z 序连爆** 4 次 SetWindowPos（controller:165-176）；**C（中）C++ 单实例唤醒 SW_MAXIMIZE**（main.cpp:13-18，先于 Dart 单实例） | win32_window.cpp:100/152-154；main.cpp:13-18；desktop_floating_tab_controller.dart:165-176 | R3-1 背景画刷 / Show 改 SW_SHOW（待产品确认）；R3-2 前台已就绪跳过 TOPMOST；R3-3 C++ 单实例改 SW_SHOW |

**find-skills 评估**：`spjoshis/claude-code-plugins@flutter-performance`（14 installs，来源未知）不安装——三症状为 L4 窗口原生层，通用 Flutter 性能技能不覆盖；复用已装 `flutter-dart-code-review` 做改后审查。

**L4 实机验证（阻塞，用户重建后逐条实测）**：① 退出延迟 flog 计时 + 确认托盘"退出" vs 任务栏"关闭"；② 复现便签消失读日志（`failed to find target window`⇒H1 已销毁 / 无候选⇒H3）；③ 录屏慢放区分 A 缩放残影 / B z序闪烁 / C 二实例。

**详细文档**：`code/round6_diagnosis.md`（根因证据链 + 方案评估 Q1-Q4 + 行为契约）+ `code/diagrams/round6_window_lifecycle.md`（改前/改后时序图）。
