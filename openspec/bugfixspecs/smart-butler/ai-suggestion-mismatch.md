# ai-suggestion-mismatch: AI suggestion chips match the current question

## Scope
- Capability: smart-butler
- Related change: claude-ui-and-progressive-ai
- Related files/symbols: `lib/presentation/pages/ai_chat/ai_chat_page.dart` / `_generateSuggestions`

## User-visible symptom
AI follow-up questions rendered the wrong quick-reply chips when a message contained overlapping keywords, such as a goal question that also mentioned time expectations.

## Root cause
Suggestion generation used broad substring checks and checked generic time/level words before the actual intent of the current question was disambiguated.

## Why it repeated
The first fix changed keyword order but kept the same broad matching model, so another phrase with the word "time" still matched the wrong branch.

## Correct fix model
Match suggestions by the semantic intent of the current AI question, using specific phrases before generic keywords and avoiding catch-all words such as "time" by itself.

## Forbidden approaches
- Do not add a broader `contains('time')` or `contains('level')` branch.
- Do not rely only on branch order when phrases have different meanings.
- Do not show chips from quoted prior answers when the current question asks for a different dimension.

## Recurrence checks
- [ ] Goal/level questions that mention time expectations still show goal/level options.
- [ ] Daily/weekly availability questions show duration options.
- [ ] A message quoting the user's prior level does not force level options when the current question asks for time.

## Minimal verification set
```powershell
flutter analyze --no-fatal-infos
flutter test
```

## Related history
| change | bugfix_count | archive_time |
|---|---:|---|
| claude-ui-and-progressive-ai | 2 | 2026-05-24 |
