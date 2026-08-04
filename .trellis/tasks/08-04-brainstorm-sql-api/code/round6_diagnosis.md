# 第六轮诊断报告：三窗口症状（任务栏退出慢 / 便签消失 / 启动重影）

> 类型：根因诊断 + 修复方案（docs-first，**本轮不写代码**，待用户确认后实施）。
> 调研方式：3 个并行子 agent（各自 codegraph/gitnexus 全链路 + 原生源码比对）+ 主 agent 逐条代码级复核。
> 层级归属：三个症状均为 **L4 窗口生命周期/时序/原生渲染类**——**未实机验证不得宣称修复**（记忆铁律 performance-l4-gate-profile-first）。

---

## 症状与调研结论总览

| # | 症状（用户实测） | 主根因（代码证据） | 证据强度 | 修复层 |
|---|---|---|---|---|
| 1 | 任务栏右键"退出"要等很久，非实时 | `await windowManager.destroy(); exit(0)` 竞态死代码 → 退出靠引擎 teardown 兜底 | 代码实证（强） | Dart tray |
| 2 | 关闭主窗→点便签→再关主窗→便签消失；任务栏"显示"无此 bug | 便签窗被真正销毁 / `_isTransitioning` 竞态，`note.show()` 静默失败 | 代码实证（强/中） | Dart + desktop_multi_window |
| 3 | 打开很快，但一刹那重影 | 首帧即最大化 + 无背景刷 + restoreFullWindow z 序连爆 | 代码实证（强） | C++ runner + Dart |

---

## 症状 1：任务栏右键"退出"慢

### 退出链路（代码实证）
```
托盘菜单"退出" tray_service_desktop.dart:39-42
  → await windowManager.destroy()          // 发 PostQuitMessage（window_manager.cpp:232-234）
  → exit(0)                                 // ← 死代码（见 H1）
  → 主循环 GetMessage 收 WM_QUIT → FALSE   // main.cpp:48-51 → main() return → 引擎 teardown
```

### 根因
- **H1（主，代码实证）`exit(0)` 是竞态死代码**：`await windowManager.destroy()` 的 Future 在 `PostQuitMessage` 抢跑后**大概率永不完成** → `exit(0)` 永不执行 → 进程退出完全依赖「GetMessage 收到 WM_QUIT → main() return → FlutterWindow 析构 → 引擎 shutdown」。若 WM_QUIT 被嵌套循环（system_tray 的 TrackPopupMenu 模态循环）吞掉/延迟，应用挂住 → 观感"等很久才退出"。位置：`lib/platform/tray_service_desktop.dart:40-41`。
- **H2（次，推断）菜单点击投递延迟**：system_tray 0.1.1 菜单点击经 MethodChannel 异步投递（`system_tray_plugin.cpp:438` WM_COMMAND→channel invoke）到主 isolate；启动后主 isolate 重负载（第五轮已大幅降低）时 onClicked 排队。
- **H4（需实机确认）用户可能点的是"关闭窗口"而非"退出"**：`main.cpp:45 window.SetQuitOnClose(false)` + `flutter_window.cpp:75-78` WM_CLOSE→`ShowWindow(SW_HIDE)` → **X 关闭 / 任务栏"关闭"根本不退出，只隐藏到托盘**。任务栏图标右键系统菜单无"退出"项，只有托盘（通知区域）菜单有。

### 修复方向
| # | 方案 | 说明 | 风险 |
|---|---|---|---|
| R1-1 | `onClicked` 改 `try { await windowManager.destroy().timeout(1s); } catch(_){} exit(0);` | destroy 有 1s 上限不阻塞，同时保留尽力优雅关闭（flush WAL/日志），随后强制 `exit(0)` 保证立即退出 | LOW；drift 已 WAL+NORMAL，强退可恢复 |
| R1-2 | 退出路径加时间戳 flog（onClicked 首行 + exit 前） | 量化「点击→onClicked 执行」「onClicked→进程退出」两段延迟，定位剩余慢因 | LOW |
| R1-3 | 实机确认用户点的入口（托盘"退出" vs 任务栏"关闭"） | 若误用"关闭"，属 H4 预期行为（隐藏到托盘），需在 UI 层加"退出"入口或提示 | 产品决策 |

---

