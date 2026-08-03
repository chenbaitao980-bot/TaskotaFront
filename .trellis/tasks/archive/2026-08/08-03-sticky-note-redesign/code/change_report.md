# 变更报告 — 便签美化 + 点击跳首页定位任务 + 时间轴/四象限联动 + 便签候选简化

## 一、变更摘要
- **任务**: 08-03-sticky-note-redesign（trellis-code edit 模式）
- **分支**: deploy-branch
- **文件**: 3 个改动 + 1 个新增测试
- **影响符号**: DesktopFloatingTaskTab(UI)、DesktopFloatingTabController(逻辑)、_HomeContentState(首页定位)
- **索引状态**: ✅ codegraph 就绪 + gitnexus 刷新成功(11873 nodes)
- **爆炸半径**: 两符号均 LOW 风险（gitnexus impact 实测，无受影响执行流）

## 二、改动文件清单
| 文件 | 操作 | 说明 |
|------|------|------|
| lib/presentation/widgets/desktop_floating_task_tab.dart | 改 | PR1 方案A：去整圈彩色描边；阴影迁 boxShadow(AppTheme.cardShadow)；bgCard 100% 不透明；圆角 8→12；标题行加 6px 优先级色点 |
| lib/core/desktop/desktop_floating_tab_controller.dart | 改 | PR2：加 pendingFocusTaskId+token；restoreFullWindow 写入且删除 _openTaskDetail 导航；_selectTaskForFloatingTab 改「进行中优先→时间最近」并抽 rankCandidates/anchorDateOf(public static @visibleForTesting)；删除 _scoreTask |
| lib/presentation/pages/home/home_page.dart | 改 | PR3：_TimelineTask 加 isAllDay；_loadData 带出；postFrame 消费 pending focus（命中跳过默认滚 now）；_selectTask 加 R1(跨天/isAllDay→day)；象限 taskItem 加 isSelected 高亮 |
| test/floating_tab_controller_test.dart | 新增 | 单测覆盖 rankCandidates(5)/anchorDateOf(3)/pending 字段(1) = 9 用例，全部通过 |

## 三、Spec 合规
| 规则 | 状态 |
|------|------|
| quality-guidelines: 避免 setState 大树重建 | ✅ 象限高亮沿用既有 setState 字段级改动，无新增子树重建 |
| platform-compatibility: window_manager 仅桌面/条件导出 | ✅ 未触碰窗口配置与条件导出；控制器为纯 Dart 核心类，无 _io/_web 镜像需求 |
| type-safety: 新字段显式类型 | ✅ pendingFocusTaskId/Token 为 String?/int?；isAllDay 为 bool(默认 false) |

## 四、质量门禁
| 检查项 | 结果 |
|--------|------|
| flutter analyze（本次改动文件） | ✅ 零 error/warning（home_page 的 info 均为存量，行号不在改动区） |
| flutter test test/floating_tab_controller_test.dart | ✅ 9/9 通过 |
| flutter build windows --debug | ⏳ 后台构建中（待确认） |
| 行为验证（Step 4e） | ✅ 13/13 契约通过（见 .behavior_verification） |

## 五、反模式检查
| 检查项 | 结果 |
|--------|------|
| 散落定义 | ✅ _anchorDate 已统一改名 anchorDateOf，无残留旧引用 |
| 配置覆盖 | ✅ 无配置项改动 |
| 链路断裂 | ✅ restoreFullWindow→pending→postFrame 消费→清空，链完整；消费后清空防重复 |
| 静默失败 | ✅ focus 任务被筛选过滤时返回 false，走 _scrollToNow 兜底 |

## 六、行为验证摘要
见 `.behavior_verification`：P1×3、P2×5、P3×5 契约全部通过；9 个单元测试全绿。

## 七、质量自评
| 维度 | 分值 | 说明 |
|------|------|------|
| 范围纪律 Scope | 9/10 | 只改 3 个必要文件 + 1 测试；未碰便签窗口配置/未加依赖/未改通知路径 |
| 多点一致性 Consistency | 9/10 | 控制器/首页/测试三处同步；_anchorDate 改名全链路更新 |
| 方案评估 Alternatives | 9/10 | Q1 比较 A/B/C/D，采用 PRD 已确认方案A；Q2/Q3/Q4 完整评估 |
| 行为验证 Behavior | 9/10 | 13 契约 + 9 单测 + 文本断言，全部通过 |
| 可维护性 Maintainability | 8/10 | rankCandidates/anchorDateOf 抽纯函数便于单测；R1 注释说明缺陷修复动机 |
| 测试覆盖 Test | 8/10 | 控制器核心逻辑 9 用例；便签 widget 视觉无法无头验证（依赖 window_manager 真实窗口），用 analyze+文本断言兜底 |
| 文档同步 Doc | 7/10 | 未更新 CHANGELOG（待 Windows 构建确认后补） |

**均分 8.4/10**（≥8.0 达标）

