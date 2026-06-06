# VIP 支付宝扫码支付 — 部署指南

## 一、支付宝开放平台配置

### 1. 注册/登录
https://open.alipay.com

### 2. 创建应用
- 控制台 → 创建应用 → 选择"网页&移动应用"
- 记录 **AppID**

### 3. 开通能力
- 应用详情 → 产品绑定 → 开通"当面付"

### 4. 设置密钥
- 应用详情 → 开发设置 → 接口加签方式
- 选择 **RSA2(SHA256)**
- 生成密钥对（推荐用支付宝开放平台密钥工具）
- 上传**应用公钥**到支付宝
- 记录：
  - **应用私钥**（PKCS8 格式 PEM）
  - **支付宝公钥**（支付宝平台自动生成，点"查看"获取）

## 二、Supabase 数据库

在 Supabase SQL Editor 中依次执行：
```
database/migration_007_subscriptions.sql
database/migration_008_payment_orders.sql
```

## 三、Supabase Edge Function 部署

### 1. 安装 Supabase CLI
```bash
npm install -g supabase
```

### 2. 登录
```bash
supabase login
```

### 3. 关联项目
```bash
cd smart_assistant
supabase link --project-ref wlehkvsxftyxmxelcaps
```

### 4. 设置环境变量（密钥）
```bash
# 支付宝配置
supabase secrets set ALIPAY_APP_ID="你的AppID"
supabase secrets set ALIPAY_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n你的私钥内容\n-----END PRIVATE KEY-----"
supabase secrets set ALIPAY_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----\n支付宝公钥内容\n-----END PUBLIC KEY-----"
supabase secrets set ALIPAY_GATEWAY="https://openapi.alipay.com/gateway.do"
supabase secrets set ALIPAY_NOTIFY_URL="https://wlehkvsxftyxmxelcaps.supabase.co/functions/v1/alipay-notify"
```

> **注意**：密钥中的换行用 `\n` 表示，整个值用双引号包裹。
> **沙箱测试**：开发阶段可将 ALIPAY_GATEWAY 改为 `https://openapi-sandbox.dl.alipaydev.com/gateway.do`

### 5. 部署 Edge Functions
```bash
supabase functions deploy create-order
supabase functions deploy alipay-notify --no-verify-jwt
supabase functions deploy order-status
```

> `alipay-notify` 需要 `--no-verify-jwt`，因为支付宝回调不带 JWT。

### 6. 验证
```bash
# 测试创建订单（需要有效的 JWT token）
curl -X POST https://wlehkvsxftyxmxelcaps.supabase.co/functions/v1/create-order \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"plan": "vip_monthly"}'
```

## 四、支付流程

```
用户 → VipPage 选择套餐 → 点击"支付宝扫码支付"
  → 客户端调用 create-order Edge Function
  → Edge Function 调用 alipay.trade.precreate → 返回二维码 URL
  → 客户端显示二维码（qr_flutter）
  → 用户打开支付宝 App 扫码
  → 客户端每 3 秒轮询 order-status
  → 支付宝异步通知 alipay-notify → 验签 → 更新 user_subscriptions
  → 客户端检测到 paid → 刷新 VIP 状态 → 返回 VipPage
```

## 五、文件清单

| 文件 | 说明 |
|-----|------|
| `supabase/functions/_shared/alipay.ts` | 支付宝 SDK：签名/验签/当面付/查询 |
| `supabase/functions/_shared/supabase.ts` | Supabase service client 工具 |
| `supabase/functions/create-order/index.ts` | 创建订单，返回二维码 |
| `supabase/functions/alipay-notify/index.ts` | 支付宝异步回调，验签+激活VIP |
| `supabase/functions/order-status/index.ts` | 查询订单支付状态 |
| `database/migration_007_subscriptions.sql` | 订阅表 |
| `database/migration_008_payment_orders.sql` | 订单表 |
| `lib/services/payment_service.dart` | 客户端支付服务 |
| `lib/presentation/pages/profile/vip_page.dart` | VIP页面+二维码支付 |