## 症状 2：关闭主窗→点便签→再关主窗→便签消失

### 三条路径链路（代码实证）
```
路径1 关闭主窗(X)：flutter_window.cpp:75-78 WM_CLOSE→SW_HIDE + window_manager 发"close"
  → window_manager_bridge_desktop.dart:47 onWindowClose（fire-and-forget 不 await:50）
  → handleCloseRequested(desktop_floating_tab_controller.dart:113-153)
      闸门 _isTransitioning/_canShowFloatingTab/_dismissedUntilRestore(:114-132)
      → _selectTaskForFloatingTab(:134) → _showNoteWindow(:148) → hideToTray(:149)
      置 _isTransitioning=true(:146)，finally 清(:151)

路径2 点便签：note_window_app.dart:158-166 _openMainWindow
  → 便签引擎先自隐(:160-162) → showMain 通道 → 主窗 handler(controller:261-266)
  → restoreFullWindow(openTaskId)(:156-181)
      ★ if (!isWindows || _isTransitioning) return;(:157)  ← 竞态早退
      → _hideNoteWindow(:163) → show+setAlwaysOnTop+focus → notifyListeners(:180)

路径3 任务栏"显示"：tray_service_desktop.dart:31-34 → restoreFullWindow()（无 openTaskId）
```

### 根因（按证据强度）
- **H1（强代码证据）便签窗被真正销毁，复用 `note.show()` 静默失败**：
  - note HWND 收 WM_DESTROY → `FlutterWindow::OnDestroy`→`RemoveManagedFlutterWindowLater`（flutter_window.cc:43）→ `CleanupRemovedWindows` 析构引擎（multi_window_manager.cc:160）→ `DesktopMultiWindowPlugin` 析构→`RemoveWindow` 移出 registry（desktop_multi_window_plugin.cpp:52）→ 下次 `GetWindow` 返回 null → `note.show()` 抛 PlatformException（multi_window_manager.cc:111），被 `_showNoteWindow` **catch 只记日志**（`desktop_floating_tab_controller.dart:227-230`）。
  - **关键缺口**：note 窗口 `setPreventClose(true)` 在 `_initNoteWindowChrome` 末尾（`note_window_app.dart:114`），即**首帧渲染完成后才设置**；创建（`WindowController.create`）到首帧之间为**无保护窗口期**，此期间 WM_CLOSE/销毁请求可直接击穿。
- **H2（中，代码结构缺陷）竞态**：`onWindowClose` 不 await（`window_manager_bridge_desktop.dart:50`）+ `restoreFullWindow` 遇 `_isTransitioning` 直接 return（`desktop_floating_tab_controller.dart:157`）。首次关闭 create 路径期间（`_isTransitioning=true`、note 未渲染完、主窗未隐）用户点便签 → `showMain`→`restoreFullWindow` 早退 → **主窗未恢复 + 便签已自隐 → 双双消失**；且 `_dismissedUntilRestore` 未被清（:162 在 :157 return 之后）。
- **H3（弱）点便签 restore 改变任务状态 → 二次关闭无候选**：`_selectTaskForFloatingTab` 无候选时走 `hideToTray`（:135-138）不弹便签。

### 修复方向
| # | 方案 | 说明 | 风险 |
|---|---|---|---|
| R2-1（主） | note 引擎**创建即保护**：`runNoteWindow` 首行（runApp 前）即 `setPreventClose(true)`，并注册 note 的 `WindowListener.onWindowClose` 兜底"只隐藏不销毁" | 消除"创建→首帧"无保护窗口期，从根上阻止 WM_CLOSE 销毁 note 引擎 | LOW |
| R2-2 | `onWindowClose` 改 `await`；`restoreFullWindow` 的 `_isTransitioning` 早退改为"主窗照常 show，仅跳过 note 交互" | 消除 H2 竞态：便签已自隐时主窗必恢复，且清 `_dismissedUntilRestore` | LOW |
| R2-3 | `_ensureNoteWindow` 记录 windowId；`_showNoteWindow/_hideNoteWindow` 前后 flog windowId；`note.show()` 失败日志含异常 code | 实机定位：日志出现"failed to find target window"⇒ 证实 H1（已销毁） | LOW |
| R2-4 | `_selectTaskForFloatingTab` 无候选时复用上次 summary 仍弹便签 | H3 兜底，避免"便签无故消失" | LOW |

