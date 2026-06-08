# 支付宝当面付上线

## Goal

个体工商户执照已到手，激活支付宝商家账号，配置 Supabase 环境变量，上线支付功能。

**代码已完整实现，零代码改动，只需配置 4 个环境变量。**

## 前置条件

- [x] 代码已实现：`lib/services/payment_service.dart`、`supabase/functions/_shared/alipay.ts` 等
- [x] 个体工商户执照已到手
- [ ] 支付宝开放平台账号已注册并完成商家实名认证
- [ ] 当面付能力已开通（审核 1-3 个工作日）
- [ ] 已获取 4 个凭证：AppID、应用私钥、支付宝公钥、回调 URL

## 用户手动步骤（需在支付宝开放平台操作）

### 第 1 步：注册支付宝商家账号

1. 打开支付宝 App → 我的 → 商家服务 → 入驻商家
2. 或直接访问 `open.alipay.com` → 注册
3. 选择**个体工商户**主体类型
4. 上传：营业执照 + 法人身份证正反面
5. 等待实名认证审核（通常当日完成）

### 第 2 步：创建应用，申请当面付

1. 登录 `open.alipay.com` → 控制台 → 网页&移动应用 → 创建应用
2. 应用类型选「网页应用」（服务端调用）
3. 进入应用 → 产品绑定 → 搜索"当面付" → 申请
4. 填写业务场景说明（如：任务管理 App 会员订阅收款）
5. 等待审核（1-3 个工作日）

### 第 3 步：配置密钥，获取凭证

1. 进入应用 → 开发设置 → 接口加签方式
2. 选择「公钥模式」
3. 使用支付宝官方密钥生成工具生成 RSA2 密钥对（PKCS8 格式）
   - 工具下载：`https://opendocs.alipay.com/open/291/106097`
4. 将**应用公钥**上传到支付宝开放平台
5. 保存以下信息（传给 AI 用于配置）：
   - `ALIPAY_APP_ID`：应用 APPID（16位数字）
   - `ALIPAY_PRIVATE_KEY`：应用**私钥**（PKCS8格式，-----BEGIN PRIVATE KEY----- 开头）
   - `ALIPAY_PUBLIC_KEY`：支付宝**公钥**（非应用公钥，在"查看支付宝公钥"里）
   - `ALIPAY_NOTIFY_URL`：`https://wlehkvsxftyxmxelcaps.supabase.co/functions/v1/alipay-notify`

### 第 4 步：白名单配置

在应用 → 开发设置 → 服务器域名白名单 中添加：
```
wlehkvsxftyxmxelcaps.supabase.co
```

## AI 实施步骤（持凭证后执行）

### 1. 配置 Supabase Secrets

```bash
supabase secrets set --project-ref wlehkvsxftyxmxelcaps \
  ALIPAY_APP_ID=<用户提供> \
  ALIPAY_PRIVATE_KEY=<用户提供> \
  ALIPAY_PUBLIC_KEY=<用户提供> \
  ALIPAY_GATEWAY=https://openapi.alipay.com/gateway.do \
  ALIPAY_NOTIFY_URL=https://wlehkvsxftyxmxelcaps.supabase.co/functions/v1/alipay-notify
```

### 2. 验证 Edge Function 能正常调用

通过 `create-order` Edge Function 创建一个测试订单，确认返回 qr_code。

### 3. Flutter 端冒烟测试

在测试设备上点击「开通VIP」→ 扫码支付 → 确认订单状态更新。

## 涉及文件（仅供参考，无需改动）

- `lib/services/payment_service.dart` — 前端支付服务
- `lib/presentation/pages/profile/vip_page.dart` — VIP 购买 UI
- `supabase/functions/_shared/alipay.ts` — 支付宝签名/调用
- `supabase/functions/create-order/index.ts` — 创建订单
- `supabase/functions/alipay-notify/index.ts` — 支付回调
- `supabase/functions/order-status/index.ts` — 查询状态

## 完成标准

- [ ] Supabase Secrets 4 个变量已配置
- [ ] `create-order` 接口返回二维码（qr_code 字段非空）
- [ ] 扫码支付 → `alipay-notify` 收到回调 → 用户订阅状态变更为 vip
- [ ] `order-status` 轮询正常工作

## Technical Notes

- Supabase 项目: `wlehkvsxftyxmxelcaps.supabase.co`
- 支付宝网关: `https://openapi.alipay.com/gateway.do`（正式环境）
- 沙箱网关: `https://openapi.sandbox.alipaydev.com/gateway.do`（测试用）
- 回调 URL 必须是公网可访问的 HTTPS，Supabase Edge Functions 满足条件
