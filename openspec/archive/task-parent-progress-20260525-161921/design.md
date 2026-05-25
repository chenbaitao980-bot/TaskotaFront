# 设计：task-parent-progress

## 需求澄清依据
已确认目标、用户场景、范围、非目标、验收标准和关键取舍

## 当前状态
- 任务详情页已展示子任务列表，支持点击进入子任务
- 进度条展示 `task.progress` 字段，但未与真实子任务完成状态联动
- 任务模型已有 `parentTaskId` 字段，支持层级关系

## 方案

### 1. 父任务展示（任务详情页）
- 在 Info Card 上方增加父任务展示区域
- 仅当 `task.parentTaskId != null` 时展示
- 展示内容：父任务标题（可点击）
- 点击后 `Navigator.push` 到父任务的 `TaskDetailPage`

### 2. 进度计算算法
在 `LocalStorageService` 中增加：

```dart
// 获取某任务的所有后代任务（递归）
List<TaskBreakdown> getAllDescendantTasks(String taskId)

// 计算任务进度（基于后代任务完成状态）
int calculateTaskProgress(String taskId)
```

算法逻辑：
1. 获取该任务的所有后代任务（递归遍历 `parentTaskId`）
2. 如果没有后代任务，返回当前任务的 `progress`
3. 如果有后代任务，统计后代任务中 `status == 'completed'` 的数量
4. 进度 = (已完成后代数 / 后代总数) × 100，取整

### 3. 进度UI更新
- 父任务详情页进度条改为调用 `calculateTaskProgress()` 实时计算
- 子任务详情页进度保持原样（展示自身 progress）

## 业务规则处理
- 原 Requirement / Scenario：无
- 本次处理方式：MODIFIED

## 回归测试方案
- 用例文件：`regression-tests/cases/task-parent-progress.md`
- 批量测试接口 / 命令：手动验证

## 回滚方案
删除 `openspec/changes/task-parent-progress/` 目录。
