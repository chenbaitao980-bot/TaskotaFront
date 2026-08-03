# Research: Flutter 移动端"父任务树状选择器"方案

- **Query**: Flutter 移动端父任务树状选择器的最佳 UI/组件方案（门控 + 树状层级可展开/折叠）
- **Scope**: mixed（内部代码梳理 + 外部生态调研）
- **Date**: 2026-08-03

## 现状代码梳理（内部）

### 审核页当前结构

- `lib/presentation/pages/home/lazy_log_draft_review_sheet.dart` 是懒人日志草稿审核页，由 home_page 用 `showModalBottomSheet` 弹出（`home_page.dart:1848-1858`，高度 `0.86 * screen`）。
- 每张草稿卡片 `_DraftReviewCard` 内一个 `Wrap` 并列放置：`_ProjectDropdown` + `_ParentDropdown` + `_PriorityDropdown` + 时间范围按钮等（`lazy_log_draft_review_sheet.dart:282-337`）。
- `_ParentDropdown` 是扁平 `DropdownButton<String?>`（`lazy_log_draft_review_sheet.dart:521-550`），直接列出 `widget.parents`，**不随所选项目过滤，也没做门控** —— 即 PRD 的"现状问题 A"。
- `LazyLogParentOption` 只有 `id / title / projectId` 三字段，**没有 parentId**（`lazy_log_creation_dialog.dart:20-30`）。

### 父任务候选数据流

- 数据源 `_TimelineTask`（`home_page.dart:5475-5501`）：有 `id / taskId / title / projectId / parentId / source`，足以构造树。
- `_lazyLogParentCandidates()`（`home_page.dart:2228-2241`）：筛 `source` 相同 且 `parentId == null`（**仅根任务**）且可选按 projectId 过滤。
- `_lazyLogParentOptions()`（`home_page.dart:2153-2164`）：把 `_TimelineTask` 转成 `LazyLogParentOption`（丢弃了 parentId）。
- 门控参考：创建弹窗已有 `_filteredParents()`（`lazy_log_creation_dialog.dart:358-363`）按 `parent.projectId == selectedProjectId` 过滤 —— 审核页可复用同款思路。

### 可复用的既有树/层级代码

| 文件 | 可复用点 |
|---|---|
| `lib/presentation/pages/tasks/task_detail/widgets/subtask_tree_section.dart` | **最强参考**：`_buildChildrenByParent` 一次性构建 parentId→children 索引（O(n)，:159-167）+ 递归 `_buildTree`（:169-213）+ `expandedNodes` Set 控制展开 + 节点行缩进 `depth * 16` + 展开/折叠 chevron（:307-324）。这就是一个完整的"自绘可展开树"骨架，可平移成选择器。 |
| `lib/presentation/pages/calendar/multi_day_task_list_page.dart` | `_sortedTasksWithDepth()`（:29-101）按父子关系 DFS 排序返回 `(task, depth)`，含 `groupRoot` 上溯找根逻辑；`indent = depth * 20`（:147）。 |
| `home_page.dart` | `_isParentNode`/`_isChildNode`（:1061-1062）父子节点判断；`_TimelineTask` 字段（:5475）。 |

### 依赖现状

- pubspec 无任何树/下拉增强包（无 dropdown_button2 / flutter_tree_view / expansion 系列）。Flutter 约束 `>=3.38.4`（`pubspec.lock`），Dart `^3.11.5`。
- 平台：Windows/macOS/Linux + Android/iOS；审核页为 bottom sheet 内卡片，空间局促，且每次可能有 N 张草稿卡片。

## 外部生态调研（Flutter 树状选择实现方式）

### 1) 内置 `TreeSliver`（Flutter 3.24+ 官方引入）—— 重点结论

- **`flutter_tree_view` 已停维护**。其 README 明确声明：该包 discontinued，被 Flutter 内置的 **`TreeSliver`**（Flutter 3.24.0 引入）和官方 **`two_dimensional_scrollables`** 包（0.5.3，2026-07 更新）的 `TreeView` 取代。
- 本项目 Flutter >= 3.38.4，**TreeSliver 直接可用，无需装包**。
- 已从 `api.flutter.dev` 核实构造函数（Flutter 3.38 版）：
  ```dart
  TreeSliver<T>({
    Key? key,
    required List<TreeSliverNode<T>> tree,   // 扁平节点列表，父子通过节点内链接
    TreeSliverNodeBuilder treeNodeBuilder = TreeSliver.defaultTreeNodeBuilder,
    TreeSliverRowExtentBuilder treeRowExtentBuilder = ...,
    TreeSliverController? controller,          // 编程式控制展开/折叠
    TreeSliverNodeCallback? onNodeToggle,
    TreeSliverIndentationType indentation = TreeSliverIndentationType.standard,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
  })
  ```
