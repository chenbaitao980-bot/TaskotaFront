-- Migration 007: VIP 会员订阅表
-- Run this in Supabase SQL Editor

-- 1. 订阅表
CREATE TABLE IF NOT EXISTS user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  plan TEXT NOT NULL DEFAULT 'free',
  status TEXT NOT NULL DEFAULT 'active',
  started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  payment_channel TEXT,
  transaction_id TEXT,
  auto_renew BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. RLS
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own subscription"
  ON user_subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- 写入只允许服务端（service_role），客户端不可直接修改订阅状态

-- 3. updated_at 自动更新
CREATE TRIGGER update_user_subscriptions_updated_at
  BEFORE UPDATE ON user_subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 4. Realtime 启用
ALTER PUBLICATION supabase_realtime ADD TABLE user_subscriptions;
