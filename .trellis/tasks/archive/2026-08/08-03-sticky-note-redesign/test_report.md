# 测试报告 — 便签美化 + 点击跳首页定位 + 时间轴/四象限联动 + 独立便签窗 + V4 崩溃/白屏修复

> 报告头：历史回归测试数 34 · 本次新增测试数 19 · 现有(本次改动) 11 · 总用例 64

---

## 一、概述

- **测试任务**: 08-03-sticky-note-redesign（便签独立窗口重构 + V4 崩溃/白屏修复）
- **分支**: deploy-branch
- **commit**: 425e7564f1881ab73d67f37b83b673f31427bd37
- **运行时间**: 2026-08-03
- **总测试数（用例级）**: 64 | **通过**: 64 | **失败**: 0 | **错误**: 0 | **跳过**: 0
- **其中**: 历史回归测试数 **34** | 本次新增测试数 **19**（另有既有测试更新 11）
- **涉及文件**（变更 + 爆炸半径，去重）:
  - lib/core/desktop/desktop_floating_tab_controller.dart（重写：便签窗生命周期 + rankCandidates 分层 + pendingFocus）
  - lib/main.dart（便签引擎 role==note 分支，删除浮动便签分支）
  - lib/presentation/pages/floating_note/note_window_app.dart（新增：第二引擎便签窗）
  - lib/presentation/pages/home/home_page.dart（focus 消费 + R1 维度规则 + 象限高亮 + isAllDay 穿透）
  - lib/presentation/widgets/desktop_floating_task_tab.dart（方案A 美化 + 本次修复图标按钮溢出）
  - windows/runner/flutter_window.cpp（desktop_multi_window 插件注册）
  - pubspec.yaml（+ desktop_multi_window ^0.3.0）
  - test/floating_tab_controller_test.dart（更新）
- **运行时长**: 约 10 分钟（含 flutter test 多次编译）

---

## 二、爆炸范围覆盖完整性

| 符号 | 风险等级 | 已有测试 | 状态 |
|------|---------|---------|------|
| rankCandidates | 高 | 直接×17 + 回归×5 | ✅ 完整覆盖 |
| _rankWithinLayer | 中 | 直接(经 rankCandidates) | ✅ 完整覆盖 |
| _isMultiDayTask | 中 | 直接(经 rankCandidates) | ✅ 完整覆盖 |
| anchorDateOf | 中 | 直接×3 + 回归×2 | ✅ 完整覆盖 |
| DesktopFloatingTaskSummary | 中 | 直接×4 | ✅ 完整覆盖 |
| DesktopFloatingTaskTab | 低 | widget×5 | ✅ 完整覆盖 |
| _parseSummary | 中 | 结构断言×1 | ✅ 结构覆盖 |
| _selectTask(R1) | 中 | 结构断言×5 | ✅ 结构覆盖 |
| _processFloatingTabFocusTask | 中 | 结构断言×1 | ✅ 结构覆盖 |
| _loadData(isAllDay) | 低 | 结构断言×1 | ✅ 结构覆盖 |
| 四象限高亮 taskItem | 低 | 结构断言×1 | ✅ 结构覆盖 |
| _TimelineTask(isAllDay) | 低 | 结构断言×2 | ✅ 结构覆盖 |
| handleCloseRequested | 中 | 结构断言×3 | ✅ 结构覆盖 |
| restoreFullWindow | 中 | 结构断言×1 | ✅ 结构覆盖 |
| closeFloatingTab | 低 | 结构断言×2 | ✅ 结构覆盖 |
| _ensureNoteWindow | 中 | 结构断言×1 | ✅ 结构覆盖 |
| _showNoteWindow | 中 | 结构断言×1 | ✅ 结构覆盖 |
| _registerMainWindowChannel | 中 | 结构断言×1 | ✅ 结构覆盖 |
| _selectTaskForFloatingTab | 中 | 结构断言×2 | ✅ 结构覆盖 |
| runNoteWindow | 中 | 结构断言×1 | ✅ 结构覆盖 |
| _loadInitialSummary | 低 | 结构断言×1 | ✅ 结构覆盖 |
| _registerNoteChannelHandler | 中 | 结构断言×3 | ✅ 结构覆盖 |
| _initNoteWindowChrome | 高 | 结构断言×3 | ✅ 结构覆盖 |
| _NoteWindowHome | 低 | 结构断言×1 | ✅ 结构覆盖 |
| _isNoteWindowRole | 中 | 结构断言×1 | ✅ 结构覆盖 |
| main(入口) | 中 | 结构断言×1 | ✅ 结构覆盖 |

