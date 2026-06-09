# 后台管理UI改进：折扣码表单体验优化

## Goal

将折扣码表单的"适用会员类型 ID"字段从手填 UUID 改为下拉选择器（从已加载的 `allTypes` 读取），同时优化折扣码字段的输入体验。消除管理员需要知道内部 UUID 的操作障碍。

## What I already know

- `allTypes: MemberType[]` 在 `loadTypes()` 完成后已存入内存，含 `id` 和 `name`
- 折扣码表单 HTML：`members.astro` 第 128-153 行
- 会员类型下拉改造只需：① HTML 改 `<select>` ② `showDiscountForm()` 中重新填充 options ③ submit 时读 select.value 而不是 input.value
- 表格展示列已有 `allTypes.find(t => t.id === c.type_id)?.name` 逻辑（第 503 行）
- 文件：`taskora-website/src/pages/admin/members.astro`

## Requirements

- [ ] "适用会员类型"字段改为 `<select>` 下拉，选项从 `allTypes` 动态填充，首选项为"全部适用"（值为空）
- [ ] 编辑已有折扣码时，下拉默认选中对应的会员类型
- [ ] 折扣码输入体验优化（待决策，见 Open Questions）

## Acceptance Criteria

- [ ] 添加折扣码时，"适用会员类型"下拉显示所有已配置的会员类型名称
- [ ] 选择"全部适用"时，`type_id` 存 `null`（与现有行为一致）
- [ ] 编辑现有折扣码，下拉自动选中正确的会员类型
- [ ] 折扣码字段优化后管理员操作步骤更少

## Open Questions

- **折扣码字段**：应保留手动输入，还是添加「自动生成」按钮/行为？（待用户决策）

## Out of Scope

- 修改 `member_discount_codes` 数据库表结构
- 折扣码使用记录/统计功能
- 充值梯度、会员类型其他字段的改动

## Technical Notes

- `taskora-website/src/pages/admin/members.astro` 第 128-153 行：折扣码表单 HTML
- 第 243 行：`let allTypes: MemberType[] = []`（已在内存中）
- 第 549-567 行：`showDiscountForm()` — 需要在此填充 select options
- 第 585-592 行：submit 逻辑读取 `discount-type-id`，改为读 select.value 即可
- 无需改动后端 API（字段名 `type_id` 不变）
