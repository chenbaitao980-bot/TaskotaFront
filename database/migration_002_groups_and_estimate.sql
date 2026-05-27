-- Migration 002: 项目分组 + 任务估时
-- 在 Supabase Dashboard → SQL Editor 中运行

-- ==========================================
-- 1. 项目表（云端）
-- ==========================================
CREATE TABLE IF NOT EXISTS public.projects (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color TEXT NOT NULL DEFAULT '#4772FA',
    group_id TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    archived INTEGER NOT NULL DEFAULT 0,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL
);

-- 兼容已存在表
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS group_id TEXT;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS archived INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_projects_user ON public.projects(user_id);

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can only access own projects" ON public.projects;
CREATE POLICY "Users can only access own projects"
    ON public.projects
    FOR ALL
    USING (auth.uid() = user_id);

-- ==========================================
-- 2. 项目分组表
-- ==========================================
CREATE TABLE IF NOT EXISTS public.project_groups (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color TEXT NOT NULL DEFAULT '#4772FA',
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_project_groups_user ON public.project_groups(user_id);

ALTER TABLE public.project_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can only access own project groups" ON public.project_groups;
CREATE POLICY "Users can only access own project groups"
    ON public.project_groups
    FOR ALL
    USING (auth.uid() = user_id);

-- ==========================================
-- 3. user_tasks 加估时字段
-- ==========================================
ALTER TABLE public.user_tasks ADD COLUMN IF NOT EXISTS estimated_minutes INTEGER;

-- ==========================================
-- 4. 启用 Realtime（需在 Dashboard → Database → Publications 中勾选）
-- 此处仅提示，无法通过 SQL 自动启用
-- ==========================================

-- 验证
SELECT
    EXISTS (SELECT FROM information_schema.tables
            WHERE table_schema='public' AND table_name='projects') AS projects_exists,
    EXISTS (SELECT FROM information_schema.tables
            WHERE table_schema='public' AND table_name='project_groups') AS project_groups_exists,
    EXISTS (SELECT FROM information_schema.columns
            WHERE table_schema='public' AND table_name='user_tasks' AND column_name='estimated_minutes')
            AS user_tasks_has_estimate;
