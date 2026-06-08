# 支付宝配置管理后台 + 上线支付功能

## Goal

在 `taskora-website` 管理后台新增支付宝配置 section，管理员可通过 Web UI 填写并保存支付宝凭证。`smart_assistant` 的 Edge Functions 从 Supabase `app_config` 表读取凭证，完成支付宝当面付上线。**凭证仅存数据库，不保留 env var 兜底。**

## Requirements

- 新建 Supabase 表 `app_config`（key-value 结构），RLS 限制只有认证管理员可读写
- `smart_assistant/supabase/functions/_shared/alipay.ts` 改为从 `app_config` 表读取凭证，表为空时抛出明确错误
- `taskora-website/src/pages/admin.astro` 新增"支付配置"section，含 3 个输入框：
  - 支付宝 AppID
  - 应用私钥（PKCS8，textarea，显示为密码框）
  - 支付宝公钥（textarea）
- 点击保存后写入 `app_config` 表，页面加载时读取当前值回填（私钥仅显示是否已设置，不回显原文）

## Acceptance Criteria

- [ ] `app_config` 表已在 Supabase 创建，RLS 策略正确
- [ ] 管理后台支付配置 section 可正常保存凭证
- [ ] 私钥字段保存后回填显示为 `••••••••（已设置）`，不显示原文
- [ ] `create-order` Edge Function 成功从表读取凭证并返回二维码
- [ ] 凭证未配置时 `create-order` 返回明确错误（非 500 崩溃）

## Definition of Done

- flutter analyze 无 error（smart_assistant 无 Dart 改动，跳过）
- `taskora-website` TypeScript 无 type error
- Supabase Edge Functions 本地 `deno check` 通过

## Technical Approach

### 数据库表结构

```sql
CREATE TABLE app_config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- RLS: 只有 authenticated 用户可读写（管理员登录后才能操作）
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin only" ON app_config
  FOR ALL USING (auth.role() = 'authenticated');
```

写入的 key：
- `alipay_app_id`
- `alipay_private_key`
- `alipay_public_key`
- `alipay_gateway`（固定值 `https://openapi.alipay.com/gateway.do`）
- `alipay_notify_url`（固定值 `https://wlehkvsxftyxmxelcaps.supabase.co/functions/v1/alipay-notify`）

### alipay.ts 改造

```typescript
// 原来
const appId = Deno.env.get('ALIPAY_APP_ID')!

// 改为（在 createAlipayClient() 或每次调用前）
const { data } = await supabase.from('app_config').select('key,value')
const config = Object.fromEntries(data.map(r => [r.key, r.value]))
if (!config.alipay_app_id) throw new Error('支付宝凭证未配置，请在管理后台设置')
```

### 管理后台 UI

- 在 `admin.astro` 现有 section 列表末尾追加"支付配置"卡片
- 样式与现有 download_links 表单保持一致
- 私钥/公钥用 `<textarea type="password">` + CSS `-webkit-text-security: disc` 遮盖显示

## Decision (ADR-lite)

**Context**: 凭证需要可通过 Web UI 动态更新，无需 CLI 操作  
**Decision**: 存 Supabase `app_config` 表（key-value），不保留 env var 兜底  
**Consequences**: 实现简单，和现有 download_links 模式一致；首次部署后必须从管理后台填写凭证才能收款

## Out of Scope

- 凭证加密存储（RLS 已保护，暂不做应用层加密）
- 沙箱环境切换（仅支持正式环境）
- 支付记录查看（管理后台本期不做）
- 微信支付等其他支付方式

## Technical Notes

- Supabase 项目: `wlehkvsxftyxmxelcaps.supabase.co`
- `smart_assistant/supabase/functions/_shared/alipay.ts` — 凭证读取入口
- `smart_assistant/supabase/functions/create-order/index.ts` — 主调用方
- `taskora-website/src/pages/admin.astro` — 现有管理页，追加 section
- `taskora-website/src/pages/api/upload-url.ts` — 现有 API route 参考模式
- 两个项目共用同一 Supabase 项目，`app_config` 表对两者可见
