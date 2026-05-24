# fix-ai-options-fallback

## 为什么
AI拆分对话时第三轮选项显示错误（显示时间选项而非目标效果选项），根因是_generateSuggestions关键词匹配方案不可靠

## 影响面
ai_chat_page.dart: _generateSuggestions/_callAI; ai_service.dart: system prompt

## 业务规范关系
- 命中的主 spec：smart-butler
- 关系判断：Bug Against Spec
- 推荐动作：不改spec只修代码

## 改动范围
<AI 实施时填写>

## 验收
- [ ] 实现本次需求的最小改动
- [ ] 已维护 `regression-tests/cases/fix-ai-options-fallback.md`
- [ ] 已执行 `gitnexus detect-changes`
- [ ] 无异常范围外变更

> 验收项由 AI 在实施中完成并打勾；用户只确认 `tasks.md` 的验证项。
