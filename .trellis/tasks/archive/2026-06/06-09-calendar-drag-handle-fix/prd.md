# 优化日历拖拽把手触发区域

## Goal

桌面端日历单日任务的上下拖拽把手热区太小，导致用户频繁错过把手，误触发整个日历的拖拽移动。需要扩大热区并修复手势竞争问题。

## What I already know

- 热区定义在 `calendar_page.dart:2463-2518`（_ResizableTaskBlock 的 Stack 顶层）
- **桌面当前热区**：
  - 顶部：高 8px，top: 0（不超出 block 顶边，完全在 block 内部）
  - 底部：高 16px，bottom: -8px（仅 8px 超出 block 底边）
- **移动端编辑模式热区**（对比参考）：
  - 顶部：高 32px，top: -16（上下各 16px）
  - 底部：高 32px，bottom: -16
- **HitTestBehavior 问题**：桌面用 `HitTestBehavior.translucent`，事件会透传给父级手势竞争者（日历拖拽），导致 GestureArena 中父级手势赢得竞争；移动端编辑模式用 `HitTestBehavior.opaque` 则没有此问题
- 把手视觉指示器：宽 32px、高 3px 的细线（视觉小，但不是问题所在）

## Root Cause

双重问题：
1. **热区过小**：8px（顶）/ 16px（底，但仅 8px 在 block 外），精确命中概率低
2. **HitTestBehavior.translucent**：命中热区后事件仍透传，父级日历拖拽 Recognizer 与 ResizeHotZone 竞争，父级可能赢得 GestureArena

## Requirements

- [ ] 增大桌面端顶部/底部热区尺寸（具体值 TBD）
- [ ] 将 `HitTestBehavior.translucent` 改为 `HitTestBehavior.opaque`（桌面端也使用）
- [ ] 不改变移动端行为

## Acceptance Criteria

- [ ] 桌面端在任务 block 顶部/底部边缘附近轻松触发 resize，不误触整体移动
- [ ] 移动端行为不变

## Definition of Done

- Lint / typecheck green
- 手动测试：桌面端拖拽把手顺滑触发

## Out of Scope

- 视觉把手外观变更（大小/颜色）
- 移动端行为改动
- 跨日任务把手（左右把手，独立逻辑，未反映此问题）

## Technical Notes

- 文件：`lib/presentation/pages/calendar/calendar_page.dart`
- 热区配置：第 2463-2518 行
- `_ResizeHotZone` 类：第 2655-2699 行
- 关键参数：`_isMobile` 条件分支（false = 桌面）
