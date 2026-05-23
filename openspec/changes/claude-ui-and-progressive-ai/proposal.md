# claude-ui-and-progressive-ai

## 为什么
1. **UI 风格过于简陋**：当前紫色渐变主题缺少专业感，与 Claude Code 的暗色+暖橙色调差距大
2. **AI 拆解交互太粗暴**：一次性要求用户提供所有信息，没有渐进式引导；且只能通过文本框输入，缺少快捷选项入口
3. **首页「新建」按钮文字冗余**：右下角 FAB 包含「+新建」文字，应简化为纯图标「+」
4. **AI 提问缺少选项回复**：AI 发出问题（如"你什么水平？"）时仍需用户打字，应自动弹出选项按钮供点击
5. **AI 建议回复选项不匹配**：当 AI 提问涉及时间时，"基础"关键字残留导致错误匹配到水平选项
6. **首页概览统计需精简**：今日概览包含"待办/进行中/已完成"三个统计，应去掉"进行中"
7. **统计未按今日过滤**：待办和已完成计数的对象需限定为今日数据

## 影响面
GitNexus impact（depth=3，全局 UI + AI 对话逻辑）:
- `app_theme.dart`：配色全面替换
- `main.dart`：强制暗色主题
- `ai_chat_page.dart`：对话重构为多轮渐进式 + 新增快捷选项区域
- `ai_service.dart`：Prompt 模板改造
- `home_page.dart`：卡片样式适配新主题 + FAB 按 Tab 可见性控制
- `calendar_page.dart`：控件颜色适配
- BugFixSpecs: 无命中（auth/register-click-no-response 不相关）

## 业务规范关系
- 主 spec：`openspec/specs/smart-butler/spec.md`
- 命中的 Requirement：AI任务拆解 + 日历视图
- 关系判断：Behavior Override（AI 交互模式改变）+ MODIFIED（UI 视觉 + FAB 可见性）
- 推荐动作：MODIFIED Requirement（AI 拆解交互流程 + FAB 可见性规则）

## 改动范围
| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/core/theme/app_theme.dart` | 重构 | Claude 配色系（#C15F3C + #1A1A2E 暗色） |
| `lib/main.dart` | 修改 | 默认暗色主题 |
| `lib/presentation/pages/ai_chat/ai_chat_page.dart` | 重构 | 渐进式多轮对话 + 快捷选项 Chip 区域 + 输入框改为备选 |
| `lib/services/ai_service.dart` | 修改 | 分步提问 Prompt 模板 |
| `lib/presentation/pages/home/home_page.dart` | 修改 | 卡片/按钮适配新配色 + FAB 仅首页可见 |
| `lib/presentation/pages/calendar/calendar_page.dart` | 修改 | 控件适配 |
| `lib/presentation/pages/profile/profile_page.dart` | 修改 | 配色适配 |
| `openspec/specs/smart-butler/spec.md` | MODIFIED | AI 拆解交互流程 + FAB 可见性规则 |

## 验收
- [x] 应用启动默认暗色主题，配色为 Claude 暖橙色系
- [x] FAB 纯图标「+」，仅首页 Tab 显示
- [x] AI 建议回复按钮关键词修复（时间优先于水平匹配）
- [x] 首页今日概览去掉「进行中」统计（仅保留待办和已完成）
- [x] 待办和已完成计数按今日过滤
- [ ] AI 助手页面展示快捷选项（如"拆解目标""安排日程"等），点击即触发对应对话流
- [ ] AI 提问时自动显示建议回复按钮（如"水平 → 零基础/会一点点/有基础"），点击可作答
- [ ] AI 每个阶段只提 1-2 个问题，不一次性列出所有
- [ ] 输入框保留为备选输入方式（非唯一入口）
- [ ] 已维护 `regression-tests/cases/claude-ui-and-progressive-ai.md`
- [ ] `flutter clean && flutter build windows --release` 通过

## Bug 修复记录
无（功能性改造）
