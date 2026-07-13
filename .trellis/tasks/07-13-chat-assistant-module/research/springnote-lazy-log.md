# SpringNote Lazy Log Research

## Source

Repository: https://github.com/Radiant303/SpringNote

Files inspected:

* `spring_note/lib/features/home/home_page.dart`
* `spring_note/lib/core/services/ai_client_service.dart`
* `spring_note/rust/src/ai.rs`
* `spring_note/lib/core/models/structured_note_section_config.dart`
* `spring_note/lib/core/services/daily_note_service.dart`
* `spring_note/lib/core/services/mock_ai_service.dart`

## How SpringNote Does Lazy Log

SpringNote implements lazy logging on the home page, not inside the memory chat page.

Flow:

1. Home page collects free-form user input plus optional image/document attachments.
2. `HomePage._submit()` calls `AiClientService.generateStructuredNote()`.
3. The Dart service sends a `StructuredNoteRequest` to Rust through Flutter Rust Bridge.
4. Rust builds `structured_system_prompt()` from configurable section definitions and asks the model to return JSON only.
5. Rust parses and validates the JSON in `parse_structured_note()`.
6. If AI structuring fails, Dart falls back to `MockAiService.structureWorkNote()`, which splits text into lines and classifies by keywords.
7. The app reads today's existing daily note and calls `mergeDailyMarkdown()` to merge old daily Markdown plus the new structured note.
8. `DailyNoteService.mergeStructuredNote()` writes the final Markdown to today's daily note file.

Default sections:

* Completed work
* Issues / blockers
* Tomorrow / next plan

Important design points:

* Two-stage AI: structure first, then merge into a human-editable daily note.
* The first AI stage returns strict JSON, not Markdown.
* Section definitions are configurable.
* There is a local deterministic fallback when AI fails.
* Existing daily content is preserved and merged instead of blindly appending every time.

## Mapping To Smart Assistant

The current smart_assistant project already has:

* A home page with cached tab pages and a home-only FAB.
* A configurable assistant model endpoint.
* Read-only assistant tools for tasks, projects, schedules.
* Task creation through `TaskNewBloc` and `TaskRepository.create`.
* Local schedule creation through `LocalStorageService.createSchedule`.

Potential implementation shape:

1. Add a compact "lazy input" panel on the home page.
2. Reuse assistant model config for the model call.
3. Add a structured-log service that asks the model for JSON sections.
4. Provide local fallback parsing by keywords.
5. Show a review card before applying write actions.
6. MVP can either save a structured local log only, or create tasks/schedules from confirmed structured results.

## Open Product Boundary

The biggest decision is whether the MVP writes only a structured log, or also creates real tasks/schedules.

Recommended MVP: model structures the input and shows a confirmation preview. After confirmation, create task drafts for extracted next actions. This fits the user's current goal of bringing lazy logging into the home page while keeping write actions explicit.
