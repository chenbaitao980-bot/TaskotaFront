# 设计：fix-task-planning-over-fragmentation

## 需求澄清依据
已确认目标：
1. 用户提出任务安排且AI无法准确判定时间范围时，弹出时间范围选择框强制用户选择
2. AI监测到话题切换时，先让用户确认是否开启新上下文，并增加主动清空上下文按钮

## 当前状态
- `ai_service.dart` System Prompt 要求AI对所有目标类输入都进行多阶段拆解，缺乏时间范围确认机制
- `ai_chat_page.dart` 话题切换检测 `_detectTopicDrift()` 过于敏感，检测到即清空历史，无用户确认

## 方案

### 方案一：时间范围确认机制

**AI Prompt 修改**：
- 增加规则：当用户输入的目标/愿望**没有明确时间范围**时，AI 返回 `{"type": "time_range_request", "message": "你想在多长时间内完成？", "options": ["1天内", "1周内", "1个月内", "3个月内"]}`
- 当用户输入包含"明天、下周、这周末、X月X日"等明确时间词时，直接按现有流程处理
- 用户选择时间范围后，将选择结果追加到对话历史，再次调用 AI 生成计划

**前端修改**：
- 在 `_handleAIResponse()` 中检测 `type == "time_range_request"`
- 弹出 `_TimeRangePickerDialog`，用户选择后再次调用 AI
- 已有明确时间则不弹出选择框

### 方案二：话题切换确认 + 主动清空上下文

**话题检测调整**：
- 修改 `_detectTopicDrift()`，检测到潜在切换时**不立即清空历史**，而是设置 `_pendingTopicSwitch = true`
- AI 回复改为：`{"type": "topic_switch_confirm", "message": "检测到新话题，是否开启新对话？", "options": ["开启新对话", "继续当前话题"]}`

**用户选择处理**：
- 选"开启新对话" → 清空 `_messages` 历史，重新初始化
- 选"继续当前话题" → 保持历史，正常回复

**主动清空按钮**：
- 在 AppBar 右侧增加 "🗑️ 清空上下文" 按钮
- 点击后弹出确认对话框，确认后清空历史

## 业务规则处理
- 原 Requirement / Scenario：无
- 本次处理方式：MODIFIED

## 回归测试方案
- 用例文件：`regression-tests/cases/fix-task-planning-over-fragmentation.md`
- 批量测试接口 / 命令：TBD

## 回滚方案
删除 `openspec/changes/fix-task-planning-over-fragmentation/` 目录。
