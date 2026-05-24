# schedule-status-checkbox-control

## 为什么
1. 日程缺少状态管理：只能创建和编辑，无法标记完成/取消完成
2. 打包经验未固化到规范：Clean rebuild 是上次修复删除按钮不显示的关键，需写入 spec 避免重复踩坑

## 影响面
GitNexus impact（预估 depth=2）:
- `Schedule` 模型：新增 `status` 字段 → 影响所有读写的文件
- `LocalStorageService`: 存储/序列化受影响
- `HomePage._buildRecentSchedules`: 日程列表渲染
- `CalendarPage._buildEventBlocksForDay`: 周视图事件块渲染
- `calendar_page.dart._buildEventList`: 日历事件列表
- BugFixSpecs: `auth/register-click-no-response.md` 不相关，未命中

## 业务规范关系
- 主 spec：`openspec/specs/smart-butler/spec.md`
- 命中的 Requirement：Calendar view → Scenario: 编辑/删除日程
- 关系判断：Spec Gap（spec 未覆盖日程状态控制）
- 推荐动作：MODIFIED（在 Calendar view 下追加状态控制 Scenario）+ 追加打包流程 Scenario 到 project-baseline

## 改动范围
| 文件 | 改动类型 |
|------|---------|
| `lib/models/entities/schedule.dart` | 修改：新增 `status` 字段（默认 `in_progress`） |
| `lib/models/entities/schedule.freezed.dart` | 自动生成 |
| `lib/models/entities/schedule.g.dart` | 自动生成 |
| `lib/presentation/pages/home/home_page.dart` | 修改：日程列表项添加 checkbox |
| `lib/presentation/pages/calendar/calendar_page.dart` | 修改：周视图事件块 + 事件列表添加 checkbox |
| `openspec/specs/smart-butler/spec.md` | MODIFIED：追加状态控制 Scenario + 打包规范 Scenario |
| `openspec/project.md` | 修改：追加打包约束 |

## 验收
- [x] Schedule 模型有 `status` 字段（`in_progress` / `completed`）
- [x] 首页今日日程列表每项前有 checkbox
- [x] 日历周视图事件块前有 checkbox
- [x] 日历事件列表每项前有 checkbox
- [x] 勾选 = 已完成，取消 = 进行中
- [x] 状态持久化到本地存储
- [x] 打包规范已写入 spec
- [x] 已维护 `regression-tests/cases/schedule-status-checkbox-control.md`
- [x] `flutter test` 通过
- [x] `flutter clean && flutter build windows --release` 通过
- [x] `gitnexus detect-changes --scope all -r smart-assistant`

## Bug 修复记录
无（功能性新增）

## 历史 BugFixSpecs 命中
- 命中文件：无
