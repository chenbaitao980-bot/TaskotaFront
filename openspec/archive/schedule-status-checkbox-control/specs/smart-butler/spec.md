# Delta: schedule-status-checkbox-control

## 与主规范关系
Spec Gap（日程状态控制未在 spec 中定义），追加 Scenario + MODIFIED 打包规范。

## 命中的主规范
- Capability: `smart-butler`
- Requirement: Calendar view
- Scenario: 编辑/删除日程

## 变更类型
追加 Scenario + MODIFIED Requirement（打包规范）

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | Calendar view |
| 关系判断 | Spec Gap（状态控制）+ New Requirement（打包约束） |
| 其他 active change 撞车 | fix-task-schedule-interaction（已完成，互补） |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 否（追加 Scenario + MODIFIED） |
| 归档完整性 | Pending |

## 原规则
spec 中无日程状态控制规则，无打包流程规则。

## 新规则
### Scenario: 标记日程完成状态
- WHEN 用户在日程列表或日历视图中点击日程旁的复选框
- THEN 勾选 SHALL 将日程状态设为已完成
- AND 取消勾选 SHALL 将日程状态设为进行中
- AND 状态变更 SHALL 立即持久化到本地存储

### Scenario: Windows 桌面打包
- WHEN 用户要求打包 Windows 桌面版应用
- THEN AI SHALL 先执行 `flutter clean` 清理增量编译缓存
- AND 执行 `flutter build windows --release` 全量构建
- AND 复制产物到 release 目录
- AND 打包为 ZIP 分发包

## 改动明细
- 文件：`lib/models/entities/schedule.dart`
  - 改前：无 status 字段
  - 改后：`@Default('in_progress') String status`

- 文件：`lib/presentation/pages/home/home_page.dart`
  - 改前：日程列表 leading 为颜色条
  - 改后：leading 为 Checkbox

- 文件：`lib/presentation/pages/calendar/calendar_page.dart`
  - 改前：无状态勾选交互
  - 改后：事件块添加 compact Checkbox，事件列表添加 Checkbox

- 文件：`openspec/specs/smart-butler/spec.md`
  - 追加：标记日程完成状态 Scenario + Windows 桌面打包 Scenario

- 文件：`openspec/project.md`
  - 追加：打包约束
