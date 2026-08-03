# brainstorm: 增加对话助手模块

## Goal

在现有底部导航的首页、任务、日历、我的模块之后增加一个新的对话助手模块，参考 SpringNote 的回忆书对话体验，让用户可以在应用内和 AI 对话，并且可以自行配置模型 API。

## What I already know

* 用户希望调研 `Radiant303/SpringNote`，并把类似这个对话功能加入当前 app。
* 当前 app 是 Flutter 项目，主入口登录后渲染 `HomePage`。
* `HomePage` 使用 `ValueNotifier<int> _tabIndex`、`IndexedStack` 和抽出的 `_BottomNavWidget` 管理底部导航。
* 当前底部页签顺序是：首页、任务、日历、我的。
* 当前 AI 拆解服务走 `TaskDecompositionService`，使用 `dio` 调用 OpenAI chat-completions 形态的接口，但配置仍来自硬编码常量。
* SpringNote 的 README 描述了“回忆书对话”：对话检索和整理记忆内容，支持思考过程、工具调用展示和 Markdown 渲染。
* SpringNote 的设置支持供应商 Base URL、手动添加模型、编辑模型、选择默认模型。

## Assumptions (temporary)

* 新模块命名为“助手”，底部导航放在“我的”之后。
* 用户已选择方案 B：一次做成 SpringNote 回忆书风格，包含工具调用、来源展示、思考过程。
* 模型接口优先支持 OpenAI-compatible chat completions：`baseUrl`、`apiKey`、`model`、可选 `apiPath`。
* API Key 应保存在本地配置中，不继续新增硬编码密钥。

## Requirements (evolving)

* 底部导航新增第 5 个模块，位于“我的”之后。
* 新模块底部导航名称为“助手”。
* 新模块提供对话页面：消息列表、输入框、发送按钮、加载/错误状态、Markdown 回答渲染。
* 用户可以配置模型 API：至少包括 API Base URL、API Key、模型 ID。
* 未配置模型时，页面应明确提示进入配置，而不是静默失败。
* 配置应本地优先保存，切换/重启后仍可使用。
* 对话请求失败时要显示可理解的错误，并保留用户输入或允许重试。
* 第一版助手工具检索范围包括：任务、项目、日历日程。
* 助手应能通过工具调用回答与本周/今天安排、项目进展、任务状态、日程冲突相关的问题。
* 第一版助手是只读助手：工具调用只能检索和总结，不允许创建、修改或删除任务、项目、日程。
* 对话历史第一版本机持久化，重启后保留最近对话，但不参与账号云同步。

## Acceptance Criteria (evolving)

* [ ] 底部导航显示 5 个模块：首页、任务、日历、我的、助手。
* [ ] 点击新模块后不会重建其他重页面，仍遵守现有 `ValueNotifier + IndexedStack` 模式。
* [ ] 未配置模型时，新模块给出配置入口或提示。
* [ ] 配置模型后，可以发送一条消息并展示模型返回内容。
* [ ] 支持 Markdown 基础渲染。
* [ ] 支持工具调用检索任务、项目、日历日程，并在回答中展示来源/工具结果入口。
* [ ] 工具层不暴露写入型操作，用户要求创建/修改时助手应说明当前版本只支持查看与总结。
* [ ] 对话历史保存到本机，重启应用后仍可查看；提供新建/清空对话入口。
* [ ] API Key 不新增到 `AppConstants` 硬编码。
* [ ] Flutter analyze 或等价检查通过。

## Definition of Done

* Tests added/updated where practical.
* Lint / typecheck / analyzer green.
* Docs/notes updated if behavior changes.
* Rollout/rollback considered if risky.

## Out of Scope (explicit)

* 不实现与任务助手无关的 SpringNote 便签/日报/周报/月报生成能力。
* 暂不把所有已有 AI 拆解功能迁移到新配置，除非后续明确要求。

## Technical Notes

* Local tab structure:
  * `lib/presentation/pages/home/home_page.dart`
  * `_HomePageState._buildPages()`
  * `_BottomNavWidget`
* Existing model-call reference:
  * `lib/services/task_decomposition_service.dart`
  * `dio` is already available.
  * `flutter_markdown` is already available.
* Relevant project guideline:
  * `.trellis/spec/frontend/quality-guidelines.md` requires `ValueNotifier + ValueListenableBuilder` for bottom tab switching and avoiding large `setState` rebuilds.
