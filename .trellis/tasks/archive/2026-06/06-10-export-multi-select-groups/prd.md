# 导出页面支持多选项目分组和项目导出

## Goal

导出页（task_export_page.dart）的"项目"筛选区升级为按 ProjectGroup 分组展示，支持三态复选框快速选组，同时 Excel 导出每行新增「分组」列（第2列），便于多 Sheet 合并分析。

## Requirements

* 导出页「项目」区改为分组树状展示：分组标题（三态复选 + 颜色点 + 可折叠）+ 组内项目列表
* 未分组项目归入"未分组"区块（同样可折叠）
* 勾选分组 = 全选组内项目；取消 = 全取消；组内单项独立勾选（三态自动更新）
* 保留"全部项目"总开关
* 导出 Excel 在第2列（层级之后、任务标题之前）新增「分组」列，每行显示该项目所属分组名（未分组为空字符串）

## Acceptance Criteria

* [ ] 勾选某分组后，该组所有项目被选中，导出结果正确过滤
* [ ] 组内部分项目选中时，分组标题呈半选态（`tristate`)
* [ ] 点击分组展开/折叠箭头，组内项目列表正常展开收起
* [ ] 未分组项目在"未分组"区块中独立显示和勾选
* [ ] 全选时 projectIds 仍传空集合（现有逻辑不变）
* [ ] Excel 每行第2列为分组名，表头为「分组」，未分组为空
* [ ] 现有测试通过，新增分组列测试

## Definition of Done

* `flutter analyze` 通过
* `task_export_service_test.dart` 更新（`_project` 加 `groupId`，加分组列 assert）
* CHANGELOG.md 更新
* git push github master:main 触发 Vercel 同步

## Technical Approach

### 文件改动清单

**1. `lib/services/task_export_service.dart`**
- `exportTasksToExcel` 新增可选参数 `List<ProjectGroup> groups = const []`
- 在方法内构建 `groupNameMap`（projectId → groupName）
- `_writeProjectSheet` 接收 `String? groupName`，在 col 1 写入分组名
- headers 改为 9 列：`['层级', '分组', '任务标题', '重要级别', '状态', '开始时间', '截止时间', '完成时间', '描述']`
- `_setupColumns` widths 改为 9 列（新增 col 1 宽 14.0）
- `_mergeWrite` 的合并终止列从 7 改为 8（0-indexed）
- `_writeEmptySheet` 同步更新合并列范围

**2. `lib/presentation/pages/profile/task_export_page.dart`**
- 构造参数新增 `ProjectGroupRepository? projectGroupRepository`
- state 新增 `List<ProjectGroup> _groups` 和 `Set<String> _expandedGroupIds`
- `_load()` 同时加载 groups
- `_buildProjectSection()` 改为分组树：全选行 + 分组折叠区块
- `_export()` 将 `groups` 传入 `exportTasksToExcel`

**3. `test/task_export_service_test.dart`**
- `_project()` 辅助函数加 `groupId: null`（Project 模型已有此字段）
- 更新 Excel 列索引断言（分组列插入后标题 col 偏移 +1）
- 新增 `_projectGroup` 辅助函数 + 分组列值测试

## Decision (ADR-lite)

**Context**: 选择「UI 层按 projectIds 过滤」vs「服务层新增 groupIds 参数」  
**Decision**: 保持服务层仍按 projectIds 过滤，UI 层将选中的分组展开为 projectIds 集合  
**Consequences**: 导出服务零改动（仅加 `groups` 用于列值），UI 逻辑自包含，易测试

## Spec Conflicts

* 无。导出 VIP 判断逻辑（`canExportData()`）本次不改动。

## Out of Scope

* Excel 中按分组拆 Sheet（仍按项目一 Sheet）
* 分组管理功能

## Technical Notes

* `Project.groupId` 可空；`ProjectGroup` 字段：id/name/color/sortOrder
* 参考：`project_sidebar.dart _buildGroupedProjects()` 分桶逻辑
* `_project()` 测试辅助函数需加 `groupId` 字段（数据库字段，可能已有）
* 需确认 Task_export_page 调用入口是否已传 projectRepository（以同模式注入 groupRepository）
