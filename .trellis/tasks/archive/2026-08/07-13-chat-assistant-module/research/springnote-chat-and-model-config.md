# SpringNote chat and model configuration research

## Source

- Repository: https://github.com/Radiant303/SpringNote
- README inspected on 2026-07-13.
- Key files inspected via GitHub raw:
  - `spring_note/lib/features/memory/memory_page.dart`
  - `spring_note/lib/features/settings/settings_providers_panel.dart`
  - `spring_note/lib/features/settings/settings_default_models_panel.dart`

## Findings

SpringNote presents the chat-like feature as "memory book conversation": a conversational UI that can retrieve and organize previous records, display reasoning, show tool calls, and render Markdown.

The memory page is a Flutter `StatefulWidget` that persists conversation messages, streams model output, supports tool-calling rounds, renders reasoning separately, shows tool-result chips/dialogs, and falls back to local search when no model stream is available.

Provider configuration is first-class. SpringNote lets users add providers, set provider name, API key, protocol, API Base URL, API path, enable/disable providers, add/fetch/edit/delete models, and test the provider connection.

Default model selection is separate from provider management. SpringNote has explicit default-model slots, including a memory-book model for memory Q&A and retrieval answers.

## Mapping to smart_assistant

The requested feature should not copy SpringNote wholesale. The closest fit for this app is a new bottom-tab module that exposes a task-aware assistant:

- Conversation UI with user/assistant messages.
- Markdown rendering using the existing `flutter_markdown` dependency.
- Streaming can be deferred unless the selected API path is simple enough to support cleanly.
- Model provider settings should be user-configurable instead of adding more hardcoded API constants.
- The first MVP can answer with direct chat plus optional local task context; full tool-calling and source chips can be a second pass.

## Implementation candidates

### Approach A: MVP chat plus configurable OpenAI-compatible endpoint (recommended)

Add a new bottom tab, a chat page, a local model config page under settings/profile, and a small `AiChatService` using `dio`.

Pros: matches user request, low blast radius, can verify quickly.
Cons: does not include SpringNote's full tool-call loop or source attachments yet.

### Approach B: SpringNote-like memory/tool chat

Add provider config, chat UI, task search tools, tool-call execution loop, source chips, reasoning display, and persisted conversations.

Pros: closest to SpringNote's feature set.
Cons: larger scope, touches local storage, task repository, UI, model protocol parsing, and error recovery all at once.

### Approach C: Settings/config first, chat second

Build provider/model configuration and default model selection first; add the chat module after configuration is stable.

Pros: reduces risk around credentials and model selection.
Cons: user cannot try the new module immediately.

## Recommendation

Start with Approach A, while designing file and model names so Approach B can be added later without rewriting the tab/page skeleton.
