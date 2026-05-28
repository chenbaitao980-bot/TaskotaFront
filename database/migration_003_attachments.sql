-- Migration 003: 附件云同步表 + REPLICA IDENTITY FULL（DELETE 事件携带完整旧记录）
-- 用 Supabase Management API 跑

-- ==========================================
-- 1. 让 DELETE Realtime 事件携带完整旧记录
-- ==========================================
ALTER TABLE public.projects REPLICA IDENTITY FULL;
ALTER TABLE public.project_groups REPLICA IDENTITY FULL;
ALTER TABLE public.user_tasks REPLICA IDENTITY FULL;

-- ==========================================
-- 2. 附件 metadata 表
-- ==========================================
CREATE TABLE IF NOT EXISTS public.task_attachments (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id TEXT NOT NULL,
    file_name TEXT NOT NULL,
    storage_path TEXT NOT NULL,  -- bucket 内的对象 key：<user_id>/<task_id>/<uuid>_<filename>
    size_bytes BIGINT,
    mime_type TEXT,
    added_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_task_attachments_user ON public.task_attachments(user_id);
CREATE INDEX IF NOT EXISTS idx_task_attachments_task ON public.task_attachments(task_id);

ALTER TABLE public.task_attachments REPLICA IDENTITY FULL;
ALTER TABLE public.task_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can only access own attachments" ON public.task_attachments;
CREATE POLICY "Users can only access own attachments"
    ON public.task_attachments
    FOR ALL
    USING (auth.uid() = user_id);

-- 加入 Realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.task_attachments;

-- ==========================================
-- 3. Storage bucket 'task_attachments' RLS
-- bucket 本身用 Management API 建（SQL 不能直接建 bucket）
-- 这里建 RLS policy：用户只能访问自己 user_id 开头的对象
-- ==========================================
DROP POLICY IF EXISTS "Users can upload own attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can read own attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own attachments" ON storage.objects;

CREATE POLICY "Users can upload own attachments"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'task_attachments'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can read own attachments"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'task_attachments'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can delete own attachments"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'task_attachments'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- 验证
SELECT
    EXISTS (SELECT FROM information_schema.tables
            WHERE table_schema='public' AND table_name='task_attachments') AS task_attachments_exists,
    (SELECT relreplident FROM pg_class WHERE relname='project_groups') AS pg_replident,
    (SELECT relreplident FROM pg_class WHERE relname='task_attachments') AS att_replident;
