# 首页任务详情可编辑描述

## Goal

首页时间轴选中任务后，详情卡片中的描述区域能直接编辑，空描述时也应显示可编辑区域而不是完全隐藏。

## Requirements

- 首页任务详情卡片始终显示描述编辑区域（不因描述为空而隐藏）
- 描述为空时显示占位提示"添加描述..."
- 支持直接输入、按描述节流自动保存（已有逻辑不变）

## Acceptance Criteria

- [ ] 任务无描述时，详情卡片显示可编辑区域 + 占位提示
- [ ] 输入描述后 blur 或等 600ms 自动保存到数据库
- [ ] 清空描述后再次查看，仍显示可编辑区域（不是隐藏）

## Definition of Done

- [ ] lint 无新增 warning/error
- [ ] dart analyze 无新增 issue

## Technical Approach

- 移除 `_buildTaskDetail()` 中描述区域的 `if (task.description != null && task.description!.isNotEmpty)` 守卫条件
- 在 `_buildDescriptionBox()` 的 `InputDecoration` 中添加 `hintText: '添加描述...'`
- `hintStyle` 使用 `AppTheme.textHint` 颜色

## Out of Scope

- 不涉及 Markdown 渲染切换（首页用纯文本编辑、任务详情页用 MarkdownDescriptionSection）
- 不涉及图片附件编辑（已有逻辑不变）
