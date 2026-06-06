# 极致性能优化：Tab 页面切换卡顿

## Goal

消除首页/任务/日历/我的四个 tab 页面之间切换时的卡顿（当前有时卡住几秒），实现毫秒级的即时切换体验。该项目是一个 Flutter 桌面+移动端应用，使用 `IndexedStack` + `BottomNavigationBar` 实现 tab 导航。

## What I already know

### 当前架构

- **main.dart**: `MyApp` → 登录后渲染 `HomePage`
- **HomePage** (home_page.dart):
  - 使用 `IndexedStack(index: _currentIndex, children: _pages)` 保持所有页面存活
  - `_pages = _buildPages()` 使用 `late final` 只构建一次（缓存页面实例）
  - `ValueNotifier<int> _visibleTabIndex` 通知首页 tab 可见性
  - 4 个 tab: `_HomeContent` (首页), `TasksPage` (任务), `CalendarPage` (日历), `ProfilePage` (我的)
  - 使用 `BottomNavigationBar`，`onTap` 调用 `setState(() => _currentIndex = index)`
  - 已应用防抖：`_debounceLoadTasks`（500ms）、项目变更 debounce（500ms）

### 各 Tab 页面的性能负载

1. **`_HomeContent`** (首页 2500+行):
   - `_loadData()`: 加载 projects（DB）、storage tasks（本地存储）、DB tasks（SQLite）
   - 构建 timeline 列表（排序+去重）
   - 过滤/统计计算
   - `BlocListener<TaskNewBloc>` 监听 state 变化，TaskNewLoaded 时触发 `_loadData()`
   - 每 2 秒节流
   - build 方法极其复杂：`_buildTimeline()`、`_buildTaskDetail()`、`_buildQuadrantChart()`、`_buildProjectFilter()` 一个不落全都执行

2. **`TasksPage`** (任务 1300+行):
   - `initState` 中加载项目侧边栏偏好 + `context.read<TaskNewBloc>().add(LoadTasks())`
   - 项目侧边栏 + 任务列表 + 思维导图

3. **`CalendarPage`** (日历 2600+行):
   - `initState` 中初始化 repos、加载节假日数据
   - 周视图/月视图切换、任务拖拽

4. **`ProfilePage`** (我的 400+行):
   - `initState._init()`: DB 查询全部 tasks，计算完成率/连续天数

### 已有的优化措施

- `late final _pages` 避免每次 build 重建页面
- `_visibleTabIndex` + `_onVisibleTabChanged` 让首页在不可见时跳过 `_loadData`
- 防抖定时器避免密集触发

### 仍然存在卡顿的根因

用户反馈：**桌面端 来回切换偶发卡顿；长时间不操作后第一次切 tab 卡，连续切反而顺**

根因定位：

1. **`setState` 重建了整个 `HomePage.build()`**（4272 行的大文件）
   - `BottomNavigationBar.onTap → setState(() => _currentIndex = index)` 触发 `_HomePageState.build()` 全量重跑
   - 每次 build 创建全新的 `Scaffold` + `_buildBottomNav()`（Container + SafeArea + BottomNavigationBar + 4 个 BottomNavigationBarItem × 各自的 Column + Icon + Container(小圆点)）
   - Flutter 框架 diff 新的 BottomNavigationBar widget 树 → layout → paint

2. **长时间 idle 后 Dart VM 去优化**
   - 桌面端 Dart 的 JIT 编译热点在 GC/空闲后可能丢失
   - 首次交互触发编译器重新预热 → 卡顿

3. **`_buildBottomNav()` 不是 const/可复用 widget**
   - 每次 build 创建全新的 widget 引用，框架无法跳过 diff

## Assumptions (temporary)

- 卡顿主要发生在桌面端（Windows/macOS/Linux）和高端 Android 设备上
- DB 查询（SQLite 通过 drift）是主要瓶颈之一
- 用户期望切换时间 < 100ms（感觉不到延迟）

## Requirements

1. Tab 切换时不触发 `HomePage.build()` 全量重建
2. BottomNavigationBar 独立更新其选中态，不带动 body 重建
3. 新增 `RepaintBoundary` 包裹每个 tab 页面，隔离不可见页面的重绘
4. 保持所有页面存活（依然使用 IndexedStack，不切换为懒加载）

## Acceptance Criteria

- [ ] 桌面端点击 tab 响应时间 < 16ms（1帧内切换）
- [ ] `setState` 不完全不在 tab 切换路径上出现
- [ ] `ValueListenableBuilder` 仅重建 `IndexedStack` 部分，不波及 Scaffold
- [ ] `_buildBottomNav()` 抽出为独立 Widget，可被框架高效复用

## Decision (ADR-lite)

**Context**: `setState` 导致 HomePage.build() 全量重建（4272 行文件），重建包含 Scaffold + IndexedStack + FAB + BottomNavigationBar

