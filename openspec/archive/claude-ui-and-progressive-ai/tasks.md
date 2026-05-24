# 任务：claude-ui-and-progressive-ai

## 实施

### UI 配色改造（已完成）
- [x] 1-8. 配色全面替换为 Claude 暖橙暗色系

### FAB 简化（纯图标）
- [x] 9. `home_page.dart`：FAB 改为条件渲染，仅首页可见
- [x] 14. `home_page.dart`：`FloatingActionButton.extended` → `FloatingActionButton`，去掉「新建」文字，仅保留「+」图标

### AI 渐进式对话
- [x] 10. `ai_service.dart`：改造 Prompt 为分步引导模式
- [x] 11. `ai_chat_page.dart`：添加快捷选项 Chip 区域
- [x] 12. `ai_chat_page.dart`：重构对话流为多轮渐进式
- [x] 13. `ai_chat_page.dart`：添加确认卡片组件
- [x] 15. `ai_chat_page.dart`：AI 提问时自动显示建议回复按钮（关键词检测 → 生成选项）

### 本轮修复
- [x] 16. `ai_chat_page.dart`：`_generateSuggestions` 关键词顺序改为时间优先于水平
- [x] 17. `home_page.dart`：`_buildTodayOverview` 移除「进行中」统计
- [x] 18. `home_page.dart`：`_loadStats` 按今日过滤 + 移除 inProgress
- [x] 19. `ai_chat_page.dart`：`_generateSuggestions` 彻底修复——移除泛化'时间'关键词，目标优先，仅匹配具体时间单位

## 验证
- [ ] AI 回复"想达到什么程度？有没有一个大致的时间期望" → 显示目标选项（非时间选项）
- [ ] 首页今日概览仅显示「待办」和「已完成」
- [ ] 待办和已完成计数限定为今日数据
- [x] `flutter analyze` 无 error（仅预存 deprecation info）
