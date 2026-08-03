# brainstorm: 懒人日志 AI 思考模式控制 + 审核页父任务树状选择

## Goal

两个需求：
1. 懒人日志调用 AI 大模型时，提供"关闭思考模式 / 思考等级最低"的控制能力（现状完全由用户填写的模型 ID 决定是否思考）
2. 审核页（懒人日志草稿审核）父任务选择：
   - 先选择项目，才能选择父任务（项目门控）
   - 父任务可选项从扁平列表改为树状图，更直观

## What I already know

### 需求 1：AI 思考模式
- AI 调用在 `lib/services/home_lazy_log_service.dart` 的 `structure()`
- 请求体只传：`model`、`temperature: 0.2`、`messages`（system + user）—— **没有任何 thinking/reasoning 参数**
- 是否"思考"完全由用户配置的模型 ID 决定：`gpt-4o-mini`/`deepseek-chat`/`doubao` 不思考；`deepseek-reasoner`/`o1`/`o3`/`kimi-k2-thinking` 类会思考
- 配置在 `AssistantModelConfig`（baseUrl/apiPath/apiKey/model/userInstructions），SharedPreferences 持久化，设置对话框在 assistant_page.dart `_AssistantConfigDialog`
- 配置默认示例：baseUrl `https://ark.cn-beijing.volces.com/api/coding/v3`，模型 `gpt-4o-mini`（火山方舟 OpenAI-compatible）
- 测试：`test/home_lazy_log_service_test.dart` 存在，直接调用 `HomeLazyLogService`，mock Dio

### 需求 2：审核页父任务树
- 审核页：`lib/presentation/pages/home/lazy_log_draft_review_sheet.dart`
- 每张草稿卡片 `_DraftReviewCard` 里有 `_ProjectDropdown`（项目）+ `_ParentDropdown`（父任务）两个并列下拉
- **现状问题 A**：`_ParentDropdown` 列出全部父任务，不随所选项目过滤，也没做"先选项目"门控
- **现状问题 B**：父任务是扁平 `DropdownButton`，一行一个 `Text(parent.title)`，无树状层级
- `LazyLogParentOption` 只有 id/title/projectId 三个字段，**没有 parentId**（构造在 home_page.dart `_lazyLogParentOptions()`）
- 父任务候选 `_lazyLogParentCandidates()` 只筛**根任务**（`task.parentId == null`）＋ 按 projectId 过滤
- `_TimelineTask` 有 parentId/projectId/title/id/taskId/source 字段（home_page.dart），数据源足够，但要构造树需要把 parentId 传进 `LazyLogParentOption`
- 数据更新走 `repository.updateDraft(draft.id, projectId/parentTaskId/...)`

## Assumptions (temporary)

* 需求 1 需要一个跨 OpenAI-compatible 提供商都尽量生效的思考控制参数（待 research 确认）
* 需求 2 的树状图：用户希望看到项目 → 根任务 → 子任务的层级，可选项可能是根任务，也可能任意层级节点（待确认）

## Research References

* [`research/ai-thinking-control.md`](research/ai-thinking-control.md) — 跨 OpenAI-compatible 提供商思考控制参数调研
* [`research/flutter-tree-picker.md`](research/flutter-tree-picker.md) — Flutter 树状选择器 UI/组件方案调研

## Decision (ADR-lite)

**Context**: 3 个关键决策需用户拍板（2026-08-03 已确认）
**Decision**:
1. 父任务树**任意层级都可选**（去掉 parentId==null 过滤，允许更深嵌套）
2. 选择器形态 = **底部弹层 + 可展开树 + 搜索**（自绘，复用 subtask_tree_section 骨架，零依赖）
3. 思考控制 = **配置加"思考等级"下拉 + 按模型前缀自动映射**（AssistantModelConfig 加字段，未命中兜底 reasoning_effort:low）
**Consequences**: 改动集中在 3 个文件层（配置模型/服务 + 审核页 + 树选择器组件）；需维护一张模型前缀映射表；静默 fallback 陷阱需测试覆盖

## Requirements (evolving)

### 需求 1：懒人日志 AI 思考控制
* `AssistantModelConfig` 新增思考等级字段（auto/off/low/medium/high，默认 auto）
* 设置页 `_AssistantConfigDialog` 加"思考等级"下拉
* `HomeLazyLogService.structure()` 根据字段 + 模型 ID/baseUrl 自动拼装请求体：
  - `off`：按模型前缀分发原生关闭参数（deepseek-v4/glm→`thinking:{type:disabled}`、qwen 混合思考→`enable_thinking:false`、kimi-k3→`reasoning_effort:"low"`、openai 新推理模型→`reasoning_effort:"none"`）
  - `low/medium/high`：统一发 `reasoning_effort`
  - `auto`：保持现状不发
  - 映射未命中：兜底发 `reasoning_effort: "low"`
* 检测到推理模型（o1/o3/gpt-5、deepseek-v4 思考模式）时不发 `temperature`（避免 400 静默 fallback）

