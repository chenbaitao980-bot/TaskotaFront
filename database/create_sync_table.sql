-- Smart Assistant - 云同步数据表
-- 使用方法：登录 Supabase Dashboard → SQL Editor → 粘贴此脚本 → 运行

-- 本地任务云同步表（存储跨设备同步的任务 JSON 快照）
CREATE TABLE IF NOT EXISTS public.local_task_sync (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tasks_data JSONB NOT NULL DEFAULT '[]',
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.local_task_sync ENABLE ROW LEVEL SECURITY;

-- 允许用户访问自己的同步数据
DROP POLICY IF EXISTS "Users can only access own task sync" ON public.local_task_sync;
CREATE POLICY "Users can only access own task sync"
    ON public.local_task_sync
    FOR ALL
    USING (auth.uid() = user_id);

-- 验证：检查表是否创建成功
SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = 'local_task_sync'
) AS table_created;