**Decision**: 将 `int _currentIndex` 改为 `ValueNotifier<int> _tabIndex`，用 `ValueListenableBuilder` 分别包裹：
- `IndexedStack`（body 切换）
- BottomNavigationBar 选中态
- FAB（只在首页显示）

`BottomNavigationBar.onTap` 改为 `_tabIndex.value = i`（无 `setState`）。  
提取 `_buildBottomNav()` 为独立 `_BottomNavWidget` 类。

**Consequences**:
- Tab 切换触发 0 次 `_HomePageState.build()` 调用
- 每个 ValueListenableBuilder 只重建自己负责的子树
- Scaffold / Container / SafeArea 等框架 widget 在 tab 切换时完全不重建
- Bar 选中态仍正确更新（ValueNotifier 通知）

## Definition of Done

- 代码改动完成，编译通过
- 在桌面端运行时 tab 切换感觉不到任何延迟
- 无功能性退化（所有 tab 页面正确显示、滚动、交互）

## Out of Scope (explicit)

- 不改变 `IndexedStack` 为 `PageView` 或其他方案
- 不改变 `_buildPages()` 为懒加载
- 不优化单个 tab 页面的内部性能（如 `_loadData()`、timeline 构建等）
- 不引入新依赖

## Technical Approach

### 核心改动：用 ValueNotifier + ValueListenableBuilder 替代 setState

**改前**：
```
int _currentIndex;
BottomNavigationBar.onTap → setState(() => _currentIndex = index)
  → HomePage.build() 全量重跑
    → Scaffold(body: IndexedStack) + _buildBottomNav() + FAB
```

**改后**：
```
ValueNotifier<int> _tabIndex = ValueNotifier(0);
BottomNavigationBar.onTap → _tabIndex.value = index
  → 仅 ValueListenableBuilder.valueListenable=_tabIndex 的子树重跑
    → IndexedStack (body) ← 仅这一个 builder 重跑
    → _BottomNavWidget (nav) ← 仅这一个 builder 重跑
    → FAB ← 仅这一个 builder 重跑
  → Scaffold 不重建
  → Container / SafeArea / boxShadow 不重建
```

### 具体改动（3 处）：

**改动 1**：替换字段声明和 build 方法
```dart
// Before
int _currentIndex = 0;

// After
final ValueNotifier<int> _tabIndex = ValueNotifier(0);
```

**改动 2**：build 方法
```dart
// Before
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: IndexedStack(index: _currentIndex, children: _pages),
    bottomNavigationBar: _buildBottomNav(),
    floatingActionButton: _currentIndex == 0
        ? FloatingActionButton(onPressed: _createSchedule, ...)
        : null,
  );
}

// After
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      builder: (ctx, index, _) => IndexedStack(index: index, children: _pages),
    ),
    bottomNavigationBar: ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      builder: (ctx, index, _) => _BottomNavWidget(
        currentIndex: index,
        onTap: _onNavTap,
      ),
    ),
    floatingActionButton: ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      builder: (ctx, index, _) => index == 0
          ? FloatingActionButton(onPressed: _createSchedule, elevation: 2, child: const Icon(Icons.add))
          : const SizedBox.shrink(),
    ),
  );
}
```

**改动 3**：提取 `_BottomNavWidget` + 修改 `_jumpToMindMap`
```dart
// 从 _HomePageState 中移除 _buildBottomNav() 和 _navItem()
// 替换为独立 class _BottomNavWidget extends StatelessWidget

// BottomNavigationBar.onTap:
void _onNavTap(int index) {
  if (_tabIndex.value == index) return;
  _tabIndex.value = index;
  _visibleTabIndex.value = index;
}

// _jumpToMindMap:
void _jumpToMindMap(Task task) {
  _tabIndex.value = 1;
  _visibleTabIndex.value = 1;
  // ... rest unchanged
}
```

### 额外收益

- `_HomePageState.initState()` 中添加 `_tabIndex.addListener(...)` 替代码中所有 `_currentIndex` 读取点
- 搜索 `_currentIndex` 旧引用全部替换为 `_tabIndex.value`

## Technical Notes

### 关键文件

- `lib/presentation/pages/home/home_page.dart` — 唯一需要修改的文件（~4272 行）

### 搜索范围（需替换的 `_currentIndex` 引用）

- `_currentIndex` 字段声明
- `build()` 中的 body/bottomNav/FAB
- `_buildBottomNav()` 和 `_navItem()` 中的 `_currentIndex`
- `_jumpToMindMap()` 中的 `_currentIndex = 1`
- 所有 `setState(() { _currentIndex = ... })` → 替换为 `_tabIndex.value = ...`

## Implementation Plan

**Step 1**: 替换 `_currentIndex` → `_tabIndex`，build 方法中包裹 ValueListenableBuilder
**Step 2**: 提取 `_BottomNavWidget` 独立类（含 _navItem 逻辑）
**Step 3**: 替换 `_jumpToMindMap` 和 BottomNavigationBar.onTap 中的 setState
**Step 4**: 给每个 tab 页面添加 `RepaintBoundary`（额外优化）