- 特点：懒加载 sliver（须放 `CustomScrollView` 内）、自带展开/折叠动画与缩进线、`TreeSliverController` 可批量展开；`TreeSliverNode` 需要自己把 `children/parent` 接好（用 DFS 生成扁平列表）。
- **注意**：是 sliver 而非独立控件，**不能直接内联到卡片 Wrap 里**，必须放进滚动容器/弹层；样式定制自由度低于自绘。

### 2) 第三方包现状（已逐个核验 pub.dev）

| 包 | 状态 | 说明 |
|---|---|---|
| `flutter_tree_view` / `flutter_fancy_tree_view` | **已废弃**（baumths 维护，被官方 TreeSliver 取代） | 别再引入 |
| `flutter_simple_treeview` | 3.0.2（2022，SDK <3.0 已过期） | 老、无维护、Dart 2 时代 |
| `tree_view_flutter` | 1.0.2（2024） | 小维护少星 |
| `recursive_tree_flutter` | 1.0.4（2025） | 依赖 `flutter_tree` 作为核心 |
| `two_dimensional_scrollables` | 0.5.3（官方，活跃） | `TreeView` 是 `TwoDimensionalScrollView` 子类，**2D 双向滚动**树，适合横向宽树/缩进线展示；移动小屏弹层内属过重 |
| `dropdown_button2` | 3.1.0（活跃） | 增强下拉；v3 支持 nested submenu（`MultiMenuButton`/`MultiDropdownItem`），但级联子菜单偏桌面鼠标交互，移动端点按多级子菜单体验差 |

**结论：三方可选且值得为"单个树选择器"引入的包基本没有 —— 要么已废弃、要么过重。自绘或官方 TreeSliver 是更优解。**

### 3) Android / Material Design 惯例

- Material Design（M3）**没有针对移动端的"树视图"组件**；树主要用于桌面（M2 时代的 data tables 层级行、菜单子项）。移动端官方推荐模式是：**展开式列表（expansion）+ 页面/弹层导航（drill-down）**，而非内联树。
- 移动端分层选择的常见现实模式（Todoist/Notion/ClickUp/Asana 的项目选择、Android 文件/文件夹选择器、电商级联分类）：
  1. **模态弹层树选择器**：点下拉 → 弹出（对话框/底部抽屉/全屏页）含搜索 + 可展开树的列表，点行即选即回填。Todoist 任务的项目选择即此模式。
  2. **级联/联动选择（cascader）**：先选第一级再选第二级（如省市区、京东分类）。优点是最省空间；缺点是不能一眼看到全树，需多次点按。
  3. **钻取（drill-down）**：面包屑 + 逐级下钻的文件夹式导航。
  4. **内联展开**：直接把树展开在表单里 —— 在卡片/Wrap 布局下会挤爆版面，不推荐。

## 移动端小屏"层级选择"最佳实践

- 空间敏感（卡片 / bottom sheet / 小屏）→ **避免内联展开**，用 **弹层**：`showDialog` 或 `showModalBottomSheet`（本项目已大量用 bottom sheet，风格统一）。
- 弹层内放 **可搜索 + 可展开/折叠的树列表**：搜索能极大缓解"树层级深、找不到"的问题；展开状态默认只展开根任务（或记忆上次选择路径自动展开到当前选中项）。
- 单点即选即回填（点叶子/父节点直接 `Navigator.pop(value)`），比"确定/取消"少一步。
- 门控的 UX 惯例：未选项目时父任务入口禁用 + 提示文案（如"先选项目"）；选了项目后只展示该项目子树。

## 结合本项目约束的方案（2-3 个）

> 前置改造（三方案通用）：`LazyLogParentOption` 增加 `parentId` 字段；`_lazyLogParentCandidates`（或新增方法）改为返回所选项目下的**全量任务**（根+后代，带 parentId），构造处透传 parentId；审核页 `_ParentDropdown` 改造为"门控 + 弹层选择器"。

### 方案 A（推荐）：自绘树 + showModalBottomSheet 弹层选择器 —— 零依赖、复用既有骨架

