-- Migration 009: 用户反馈表（配合官网反馈页）
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS user_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nickname TEXT,
  contact TEXT,
  category TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE user_feedback ENABLE ROW LEVEL SECURITY;

-- 匿名可插入，不可读取（只有 service_role 可读）
CREATE POLICY "Anyone can insert feedback"
  ON user_feedback FOR INSERT
  WITH CHECK (true);
