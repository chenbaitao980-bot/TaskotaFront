-- Migration 008: 支付订单表（配合 VIP 会员支付宝扫码支付）
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS payment_orders (
  out_trade_no TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  plan TEXT NOT NULL,
  amount TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',  -- 'pending' | 'paid' | 'closed'
  trade_no TEXT,                            -- 支付宝交易号
  expires_at TIMESTAMPTZ NOT NULL,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE payment_orders ENABLE ROW LEVEL SECURITY;

-- 用户只能读自己的订单
CREATE POLICY "Users can read own orders"
  ON payment_orders FOR SELECT
  USING (auth.uid() = user_id);

-- 写入只允许服务端
CREATE INDEX idx_payment_orders_user ON payment_orders(user_id);
CREATE INDEX idx_payment_orders_status ON payment_orders(status);
