# smart-butler-core-intelligence

## 为什么
基于产品设计文档 [智能小管家 P1 第二版](E:/黑曜石/obsidian/智能小管家.md)，实现四项核心智能功能：
- **F7 用户画像构建**：Onboarding 问卷 + 任务完成率隐式学习
- **F8 个性化任务拆解**：AI Prompt 注入用户画像，调整拆解策略
- **F9 冲突检测**：日程时间重叠检测 + AI 决策建议(收益/风险)
- **F10 动态提醒策略**：紧迫性评分驱动提醒时间和频率

## 影响面
- `ai_service.dart`：Prompt 模板加入用户画像、冲突分析、提醒策略
- `home_page.dart`：首次启动引导 Onboarding 问卷
- `user_profile` 模型：读写画像数据
- `local_storage_service.dart`：画像持久化
- `schedule` 模型：冲突检测逻辑
- 新页面：`onboarding_page.dart`

## 业务规范关系
- 主 spec：`openspec/specs/smart-butler/spec.md`
- 命中的 Requirement：AI任务拆解、日历视图、云端同步
- 关系判断：Add Scenarios（四块新能力均未覆盖，追加到现有 Requirement 下）
- 推荐动作：ADDED Scenarios under existing Requirements

## 改动范围
| 文件 | 操作 | 对应F# |
|------|------|--------|
| `lib/presentation/pages/onboarding/` | 新增 | F7 |
| `lib/presentation/pages/home/home_page.dart` | 修改 | F7 |
| `lib/models/entities/user_profile.dart` | 修改 | F7 |
| `lib/services/local_storage_service.dart` | 修改 | F7 |
| `lib/services/ai_service.dart` | 修改 | F8, F9, F10 |
| `lib/presentation/pages/ai_chat/ai_chat_page.dart` | 修改 | F8 |
| `lib/presentation/pages/home/home_page.dart` | 修改 | F9 |
| `lib/services/notification_service.dart` | 修改 | F10 |

## 验收
- [ ] Onboarding 问卷首次启动时弹出
- [ ] 用户画像（显式+隐式）持久化到本地
- [ ] AI 拆解时 Prompt 包含用户画像（水平、时间、偏好）
- [ ] 新建日程时检测时间冲突并弹出 AI 建议
- [ ] 动态提醒根据紧迫性分数自动调整提前时间
- [ ] 已维护 `regression-tests/cases/smart-butler-core-intelligence.md`

## Bug 修复记录
无（新功能）
