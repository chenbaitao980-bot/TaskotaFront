# brainstorm: 接入支付宝支付系统调研

## Goal

调研项目当前支付系统状态，以及在没有个体工商户执照的情况下，如何合法低成本地接入支付宝（或其他支付渠道）。

## What I already know

### 项目现状（已从代码库确认）

**项目已完整实现支付宝当面付（扫码支付）！**

- `lib/services/payment_service.dart` — 前端支付服务：创建订单、查询状态、轮询状态流
- `lib/presentation/pages/profile/vip_page.dart` — VIP购买页：支付宝扫码支付 UI，月度¥9.9/年度¥68
- `lib/models/entities/user_subscription.dart` — 订阅模型：free/vip_monthly/vip_yearly
- `supabase/functions/_shared/alipay.ts` — 支付宝 SDK（Deno版）：RSA2签名、当面付precreate、查询
- `supabase/functions/create-order/index.ts` — 创建订单 Edge Function
- `supabase/functions/alipay-notify/index.ts` — 支付宝回调通知
- `supabase/functions/order-status/index.ts` — 查询订单状态

技术方案：支付宝「当面付」扫码支付，需要以下环境变量：
- `ALIPAY_APP_ID`
- `ALIPAY_PRIVATE_KEY` (PKCS8格式)
- `ALIPAY_PUBLIC_KEY`
- `ALIPAY_GATEWAY`
- `ALIPAY_NOTIFY_URL`

### 核心问题

代码已写好，**但尚不清楚是否已配置好支付宝商户账号并实际可用**。

## Open Questions

1. 支付宝当面付需要什么资质？个人（无营业执照）能否申请？
2. 没有个体工商户执照的情况下，有哪些替代方案？成本如何？
3. 当前 Supabase 环境变量是否已配置（ALIPAY_APP_ID 等）？

## Requirements (evolving)

- 了解支付宝当面付的资质要求
- 了解个人开发者可用的支付接入方案
- 确定最低成本、最快接入路径

## Technical Notes

- 现有代码完全针对支付宝当面付实现，如要换方案需评估改动范围
- 套餐：月度VIP ¥9.9，年度VIP ¥68
- Supabase Edge Functions 部署在海外，需确认支付宝回调能否正常到达

## Research References

* [`research/alipay-personal-requirements.md`](research/alipay-personal-requirements.md) — 当面付需营业执照；个体户可申请；办照约1周；0手续费
* [`research/payment-alternatives.md`](research/payment-alternatives.md) — 虎皮椒可无执照接入(~1%手续费)；爱发电最快但8%；推荐先办执照用现有代码

## Decision (ADR-lite)

**Context**: 项目代码已完整实现支付宝当面付，但需要营业执照才能激活商户账号。

**推荐路径**：
- **立即合规（推荐）**：办个体工商户执照（约1周）→ 配置4个环境变量 → 直接上线，代码零改动，0手续费
- **快速临时**：接入虎皮椒（2-3天开发）→ 后续迁移到正规支付宝

**Consequences**: 办执照路径一次性解决合规问题，且项目代码完全复用；虎皮椒属灰色地带，存在封号风险。
