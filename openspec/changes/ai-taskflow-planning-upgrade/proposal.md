# ai-taskflow-planning-upgrade

## Why
1. 用户可见提示仍有英文，例如 `Cannot delete a task that still has subtasks`，应统一为中文，并允许用户点击/操作后消失。
2. 当前 AI 助手的任务拆解不够稳定，咨询提问和最终任务产物缺少“可执行、可分配、可进入日历”的硬约束。
3. `taskflow.zip` 提供了更适合的流程模型：按步骤诊断、分类、等待补充、产出结构化交付物，再路由到具体动作。

## Impact
- `AIService`: LOW risk. Update system prompt and structured output contract.
- `AiChatPage`: LOW risk. Parse/render TaskFlow-style deliverables and adjust assignment mapping.
- `TaskDetailPage`: LOW risk. Replace English deletion guard prompt with Chinese dismissible prompt.
- `LocalStorageService`: HIGH risk if modified. Preferred implementation avoids storage changes and reuses existing task creation/query APIs.

## Business Context
- Main spec: `openspec/specs/smart-butler/spec.md`
- Requirement hit: AI任务拆解, 日历视图
- Relation: Same Requirement / MODIFIED behavior.
- Active change overlap: `planner-flow-multiday-task-ui` covers plan rendering and assignment UI; this change narrows the AI engine contract and prompt behavior.

## Acceptance
- [x] All user-facing transient prompts in the touched flow are Chinese.
- [x] The parent-task deletion guard message is Chinese and can be dismissed by tapping or action.
- [x] AI consultation follows a TaskFlow-style sequence: diagnose goal, classify missing slots, ask one key question, then deliver structured rows.
- [x] AI final output includes table rows, hierarchy/mind-map content, and assignable task rows, with stable `[TABLE_BEGIN]`/`[TABLE_END]`/`[HIERARCHY_BEGIN]`/`[HIERARCHY_END]` markers.
- [x] One-click assignment creates task records with title, notes, start/end time, parent-child relationship when available, and calendar visibility.
- [x] `flutter analyze --no-fatal-infos` passes.
- [ ] `flutter test` passes. (blocked by sandbox env: %PROGRAMFILES(X86)% not found)
- [x] `gitnexus detect-changes --scope all -r smart-assistant` is executed before delivery.