### 需求 2：审核页父任务树状选择
* `LazyLogParentOption` 增加 `parentId` 字段（定义在 lazy_log_creation_dialog.dart，构造在 home_page.dart `_lazyLogParentOptions()`）
* `_lazyLogParentCandidates` 返回所选项目下**全量任务**（根+后代，带 parentId），不再只筛根任务
* 审核页父任务选择**门控**：未选项目时禁用父任务入口 + 提示"先选项目"
* 选定项目后：父任务弹层只展示该项目子树
* 切换项目时若已选父任务不属于新项目 → 清除 parentTaskId
* 新增可复用组件 `TaskTreePickerSheet`（底部弹层 + 可展开/折叠树 + 搜索框，单点即回填）
* 新增可复用 widget `TaskTreePickerSheet`（`lib/presentation/widgets/`），复用 subtask_tree_section 的 `_buildChildrenByParent` + 递归树 + expandedNodes 骨架
* 父任务选择器交互模型（第三轮迭代定稿）：
  - **点选不关闭**：点节点 = 切换勾选（已选→取消勾选并清空父任务选择，未选→勾选），窗口保持打开，可反复改
  - **完成按钮提交**：底部"完成"按钮确认返回（有勾选→返回该节点；无勾选→返回静态哨兵 `clearSelection` 清空父任务）
  - **关闭语义**：右上角 X / 点外面 → `null`，关闭弹层不保存（不误清父任务）
  - **默认收缩**：打开时树默认全部折叠（不再预展开根节点）
  - **选中路径可见**：已选中某父任务时，打开自动展开其祖先链，保证当前勾选可见
  - **一键展开/收起**：header 提供"全部展开/全部收起"切换按钮

## Acceptance Criteria (evolving)

* [x] 懒人日志在思考等级=off 时，请求体包含对应厂商的关闭参数
* [x] 思考等级=low 时，请求体含 `reasoning_effort: "low"`
* [x] 推理模型检测到时去掉 temperature
* [x] `home_lazy_log_service_test.dart` 覆盖：off/low 映射、兜底、静默 fallback 链路不回归
* [x] 审核页未选项目时父任务入口禁用/提示
* [x] 选定项目后父任务树只显示该项目下任务（含子任务）
* [x] 父任务树可展开/折叠、可搜索、单点回填
* [x] 切换项目时清除不属于新项目的已选父任务
* [x] 空项目（无任务）显示空态
* [x] 点节点切换勾选、窗口不关闭；底部"完成"按钮确认提交
* [x] 再点一次已选节点 → 取消勾选，点"完成"清空父任务（clearSelection 哨兵；关闭弹层/点外不误清）
* [x] 默认树形结构收缩；已选中项自动展开祖先路径
* [x] header 提供一键"全部展开/全部收起"按钮

## Definition of Done (team quality bar)

* 测试更新（home_lazy_log_service_test + TaskTreePickerSheet widget 测试）
* lint / flutter analyze 绿
* docs/notes 更新（CHANGELOG.md）
* 网页版同步（若涉及）

## Out of Scope (explicit)

* 不把树选择器迁移到懒人日志创建弹窗（lazy_log_creation_dialog 保持现状，字段兼容即可）
* 不做服务端改动
* 不改变懒人日志其他请求参数
* 不处理"仅思考模型无法关闭"的情况（qwq/r1/kimi-k2-thinking 等靠换模型 ID，只在映射提示）

## Spec Conflicts

* 无

## Technical Notes

* 已查文件：
  - `lib/services/home_lazy_log_service.dart`（AI 请求构造，structure():34-57）
  - `lib/models/assistant/assistant_models.dart`（AssistantModelConfig）
  - `lib/services/assistant_config_service.dart`（配置持久化）
  - `lib/presentation/pages/assistant/assistant_page.dart`（_AssistantConfigDialog）
  - `lib/presentation/pages/home/lazy_log_draft_review_sheet.dart`（审核页 _ProjectDropdown/_ParentDropdown）
  - `lib/presentation/pages/home/home_page.dart`（_lazyLogParentOptions:2153 / _lazyLogParentCandidates:2228 / _TimelineTask）
  - `lib/presentation/pages/home/lazy_log_creation_dialog.dart`（LazyLogParentOption 定义 / _filteredParents 门控先例）
  - `lib/presentation/pages/tasks/task_detail/widgets/subtask_tree_section.dart`（可复用展开树骨架 :159-213）
- 取消选择实现：`TaskTreePickerSheet.clearSelection` 静态 const 哨兵（`LazyLogParentOption` 无 `==` 覆写 → 身份相等比较）；选中节点再点 pop 哨兵，`_ParentTaskButton` 识别后 `onChanged(null)` 清空父任务；null 保留给"关闭弹层"语义
- 上个相关任务：`.trellis/tasks/07-17-lazy-log-ai-analysis/`（AI auth 错误透传）
