# Design: stabilize-ai-options-plan-visuals

## Current State
The project already has prior work around AI option parsing and plan rendering, but user verification shows two remaining gaps:
- some assistant questions are still displayed as pure text with no selectable options;
- final plan visuals do not consistently match the desired table and flowchart presentation shown in the provided screenshots.

## Approach
1. Treat AI options as part of the structured response contract.
   - Prefer explicit structured markers already used by the app.
   - If options are missing, infer fallback choices from the current conversation stage/state, not by scanning arbitrary response keywords.
   - Clear stale options when a new assistant message arrives, then attach only options belonging to that message.

2. Treat final plans as structured data before rendering.
   - Reuse existing table/hierarchy/flow markers when possible.
   - Add parsing support only for fields needed by the screenshot target: week title/date range, day rows, flow nodes, directed edges, materials/checklist, key points, and progress.
   - Keep plain-text fallback for unparseable content, but do not let it replace structured rendering when structured sections exist.

3. Render screenshot-aligned components inside the existing app theme.
   - Weekly overview: table with header row and compact, high-contrast cells.
   - Flowchart: rounded pastel nodes, visible arrows, responsive wrapping/stacking for small screens.
   - Supporting sections: checklist panel, key-point callout band, and horizontal progress indicator.
   - Avoid nested cards and oversized marketing-style layout.

## Business Rule Handling
- Original Requirement / Scenario: `AI任务拆解 / 目标拆解`
- Change type: MODIFIED behavior under existing smart-butler capability.
- No new persistence requirement.
- No task model change unless implementation inspection proves the existing final-plan model cannot express the required visual sections.

## GitNexus / Impact Plan
Before editing any function, class, or method:
- run GitNexus impact analysis or the closest available CLI equivalent for the specific target symbol;
- report direct callers, affected flow, and risk level;
- stop and warn before editing if risk is HIGH or CRITICAL.

Expected initial targets to inspect:
- `AIService` prompt/output contract methods;
- `AiChatPage` response parsing and option-chip rendering methods;
- final plan table/flow rendering helpers or widgets.

## Regression Plan
- Add or update a regression case covering:
  - assistant question with explicit options;
  - assistant question missing options but current stage fallback available;
  - final weekly football-learning plan renders table rows and flow nodes similar to the supplied screenshots.
- Run `flutter analyze --no-fatal-infos`.
- Run focused widget/unit tests if existing tests cover AI chat rendering.
- Run GitNexus change detection or closest available CLI equivalent before delivery.

## Rollback
Remove `openspec/changes/stabilize-ai-options-plan-visuals/` and revert the implementation files touched by this change.