---

## 症状 3：启动一刹那重影

### 启动时序（代码实证）
```
main() 同步初始化(main.dart:57)
  └─ async gap①: 便签角色检测(72) → _initWindowManager(78) → 单实例socket(85)
     → Future.wait[主题/隐私/Supabase≤2s](99-103) → _initServices(106)
  └─ runApp(108) → 首帧渲染
  └─ 原生：首帧回调→Show()→ShowWindow(SW_MAXIMIZE)   ← win32_window.cpp:152-154 / flutter_window.cpp:40-42
  └─ postFrame(121): restoreFullWindow(125)+initTray(126)
     = show→setAlwaysOnTop(true)→(false)→focus()（4 次 SetWindowPos z 序）
```

### 根因（按证据强度）
- **A（高）首次可见即最大化 + 无背景刷**：窗口创建 rect(10,10,1280×860)（main.cpp:40-41）；首帧渲染完成回调 `Show()` = **`ShowWindow(SW_MAXIMIZE)`**（win32_window.cpp:152-154 / flutter_window.cpp:40-42）；窗口类 **`hbrBackground = 0`（无背景画刷）**（win32_window.cpp:100）。DWM 最大化缩放动画（1280×860→全屏）期间 Flutter 子 surface 滞后，未铺满区域露出陈旧/黑色像素 = 拖影/残影。
- **B（高）restoreFullWindow z 序连爆**：postFrame 紧贴首帧执行 `show→setAlwaysOnTop(true)→(false)→focus`（desktop_floating_tab_controller.dart:165-176）共 4 次 SetWindowPos 改 z 序 → DWM 重合成闪烁/残影。
- **C（中）C++ 单实例唤醒路径**：`main.cpp:13-18` 第二实例对隐藏主窗 `SW_MAXIMIZE` + `SetForegroundWindow` 后立即 exit（最大化跳变+残影）；且此路径先于 Dart `SingleInstance` 执行（`single_instance.dart` 实际失效——C++ mutex 先挡）。
- **D（低，已排除）透明/LAYERED 残留**：lib 主窗路径无 setOpacity/setBackgroundColor；透明背景仅 note 引擎（note_window_app.dart:99）；主窗 Theme 背景不透明。
- **E（低，已排除）双引擎重叠**：note 窗仅 `handleCloseRequested` 懒建（desktop_floating_tab_controller.dart:197-214）+`hiddenAtLaunch`，启动不创建。

### 修复方向
| # | 方案 | 说明 | 风险 |
|---|---|---|---|
| R3-1 | 启动窗口不以最大化显示：`win32_window.cpp:152-154` Show 改 `SW_SHOW`（正常尺寸），或保留最大化但**给窗口加背景画刷**（win32_window.cpp:100 `hbrBackground` 设主题底色） | 前者消除 DWM 缩放动画（但改变启动窗口尺寸=产品决策，需用户确认）；后者最小改动消除未铺满残影 | 需确认产品预期 |
| R3-2 | `restoreFullWindow` 前台已就绪时跳过 TOPMOST 切换（仅 `SetForegroundWindow` 静默失败才用），或 TOPMOST 双切延迟 ~250ms | 消除 z 序连爆闪烁；冷启动仍保可靠置前台（第五轮 P1-B 能力不回归） | LOW |
| R3-3 | C++ 单实例唤醒改 `SW_SHOW` + 移除强制置前，恢复统一走 Dart 握手 `restoreFullWindow` | 消除第二实例最大化跳变；同时让 Dart 侧单实例逻辑真正生效 | LOW（改 main.cpp） |

---

## find-skills 评估（本轮是否引入新技能）

- 候选：`spjoshis/claude-code-plugins@flutter-performance`（14 installs，来源未知）。
- **结论：不安装。** 理由：① 三症状均为 **Flutter Windows 原生窗口层（L4）**（窗口生命周期/原生 runner/启动渲染），通用 Flutter 性能技能（面向 widget 重建/布局优化）不覆盖此层，证据价值低；② 该技能 installs 仅 14（按 find-skills 质量标准 <100 需谨慎）、来源不权威。
- 复用：已装 `flutter-dart-code-review` 技能用于本轮改动后的代码审查；本任务继续沿用 trellis-code 工作流（L4 门禁 + profile-first + 根因集归并）。