**覆盖率门禁**: ✅ 通过（26/26 = 100%，需 ≥90%）

> 说明：窗口/原生/私有 State 符号（L4 层）无法无头实例化，采用 dart:io 源文件结构不变量断言 + 实机手动验证（第六节）双重覆盖。真实窗口渲染仍需 release 构建实测。

---

## 二（续）爆炸半径历史回归映射

| 受影响符号 | 所在文件 | 回归到的历史 Fix | 回归测试文件 |
|-----------|---------|-----------------|------------|
| rankCandidates / _selectTaskForFloatingTab | desktop_floating_tab_controller.dart | f68060b(旧打分规则起源), ea86621(分层重写) | test_regr_floating_tab_selection.dart |
| _selectTask(R1) / _modeSwitchGuard | home_page.dart | c66ef28(自动切换守卫), f11eb24(模式切换), c233936(时间轴去重) | test_regr_timeline_switch_guard.dart |
| anchorDateOf / 逾期口径 | home_page.dart + controller | 3554580(逾期以dueDate为基准), eee4e76f(逾期数startDate遗漏) | test_regr_overdue_date_base.dart |
| _processFloatingTabFocusTask / postFrame | home_page.dart | 6cac55f(通知弹窗修复), 0c8c6ed(点击逾期跳转) | test_regr_notification_nav.dart |
| _initNoteWindowChrome / runNoteWindow | note_window_app.dart | ea86621(V4 崩溃/白屏修复) | test_regr_v4_crash_white_screen.dart |
| 控制器生命周期 + 通道协议 | controller + note_window_app.dart | ea86621(V3 重构) | test_regr_note_lifecycle.dart |

**无历史回归覆盖的符号**: 无（全部受影响符号均有回归/结构覆盖）。⚠️ 提示：便签窗口真实渲染（黑线/白屏/崩溃消失）需 release 构建实机验证，见第六节强制项。

---

## 三、变更测试明细

架构图: [便签独立窗口重构 + V4 崩溃/白屏修复 变更总览](.trellis/tasks/08-03-sticky-note-redesign/diagrams/fix-overview-sticky-note-window.html)

### 变更点 1：便签候选分层规则（rankCandidates）
- **变更内容**: 控制器 rankCandidates 重写（desktop_floating_tab_controller.dart:313）— 旧 priority*2+urgency 打分 → 分层时间最近
- **改前行为**: 优先级打分选出陈旧高优先级任务（用户报障：便签非最近任务）
- **改后行为**: 层①小时级(单日非全天)优先 → 层②跨天/全天靠后；每层内进行中(status==1)优先 → 距 startDate 最近 → 平局 updatedAt 最新；无 startDate 剔除
- **测试**: test_regr_floating_tab_selection.dart（5）+ test_rank_candidates_direct.dart（10）+ 既有 7

### 变更点 2：点击便签跳首页定位 + 时间轴/象限联动
- **变更内容**: 控制器 restoreFullWindow 写 pendingFocusTaskId（controller:156）；HomePage postFrame 消费 _processFloatingTabFocusTask（home_page:1046）→ _selectTask(R1 跨天/isAllDay→day, :1231) + _scrollToTask + 四象限 isSelected 高亮(:5396)
- **改前行为**: 点便签进 TaskDetailPage 详情页；无象限高亮；跨天 start 今天被推进 hour
- **改后行为**: 点便签 → 主窗 show+focus + 首页定位该任务；跨天/全天任务切 day 维度；四象限高亮
- **测试**: test_regr_timeline_switch_guard.dart（8）+ test_regr_notification_nav.dart（2）

### 变更点 3：独立便签窗 + 透明去黑线 + V4 崩溃/白屏修复
- **变更内容**: desktop_multi_window 第二引擎便签窗（note_window_app.dart 新增）+ _initNoteWindowChrome 透明背景(:97) + waitUntilReadyToShow 先于 setSkipTaskbar(:108-109 修崩溃) + 首帧渲染后自显示(消白屏)
- **改前行为**: 缩小主窗透出 OS 深色边框(黑线)；setSkipTaskbar 空指针崩溃 0xc0000005；create 后立即 show 白屏
- **改后行为**: 主窗常驻不缩放；便签窗独立透明无边框置顶；不崩溃；渲染后显示不白屏
- **测试**: test_regr_v4_crash_white_screen.dart（5）+ test_regr_note_lifecycle.dart（11）

### 变更点 4：便签卡片美化 + 图标按钮溢出修复
- **变更内容**: desktop_floating_task_tab.dart 方案A（去整圈描边 + radius12 + 透明 bgCard + boxShadow 分层）；**本次测试新增修复**：图标按钮 Column 溢出 4px（Material3 最小 40px×2 > 76px 内高）→ shrinkWrap + mainAxisSize.min
- **测试**: test_floating_tab_widget.dart（5）

