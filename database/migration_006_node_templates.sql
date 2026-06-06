-- 目的：节点模板双端同步。模板复用时会填充新节点的描述、检查项、图片和子任务。
-- 执行方式：Supabase Management API / Dashboard SQL Editor

CREATE TABLE IF NOT EXISTS public.node_templates (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  priority integer NOT NULL DEFAULT 1,
  checklist jsonb NOT NULL DEFAULT '[]'::jsonb,
  images jsonb NOT NULL DEFAULT '[]'::jsonb,
  subtasks jsonb NOT NULL DEFAULT '[]'::jsonb,
  deleted integer NOT NULL DEFAULT 0,
  created_at bigint NOT NULL,
  updated_at bigint NOT NULL
);

ALTER TABLE public.node_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.node_templates REPLICA IDENTITY FULL;

DROP POLICY IF EXISTS "Users can only access own node templates" ON public.node_templates;
CREATE POLICY "Users can only access own node templates"
  ON public.node_templates
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_node_templates_user_updated
  ON public.node_templates(user_id, updated_at DESC);

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.node_templates;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
