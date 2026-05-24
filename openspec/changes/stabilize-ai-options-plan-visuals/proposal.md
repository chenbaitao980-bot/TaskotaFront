# stabilize-ai-options-plan-visuals

## Why
1. AI 助手回答时仍可能只返回纯文字问答，没有给用户可点击的选项，导致对话推进不稳定。
2. AI 生成的学习计划和流程图需要参考用户提供的截图：计划总览应是清晰表格，流程图应是彩色节点、箭头连接、材料清单、核心要点和进度条式的结构化视图，而不是大段纯文本。

## Impact
- `AiChatPage`: expected LOW to MEDIUM risk. It owns AI chat parsing, option chips, and final plan rendering.
- `AIService`: expected LOW risk. It owns the prompt/output contract and should require structured option and plan markers.
- Plan rendering widgets/helpers: expected LOW to MEDIUM risk, depending on whether current final-plan rendering is inline or extracted.
- No storage or task persistence behavior should change unless existing rendering code requires a minimal mapping adjustment.

## Business Context
- Main spec: `openspec/specs/smart-butler/spec.md`
- Requirements hit: `AI任务拆解`
- Relation: Same Requirement / MODIFIED behavior.
- Related active/history changes:
  - `fix-ai-options-fallback` addressed option parsing instability, but user feedback shows options can still be absent.
  - `planner-flow-multiday-task-ui` already requires final AI plans to render as a structured table and readable flowchart; this change tightens the visual target using the new screenshots.
  - `ai-taskflow-planning-upgrade` already introduced structured table/hierarchy markers; this change should reuse or harden those contracts instead of inventing unrelated output formats.

## Change Scope
- Inspect current AI chat response parser and final plan renderer.
- Harden the AI output contract so every assistant question includes explicit selectable options.
- Add a deterministic fallback only when the AI omits options, with options derived from the current question stage rather than stale keyword matching.
- Render final plans in a screenshot-aligned layout:
  - weekly plan overview table with date, theme, and training/content columns;
  - flowchart with pastel rounded nodes and directional arrows;
  - equipment/material checklist section when present;
  - zero-foundation/key-point note band;
  - visible progress bar for plan progress or training progress.

## Acceptance
- [ ] Every AI assistant question in the task-planning flow displays relevant option chips.
- [ ] If the AI omits structured options, the UI still shows safe options for the current question stage and never reuses stale options from a previous question.
- [ ] Final weekly plans render as a table comparable to the user's first screenshot.
- [ ] Final process/flow plans render as a colored node-and-arrow flowchart comparable to the user's second screenshot.
- [ ] The final plan view can show supporting checklist, key points, and progress bar sections when the AI output includes those fields.
- [ ] No unrelated refactor, storage migration, or behavior change is introduced.
- [ ] `flutter analyze --no-fatal-infos` passes after implementation.
- [ ] GitNexus change detection or the closest available GitNexus CLI equivalent is run before delivery.
