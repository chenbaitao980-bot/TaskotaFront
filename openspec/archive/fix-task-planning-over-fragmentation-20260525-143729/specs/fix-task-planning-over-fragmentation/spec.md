# Delta: fix-task-planning-over-fragmentation

## 与主规范关系
New Capability

## 命中的主规范
- Capability: `fix-task-planning-over-fragmentation`
- Requirement: `REQ-001 时间范围确认机制`, `REQ-002 话题切换确认机制`
- Scenario: `SCN-001 用户提出无明确时间范围的任务时弹出时间选择`, `SCN-002 用户切换话题时弹出确认对话框`, `SCN-003 用户主动清空上下文`

## 变更类型
MODIFIED

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | 无 |
| 关系判断 | 新增 |
| 其他 active change 撞车 | 无 |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 是 |
| 归档完整性 | ✅ |

## 原规则
1. AI 对所有目标类输入都进行多阶段拆解，不区分时间范围是否明确
2. 话题切换检测到时立即清空历史，无用户确认
3. 无主动清空上下文按钮

## 新规则
1. **时间范围确认**：当用户输入的目标/愿望没有明确时间范围（不含"明天、下周、X月X日"等时间词）时，AI 返回 `type: "time_range_request"`，前端弹出时间范围选择框。用户选择后，AI 再生成计划。
2. **话题切换确认**：当检测到话题切换时，AI 返回 `type: "topic_switch_confirm"`，前端弹出确认对话框。用户选择"开启新对话"才清空历史，选择"继续当前话题"保持历史。
3. **主动清空上下文**：AppBar 增加"清空上下文"按钮，点击后弹出确认对话框，确认后清空 `_messages` 历史。

## 改动明细

### ai_service.dart
- **位置**：System Prompt 文本
- **改前**：所有目标类输入直接进行多阶段拆解；话题切换检测到时立即清空历史
- **改后**：
  - 增加时间范围判断规则：无明确时间范围时返回 `{"type": "time_range_request", ...}`
  - 增加话题切换确认规则：检测到切换时返回 `{"type": "topic_switch_confirm", ...}`
  - 所有回复增加 `type` 字段（`normal`、`time_range_request`、`topic_switch_confirm`）

### ai_chat_page.dart
- **位置**：`_AiChatPageState` 类
- **改前**：`_handleAIResponse()` 只处理普通消息；`_detectTopicDrift()` 立即清空历史；无清空按钮
- **改后**：
  - 增加 `_showTimeRangePicker()` 方法
  - 增加 `_showTopicSwitchConfirm()` 方法
  - 增加 `_clearContext()` 方法
  - AppBar `actions` 增加清空上下文按钮
  - `_handleAIResponse()` 根据 `type` 字段分发处理
