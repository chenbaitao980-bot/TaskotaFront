-- 微信提醒模块：WxPusher 绑定 + 推送日志
-- 独立模块，不修改现有表

-- 微信绑定表
CREATE TABLE IF NOT EXISTS wechat_bindings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wxpusher_uid TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

ALTER TABLE wechat_bindings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own binding"
  ON wechat_bindings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own binding"
  ON wechat_bindings FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own binding"
  ON wechat_bindings FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Service role can insert bindings"
  ON wechat_bindings FOR INSERT
  WITH CHECK (true);

-- 推送日志表（防重复推送）
CREATE TABLE IF NOT EXISTS wechat_reminder_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  task_id TEXT NOT NULL,
  reminder_type TEXT NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, task_id, reminder_type)
);

-- 定时清理 7 天前的日志
CREATE OR REPLACE FUNCTION clean_old_wechat_logs() RETURNS void AS $$
  DELETE FROM wechat_reminder_log WHERE sent_at < now() - interval '7 days';
$$ LANGUAGE sql;
