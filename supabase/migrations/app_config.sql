-- 应用全局配置表（key-value 结构）
-- 用于存储支付宝凭证等动态配置，管理员通过后台 UI 更新
CREATE TABLE IF NOT EXISTS public.app_config (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- 已登录用户（管理员）可读写；Edge Function 使用 service_role 绕过 RLS
CREATE POLICY "authenticated can read write app_config"
  ON public.app_config
  FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');
