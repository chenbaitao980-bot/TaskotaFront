-- 支付订单表
CREATE TABLE IF NOT EXISTS public.payment_orders (
  out_trade_no  TEXT PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan          TEXT NOT NULL,
  amount        TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending',  -- pending / paid / closed
  expires_at    TIMESTAMPTZ,
  trade_no      TEXT,       -- 支付宝交易号，支付成功后填入
  paid_at       TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_orders_user_id ON public.payment_orders (user_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_status  ON public.payment_orders (status);

ALTER TABLE public.payment_orders ENABLE ROW LEVEL SECURITY;
-- 用户只能查自己的订单；Edge Function 使用 service_role 绕过 RLS
CREATE POLICY "users can read own orders"
  ON public.payment_orders FOR SELECT
  USING (auth.uid() = user_id);

-- VIP 订阅表（每用户一条，upsert 更新）
CREATE TABLE IF NOT EXISTS public.user_subscriptions (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  plan            TEXT NOT NULL DEFAULT 'free',
  status          TEXT NOT NULL DEFAULT 'active',   -- active / expired / cancelled
  started_at      TIMESTAMPTZ,
  expires_at      TIMESTAMPTZ,
  payment_channel TEXT,
  transaction_id  TEXT,
  auto_renew      BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users can read own subscription"
  ON public.user_subscriptions FOR SELECT
  USING (auth.uid() = user_id);
