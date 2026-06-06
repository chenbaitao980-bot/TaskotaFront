-- migration_010: 补全远端索引，加速 sync 查询
-- 执行方式：Supabase Management API 或 Dashboard SQL Editor

-- user_tasks
CREATE INDEX IF NOT EXISTS idx_user_tasks_user_id ON public.user_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_user_tasks_user_deleted ON public.user_tasks(user_id, deleted);
CREATE INDEX IF NOT EXISTS idx_user_tasks_user_updated ON public.user_tasks(user_id, updated_at);

-- checklist_items
CREATE INDEX IF NOT EXISTS idx_checklist_items_user_id ON public.checklist_items(user_id);
CREATE INDEX IF NOT EXISTS idx_checklist_items_task_id ON public.checklist_items(task_id);
CREATE INDEX IF NOT EXISTS idx_checklist_items_user_updated ON public.checklist_items(user_id, updated_at);

-- projects
CREATE INDEX IF NOT EXISTS idx_projects_user_updated ON public.projects(user_id, updated_at);

-- project_groups
CREATE INDEX IF NOT EXISTS idx_project_groups_user_updated ON public.project_groups(user_id, updated_at);

-- task_attachments
CREATE INDEX IF NOT EXISTS idx_task_attachments_user ON public.task_attachments(user_id);
CREATE INDEX IF NOT EXISTS idx_task_attachments_task ON public.task_attachments(task_id);
