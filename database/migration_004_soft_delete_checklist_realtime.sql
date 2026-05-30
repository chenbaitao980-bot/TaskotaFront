-- migration_004: 软删除墓石列 + checklist_items 上云 + Realtime publication
-- 目的：全部业务数据双端同步（tasks/projects/project_groups/checklist_items/task_attachments），
--       统一软删除（deleted 墓石）+ 双向 LWW 对账，删除靠墓石传播不复活。
-- 执行方式：Supabase Management API
--   POST https://api.supabase.com/v1/projects/<PROJECT_REF>/database/query
--   Authorization: Bearer <sbp token>（token 不入库）

-- 1) 为既有表添加 deleted 墓石列
ALTER TABLE public.user_tasks       ADD COLUMN IF NOT EXISTS deleted int NOT NULL DEFAULT 0;
ALTER TABLE public.projects         ADD COLUMN IF NOT EXISTS deleted int NOT NULL DEFAULT 0;
ALTER TABLE public.project_groups   ADD COLUMN IF NOT EXISTS deleted int NOT NULL DEFAULT 0;

-- 2) 新建 checklist_items 云表
CREATE TABLE IF NOT EXISTS public.checklist_items (
  id             text PRIMARY KEY,
  user_id        uuid NOT NULL,
  task_id        text NOT NULL,
  title          text NOT NULL DEFAULT '',
  status         int  NOT NULL DEFAULT 0,
  sort_order     int  NOT NULL DEFAULT 0,
  obsidian_uri   text,
  completed_time bigint,
  deleted        int  NOT NULL DEFAULT 0,
  created_at     bigint NOT NULL,
  updated_at     bigint NOT NULL
);

-- 3) RLS：仅本人可读写
ALTER TABLE public.checklist_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS checklist_items_select ON public.checklist_items;
DROP POLICY IF EXISTS checklist_items_insert ON public.checklist_items;
DROP POLICY IF EXISTS checklist_items_update ON public.checklist_items;
DROP POLICY IF EXISTS checklist_items_delete ON public.checklist_items;

CREATE POLICY checklist_items_select ON public.checklist_items
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY checklist_items_insert ON public.checklist_items
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY checklist_items_update ON public.checklist_items
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY checklist_items_delete ON public.checklist_items
  FOR DELETE USING (auth.uid() = user_id);

-- 4) Realtime：DELETE 事件携带完整旧记录 + 加入 publication
ALTER TABLE public.checklist_items REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.checklist_items;

-- 5) 阶段0 清空全部业务数据（不可逆）
DELETE FROM public.user_tasks;
DELETE FROM public.task_attachments;
DELETE FROM public.projects;
DELETE FROM public.project_groups;
-- checklist_items 新建即空，无需 DELETE
