# BugFix Log: fix-ai-options-fallback

## Bug Index

| bug_id | 现象 | 关联文件/函数 | bugfix_count | 当前状态 | 是否需沉淀 |
|---|---|---|---:|---|---|
| bug-003 | AI拆分对话时第三轮问题（'希望达到什么效果'）显示的选项卡是时间选项而非目标选项 | ai_chat_page.dart:_generateSuggestions,ai_chat_page.dart:_callAI,ai_service.dart:_systemPrompt | 1 | fixed | 否 |

## Bug Events

### bug-003 / 第 1 次修复

- 触发时间：2026-05-24 19:53
- 用户现象：AI拆分对话时第三轮问题（'希望达到什么效果'）显示的选项卡是时间选项而非目标选项
- 复现路径：TBD
- 触发条件：TBD
- 失败验证：TBD
- 本轮根因假设：TBD
- 最终根因：TBD
- 修复点：ai_service.dart: system prompt加入[OPTIONS:]必须规则和明确示例; ai_chat_page.dart: 移除_generateSuggestions/_canUseExplicitOptions/_shouldSuggestForQuestion/_isShortQuestion方法; _callAI建议逻辑简化为仅解析[OPTIONS:]标记
- 验证结果：pending
- 是否同一 bug：-
