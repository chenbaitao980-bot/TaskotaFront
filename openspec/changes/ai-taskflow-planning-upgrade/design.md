# Design: ai-taskflow-planning-upgrade

## TaskFlow Reference
`taskflow.zip` models long work as named steps with state and routing:
- fetch/diagnose input
- classify state
- route by condition
- wait when missing information
- finish with a structured result

The app does not need a real background TaskFlow runtime here. It needs the same discipline in the AI planning prompt and renderer.

## AI Planning Contract
The AI assistant SHALL run this logical flow:
1. `diagnose_goal`: extract goal, domain, desired outcome.
2. `classify_missing_slots`: check current level, available time, deadline, constraints, preferred schedule.
3. `ask_next_question`: if any required slot is missing, ask exactly one highest-value question and include `[OPTIONS: ...]`.
4. `build_plan`: when enough information exists, return a structured deliverable.
5. `route_assignment`: each deliverable row must be assignable as a task or subtask.

## Required Final Deliverable
Final AI answer should include enough structure for current UI parsing:
- Markdown table with columns: `阶段 | 任务 | 时间范围 | 说明`
- Hierarchy section for mind-map rendering.
- Assignment rows with concrete enough title/time/notes.

The UI can keep existing table and mind-map renderer. The prompt should force stable markers so renderer detection is less fragile.

## Assignment Rules
- Top-level rows become tasks.
- Child rows become subtasks when the hierarchy indicates a parent.
- Default generated task range must be same-day unless the row explicitly says multi-day.
- Generated tasks must include start/end DateTime so they appear in the calendar hourly grid or multi-day lane.

## Prompt Language
- System prompt and fallback UI messages should be Chinese-first.
- Do not expose raw English runtime errors to users in Snackbar text.

## Dismissible Prompt Rule
For transient prompts in touched flows:
- Use a Chinese message.
- Provide a visible action or allow normal SnackBar swipe/tap dismissal where supported.
- Avoid persistent black English SnackBars.

## Regression Plan
- Existing widget/unit tests.
- Add/extend tests for deletion guard where practical.
- Manual check AI plan generation and assignment because live LLM output is nondeterministic.