- 实现：新增可复用 widget `TaskTreePickerSheet`（项目内 `widgets/` 下）。复用 `subtask_tree_section.dart:159-213` 的 `_buildChildrenByParent` + 递归 `_buildTree` + `expandedNodes` Set 逻辑，行样式换成可点选（`InkWell` + 选中高亮/勾选），缩进 `depth * 16`，带展开/折叠 chevron。支持传入 `searchQuery` 过滤。
- 触发：`_ParentDropdown` 换成 `TextButton/OutlinedButton`（显示"无父任务/当前父任务标题"），点击 `showModalBottomSheet`（可复用 home_page 现成 bottom sheet 样式）。
- 选中：`Navigator.pop(context, selected)` 回填到 `repository.updateDraft(draft.id, parentTaskId: ...)`。
- 优点：零新增依赖；完全贴合 AppTheme；与 `subtask_tree_section` / `multi_day_task_list_page` 的既有 DFS 实现同构，维护成本低；移动端+桌面端均好使；易加搜索。
- 成本：约 100-150 行新代码 + 单测/widget 测试。
- 风险：低。

### 方案 B：官方内置 `TreeSliver` 弹层

- 实现：`showDialog`/`showModalBottomSheet` 内放 `CustomScrollView` + `TreeSliver<TreeOption>`；用 DFS 把项目子树接成 `List<TreeSliverNode>`，`TreeSliverController` 控制展开/折叠，`treeNodeBuilder` 渲染行、`onNodeToggle` 记录展开态。
- 优点：官方、零依赖、懒加载（树很深/很宽时内存友好）、自带展开动画与缩进线；符合"生态已把 flutter_tree_view 归并到 TreeSliver"的方向。
- 缺点：须包在滚动容器里（无法内联卡片）；要自己接 `children/parent` 链接 + 维护扁平列表；行样式定制自由度低于自绘；项目里没有现成 TreeSliver 先例，学习/调试成本更高。
- 适用：若预期父任务树规模很大（几百上千节点）值得选它。

### 方案 C：级联/两级联动选择（dropdown_button2 MultiMenuButton 或 联动两步）

- 实现：不做整树展示。第一步下拉选根任务，若根任务有子任务则出现第二级下拉选子任务；或 `dropdown_button2` 3.x `MultiMenuButton` 做级联子菜单（桌面鼠标友好）。
- 优点：最省弹层空间，行内即可完成；联动思路有 `lazy_log_creation_dialog.dart:358` 的既有过滤先例。
- 缺点：**不是"树状图"，看不到全层级**，与 PRD"树状图更直观"的诉求相悖；`MultiMenuButton` 子菜单在移动端点按体验差（hover/expand 交互）。只适合作为"空间极受限时的降级"。

### 三方案对比

| 维度 | A 自绘弹层树 | B TreeSliver 弹层 | C 级联/联动 |
|---|---|---|---|
| 是否"树状图"直观 | ✅ 全层级可见 | ✅ 全层级可见 | ⚠️ 只见两级 |
| 新增依赖 | 无 | 无 | dropdown_button2 |
| 移动端体验 | 好（点按+搜索） | 好 | 一般（多级菜单） |
| 代码量 | 中（~150 行） | 中（接节点+controller） | 少 |
| 大规模树性能 | 一次性渲染 | 懒加载更优 | 不限 |
| 复用既有 DFS 代码 | ✅ 直接平移 | ✅ 复用生成扁平列表 | 复用过滤 |

## 需要主 Agent 决策的开放点

- **可选项范围**：PRD 开放问题"父任务可选仅根任务还是任意层级"。建议默认**任意层级节点都可选**（更能体现树的价值），并在弹层里对根任务视觉上区别于子任务（如加粗/文件夹图标）。若坚持仅根任务可选，则子任务仅作层级展示、不可点选（灰置）。该选择决定 `_lazyLogParentCandidates` 是否去掉 `parentId == null` 条件。
- **是否要搜索框**：建议加，成本低收益高。
- 平台优先：需求写"移动端"，但 Taskora 同时是桌面应用；方案 A/B 均双端通用，方案 C 更偏桌面。

## Caveats / Not Found

- **`flutter_tree_view` 在 pub.dev 上不存在**（API 返回 `NoSuchKey`）——用户提到的包名应指 `baumths/flutter_tree_view`（已改名 `flutter_fancy_tree_view` 且废弃）。见上文。
- 外部网页调研受限：Jina Reader 网络不可达、gh code-search 无结果，部分 Material 交互惯例结论基于常识与主流产品实践（Todoist/Notion 等），建议实施前用最新文档复核 TreeSliver API 细节（`api.flutter.dev/flutter/widgets/TreeSliver-class.html`）。
- 未实测：TreeSliver 在弹层内的具体表现（滚动 + 节点行自定义）未跑 demo，实施时先做最小可运行样例。