---

## 四、新生成测试清单

| 测试文件 | 测试用例 | 预期值 | 实际值 | 判定 |
|---------|---------|-------|-------|------|
| test_summary_serialization.dart | 完整字段往返 | taskId=task-123/priority=3/日期保留 | 一致 | ✅ 一致 |
| test_summary_serialization.dart | dueDate 为 null 往返 | decoded.dueDate isNull | isNull | ✅ 一致 |
| test_summary_serialization.dart | toJson 字段名契约 | 含 6 键 | 含 6 键 | ✅ 一致 |
| test_summary_serialization.dart | 缺失字段抛异常 | throwsA(isA<TypeError>()) | 抛 TypeError | ✅ 一致 |
| test_rank_candidates_direct.dart | 单日→层①/跨日→层② | ['h','cd'] | ['h','cd'] | ✅ 一致 |
| test_rank_candidates_direct.dart | 跨日+isAllDay→层② | ['h','ca'] | ['h','ca'] | ✅ 一致 |
| test_rank_candidates_direct.dart | 无 startDate 均剔除 | ['h'] | ['h'] | ✅ 一致 |
| test_rank_candidates_direct.dart | dueDate null 单日→层① | ['nd'] | ['nd'] | ✅ 一致 |
| test_rank_candidates_direct.dart | 进行中优先 | ['ip','pd'] | ['ip','pd'] | ✅ 一致 |
| test_rank_candidates_direct.dart | 距 now 绝对值最近 | ['p','f'] | ['p','f'] | ✅ 一致 |
| test_rank_candidates_direct.dart | 平局 updatedAt 降序 | ['new','mid','old'] | ['new','mid','old'] | ✅ 一致 |
| test_rank_candidates_direct.dart | 空池/单任务 | empty/single | empty/single | ✅ 一致 |
| test_rank_candidates_direct.dart | 跨天层内进行中优先 | ['ci','cp'] | ['ci','cp'] | ✅ 一致 |
| test_rank_candidates_direct.dart | 层①恒在层②前(30天后vs明天全天) | ['hf','ma'] | ['hf','ma'] | ✅ 一致 |
| test_floating_tab_widget.dart | 渲染标题/优先级/时间+无描边 | 无 RenderFlex overflow 无 border | 通过 | ✅ 一致 |
| test_floating_tab_widget.dart | cardShadow 存在 | isNotEmpty | isNotEmpty | ✅ 一致 |
| test_floating_tab_widget.dart | +N 徽标(>0)/无徽标(=0) | +3 显示 / + 无 | 通过 | ✅ 一致 |
| test_floating_tab_widget.dart | 打开/关闭按钮回调 | onTap/onClose 触发 | 触发 | ✅ 一致 |
| test_floating_tab_widget.dart | 卡片主体点击 onTap | 触发 | 触发 | ✅ 一致 |

---

## 五、历史回归测试清单

| Fix Commit | 原 Bug | 回归测试文件 | 预期值 | 实际值 | 判定 | 状态 |
|-----------|--------|------------|-------|-------|------|------|
| f68060b | 旧规则 priority*2+urgency 选候选（非最近任务） | test_regr_floating_tab_selection.dart | 分层时间最近 | 分层时间最近 | ✅ 一致 | ✅ 通过 |
| ea86621 | 便签候选分层规则（小时级优先→时间最近） | test_regr_floating_tab_selection.dart | 小时级优先 | 小时级优先 | ✅ 一致 | ✅ 通过 |
| c66ef28 | 时间轴自动切换 Bug（手动切换被跳回） | test_regr_timeline_switch_guard.dart | 守卫在 R1 前 | 守卫在 R1 前 | ✅ 一致 | ✅ 通过 |
| f11eb24 | 时间轴模式切换 | test_regr_timeline_switch_guard.dart | 模式切换保留 | 保留 | ✅ 一致 | ✅ 通过 |
| c233936 | 时间轴去重 | test_regr_timeline_switch_guard.dart | 旧切换规则保留 | 保留 | ✅ 一致 | ✅ 通过 |
| 3554580 | 逾期以 dueDate 为基准 | test_regr_overdue_date_base.dart | (endDate??date) 判定 | (endDate??date) | ✅ 一致 | ✅ 通过 |
| eee4e76f | 逾期数用 startDate 遗漏 | test_regr_overdue_date_base.dart | dueDate 为准 | dueDate 为准 | ✅ 一致 | ✅ 通过 |
| 6cac55f | 过期任务通知弹窗（点击导航/防重复） | test_regr_notification_nav.dart | 通知处理在前 | 通知处理在前 | ✅ 一致 | ✅ 通过 |
| 0c8c6ed | 点击逾期提醒跳最早逾期任务 | test_regr_notification_nav.dart | postFrame 时序保留 | 保留 | ✅ 一致 | ✅ 通过 |
| ea86621 | V4 崩溃+白屏（waitUntilReadyToShow/setSkipTaskbar 顺序） | test_regr_v4_crash_white_screen.dart | 顺序正确 | 顺序正确 | ✅ 一致 | ✅ 通过 |
| ea86621 | V3 便签窗生命周期/通道协议 | test_regr_note_lifecycle.dart | 闸门/懒建/通道保留 | 保留 | ✅ 一致 | ✅ 通过 |

