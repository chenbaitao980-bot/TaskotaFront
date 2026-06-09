# 时间选择分钟支持手动输入

## Goal

`calendar_date_picker.dart` 中的分钟选择器目前只能从 12 个固定选项（0/5/10…55）中选择。用户需要能手动输入任意分钟值（0–59），例如想设置 8:37 这样的精确时间。

## Requirements

* 将分钟 `DropdownButton` 替换为可编辑 `TextField`，显示当前分钟值（两位数，补零）
* 支持手动输入 0–59 的任意整数
* 旁边提供 ▲▼ 按钮，每次步进 ±1 分钟（边界循环：59→0，0→59）
* 失焦时自动校验：空值或非法值 → 重置为 0；超出范围 → clamp 到 0–59
* 小时下拉框不变

## Acceptance Criteria

* [ ] 分钟区域显示为可编辑文本框（两位数格式）
* [ ] 用户可直接输入 0–59 的任意值
* [ ] ▲ 按钮 +1 分钟（59 → 0）
* [ ] ▼ 按钮 -1 分钟（0 → 59）
* [ ] 输入非法值（超范围/空）失焦时自动纠正
* [ ] 时/分之间的冒号分隔符保留，整体布局不破坏

## Definition of Done

* Lint / 类型检查通过
* 手动测试：直接输入 37，确认结果为 37 分；输入 99 失焦后变为 0

## Technical Approach

修改 `lib/presentation/widgets/calendar_date_picker.dart`：

1. 新增 `_minuteController`（`TextEditingController`）
2. 在 `initState` 中初始化，`dispose` 中释放
3. `_buildTimeRow` 中：用 `Row(▲ / TextField / ▼)` 替换原分钟 `_timeDropdown` 调用
4. TextField `onChanged`：尝试 parse，合法则实时更新 `_selectedMinute`
5. TextField `onEditingComplete` / `onTapOutside`：clamp + 格式化回显

## Decision (ADR-lite)

**Context**: 需要兼顾"快速步进"和"任意值输入"两种场景  
**Decision**: 方案 1 — TextField + ▲▼ 步进按钮，移除原下拉  
**Consequences**: 失去 5 分钟快选便捷性；换来任意精度

## Out of Scope

* 小时字段手动输入（保持下拉）
* 键盘上下箭头监听
* 鼠标滚轮调节

## Technical Notes

* 文件：`lib/presentation/widgets/calendar_date_picker.dart`
* `_minuteOptions` 列表可保留或移除（移除更干净）
* `_selectedMinute` 初始化逻辑（吸附到 5 分钟）：保留，因为从外部传入的时间仍可能是 5 分钟档；用户打开后可自行修改