* Research reference:
  * `research/springnote-chat-and-model-config.md`
  * `research/springnote-lazy-log.md`

## Scope Update: Home Lazy Log

User requested that the SpringNote-style lazy log input should also be integrated into the Home page.

Known facts from SpringNote research:

* SpringNote lazy log is implemented on the Home page, separate from the memory chat page.
* It uses a two-stage AI flow: free-form input to structured JSON, then structured result merged into a daily Markdown note.
* Default structure is completed work, problems/blockers, and tomorrow/next plan.
* It validates strict JSON and has a local keyword fallback when AI fails.
* It preserves existing daily note content instead of blindly replacing it.

Smart Assistant mapping:

* Add a compact lazy input panel to the Home page, near the main daily overview/timeline entry area.
* Reuse the assistant model configuration instead of creating another model settings surface.
* First stage should structure user input into sections such as done/progress, blockers, next actions, and possible tasks/schedules.
* Write actions must be explicit: show a preview/confirmation before creating tasks or schedules.
* If AI fails, use local parsing fallback so the input is not lost.

MVP requirements added:

* Home page exposes a quick free-form input for lazy logging.
* Submitting lazy input calls a structured parsing service backed by the configured assistant model.
* Parsed result is shown to the user before any task/schedule creation.
* User can confirm generated task and schedule drafts; confirmed drafts create real tasks and schedules through existing write paths.
* The flow refreshes Home/Task state after confirmed creation.
* The input is preserved on failure and a readable error is shown.

MVP out of scope added:

* Full SpringNote daily/weekly/monthly Markdown report system.
* Silent auto-create without confirmation.
* Cloud-synced long-form journal storage unless it already falls out naturally from existing task/schedule persistence.

Decision from user:

* MVP should include both task and schedule creation after confirmation.

## Research Notes

### Feasible approaches

**Approach A: MVP chat plus configurable OpenAI-compatible endpoint (Recommended)**

* How it works: Add the new tab/page, a small local model config object, and a chat service using `dio`.
* Pros: directly satisfies the user-visible request with limited blast radius.
* Cons: tool calls and memory-source chips come later.

**Approach B: SpringNote-like memory/tool chat**

* How it works: Add chat UI plus task-search tools, tool-call loop, reasoning display, source chips, and conversation persistence.
* Pros: closest to SpringNote.
* Cons: bigger first implementation and higher regression risk.
* Decision: selected by user.

**Approach C: Provider/model settings first**

* How it works: Build provider/model management and default selection first, then build chat.
* Pros: strongest long-term foundation for all AI features.
* Cons: delays the actual chat module.

## Open Questions

* No open product questions remain before implementation.

## Technical Approach

Implement a new assistant feature area with four pieces:

1. Navigation/page shell: add a fifth bottom tab in `HomePage`, preserving the existing `ValueNotifier + IndexedStack` pattern.
2. Local configuration: store provider/model settings locally, with fields for API Base URL, API Key, model ID, and optional API path.
3. Conversation runtime: persist messages locally, call an OpenAI-compatible chat-completions endpoint, render Markdown, display reasoning content when returned, execute read-only local tools, and show tool/source entries.
4. Read-only tools: expose task/project/schedule search and date-window summaries only; no write tools in v1.

## Decision (ADR-lite)

**Context**: The feature can be implemented as a simple chat tab, as a provider-config foundation, or as a fuller SpringNote-style memory/tool conversation.

**Decision**: Build the fuller SpringNote-like experience in the first version: configurable model providers, chat UI, reasoning display, tool-call loop, tool/source display, and persisted conversation.

**Consequences**: The implementation touches more modules and needs stronger quality checks, but the first shipped feature will match the requested reference project more closely.

## Final Requirement Summary

Build a new bottom-tab module named "助手" after 首页、任务、日历、我的.

The assistant should be SpringNote-like, not just a simple chat box:

* Configurable model provider/API, using OpenAI-compatible chat-completions shape.
* Local-only persisted conversation history with a new/clear conversation entry.
* Markdown answer rendering.
* Reasoning display when model output contains reasoning content.
* Tool-call loop with visible tool/source result entries.
* Read-only local tools for tasks, projects, and calendar schedules.
* No create/update/delete actions in v1.

Implementation should keep the current `HomePage` tab pattern: `ValueNotifier`, `ValueListenableBuilder`, cached `_pages`, and `IndexedStack`.
