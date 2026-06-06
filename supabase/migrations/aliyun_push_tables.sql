-- 设备注册表：存储阿里云推送 deviceId（每用户最新一台设备）
CREATE TABLE IF NOT EXISTS public.user_devices (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  aliyun_registration_id TEXT NOT NULL,
  platform    TEXT NOT NULL DEFAULT 'android',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id)  -- 每个用户只保留最新设备
);

-- 定时推送队列：记录已调度的推送及阿里云 messageId（用于取消）
CREATE TABLE IF NOT EXISTS public.scheduled_pushes (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  task_id             TEXT NOT NULL,
  title               TEXT NOT NULL,
  body                TEXT NOT NULL,
  scheduled_at        TIMESTAMPTZ NOT NULL,
  aliyun_message_id   TEXT,           -- 阿里云返回的 MessageId，用于取消
  sent_at             TIMESTAMPTZ,    -- 非 NULL 表示已发送（WxPusher cron 去重用）
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, task_id)
);

CREATE INDEX IF NOT EXISTS idx_scheduled_pushes_pending
  ON public.scheduled_pushes (scheduled_at)
  WHERE sent_at IS NULL;

-- RLS：用户只能访问自己的数据
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scheduled_pushes ENABLE ROW LEVEL SECURITY;

-- Edge Function 通过 service_role_key 访问，不受 RLS 限制，无需额外 policy
