# 日历甘特图点击弹窗展示任务列表

## Goal

在日历周/月视图中，顶部横向甘特图区域（显示跨天任务的横条区域）支持点击交互：点击后弹出弹框，以列表形式完整展示所有跨天任务条目。当任务数量超出可视区域时，弹框内容支持上下滚动浏览。

## What I already know

* **目标组件**: `_buildMultiDayLane()` (calendar_page.dart 行 1756-1943) — 顶部甘特图容器
* **当前限制**: 最多显示 4 行 (`maxVisibleLanes = 4`)，每行高 24px（实际条高 16px），超出部分被裁剪不可见
* **数据来源**: `_filteredTasks()` → `.where(_isMultiDayTask && _taskOverlapsRange)` 筛选出跨天任务
* **现有弹窗模式**:
  - `showDialog` + `AlertDialog` — 用于筛选项目、确认删除等
  - `showModalBottomSheet` — 用于右键菜单、创建任务
  - `Navigator.push` → `TaskDetailPage` — 任务详情页
* **单个条渲染**: `_buildMultiDayBar()` (行 1946-2042) → `_EditableMultiDayBar` (行 2775-2983)
* **条的 UI**: 圆角8px + Checkbox + 标题文字 + 按优先级着色

## Decision

* **弹窗形式**: 全屏页面 (FullScreenDialog) — `showGeneralDialog` 或 `Navigator.push` + 自定义 PageRoute
* **弹窗内容样式**: 复刻甘特图横向长条块样式 — 保留圆角、优先级颜色、Checkbox，下方标注日期跨度，视觉与甘特图区一致
* **触发方式**: 甘特图区域右下角「查看全部 N 条 ▸」入口按钮 — 不干扰现有拖拽编辑
* **列表项交互**:
  - 点击 → 跳转任务详情页 (TaskDetailPage)
  - 桌面端右键 → 弹出操作菜单（编辑/归档/删除/跳转思维导图）
  - 移动端长按 → 弹出同样操作菜单

## Requirements

* 周视图甘特图区域右下角「查看全部 N 条 ▸」入口按钮
* 点击按钮打开全屏弹窗 (FullScreenDialog)
* 弹窗内复刻甘特图横向长条块样式（圆角、优先级颜色、Checkbox、下方日期跨度）
* 列表支持上下滚动（任务多时）
* 弹窗标题展示「全部跨天任务」+ 总数
* 点击任务项 → 跳转 TaskDetailPage
* 桌面端右键 / 移动端长按 → 弹出操作菜单（编辑/归档/删除/跳转思维导图）
* 关闭按钮（左上返回箭头 / 右上 ✕）

## Acceptance Criteria

* [ ] 甘特图右下角显示「查看全部 N 条 ▸」按钮，N 与实际跨天任务数一致
* [ ] 跨天任务数为 0 时按钮不显示
* [ ] 点击按钮打开全屏弹窗
* [ ] 弹窗完整展示所有跨天任务（不受 4 行限制）
* [ ] 超过可视高度时支持上下滚动
* [ ] 任务项点击跳转到 TaskDetailPage
* [ ] 桌面端右键弹出操作菜单；移动端长按弹出操作菜单
* [ ] 关闭按钮/返回手势正常关闭弹窗
* [ ] 任务被修改后重新打开弹窗数据刷新

## Definition of Done

* Lint / typecheck 通过
* 与现有日历视图交互不冲突（拖拽、折叠等功能正常）
* 桌面 + 移动端双端兼容

## Out of Scope (explicit)

* 不修改现有甘特图条的拖拽/编辑逻辑
* 不改变现有的 4 行显示限制（弹窗只是扩展查看方式）
* 弹窗内不支持拖拽编辑任务日期
* 日视图/月视图同步（仅周视图）
* 弹窗内按分组折叠

## Technical Notes

* 主文件: `lib/presentation/pages/calendar/calendar_page.dart` (~2994行)
* 关键方法:
  - `_buildMultiDayLane()` 行 1756-1943 — 需在容器右下角叠加入口按钮
  - `_buildMultiDayBar()` 行 1946-2042 — 单个条的渲染（可复用为弹窗列表项）
  - `_EditableMultiDayBar` 行 2775-2983 — 可编辑条组件（UI 参考复用）
  - `_isMultiDayTask()` 行 213-222 — 跨天判断
  - `_showTaskContextActions()` 行 497-535 — 右键菜单复用
  - `_openTaskDetail()` 行 480-491 — 详情导航复用
* 新增文件: 可能需要新建 `lib/presentation/pages/calendar/multi_day_task_list_page.dart` 作为弹窗页面
