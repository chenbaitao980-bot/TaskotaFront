# ai-suggestion-mismatch: AI suggestion chips match the current question

## Scope
- Capability: smart-butler
- Related change: claude-ui-and-progressive-ai, fix-ai-options-fallback
- Related files/symbols: `lib/presentation/pages/ai_chat/ai_chat_page.dart` / `_generateSuggestions`, `lib/services/ai_service.dart` / `_systemPrompt`

## User-visible symptom
AI follow-up questions rendered the wrong quick-reply chips when a message contained overlapping keywords, such as a goal question that also mentioned time expectations.

## Root cause
Suggestion generation used broad substring checks and checked generic time/level words before the actual intent of the current question was disambiguated. The keyword matching approach is fundamentally unreliable because natural language questions can mention multiple dimensions.

## Why it repeated
- Fix 1 (claude-ui-and-progressive-ai, bugfix_count=1): Changed keyword order but kept the same broad matching model.
- Fix 2 (claude-ui-and-progressive-ai, bugfix_count=2): Added more keywords but still used contains checks.
- Fix 3 (fix-ai-options-fallback, bugfix_count=3): Root cause confirmed — keyword matching is fundamentally unreliable and cannot be fixed by tuning keyword order or count. **Completely replaced with AI-generated [OPTIONS:] structured output.**

## Correct fix model
**完全放弃关键词匹配方案。** 所有选项必须来自 AI 在回复末尾输出的 `[OPTIONS:]` 结构化标记。UI 端只解析 `[OPTIONS:]` 标记渲染选项卡，不做任何关键词猜测。

AI system prompt 中加入了明确的 `[OPTIONS:]` 必须规则和示例，确保每轮提问都输出正确格式。

## 历史经验（仅供复盘参考）

> **⚠️ 重要：此 BugFixSpec 仅作为过去的 bug 修复经验参考。**
> 如果再次触发同一类 bug，说明过去的修复策略失败，需要重新分析根因并调整修复方案，而不是简单套用以下经验。

| 轮次 | change | 修复策略 | 结果 |
|---|---|---|---|
| 1 | claude-ui-and-progressive-ai | 调整关键词匹配顺序 | ❌ 复发 |
| 2 | claude-ui-and-progressive-ai | 增加更多关键词 | ❌ 复发 |
| 3 | fix-ai-options-fallback | 完全放弃关键词匹配，改用 AI 生成 [OPTIONS:] | 当前策略 |

### 经验总结
- 客户端关键词 contains 匹配不可靠，无法通过调参数解决
- 依赖 AI 生成结构化 `[OPTIONS:]` 比客户端猜测更可靠
- 若此 bug 再次出现，建议重新评估 AI 侧的 `[OPTIONS:]` 生成质量，而非回到客户端匹配方案

## Recurrence checks
- [x] _generateSuggestions 方法已完全移除
- [x] _callAI 建议逻辑简化为仅解析 [OPTIONS:] 标记
- [x] system prompt 加入明确的 [OPTIONS:] 规则和示例

## Minimal verification set
```powershell
flutter analyze --no-fatal-infos
```

## Related history
| change | bugfix_count | archive_time |
|---|---:|---|
| claude-ui-and-progressive-ai | 2 | 2026-05-24 |
| fix-ai-options-fallback | 3 | (ongoing) |
