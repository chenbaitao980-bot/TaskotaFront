# Research: Track 2 根因定位 — 启动慢 / 点两下才展示 / 加载卡顿 / 模块点击无反应

- **Query**: 四个症状根因定位（①打开等很久 ②窗口点两下才展示 ③本地化后数据仍卡慢 ④点进模块点击无反应卡住）
- **Scope**: internal（只读，未改代码）
- **Date**: 2026-08-04
- **目标文件**: main.dart / home_page.dart / connection_native.dart / single_instance.dart / window_manager_bridge / desktop_floating_tab_controller / notification_service_io / subscription_service / task_new/task_bloc / supabase/gotrue 包源码

---

## 结论速览（Q1–Q3）

| 症状 | 根因 | 主证据 file:line |
|---|---|---|
| ① 打开等很久 | `Supabase.initialize` 在 **runApp 之前**、无超时；持久化会话过期时发 refresh-token 网络 POST | main.dart:99-106；gotrue_client.dart:1114-1118,1195-1205 |
| ② 点两下才展示 | 首帧前网络阻塞 → 白窗；冷启动主窗从未显式 show/focus，Windows 前台锁拒绝前台权 | main.dart:111 runApp 无后续 focus；restoreFullWindow 只在 restore 时 setAlwaysOnTop（controller:156-181） |
| ③ 加载卡慢 | 非 SQLite 慢（drift 后台 isolate），而是：首次打开 DB 迁移 + `_loadData` 三查询串行 + 484 时间轴 overlay 每次重建 + 频繁重载 | connection_native.dart:15；home_page.dart:899-912,3784；main.dart:109 |
| ④ 模块点击无反应 | **不是**残留同步 IO/分层窗口/主线程硬阻塞；是 UI isolate 构建风暴 + 首帧白窗 + 未守卫的网络 socket 悬挂 | 见下"主线程阻塞证据" |

Q2 关键判定：**旧 WS_EX_LAYERED 分层窗口回归已确认删除**（desktop_floating_tab_controller.dart:191-192 hideToTray 不再 setOpacity；restoreFullWindow 改用 setAlwaysOnTop 切换），本轮"模块无反应"是**新原因**（构建风暴+首帧延迟），不是旧残留。

---

## 启动关键路径与时间线（Q1）

### 启动时间线（file:line 证据）

| 序 | 步骤 | 位置 | 成本 | 是否阻塞首帧 |
|---|---|---|---|---|
| 1 | WidgetsFlutterBinding.ensureInitialized | main.dart:57 | 低 | 是（必要） |
| 2 | FileLogger.clear（unawaited） | main.dart:65-68 | 磁盘 IO 已延后 | 否 |
| 3 | _isNoteWindowRole | main.dart:72-75 | 低（WindowController.fromCurrentEngine） | 是 |
| 4 | _initWindowManager | main.dart:78→bridge:10-43 | 低（ensureInitialized+setPreventClose） | 是 |
| 5 | SingleInstance.tryAcquire（loopback bind） | main.dart:85-94；single_instance.dart:26-38 | 低 | 是 |
| 6 | **Future.wait[theme, privacy, Supabase.initialize]** | main.dart:99-106 | **网络无超时，最高** | **是** |
| 7 | _initServices：AppDatabase()+SubscriptionService.init | main.dart:109,199-247,225；subscription_service.dart:52-54 | 低（仅读 prefs 缓存） | 是 |
| 8 | runApp → 首帧 | main.dart:111-121 | 中（5 页 IndexedStack 全构建，见下） | 是 |
| 9 | postFrame：initTray+_initDeferredServices | main.dart:124-133 | 低 | 否 |
| 10 | HomePage._initStorage → NotificationService.requestMobilePermissions + _rescheduleTaskReminders | home_page.dart:216-231 | 中（见 reschedule 链） | 否（首帧后） |
| 11 | HomeContent postFrame → _loadData → **首次 DB 打开**（LazyDatabase 触发迁移） | home_page.dart:849,889；connection_native.dart:5-23 | 中（schema v13 迁移在后台 isolate，但首查等待） | 否（首帧后） |