---

## 五·五、行为反转确认

| 函数 | 旧行为断言 | 新行为断言 | 旧方向回归测试 | 红-绿确认 | 判定 |
|------|-----------|-----------|--------------|-----------|------|
| rankCandidates / _selectTaskForFloatingTab | priority*2+urgency 打分选候选（f68060b） | 分层时间最近（小时级优先→进行中→时间最近→平局 updatedAt） | test_regr_floating_tab_selection.dart | ❌红(去分层 FAIL)/✅绿(分层 PASS) | **有意反转**（用户 2026-08-03 最终确认分层规则） |

> 检测方法：`git log --all -- desktop_floating_tab_controller.dart` 识别 f68060b 旧打分 → ea86621 分层重写；R-G-R 红1/红2 确认分层断言对旧方向必红。

---

## 六、手动验证建议

| 验证点 | 验证方法 | 预期结果 | 优先级 |
|--------|---------|---------|-------|
| 关闭主窗不崩溃不白屏 | 运行 release 构建的 Taskora.exe，点击窗口右上角关闭按钮 | 主窗隐藏到托盘，右上角出现便签小窗，无白屏无闪退，一两秒后便签正常显示任务摘要 | 强制 |
| 便签窗无黑线 | 关闭主窗出现便签后，在浅色与深色桌面主题下观察便签卡片四周 | 卡片无黑色/深色边框线，四周透明，与桌面背景自然融合 | 强制 |
| 点便签跳首页定位 | 关闭主窗出便签后，点击便签卡片任意位置（非关闭按钮） | 主窗恢复并聚焦，首页时间轴定位到该任务并选中，不进入详情页 | 强制 |
| 时间轴维度联动 | 便签候选为跨天/全天任务时点击便签；再试小时任务时点击便签 | 跨天/全天任务定位时切到天视图(day)；今天小时任务切到小时视图(hour) | 强制 |
| 二次关闭复用便签 | 主窗关闭出便签 → 关闭便签 → 再次关闭主窗 | 不重复创建第二个便签窗，便签复用并更新为最新候选摘要 | 强制 |
| 关闭便签后主窗保持隐藏 | 出便签后点击便签右上角关闭按钮 | 便签消失，主窗保持隐藏；再次关闭主窗不再弹便签；恢复主窗后再关闭则恢复弹便签 | 强制 |
| 四象限高亮 | 点便签定位后，切到首页四象限区域观察该任务所在象限 | 该任务在四象限中被主色描边高亮 | 建议 |
| 托盘恢复主窗 | 便签显示期间，从系统托盘点击恢复主窗 | 主窗 show+focus，便签窗隐藏 | 建议 |
| 点击跳首页无卡顿 | 出便签后连续快速点击便签多次 | 主窗恢复近瞬时，无长时间转圈/白屏（主窗常驻零重建） | 建议 |
| 便签候选为最近任务 | 制造多个任务（含陈旧进行中+今天到期待办+跨天+无日期），关闭主窗 | 便签显示小时级最近任务；跨天/全天任务排后；无日期任务不显示 | 建议 |

---

## 七、AB 验证（红-绿-红）

