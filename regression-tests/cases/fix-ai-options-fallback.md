# Regression Cases: fix-ai-options-fallback

## Cases

| case_id | 目标 | 入参摘要 | 期望出参关键字段 | 断言 | 来源 | 状态 |
|---|---|---|---|---|---|---|
| OPT-001 | AI 提问正确展示 [OPTIONS:] 选项卡 | 用户说"想学做饭"，AI 按流程提问 | 3 轮对话各显示正确选项卡，无错乱 | 截图验证每轮选项卡匹配问题内容 | 本次 bug | active |
| OPT-002 | AI 未输出 [OPTIONS:] 时显示通用回退选项 | AI 提问但未加 [OPTIONS:] | 显示通用户选项 ["好的，继续", "让我想想", "换个方向"] | chip 内容 == 通用选项，不猜测具体内容 | boundary | active |
| OPT-003 | [OPTIONS:] 优先于通用回退 | AI 回复包含 [OPTIONS:] | 显示 [OPTIONS:] 内容，非通用选项 | chip 内容 == [OPTIONS:] 内容 | regression | active |

## Notes
- 核心原则：所有选项必须来自 AI 的 [OPTIONS:] 标记
- 客户端不做任何选项猜测或固定模板回退
- AI 未输出 [OPTIONS:] 时，UI 不展示任何选项，用户手动打字
- 如果频繁出现无选项情况，应加强 AI prompt 而非回退到客户端匹配