### 第 6 步网络链（核心）

- supabase_flutter 2.12.4 `Supabase.initialize` → `supabaseAuth.initialize()` → `recoverSession()`（supabase_auth.dart:118-133 同步 await）。
- gotrue 2.20.0 `recoverSession`（gotrue_client.dart:1103-1118）：持久化会话 `isExpired` 且 `_autoRefreshToken`（默认 true）→ `_callRefreshToken` → **POST /auth/v1/token 无 timeout**（gotrue_client.dart:1195-1205）。
- 历史 flog「10:49:40 应用启动 → 10:49:47 首次提醒调度」7.8s 即落在 第6→第10 步，主因是第 6 步网络（弱网/项目暂停/Supabase 不可达时可挂 OS 级 socket 超时）。
- 若用户为纯本地（LocalAuthenticated、无持久化 Supabase session），recoverSession 无网络（gotrue_client.dart:1108-1113），启动快——症状与"登录过+token 过期"强相关。

### drift / WAL（第 4 条排查路径）

- connection_native.dart:15-21：`NativeDatabase.createInBackground`（后台 isolate 跑 SQL，UI 不阻塞）+ `PRAGMA journal_mode=WAL; synchronous=NORMAL` **已生效**。
- 首次打开迁移：app_database.dart:169 `schemaVersion => 13`，onUpgrade 链（172-186）。迁移在后台 isolate，不卡 UI，但首个查询需等其完成。
- connection.dart:1-2：桌面走 native，无问题。

---

## 主线程阻塞证据（Q2）

### 排除项（grep 全 lib）

| 项 | 结果 |
|---|---|
| `SynchronousFuture` | **0 处** |
| `readAsStringSync` | 仅 task_attachment_service_io.dart:357（用户触发读附件，非启动/加载路径） |
| SQLite 同步调用 | 无——drift 全部走后台 isolate（connection_native.dart:15） |
| `Timer.periodic` | 仅 payment_service.dart:109（VIP 页）、vip_page.dart:339（倒计时）——**非周期重载源** |
| 旧 WS_EX_LAYERED 分层窗口残留 | **已删除**：hideToTray（controller:189-194）无 setOpacity；restoreFullWindow（155-181）用 setAlwaysOnTop 切换 |

### 真正的 UI isolate 成本点

1. **时间轴 484 节点渲染**：`_buildTimelineTaskOverlays`（home_page.dart:3784-3785）→ `_timelineRenderItems`（3678-3711）→ 每个任务一个 `Positioned`+`GestureDetector`/`LongPressDraggable`/`CustomPaint`/`AnimatedContainer`（3788-3959）。每次 `_loadData`/setState 全量重建。首帧+每次加载都是爆发点。
2. **5 页 IndexedStack 首帧全构建**：home_page.dart:554-560 + `_buildPages`（177-214）late final 一次性构建全部 5 页；IndexedStack 首帧布局全部子页。任务/日历/助手/我的全部参与首帧。
3. **`_loadData` 三查询串行**（home_page.dart:899-912）：projects await → groups await → tasks await，可 `Future.wait` 并行。
4. **未守卫的网络 socket**：task_bloc.dart:342 `unawaited(_syncCloudPrefsAfterLoad(...))` → supabase_service.dart:268-280 `fetchPreferences()` **无 DataBackendConfig 守卫、无超时**，本地模式下仍发起 Supabase REST 请求；弱网悬挂堆积 socket（async，不阻塞 UI，但加剧卡感）。**这是加载路径上唯一残留网络。**
5. **reschedule 串行链**：home_page.dart:233-266 → notification_service_io.dart:944-978 `rescheduleTaskReminders` 对每个任务串行 `cancelReminderForSchedule`（每个内部取消 22 个 id，885-894）+ 重新 `scheduleReminderForSchedule`。O(n×24) 次 await，量大时首帧后长时间串行。

### RC4「每 6-12s 成对触发」判定

