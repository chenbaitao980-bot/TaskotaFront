# Delta: task-parent-progress

## 与主规范关系
New Capability

## 命中的主规范
- Capability: `task-parent-progress`
- Requirement: `REQ-001`
- Scenario: `SCN-001`

## 变更类型
MODIFIED

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | 无 |
| 关系判断 | 新增 |
| 其他 active change 撞车 | 无 |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 是 |
| 归档完整性 | ✅ |

## 原规则
无

## 新规则

### REQ-001: 父任务展示与跳转
- 子任务详情页须展示其父任务名称
- 父任务名称可点击，点击后导航至父任务详情页

### REQ-002: 父任务进度计算
- 父任务进度基于其所有后代任务的完成状态计算
- 进度 = (已完成后代数 / 后代总数) × 100%
- 支持多级嵌套（递归计算）
- 叶子节点任务进度保持原有 `progress` 字段值

## 改动明细
- 文件：`lib/services/local_storage_service.dart`
- 位置：新增方法 `getAllDescendantTasks()`、`calculateTaskProgress()`
- 改前：无递归子任务查询和进度计算
- 改后：支持递归获取所有后代任务并计算完成百分比

- 文件：`lib/presentation/pages/task/task_detail_page.dart`
- 位置：build 方法中 Info Card 前增加父任务展示；进度条区域使用计算进度
- 改前：不展示父任务；进度条使用 `task.progress`
- 改后：展示父任务（可跳转）；父任务进度条使用 `calculateTaskProgress()`
