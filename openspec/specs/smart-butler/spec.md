# Smart Butler Spec

## Purpose
定义 AI 智能日程管家 MVP 的核心业务能力和用户交互流程。

## Requirements

### Requirement: 语音/文字录入日程
用户 SHALL 能通过语音或文字输入创建日程，系统使用原生 ASR 进行语音识别，调用 LLM 解析自然语言为结构化日程数据。

#### Scenario: 语音录入日程
- WHEN 用户点击语音录入按钮并说话
- THEN 系统调用 speech_to_text 获取语音文本
- AND 调用 DeepSeek API 解析文本为结构化日程（标题、时间、优先级）
- AND 展示解析结果给用户确认
- AND 用户确认后写入本地存储和 Supabase

#### Scenario: 文字录入日程
- WHEN 用户在输入框输入日程描述（如"明天下午3点开会"）
- THEN 系统调用 LLM 解析为结构化日程
- AND 后续流程同语音录入

### Requirement: 日历视图
用户 SHALL 能在周视图和月视图中可视化查看所有日程，并支持在日历上直接新建、编辑、删除日程。

#### Scenario: 查看月视图
- WHEN 用户切换到日历Tab
- THEN 默认展示月视图
- AND 有日程的日期显示圆点标记
- AND 点击日期展示当日日程列表

#### Scenario: 切换到周视图
- WHEN 用户点击周视图切换按钮
- THEN 日历切换为周视图
- AND 显示该周每天的时间格子
- AND 日程以时间块形式展示

#### Scenario: 日历上新建日程
- WHEN 用户长按某个日期/时间格
- THEN 弹出新建日程对话框
- AND 填写后保存到本地和云端

#### Scenario: 编辑/删除日程
- WHEN 用户点击已有日程
- THEN 弹出日程详情/编辑页
- AND 支持修改标题、时间、优先级、描述
- AND 支持删除日程（确认后）

### Requirement: AI任务拆解
用户 SHALL 能输入大目标，AI 将其递归拆解为 目标→月→周 三层结构化任务。

#### Scenario: 目标拆解
- WHEN 用户输入目标描述（如"今年拿下日语N1"）
- THEN AI 先询问必要信息（当前水平、可用时间等）
- AND AI 输出三层拆解：战略层（季度里程碑）→ 战术层（月任务）→ 执行层（周任务）
- AND 用户可确认并批量写入日程

### Requirement: 云端同步
系统 SHALL 使用 Supabase 作为云端后端，实现日程和任务数据的跨设备同步。

#### Scenario: 数据同步
- WHEN 用户在任一设备上修改数据
- THEN 数据通过 Supabase 同步到云端
- AND 其他设备通过 Realtime 或轮询获取更新

### Requirement: 用户注册与登录
用户 SHALL 能通过邮箱和密码注册账号并登录，使用 Supabase Auth 进行身份认证。

#### Scenario: 用户注册
- WHEN 用户输入邮箱和密码并点击注册
- THEN 系统调用 Supabase Auth 创建账号
- AND 自动创建用户画像记录
- AND 跳转到首页

#### Scenario: 用户登录
- WHEN 用户输入正确凭据并点击登录
- THEN 系统验证身份
- AND 加载用户数据
- AND 跳转到首页

#### Scenario: 未登录访问
- WHEN 未登录用户打开应用
- THEN 展示登录页面
- AND 阻止访问其他功能页面