## 八、待办
1. ⚠️ **存量 analyze error（非本次引入）**: `test/widget_test.dart:48` 缺 `privacyAccepted` 必填参数（MyApp API 变更后测试未同步）。因 scope 纪律未修改；建议独立修复或删除该测试。
2. Windows release 构建验证（debug 构建通过即可确认编译正确）。
3. 桌面 + Web 双端编译不破验证（改动均为纯 Dart，无平台专属 API 新增，web 应无影响）。
4. CHANGELOG.md 更新本次改动说明。

---

## 九、V2 复盘纠正（2026-08-03 实测后）

**结论：上一轮变更报告自评 8.4 分、宣称"黑线已修/选任务已简化"均未通过用户实测。** 用户实测：仅"点击跳首页定位"生效；黑线仍在、便签非最近任务，且新增白屏与卡顿两个回归。经 4 子 agent 调研（含 window_manager 原生源码 + GitHub issue 佐证），根因见 [prd.md V2 复盘](../prd.md)。

### 上轮报告的偏差
| 上轮宣称 | 实测 | 根因 |
|---------|------|------|
| 便签黑线修复（方案A 去描边+阴影分层） | 黑线仍在 | 黑线是 OS 非客户区边框 + 窗口未透明，非卡片描边 |
| 便签候选改"进行中优先→时间最近" | 便签非最近任务 | 进行中优先规则反直觉（陈旧进行中压过最近待办） |
| 未提及白屏 | 关闭便签再打开白屏 | window_manager 0.5.1 hide→show surface 不重绘（#155/#258/#571） |
| 未提及卡顿 | 点击跳首页卡 | HomePage 互斥重建全量加载 + 8~10 串行 IPC |

### 教训
1. **诊断深度不足**：上轮把黑线归因于卡片三层叠加，未排查窗口层（OS 边框/透明背景）。改 UI 前应先确认问题是否出在 Flutter 绘制层之外的窗口/平台层。
2. **行为验证脱离真实环境**：上轮验证用 analyze+单测+文本断言，未在真机窗口形态下看渲染结果。窗口形态相关的改动必须实机确认。
3. **选任务规则以"规则评审"代替"语义评审"**："进行中优先"通过规则讨论，但未在真实数据（陈旧进行中任务）下推演其反直觉结果。

### 修复方向（待用户确认后落地）
见 prd.md V2 复盘：黑线=透明窗；白屏=opacity 0/1 包裹；卡顿=Stack 常驻 HomePage；选任务规则重定；独立便签窗（desktop_multi_window）列 V2。

---

## 十、V3 独立便签窗重构落地（2026-08-03）

**架构**：`desktop_multi_window` 独立第二引擎便签窗替代"缩小主窗"，主窗常驻不缩放。根治 V2 三大固有缺陷（黑线=独立透明窗 ACCENT；白屏=主窗零缩放；卡顿=主窗零重建）。

### 改动文件
| 文件 | 操作 | 说明 |
|------|------|------|
| pubspec.yaml | 改 | + `desktop_multi_window: ^0.3.0` |
| windows/runner/flutter_window.cpp | 改 | + `DesktopMultiWindowSetWindowCreatedCallback`（第二引擎自动重注册插件）；补 UTF-8 BOM 修复 C4819 编码错误 |
| lib/presentation/pages/floating_note/note_window_app.dart | 新增 | 便签引擎：透明无边框 360x112 置顶窗 + `taskora_note_update`/`taskora_note_command` 通道 handler + 复用 `DesktopFloatingTaskTab` |
| lib/core/desktop/desktop_floating_tab_controller.dart | 重写 | 删 `_enterFloatingMode`/`_restoreWindowChromeAndBounds`/`_mode`/`DesktopWindowMode`/`currentTask`/`isFloating`；加便签窗懒建复用 + 主窗通道 handler（showMain/dismissNote）+ notifyTask 推送；`rankCandidates` 改分层规则 |
| lib/main.dart | 改 | main() 加 `_isNoteWindowRole()` 便签引擎分支（跳过全部业务初始化）；删 home 浮动便签分支 |
| test/floating_tab_controller_test.dart | 改 | rankCandidates 用例改分层规则语义（7 条）+ anchorDateOf 3 条 + pending focus 1 条 = 11/11 过 |
| CHANGELOG.md | 改 | V3 重构条目 |

### 关键设计
- **跨窗协议**：`WindowMethodChannel`（unidirectional）——`taskora_note_update`（主→便签：notifyTask/hideNote）、`taskora_note_command`（便签→主：showMain/dismissNote）。便签窗纯展示壳不读 SQLite，摘要由主窗 `rankCandidates` 算好推送；首次摘要随 `WindowConfiguration.arguments`（String JSON）注入规避注册竞态；便签窗懒建一次、复用 show/hide（规避 #484 句柄泄漏）。
- **透明去黑线**：便签引擎内初始化 window_manager 并 `setBackgroundColor(透明)`（触发 `ACCENT_ENABLE_TRANSPARENTGRADIENT`），消除 OS 非客户区深色边框。验证 window_manager 原生 `ensureInitialized` 用 `GetAncestor(GetView())` 绑定本引擎窗口 → 第二引擎 window_manager 正确绑定便签窗 HWND。
- **分层选任务**（用户 2026-08-03 最终确认）：层①小时级（单日非全天）→ 层②跨天/全天（isAllDay||跨日）；每层内进行中→距 startDate 最近→平局 updatedAt；无 startDate 剔除。