---

## 方案评估（trellis-code Phase 2 Q1/Q2/Q3/Q4）

### Q1 替代方案对比
| 症状 | 方案 A | 方案 B | 结论 |
|---|---|---|---|
| 1 退出 | **A：`destroy().timeout(1s)` + `exit(0)`**（保留优雅窗口销毁上限 1s） | B：纯 `exit(0)`（最简，跳过 destroy） | 选 A：保 WAL flush + 确定退出 |
| 2 便签 | **A：note 创建即 `setPreventClose(true)` + onWindowClose 兜底只隐藏**（治 H1 根） | B：仅改竞态 await + 防抖（治 H2 但 H1 未覆盖） | 选 A 为主，A+B 同做：H1 根因 + H2 时序双保险 |
| 3 重影 | **A：加背景画刷**（最小改动治残影） | B：Show 改 SW_SHOW + TOPMOST 延迟（改启动体验） | 先实机录屏区分 A/B/C 再定；保守先做 R3-2（z 序），A/C 待实机证据 |

### Q2 连锁影响分析
- 代码：`tray_service_desktop.dart`、`desktop_floating_tab_controller.dart`、`note_window_app.dart`、`window_manager_bridge_desktop.dart`、`windows/runner/main.cpp`、`windows/runner/win32_window.cpp`
- 测试：`test/floating_tab_controller_test.dart`（便签候选/定位相关）、`test/single_instance_test.dart`（若动 C++ 单实例）
- 配置/文档：`CHANGELOG.md`、`prd.md`、本诊断文档
- 类型定义：无

### Q3 验证策略 + 行为契约（**未实机不宣称修复**）
| 契约 | 输入 | 预期输出 | 层级 |
|---|---|---|---|
| 契约 A (R1-1) | 托盘点"退出" | 进程 ≤1.5s 内退出（destroy 超时 1s + exit 立即） | L4 需实机计时 |
| 契约 B (R2-1) | note 窗口任意阶段收 WM_CLOSE | 只隐藏不销毁（`setPreventClose` 提前生效） | L4 需实机 |
| 契约 C (R2-2) | `_isTransitioning=true` 时 showMain | 主窗照常 show + 清 `_dismissedUntilRestore` | L2 单测 + L4 |
| 契约 D (R3-2) | 窗口已在前台时 restoreFullWindow | 不触发 setAlwaysOnTop 双切 | L2 单测（结构）+ L4 |
| 契约 E (R3-3) | 第二实例启动 | 首实例 `SW_SHOW` 非最大化唤醒 | L4 需实机 |

### Q4 可维护性/可测试性
- 全部改动为**最小 diff**（每处 ≤10 行），不改变公共签名；R3-1/R3-3 涉及 C++ runner（可测试性受限，靠实机）；R1/R2 纯 Dart 可加单测。
- 注释按"为什么"标准（保留各修复点的设计权衡注释，如 H1 竞态说明）。

---

## L4 实机验证（阻塞待办，重建后逐条实测；用户显式确认才转 ✅）

1. **退出**：加 flog 后量化「点击→onClicked」「onClicked→进程退出」两段延迟；确认用户点的是**托盘"退出"**还是**任务栏"关闭"**（后者=隐藏到托盘，H4）。
2. **便签消失**：按步骤复现（关主窗→点便签→再关主窗），读 `Documents/logs/task_*.log`：是否出现「便签窗 show 失败: {异常}」（异常含 `failed to find target window` ⇒ 证实 H1 已销毁）；或「无候选→hideToTray」（⇒ H3）。
3. **重影**：录屏慢放"打开一刹那"，区分 A（全屏缩放残影）/ B（z 序闪烁跳位）/ C（仅"打开已驻留实例"出现）。建议在 restoreFullWindow 各步骤加时间戳日志，确认 z 序连爆与可见帧先后。

## 待办
- [ ] 用户确认修复方案（R1-1/2/3、R2-1~4、R3-1/2/3 范围）
- [ ] 编码（trellis-code 流程：impact → 改 → 契约 → 门禁）
- [ ] L4 实机验证三项（退出延迟 / 便签消失复现 / 重影录屏）
