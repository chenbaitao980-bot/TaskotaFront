# Tasks: ai-taskflow-planning-upgrade

## Implementation
- [x] 1. Update `AIService` system prompt to use the TaskFlow-style diagnose/classify/ask/build/route contract.
- [x] 2. Update AI final deliverable instructions so table, hierarchy, and assignable rows are stable for current renderer.
- [x] 3. Update `AiChatPage` assignment mapping if needed so assigned rows create dated tasks/subtasks visible in calendar.
- [x] 4. Replace touched English user prompts with Chinese.
- [x] 5. Make parent-task deletion guard prompt dismissible with Chinese text.
- [x] 6. Maintain regression cases for AI planning, assignment, and Chinese prompts.
- [x] 7. Run `flutter analyze --no-fatal-infos`.
- [ ] 8. Run `flutter test`. (blocked by sandbox env: %PROGRAMFILES(X86)% not found)
- [x] 9. Run `gitnexus detect-changes --scope all -r smart-assistant`.

## User Verification
- [ ] Try deleting a task with subtasks; confirm the prompt is Chinese and can be dismissed.
- [ ] Ask AI to plan a broad goal; confirm it asks one useful question at a time.
- [ ] Complete AI consultation; confirm final answer renders table plus mind-map.
- [ ] Assign AI plan; confirm tasks/subtasks appear in task pages and calendar.
