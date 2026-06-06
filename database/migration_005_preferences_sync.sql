-- Taskora - 用户偏好云同步表
-- 使用方法：登录 Supabase Dashboard → SQL Editor → 粘贴此脚本 → 运行

CREATE TABLE IF NOT EXISTS public.app_preferences_sync (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    preferences_data JSONB NOT NULL DEFAULT '{}',
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.app_preferences_sync ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can only access own preferences" ON public.app_preferences_sync;
CREATE POLICY "Users can only access own preferences"
    ON public.app_preferences_sync
    FOR ALL
    USING (auth.uid() = user_id);

-- 验证
SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = 'app_preferences_sync'
) AS table_created;
