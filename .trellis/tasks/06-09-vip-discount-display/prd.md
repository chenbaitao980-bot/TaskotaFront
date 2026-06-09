# VIP页面展示折扣信息+折扣说明字段

## Goal

在 VIP 购买页面自动展示后台配置的折扣信息（不需要用户手动输入折扣码），同时为折扣码增加"折扣说明"字段，向用户解释为什么能享受折扣。

## Requirements

* `member_discount_codes` 表新增 `description` 文本字段（nullable）
* `DiscountCodeConfig` Flutter 模型新增 `description` 字段
* VIP 页面：按所选套餐的 `type_id` 自动匹配可用折扣，在套餐卡片上展示：
  - 折扣徽标（如：九折）
  - 折扣说明（`description` 字段内容）
  - 原价划线 + 折后价
* 管理后台（`members.astro`）折扣码表单新增"折扣说明"输入框
* 支付金额本次不变（纯展示，不传折扣码到 `createOrder`）

## Acceptance Criteria

* [ ] Supabase `member_discount_codes` 表有 `description` 列
* [ ] Flutter `DiscountCodeConfig` 读取并暴露 `description`
* [ ] VIP 页面月度/年度套餐卡片在有匹配折扣时展示折扣徽标 + 说明 + 折后价
* [ ] 无折扣时展示正常不变
* [ ] 管理后台折扣码表单含折扣说明输入框，保存/编辑时传递该字段

## Definition of Done

* flutter analyze 无 error
* `taskora-website` TypeScript 无 type error（需 npm run build 或 astro check）

## Technical Approach

* 后端：Supabase `member_discount_codes` 加 `description` 列；edge function 已用 `select("*")` 自动透传
* Flutter：`DiscountCodeConfig.fromJson` 加 `description`；VIP 页面 `_buildPlanSelector` 查找匹配折扣并传给 `_PlanCard`
* 折扣匹配逻辑：先取当前计划类型 `MemberTypeConfig.id`，在 `MemberConfigService.discountCodes` 里找 `typeId == planTypeId || typeId == null`，取第一个
* Admin：在折扣码表单加"折扣说明"文本框，buildRow/renderForm 同步更新

## Out of Scope

* 折扣码自动应用到支付金额（本次只展示）
* 多折扣叠加逻辑
