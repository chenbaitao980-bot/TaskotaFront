# Delta: smart-butler-core-intelligence

## 与主规范关系
Added Scenarios under existing Requirements（AI任务拆解、日历视图）

## 命中的主规范
- Capability: `smart-butler`
- Requirement: AI任务拆解, 日历视图

## 变更类型
ADDED Scenarios（四块新能力追加到现有 Requirement，不新建 capability）

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | AI任务拆解, 日历视图 |
| 关系判断 | Same Requirement（追加 Scenario） |
| 其他 active change 撞车 | claude-ui-and-progressive-ai（AI助手交互，不冲突） |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 是（追加 Scenario，非独立 capability） |
| 归档完整性 | ✅ |

## 原规则
```
Scenario: 目标拆解
- WHEN 用户输入目标描述
- THEN AI 先询问必要信息
- AND AI 输出三层拆解
```

## 新规则
```
Scenario: 个性化目标拆解
- WHEN 用户已有画像数据
- THEN AI 拆解时 SHALL 结合用户当前水平、完成率、偏好时间调整策略
- AND 生成拆解计划前参考画像数据

Scenario: Onboarding 画像采集
- WHEN 用户首次使用应用
- THEN 显示3步问卷（基本信息→目标→水平）
- AND 采集完成后写入 UserProfile
- AND 后续自动统计完成率等隐式画像

Scenario: 日程冲突检测
- WHEN 用户创建新日程且时间与现有日程重叠
- THEN 系统 SHALL 检测冲突并调用 AI 生成决策建议
- AND 展示3个选项，每个附收益风险标签
- AND 用户选择后执行选中的方案

Scenario: 动态提醒策略
- WHEN 系统为日程设置提醒
- THEN 根据优先级+剩余时间计算紧迫性分数
- AND 分数>0.8时提前2倍任务时长提醒
- AND 分数>0.5时提前1倍任务时长提醒
- AND 分数<0.3时提前15分钟提醒
```

## 改动明细
- 文件：`lib/presentation/pages/onboarding/onboarding_page.dart`（新增）
- 文件：`lib/models/entities/user_profile.dart`（修改：新增 explicit/implicit 字段）
- 文件：`lib/services/local_storage_service.dart`（修改：画像读写）
- 文件：`lib/services/ai_service.dart`（修改：Prompt 注入画像 + 冲突分析接口）
- 文件：`lib/presentation/pages/ai_chat/ai_chat_page.dart`（修改：传递用户画像到 AI）
- 文件：`lib/presentation/pages/home/home_page.dart`（修改：首次启动引导 Onboarding）
- 文件：`lib/services/notification_service.dart`（修改：动态提醒策略）
