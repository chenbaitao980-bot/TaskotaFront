# 任务：fix-ai-options-fallback

## 实施
- [x] 1. 更新AIService system prompt强化[OPTIONS:]输出要求（加入明确示例）
- [x] 2. 重构ai_chat_page.dart移除_generateSuggestions内容关键词匹配（仅保留确认类关键词或直接返回空）
- [x] 3. 清理不再使用的辅助方法（_canUseExplicitOptions/_shouldSuggestForQuestion等逻辑调整）
- [x] 4. 运行flutter analyze --no-fatal-infos
- [x] 5. 运行gitnexus detect-changes --scope all -r smart-assistant

## 验证
- [ ] <用户确认：AI拆分对话每个问题都对应正确的选项卡选项>
- [ ] <用户确认：无选项的问题不错误展示来自旧问题/关键词的选项>
- [ ] <用户确认：flutter analyze通过>
