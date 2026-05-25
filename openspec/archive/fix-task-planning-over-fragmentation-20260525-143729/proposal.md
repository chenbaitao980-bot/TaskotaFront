# fix-task-planning-over-fragmentation

## 需求澄清摘要
已确认目标：
1. 当用户提出任务安排且AI无法准确判定时间范围时，弹出时间范围选择框强制用户选择，AI再分解任务；AI能判断（如"明天几点"）则直接处理
2. AI监测到用户切换话题时，先让用户确认是否开启新上下文，并增加主动清空上下文按钮

## 为什么
用户说"明天做西红柿炒蛋"，AI却拆成5-25到5-28四天的工作量（备菜、烹饪、收尾等），严重过度规划；切换话题说"去踢球"后回复空白消息。根本原因是AI缺乏时间范围确认机制，且话题切换检测过于敏感导致上下文被强制清空。

## 影响面
- `lib/services/ai_service.dart` — System Prompt 增加时间范围请求类型和话题切换确认类型
- `lib/presentation/pages/ai_chat/ai_chat_page.dart` — 增加时间范围选择对话框、话题切换确认对话框、清空上下文按钮

## 业务规范关系
- 命中的主 spec：无
- 关系判断：New Capability
- 推荐动作：MODIFIED

## 改动范围
- `ai_service.dart`：修改 System Prompt，增加 `type` 字段（`time_range_request`、`topic_switch_confirm`、`normal`）
- `ai_chat_page.dart`：
  - 增加 `_showTimeRangePicker()` 方法
  - 增加 `_showTopicSwitchConfirm()` 方法
  - 增加 AppBar 清空上下文按钮
  - 修改 `_handleAIResponse()` 处理新类型

## 验收
- [ ] 实现本次需求的最小改动
- [ ] 已维护 `regression-tests/cases/fix-task-planning-over-fragmentation.md`
- [ ] 已执行 `gitnexus detect-changes`
- [ ] 无异常范围外变更

> 验收项由 AI 在实施中完成并打勾；用户只确认 `tasks.md` 的验证项。