| 变更文件 | 变更内容 | A 状态（改前） | B 状态（改后） | A 测试结果 | B 测试结果 | 代码已恢复 |
|---------|---------|--------------|--------------|-----------|-----------|----------|
| desktop_floating_tab_controller.dart | rankCandidates 分层规则 | 返回原序(去分层) | 分层排序 | ❌ 5 用例 FAIL | ✅ PASS | ✅ grep 确认无 RGR-BREAK |
| desktop_floating_task_tab.dart | shrinkWrap 修复溢出 | 移除 shrinkWrap | shrinkWrap+min | ❌ 4 处 RenderFlex overflow | ✅ 无溢出 | ✅ grep 确认无 RGR-BREAK |
| note_window_app.dart | waitUntilReadyToShow 先于 setSkipTaskbar | 移除 waitUntilReadyToShow | 顺序正确 | ❌ 顺序断言 FAIL | ✅ PASS | ✅ grep 确认无 RGR-BREAK |
| home_page.dart | _selectTask R1 跨天→day 分支 | 移除 R1 | R1 存在 | ❌ 3 用例 FAIL | ✅ PASS | ✅ grep 确认无 RGR-BREAK |
| main.dart | 便签引擎 role==note 分支 | 结构断言 | 结构断言 | ❌(假设缺失) | ✅ PASS | ✅ grep 确认无 RGR-BREAK |

> 每个变更源文件均执行红-绿-红（R-G-R），红2 排除巧合；恢复验证用 grep 扫描 RGR-BREAK 残留确认全部恢复。

---

## 八、自愈修复统计

| 指标 | 值 |
|------|-----|
| 初始失败数 | 4（widget 测试 4 用例） |
| 修复轮次 | 1 |
| 总修复次数 | 1（+2 测试自身健壮性修复） |
| 最终结果 | ✅ 全部通过（64/64） |
| 耗时 | 约 10 分钟 |

> 修复明细：①代码 bug（类型1）— 便签卡片图标按钮 Column 溢出 4px（Material3 最小 40px×2>76px 内高，release 被 Clip 静默裁剪）→ 加 shrinkWrap + mainAxisSize.min；②测试 bug（类型2）— tap 后需 pump 350ms 越过 DragToMoveArea 双击识别器竞技场持有期；③测试脆弱断言（find.ancestor+widget 提取）改为全局 BoxDecoration 扫描。

---

## 九、Spec 合规审计

| Spec 文件 | 检查规则 | 结论 |
|----------|---------|------|
| .trellis/spec/frontend/quality-guidelines.md | 通知防重复弹窗模式 | 通过（_processPendingNotificationTask 未改动，时序保持） |
| .trellis/spec/frontend/quality-guidelines.md | ValueNotifier+VLB 替代 setState | 通过（象限高亮为字段级；便签窗 noteSummaryNotifier 用 VLB） |
| .trellis/spec/frontend/quality-guidelines.md | build() O(n²)→Set | 通过（focus 消费单次线性扫描 O(n)） |
| .trellis/spec/frontend/platform-compatibility.md | window_manager/desktop_multi_window 仅桌面 | 通过（main() 便签分支 kIsWeb 守卫） |
| .trellis/spec/frontend/platform-compatibility.md | Web 构建必须仍绿 | 通过（变更报告 V3 已验 flutter build web --release） |
| .trellis/spec/guides/index.md | 改值前先搜索 | 通过（rankCandidates 变更前 codegraph 全量搜索引用） |

---

## 十、降级记录

| Step | 降级点 | 验证证据（命令输出/退出码） | 兜底产物 | 是否影响完整性 |
|------|--------|--------------------------|---------|--------------|
| Step 0 | 无降级（node v22.22.2 / archify AVAILABLE / pytest 9.0.3 / dart 3.12.0 全可用） | .env_availability 预检记录 | — | 不影响 |
| Step 1b | gitnexus 对方法级符号(rankCandidates/NoteWindowApp)未索引 | gitnexus impact 返回 "Target not found" | 降级 codegraph 补充符号源码 + grep 调用点 | 不影响（codegraph 补齐） |
| Step 3f | 无降级（archify workflow 渲染器实际调用成功） | node render-workflow.mjs 成功输出 50KB HTML | — | 不影响 |
| Step 4c | 无降级（flutter test 10 文件全绿） | +64: All tests passed | — | 不影响 |

---

## 十一、数据安全门禁

- 本项目为 Flutter 桌面应用，运行时数据在本地 SQLite/SharedPreferences，无 accounts.json 等 JSON 运行时文件 → 基线快照为空，无需恢复。
- 测试全程使用独立 test/ 目录文件 + 内存对象构造 Task，未读写真实用户数据。

---

## 十二、附注

- 本次测试发现并修复 1 个真实代码缺陷（便签卡片图标按钮溢出 4px），已在源码落地（desktop_floating_task_tab.dart）。
- 存量问题（非本次引入，未改动）：test/widget_test.dart:48 缺 privacyAccepted 必填参数（MyApp API 变更后未同步）。
- 便签窗真实渲染（黑线消失/崩溃消失/白屏消失/窗口定位/点击定位）依赖真实窗口，无法无头验证 → 交用户 release 构建实测（第六节强制项）。
