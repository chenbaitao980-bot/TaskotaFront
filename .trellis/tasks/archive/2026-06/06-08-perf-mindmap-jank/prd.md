# perf: 消除思维导图/tab 切换/拖拽/输入卡顿

## Goal

让用户在切换 tab、拖拽画布、拖拽节点、输入文字、创建节点等所有高频交互场景中感知不到卡顿（目标：稳定 60 fps，无丢帧）。

## What I already know

### 已确认的性能瓶颈（代码级）

1. **MindMapView — AnimatedBuilder 合并所有 Notifier**
   - `canvasContent()` 中用 `Listenable.merge(_positionNotifiers.values)` 驱动整个 `AnimatedBuilder`
   - 拖拽任意一个节点 → 所有节点全部 rebuild + Lines painter 重绘
   - 节点数 50+ 时每帧 O(n) rebuild

2. **MindMapLinesPainter — shouldRepaint 恒 true**
   - `_buildPendingPositionMap()` 每次返回新 `Map` 对象
   - `old.nodePositions != nodePositions` 始终为 true → 每帧强制重绘连线

3. **onDragStart / onDragEnd 触发 setState**
   - `_nodeDragging` 状态改变触发 `_MindMapViewState.build()` 全量重建
   - 包括重新创建所有 `buildNodeCard` 闭包、所有 `ValueListenableBuilder`

4. **`_buildExpandCollapseButton` — O(n²) 计算在 build 中**
   - `state.tasks.any((c) => c.parentId == t.id)` 在每次 widget build 时执行 O(n²) 遍历

5. **_saveOffsets 每次拖拽结束写 SharedPreferences**
   - 写 I/O 在主线程同步感知（虽然异步，但频繁触发）

6. **BLoC 每次 mutation 都完整重走 _emitTaskSnapshot**
   - 包含多次数据库查询 + `_calculateProgress`（遍历所有任务+检查项）
   - 创建节点后立即切换 tab，会看到 loading 状态闪烁

### 已有的优化

- `_pages` 缓存（tab 切换不重建页面）✓
- `RepaintBoundary` 包裹每个页面 ✓
- 每个节点 `ValueNotifier<Offset>` 独立 ✓
- 节点 `RepaintBoundary` 包裹 ✓

## Assumptions (temporary)

- 节点数量：中等（20~100），不是超大规模
- 目标平台：Windows 桌面端（主要）+ 移动端
- 不需要引入新的外部依赖

## Open Questions

（逐一通过用户确认）

## Requirements (evolving)

- [ ] 拖拽节点时只重绘该节点和连线层，其余节点不 rebuild
- [ ] Lines painter 只在连线实际位置变化时重绘
- [ ] onDragStart/End 不触发全量 setState
- [ ] TasksPage build 中的 O(n²) 计算改为缓存/O(n)
- [ ] _saveOffsets 加防抖（如 300ms）

## Acceptance Criteria (evolving)

- [ ] 拖拽节点时 Flutter DevTools 帧率稳定 ≥ 60fps
- [ ] 50 个节点场景下拖拽无丢帧
- [ ] tab 切换无闪烁（当前已基本满足）
- [ ] 创建节点后立即可操作，不出现 loading 遮挡

## Definition of Done

- lint / type-check 通过
- 人工验证上述 Acceptance Criteria

## Out of Scope

- 虚拟化（Canvas 视口剔除）——当前节点数不需要
- 后端 / 数据库查询优化

## Technical Notes

- `mind_map_view.dart`: 单文件 2076 行，包含 State + 多个 CustomPainter + NodeCard
- `tasks_page.dart`: 1454 行，BlocConsumer + 所有 CRUD 对话框
- `task_bloc.dart`: 1428 行，所有事件处理
- 核心瓶颈集中在 `_MindMapViewState._buildMindMapCanvas()` 的 `canvasContent()` 方法