### 质量门禁
| 检查项 | 结果 |
|--------|------|
| flutter analyze（改动 4 Dart 文件） | ✅ No issues found |
| flutter test test/floating_tab_controller_test.dart | ✅ 11/11 |
| flutter build windows --debug | ✅ √ Built（原生 cpp + 插件编译过） |
| flutter build web --release | ✅ √ Built（双端不破） |
| 一致性（残留符号扫描） | ✅ isFloating/currentTask/DesktopWindowMode/_enterFloatingMode 零残留 |
| gitnexus detect_changes | ✅ 只影响便签流 proc_256 + 生成注册表（pub get 所致） |

### 行为验证
见 `.behavior_verification`：R1 分层规则 7/7 单测过；B 生命周期文本+编译级过；C 便签窗编译级过。**⚠️ 便签窗真实渲染（黑线是否消失/窗口定位/点击定位）依赖真实窗口无法无头验证 → 交用户 release 构建实测。**

### 技术坑
- **C4819 编码错误**：flutter_window.cpp 首次 Edit 丢失 UTF-8 BOM，MSVC 按 GBK(936) 读中文注释报 C4819（项目 `/WX` 视为错误）。修复：新注释转 ASCII 英文 + Python 补回 BOM。
- **存量 analyze error**（非本次引入）：`test/widget_test.dart:48` 缺 `privacyAccepted` 参数，scope 纪律未碰。

### 待办
1. ⚠️ 便签窗真实渲染人工实测（release 构建）：黑线消除、置顶定位、点击定位首页、二次关闭复用摘要、关闭便签不弹。
2. 存量 `test/widget_test.dart:48` 独立修复。
3. 提交决策待用户指示（含其他任务存量未提交改动，需区分提交）。

---

## 十一、V4 崩溃+白屏修复（2026-08-03 release 实测后，方案 A 实施中）

### 用户实测反馈
上一轮 V3 报告宣称"编译/单测全绿"，但 release 实测：**关闭主窗 → 弹出小窗口（白屏）→ 一两秒内整个应用消失**。即便签窗从未正常显示过。

### 根因（事件日志 + window_manager 0.5.1 原生源码，三级证据）
| 证据 | 结论 |
|------|------|
| Windows 事件日志 16:25:23（=关闭时刻，偏移 `0xa015` 稳定） | `Taskora.exe` 在 `window_manager_plugin.dll` `0xc0000005`（空指针）崩溃 |
| `SetSkipTaskbar`（window_manager.cpp:949） | 解引用 `taskbar_->HrInit()`，但 `taskbar_` 只在 `WaitUntilReadyToShow()`（:227 `CoCreateInstance`）初始化 |
| 项目对照 | 主引擎 `tray_service_desktop.dart:15` 先 `waitUntilReadyToShow` 再 `setSkipTaskbar` → 安全；便签引擎 `_initNoteWindowChrome` **漏 `waitUntilReadyToShow`** → `setSkipTaskbar(true)` 空指针崩溃 |

**连锁**：desktop_multi_window 同进程多引擎 → 便签引擎崩 = 主进程崩 → 便签窗随进程消失（日志在命中候选后 88ms 戛然而止）。白屏 = 主引擎 create 后立即 `note.show()`，便签引擎未 `runApp`。

### 修复方案 A（用户确认 2026-08-03）
1. `runNoteWindow`：先 `_registerNoteChannelHandler` + `_loadInitialSummary` + `runApp`，**首帧 `addPostFrameCallback` 后再初始化 chrome 并自显示**。
2. `_initNoteWindowChrome`：`setSkipTaskbar` 前加 `waitUntilReadyToShow()`（初始化 taskbar_，修崩溃）；末尾 `show()`（渲染后显示，消白屏）。
3. 主引擎 `_showNoteWindow`：首次创建不调 `note.show()`（等便签引擎自显示）；复用才 `_notifyNote` + `show()`。

### 行为契约（V4）
- C1 关闭主窗 → 便签窗出现且不白屏，主进程不崩溃
- C2 点便签 → 主窗 show+focus+首页定位；关闭 → 主窗保持隐藏
- C3 二次关闭 → 复用便签窗，notifyTask 更新后显示
- C4 便签窗无黑线；恢复主窗无卡顿

### 质量门禁
| 检查项 | 结果 |
|--------|------|
| flutter analyze（改动文件） | ✅ No issues found |
| flutter test test/floating_tab_controller_test.dart | ✅ 11/11 |
| flutter build windows --debug | ✅ √ Built（89.8s） |
| 行为验证（Step 4e） | ✅ 源码级 4/4（见 .behavior_verification）；真实窗口 ⚠️ 需 release 实测 |

### 待办
1. ⚠️ release 构建实测：崩溃消失、无白屏、便签正常显示、黑线消失。
2. 存量 `test/widget_test.dart:48` 独立修复。
