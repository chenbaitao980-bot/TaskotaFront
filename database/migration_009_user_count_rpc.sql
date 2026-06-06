-- Migration 009: 注册用户数检查 RPC 函数
-- Run this in Supabase SQL Editor

CREATE OR REPLACE FUNCTION get_user_count()
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT COUNT(*)::INTEGER FROM auth.users;
$$;
