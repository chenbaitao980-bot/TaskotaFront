# Delta: claude-ui-and-progressive-ai

## 与主规范关系
Behavior Override（AI 拆解交互流程 + FAB 可见性）+ MODIFIED（UI 视觉规范）

## 命中的主规范
- Capability: `smart-butler`
- Requirement: AI任务拆解, 日历视图

## 变更类型
MODIFIED：AI 拆解交互改为渐进式多轮对话 + 快捷选项入口；UI 配色改为 Claude 暗色系；FAB 限制为首页可见

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | AI任务拆解, 日历视图 |
| 关系判断 | Behavior Override + Visual MODIFIED |
| 其他 active change 撞车 | fix-task-schedule-interaction（已完成，不冲突） |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 否（MODIFIED 现有能力） |
| 归档完整性 | Pending |

## 原规则
```
Scenario: 目标拆解
- WHEN 用户输入目标描述
- THEN AI 先询问必要信息（当前水平、可用时间等）
- AND AI 输出三层拆解
```

## 新规则
```
Scenario: 渐进式目标拆解
- WHEN 用户进入 AI 助手页面
- THEN 系统 SHALL 展示快捷选项（"拆解目标""安排日程""今日建议"等）
- AND 用户点击快捷选项或手动输入后
- THEN AI SHALL 先确认理解用户的意图
- AND 每次只提出 1 个最关键的缺失信息问题
- AND 用户回答后继续追问下 1 个关键问题
- AND 收集足够信息后生成三层拆解计划
- AND 展示确认卡片供用户确认或修改
- AND 用户确认后批量写入日程

Scenario: Claude Code 风格 UI
- WHEN 应用启动
- THEN 默认使用暗色主题
- AND 主色调为暖橙色 #C15F3C
- AND 卡片使用大圆角 + 暗色背景差分层级
- AND 减少装饰性元素，保持简洁专业

Scenario: 首页新建按钮可见性
- WHEN 用户位于首页 Tab
- THEN 右下角 SHALL 显示「+」FloatingActionButton（纯图标，无文字）
- WHEN 用户切换到日历/AI助手/我的 Tab
- THEN 「+」FloatingActionButton SHALL 隐藏

Scenario: AI 建议回复按钮
- WHEN AI 发出包含提问的消息
- THEN 该消息气泡下方 SHALL 显示建议回复按钮
- AND 按钮内容根据提问关键词自动适配，优先级：时间 > 水平 > 目标
- AND 用户点击按钮 SHALL 自动发送对应回复
- AND 输入框保留为备选输入方式

Scenario: 首页概览统计
- WHEN 用户进入首页
- THEN 今日概览 SHALL 显示「待办」和「已完成」两条统计（不含「进行中」）
- AND 「待办」计数 SHALL 为今日待办任务数 + 今日日程数
- AND 「已完成」计数 SHALL 为今日已完成任务数
- AND 统计数据 SHALL 限定为今日范围
```

## 改动明细
- 文件：`lib/core/theme/app_theme.dart`
  - 改前：紫色系（#6C63FF）+ 亮色主题默认
  - 改后：Claude 暖橙系（#C15F3C）+ 强制暗色

- 文件：`lib/main.dart`
  - 改前：`themeMode: ThemeMode.system`
  - 改后：`themeMode: ThemeMode.dark`

- 文件：`lib/services/ai_service.dart`
  - 改前：一次性问答 Prompt
  - 改后：分步引导 Prompt（每轮只问 1 个问题）

- 文件：`lib/presentation/pages/home/home_page.dart`
  - 改前：`FloatingActionButton.extended` + 无条件渲染
  - 改后：`FloatingActionButton`（纯图标「+」）+ 条件渲染（仅首页）

- 文件：`lib/presentation/pages/ai_chat/ai_chat_page.dart`
  - 改前：单轮 send → response + 快捷选项区域
  - 改后：多轮渐进式对话 + AI 提问时建议回复按钮 + 确认卡片