- 触发源：`AppLifecycleListener(onResume: _onAppResume)`（home_page.dart:119）。每次 resumed → `_debounceLoadTasks`（500ms，146-159）+ `_rescheduleTaskReminders`（2s 节流，233-238）。
- **无应用内 Timer.periodic 制造周期**；周期来自 Windows 生命周期反复 resumed：restore 的 setAlwaysOnTop(true/false) 切换、便签窗（第二引擎）抢/还焦点、窗口 focus 抖动都会再次触发 onResume → 成对重载。节流仅 2s，挡不住 6-12s 周期。
- 每次成对触发 → HomeContent `_loadData` 全量重查 + 484 overlay 重建 + 全量 reschedule → 表现"点进模块卡/无反应/又卡又慢"。

---

## 窗口「点两下才展示」（第 5 条排查路径）

- 冷启动：main.dart 自 `_initWindowManager` 至 runApp 均无 `windowManager.hide()`；但 **runApp 后无显式 `show()+focus()`**。Windows 前台锁使自启/快捷方式启动的窗口被拒前台权 → 白窗存在但无焦点，第一次点击聚焦，内容出现需第二次点击/等待。
- 单实例 restore 路径：第二实例握手 → 首实例 `onActivate` → `restoreFullWindow`（main.dart:85-89）。注意 onActivate 回调可能在首实例 **runApp 之前**（main.dart 第 87 行早于 111 行）触发，此时窗口未就绪，restore 的 show/focus 可能静默失败；且 `restoreFullWindow` 在 `_isTransitioning` 时早退（controller:157）。
- P0-2 的 setAlwaysOnTop 前后切换只存在于 `restoreFullWindow`（托盘恢复），**冷启动不执行** → 冷启动无置前台兜底。

---

## Q3：最小改动集

按性价比排序（全部只读建议，未实施）：

1. **Supabase.initialize 移出 runApp 关键路径 + 加超时**（main.dart:96-106）：包 `timeout(1.5s)`；或改为不 await，runApp 先走本地 auth（LocalAuthenticated 已支持），AuthBloc 内懒初始化。直接消灭"打开等很久"的白窗期。
2. **`_loadData` 三查询 Future.wait 并行**（home_page.dart:899-912）：projects/groups/tasks 同时发。
3. **延迟非首页构建**：`_buildPages`（177-214）/IndexedStack（554-560）改为仅首帧构建首页，其余 tab 首次切换时懒构建（或非首页包 DeferredWidget）。削减首帧 5 页全构建。
4. **周期刷新节流**：`_onAppResume`（131-143）加最小间隔（如 ≥30s 才重载），或仅 hidden→visible 真切换时触发；`_rescheduleTaskReminders` 节流 2s→更严格。断掉 6-12s 成对重载。
5. **首帧轻量化**：时间轴 overlay（3784）仅渲染视口内任务/懒构建；至少首帧不渲染 484 个 overlay。
6. **补未守卫网络**：task_bloc.dart:342 用 `DataBackendConfig.current == DataBackend.cloud` 守卫 + 加 timeout（当前唯一加载路径残留网络）。
7. **reschedule 降量**：notification_service_io.dart:944-978 批量取消旧 timer，不做逐 id await；无 reminderEnabled 变更时跳过。
8. **冷启动置前台**：runApp 后 postFrame 显式 `windowManager.show()+focus()`；`onActivate` 改为等首帧后再 restore。

---

## Caveats / Not Found

- 未能实机采样启动耗时（只读，无运行环境/日志新样本）；7.8s 为历史 flog 证据引用。
- 「6-12s 周期」触发源在源码内无 Timer.periodic 直接命中，判定为生命周期 resumed 反复触发 + 便签第二引擎焦点竞争，需实机 `--trace-startup`/lifecycle 日志确认精确频率。
- supabase/gotrue 结论基于 pub 缓存 2.12.4/2.20.0 源码实读；具体项目 Supabase 是否可达/会话是否过期需运行时确认。
- 未检查 Windows 构建产物（exe）首帧计时与字体/引擎初始化，桌面引擎冷启动本身亦有固定开销未计入。
