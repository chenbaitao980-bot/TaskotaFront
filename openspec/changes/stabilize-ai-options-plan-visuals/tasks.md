# Tasks: stabilize-ai-options-plan-visuals

## Implementation
- [ ] 1. Locate the AI chat parsing/rendering symbols and run GitNexus impact analysis or closest available CLI equivalent before editing.
- [ ] 2. Harden AI prompt/output parsing so assistant questions consistently attach structured options.
- [ ] 3. Add current-stage fallback options for missing `[OPTIONS]` output without stale keyword matching.
- [ ] 4. Update final plan parsing/rendering to support weekly table rows matching the provided plan screenshot.
- [ ] 5. Update final plan flow rendering to support colored nodes, arrows, checklist, key-point band, and progress bar matching the provided flow screenshot.
- [ ] 6. Add or update regression coverage for options fallback and screenshot-aligned plan rendering.
- [ ] 7. Run `flutter analyze --no-fatal-infos`.
- [ ] 8. Run GitNexus change detection or closest available CLI equivalent before delivery.

## Verification
- [ ] User confirms AI questions always show relevant options.
- [ ] User confirms final weekly plan table matches the provided table reference.
- [ ] User confirms final flowchart layout matches the provided flowchart reference.
