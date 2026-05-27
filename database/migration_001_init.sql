-- Migration 001: Initialize Supabase Schema for 智能小管家
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)

-- 1. 用户画像表
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    encrypted_data JSONB,
    explicit_profile JSONB,
    implicit_profile JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. 日程表
CREATE TABLE IF NOT EXISTS schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    priority TEXT DEFAULT 'P2',
    focus_required BOOLEAN DEFAULT false,
    parallelizable BOOLEAN DEFAULT false,
    metadata JSONB,
    source TEXT DEFAULT 'manual',
    parent_task_id UUID,
    remind_before_minutes INTEGER DEFAULT 15,
    reminder_enabled BOOLEAN DEFAULT true,
    is_repeating BOOLEAN DEFAULT false,
    repeat_interval INTEGER,
    reminder_type TEXT DEFAULT 'once',
    sync_status TEXT DEFAULT 'local',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 提醒表（已存在，补充索引）
CREATE INDEX IF NOT EXISTS idx_reminders_schedule ON reminders(schedule_id);

-- 兼容：为已存在的 schedules 表添加提醒字段（如有重复运行忽略）
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS remind_before_minutes INTEGER DEFAULT 15;
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS reminder_enabled BOOLEAN DEFAULT true;
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS is_repeating BOOLEAN DEFAULT false;
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS repeat_interval INTEGER;
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS reminder_type TEXT DEFAULT 'once';
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS sync_status TEXT DEFAULT 'local';

-- 3. 任务拆解表（树形结构）
CREATE TABLE IF NOT EXISTS task_breakdowns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    parent_goal_id UUID REFERENCES task_breakdowns(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    level TEXT NOT NULL CHECK (level IN ('yearly','quarterly','monthly','weekly','daily','hourly')),
    start_date DATE,
    end_date DATE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending','in_progress','completed','failed','deferred')),
    progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
    priority TEXT DEFAULT 'P2',
    focus_required BOOLEAN DEFAULT false,
    dependencies UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. AI 对话历史
CREATE TABLE IF NOT EXISTS ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    user_input TEXT NOT NULL,
    ai_response JSONB,
    context JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. 进度追踪表
CREATE TABLE IF NOT EXISTS progress_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    task_id UUID REFERENCES task_breakdowns(id) ON DELETE CASCADE,
    progress_change INTEGER,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. 提醒任务表
CREATE TABLE IF NOT EXISTS reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    task_id UUID REFERENCES task_breakdowns(id) ON DELETE CASCADE,
    schedule_id UUID REFERENCES schedules(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    remind_at TIMESTAMPTZ NOT NULL,
    urgency_score FLOAT DEFAULT 0.5,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending','sent','cancelled')),
    sent_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. 奖励记录表（第三版使用）
CREATE TABLE IF NOT EXISTS rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    reward_type TEXT,
    reward_content TEXT,
    unlocked_at TIMESTAMPTZ DEFAULT now(),
    related_task_id UUID REFERENCES task_breakdowns(id) ON DELETE CASCADE
);

-- 启用 Row Level Security
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_breakdowns ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;

-- RLS 策略：用户只能访问自己的数据
CREATE POLICY "Users can only access own profiles" ON user_profiles
    FOR ALL USING (auth.uid() = id);

CREATE POLICY "Users can only access own schedules" ON schedules
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can only access own tasks" ON task_breakdowns
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can only access own conversations" ON ai_conversations
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can only access own progress" ON progress_logs
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can only access own reminders" ON reminders
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can only access own rewards" ON rewards
    FOR ALL USING (auth.uid() = user_id);

-- 自动更新 updated_at 的触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_schedules_updated_at
    BEFORE UPDATE ON schedules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_task_breakdowns_updated_at
    BEFORE UPDATE ON task_breakdowns FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 本地任务云同步表（存储 Drift 本地任务的 JSON 快照，用于跨设备同步）
CREATE TABLE IF NOT EXISTS local_task_sync (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tasks_data JSONB NOT NULL DEFAULT '[]',
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE local_task_sync ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access own task sync" ON local_task_sync
    FOR ALL USING (auth.uid() = user_id);

-- 索引
CREATE INDEX IF NOT EXISTS idx_schedules_user_time ON schedules(user_id, start_time);
CREATE INDEX IF NOT EXISTS idx_task_breakdowns_user ON task_breakdowns(user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_user_time ON reminders(user_id, remind_at);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user ON ai_conversations(user_id);
