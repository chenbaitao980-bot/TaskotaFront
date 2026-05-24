# Tasks: fix-calendar-refresh-and-ai-options

## Implementation
- [x] 1. Add Home-to-Calendar refresh signal and reload Calendar events when it changes.
- [x] 2. Parse explicit `[OPTIONS: ...]` AI response lines into clickable suggestions and hide the raw marker.
- [x] 3. Maintain regression case file and run verification gates.
- [x] 4. Update proposal/tasks/delivery after implementation.

## User Verification
- [x] Create a schedule on Home, open Calendar week view, and confirm it appears immediately.
- [x] Trigger AI goal breakdown, confirm options render as clickable chips rather than raw `[OPTIONS: ...]` text.
- [x] Click one option and confirm it sends the selected text.
