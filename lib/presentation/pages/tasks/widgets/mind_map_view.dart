import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database/app_database.dart';
import '../../../../services/task_conflict_service.dart';
import '../../../blocs/task_new/task_bloc.dart';
import '../../../blocs/task_new/task_event.dart';
import '../../../widgets/calendar_date_picker.dart';
import '../../../widgets/task_conflict_dialog.dart';

// ─── 布局常量 ───
const double _kNodeWidth = 260.0;
const double _kNodeHeight = 90.0;
const double _kHGap = 100.0;
const double _kVGap = 48.0;
const double _kCanvasPadding = 100.0;
const double _kCanvasShift = 20000.0; // 固定偏移，确保负坐标节点始终在 bounds 内
const double _kCanvasSize = 50000.0; // 固定大画布尺寸

// ─── 布局数据 ───
class _LayoutNode {
  final Task task;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final List<_LayoutNode> children;
  double x = 0;
  double y = 0;
  double subtreeHeight = 0;

  _LayoutNode({
    required this.task,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
    this.children = const [],
  });
}

class MindMapView extends StatefulWidget {
  final List<Task> tasks;
  final Map<String, String> projectNames;
  final List<Project> projects;
  final Map<String, int> taskProgress;
  final String? selectedFilter;
  final String? selectedProjectId;
  final String? focusTaskId;
  final int? focusRequestToken;
  final Set<String> expandedIds;
  final String userId;
  final void Function(String id) onTaskTap;
  final void Function(String id) onTaskToggle;
  final void Function(String id) onTaskDelete;
  final void Function(String taskId, String? newParentId) onMoveToParent;
  final void Function(String taskId) onToggleExpand;
  final void Function(String parentId) onAddSubtask;

  const MindMapView({
    super.key,
    required this.tasks,
    this.projectNames = const {},
    this.projects = const [],
    this.taskProgress = const {},
    this.selectedFilter,
    this.selectedProjectId,
    this.focusTaskId,
    this.focusRequestToken,
    this.expandedIds = const {},
    required this.userId,
    required this.onTaskTap,
    required this.onTaskToggle,
    required this.onTaskDelete,
    required this.onMoveToParent,
    required this.onToggleExpand,
    required this.onAddSubtask,
  });

  @override
  State<MindMapView> createState() => _MindMapViewState();
}

class _MindMapViewState extends State<MindMapView> {
  final TransformationController _transformController =
      TransformationController();

  // ─── 自由拖拽模式 ───
  final bool _freeDragMode = true;

  // ─── 节点拖拽中标记：true 时禁用画布平移，避免整片画布联动 ───
  bool _nodeDragging = false;

  // ─── 框选模式（桌面端 Ctrl+左键） ───
  final ValueNotifier<bool> _ctrlPressed = ValueNotifier(false);
  bool _isSelecting = false;
  Rect? _selectionRect;
  Offset? _selectionStart;
  Offset? _pointerDownPos;
  String? _pointerDownNodeId;
  final Set<String> _selectedIds = {};
  // 空白处点击取消框选：记录背景按下位置，区分点击与平移
  Offset? _bgPointerDownPos;

  // ─── 节点连线模式 ───
  String? _connectingFromId;
  Offset? _connectingEndPos;

  // ─── 布局缓存 ───
  List<_LayoutNode> _cachedPendingNodes = [];
  List<_ConnectorLine> _cachedPendingLines = [];
  Size _cachedPendingCanvasSize = Size.zero;

  // ─── 每个 pending 节点一个稳定的 ValueNotifier（创建时即分配，拖拽期间不重建） ───
  final Map<String, ValueNotifier<Offset>> _positionNotifiers = {};
  final Set<String> _draggedIds = {};
  int? _handledFocusRequestToken;

  // ─── 初始定位标志 ───
  bool _initialFocusDone = false;
  bool _offsetsLoaded = false;

  String get _storageKey => 'mindmap_offsets_${widget.userId}';

  @override
  void initState() {
    super.initState();
    _computeLayoutCache();
    _loadOffsets();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    // 初始视口定位到内容区域（偏移后的坐标）
    _transformController.value = Matrix4.identity()
      ..setTranslationRaw(-_kCanvasShift, -_kCanvasShift, 0);
  }

  @override
  void didUpdateWidget(MindMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks ||
        oldWidget.expandedIds != widget.expandedIds) {
      _computeLayoutCache();
      _reloadOffsets();
    }
    if (oldWidget.selectedFilter != widget.selectedFilter ||
        oldWidget.selectedProjectId != widget.selectedProjectId) {
      _initialFocusDone = false;
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _ctrlPressed.dispose();
    for (final n in _positionNotifiers.values) {
      n.dispose();
    }
    _transformController.dispose();
    super.dispose();
  }

  // ─── 布局缓存计算 ───
  void _computeLayoutCache() {
    // 已完成任务并入主导图（保持原父子位置，仅节点置灰），不再单独成列
    final allTasks = widget.tasks
        .where((t) => t.status == 0 || t.status == 2)
        .toList();

    final roots = _buildTree(allTasks, widget.expandedIds);
    _layoutTree(roots);
    _cachedPendingNodes = [];
    for (final root in roots) {
      _collectNodes(root, _cachedPendingNodes);
    }
    _cachedPendingLines = [];
    for (final root in roots) {
      _cachedPendingLines.addAll(_collectLines(root));
    }
    _cachedPendingCanvasSize = _computeCanvasSize(_cachedPendingNodes);

    // 为每个节点创建/更新稳定的 ValueNotifier
    _syncNotifiersToLayout();
  }

  /// 为每个 pending 节点创建/更新 notifier，清理移除节点的 notifier
  void _syncNotifiersToLayout() {
    final currentIds = _cachedPendingNodes.map((n) => n.task.id).toSet();
    // 清理已移除节点
    for (final id in _positionNotifiers.keys.toList()) {
      if (!currentIds.contains(id)) {
        _positionNotifiers.remove(id)?.dispose();
        _draggedIds.remove(id);
      }
    }
    // 创建新节点 notifier，非拖拽节点更新到新布局位置
    for (final node in _cachedPendingNodes) {
      final id = node.task.id;
      final existing = _positionNotifiers[id];
      if (existing == null) {
        _positionNotifiers[id] = ValueNotifier(Offset(node.x, node.y));
      } else if (!_draggedIds.contains(id)) {
        existing.value = Offset(node.x, node.y);
      }
    }
  }

  Future<void> _loadOffsets() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (!mounted) return;
    if (json != null) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(json) as Map);
        for (final entry in map.entries) {
          final list = entry.value as List;
          final notifier = _positionNotifiers[entry.key];
          if (notifier != null) {
            notifier.value = Offset(
              (list[0] as num).toDouble(),
              (list[1] as num).toDouble(),
            );
            _draggedIds.add(entry.key);
          }
        }
      } catch (_) {
        // 解析失败则忽略，使用默认布局
      }
    }
    if (mounted) setState(() => _offsetsLoaded = true);
  }

  /// 在 [didUpdateWidget] 中重新加载存储的 offset，不触发 [setState] 或 [_focusNearestTask]。
  /// 区别于 [_loadOffsets]（仅在 initState 调用一次，含 _offsetsLoaded 标记）。
  Future<void> _reloadOffsets() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (!mounted) return;
    if (json != null) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(json) as Map);
        for (final entry in map.entries) {
          final list = entry.value as List;
          final notifier = _positionNotifiers[entry.key];
          if (notifier != null) {
            notifier.value = Offset(
              (list[0] as num).toDouble(),
              (list[1] as num).toDouble(),
            );
            _draggedIds.add(entry.key);
          }
        }
      } catch (_) {
        // 解析失败则忽略，使用默认布局
      }
    }
  }

  Future<void> _saveOffsets() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, List<double>>{};
    for (final id in _draggedIds) {
      final notifier = _positionNotifiers[id];
      if (notifier != null) {
        map[id] = [notifier.value.dx, notifier.value.dy];
      }
    }
    if (map.isEmpty) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(_storageKey, jsonEncode(map));
    }
  }

  // ─── 键盘事件处理 ───
  bool _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
          event.logicalKey == LogicalKeyboardKey.controlRight) {
        _ctrlPressed.value = true;
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _selectedIds.clear();
        _isSelecting = false;
        _selectionRect = null;
        _connectingFromId = null;
        _connectingEndPos = null;
        if (_nodeDragging) _nodeDragging = false;
        setState(() {});
        return true;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
          event.logicalKey == LogicalKeyboardKey.controlRight) {
        _ctrlPressed.value = false;
        _isSelecting = false;
        _selectionRect = null;
        _pointerDownPos = null;
        _pointerDownNodeId = null;
        setState(() {});
        return true;
      }
    }
    return false;
  }

  // ─── 节点碰撞检测 ───
  String? _hitTestNode(Offset position) {
    for (final node in _cachedPendingNodes) {
      final notifier = _positionNotifiers[node.task.id];
      final pos = notifier?.value ?? Offset(node.x, node.y);
      if (Rect.fromLTWH(pos.dx, pos.dy, _kNodeWidth, _kNodeHeight)
          .contains(position)) {
        return node.task.id;
      }
    }
    return null;
  }

  // ─── 框选指针事件处理 ───
  void _onSelectionPanStart(DragStartDetails d) {
    final raw = d.localPosition -
        const Offset(_kCanvasShift, _kCanvasShift);
    _pointerDownPos = raw;
    _pointerDownNodeId = _hitTestNode(raw);
    _isSelecting = true;
    _selectionStart = raw;
    _selectionRect = null;
    _nodeDragging = true;
    setState(() {});
  }

  void _onSelectionPanUpdate(DragUpdateDetails d) {
    if (!_isSelecting || _selectionStart == null) return;
    final raw = d.localPosition -
        const Offset(_kCanvasShift, _kCanvasShift);
    final a = _selectionStart!;
    setState(() {
      _selectionRect = Rect.fromLTRB(
        math.min(a.dx, raw.dx),
        math.min(a.dy, raw.dy),
        math.max(a.dx, raw.dx),
        math.max(a.dy, raw.dy),
      );
    });
  }

  void _onSelectionPanEnd(DragEndDetails d) {
    if (!_isSelecting) return;
    if (_selectionRect != null) {
      _selectedIds
        ..clear()
        ..addAll(_computeIntersectingNodes(_selectionRect!));
    } else if (_pointerDownNodeId != null && _pointerDownPos != null) {
      if (_selectedIds.contains(_pointerDownNodeId)) {
        _selectedIds.remove(_pointerDownNodeId);
      } else {
        _selectedIds.add(_pointerDownNodeId!);
      }
    } else {
      _selectedIds.clear();
    }
    _isSelecting = false;
    _selectionRect = null;
    _nodeDragging = false;
    _pointerDownPos = null;
    _pointerDownNodeId = null;
    setState(() {});
  }

  Set<String> _computeIntersectingNodes(Rect rect) {
    final ids = <String>{};
    for (final node in _cachedPendingNodes) {
      final notifier = _positionNotifiers[node.task.id];
      final pos = notifier?.value ?? Offset(node.x, node.y);
      if (rect.overlaps(
          Rect.fromLTWH(pos.dx, pos.dy, _kNodeWidth, _kNodeHeight))) {
        ids.add(node.task.id);
      }
    }
    return ids;
  }

  // ─── 树构建 ───
  List<_LayoutNode> _buildTree(List<Task> tasks, Set<String> expandedIds) {
    final taskIds = tasks.map((t) => t.id).toSet();
    final roots = tasks.where((t) {
      final pid = t.parentId;
      return pid == null || !taskIds.contains(pid);
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return roots.map((r) => _buildNode(r, 0, tasks, expandedIds)).toList();
  }

  _LayoutNode _buildNode(
      Task task, int depth, List<Task> allTasks, Set<String> expandedIds) {
    final childTasks = allTasks.where((t) => t.parentId == task.id).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final hasChildren = childTasks.isNotEmpty;
    final isExpanded = expandedIds.contains(task.id);

    final children = (hasChildren && isExpanded)
        ? childTasks
            .map((c) => _buildNode(c, depth + 1, allTasks, expandedIds))
            .toList()
        : <_LayoutNode>[];

    return _LayoutNode(
      task: task,
      depth: depth,
      hasChildren: hasChildren,
      isExpanded: isExpanded,
      children: children,
    );
  }

  // ─── 坐标计算 ───
  void _layoutTree(List<_LayoutNode> roots) {
    for (final root in roots) {
      _computeSubtreeHeight(root);
    }

    double currentY = _kCanvasPadding;
    for (final root in roots) {
      _assignPositions(root, _kCanvasPadding, currentY);
      currentY += root.subtreeHeight + _kVGap * 2;
    }
  }

  void _computeSubtreeHeight(_LayoutNode node) {
    if (node.children.isEmpty) {
      node.subtreeHeight = _kNodeHeight;
      return;
    }
    for (final child in node.children) {
      _computeSubtreeHeight(child);
    }
    final childrenTotalHeight = node.children.fold<double>(
          0,
          (sum, c) => sum + c.subtreeHeight,
        ) +
        (node.children.length - 1) * _kVGap;
    node.subtreeHeight = math.max(_kNodeHeight, childrenTotalHeight);
  }

  void _assignPositions(_LayoutNode node, double x, double y) {
    node.x = x;
    node.y = y + (node.subtreeHeight - _kNodeHeight) / 2;

    if (node.children.isEmpty) return;

    final childX = x + _kNodeWidth + _kHGap;
    final childrenTotalHeight = node.children.fold<double>(
          0,
          (sum, c) => sum + c.subtreeHeight,
        ) +
        (node.children.length - 1) * _kVGap;
    double childY = y + (node.subtreeHeight - childrenTotalHeight) / 2;

    for (final child in node.children) {
      _assignPositions(child, childX, childY);
      childY += child.subtreeHeight + _kVGap;
    }
  }

  // ─── 收集所有节点和连线 ───
  void _collectNodes(_LayoutNode node, List<_LayoutNode> out) {
    out.add(node);
    for (final child in node.children) {
      _collectNodes(child, out);
    }
  }

  List<_ConnectorLine> _collectLines(_LayoutNode node) {
    final lines = <_ConnectorLine>[];
    for (final child in node.children) {
      lines.add(_ConnectorLine(parentId: node.task.id, childId: child.task.id));
      lines.addAll(_collectLines(child));
    }
    return lines;
  }

  /// 获取节点当前位置（自动布局 + 拖拽偏移）
  Map<String, Offset> _buildNodePositionMap(List<_LayoutNode> nodes) {
    final map = <String, Offset>{};
    for (final node in nodes) {
      final notifier = _positionNotifiers[node.task.id];
      if (notifier != null) {
        map[node.task.id] = notifier.value;
      } else {
        map[node.task.id] = Offset(node.x, node.y);
      }
    }
    return map;
  }

  /// 获取 pending 节点当前位置（用于 lines painter，每次拖拽时调用）
  Map<String, Offset> _buildPendingPositionMap() {
    final map = <String, Offset>{};
    for (final node in _cachedPendingNodes) {
      final notifier = _positionNotifiers[node.task.id];
      map[node.task.id] = notifier?.value ?? Offset(node.x, node.y);
    }
    return map;
  }

  Size _computeCanvasSize(List<_LayoutNode> allNodes) {
    if (allNodes.isEmpty) return const Size(400, 400);
    double maxX = 0, maxY = 0;
    for (final n in allNodes) {
      final notifier = _positionNotifiers[n.task.id];
      final px = notifier?.value.dx ?? n.x;
      final py = notifier?.value.dy ?? n.y;
      maxX = math.max(maxX, px + _kNodeWidth);
      maxY = math.max(maxY, py + _kNodeHeight);
    }
    return Size(maxX + _kCanvasPadding * 2 + 300, maxY + _kCanvasPadding * 2 + 300);
  }

  void _centerLayoutNode(_LayoutNode node, Size viewportSize) {
    final nodePosition = _positionNotifiers[node.task.id]?.value ??
        Offset(node.x, node.y);
    final targetCenter = nodePosition +
        const Offset(_kCanvasShift, _kCanvasShift) +
        const Offset(_kNodeWidth / 2, _kNodeHeight / 2);
    final scale = _transformController.value.getMaxScaleOnAxis();
    final next = Matrix4.copy(_transformController.value)
      ..setTranslationRaw(
        viewportSize.width / 2 - targetCenter.dx * scale,
        viewportSize.height / 2 - targetCenter.dy * scale,
        0,
      );
    _transformController.value = next;
  }

  void _focusTask(String taskId, Size viewportSize) {
    final target = _cachedPendingNodes
        .where((node) => node.task.id == taskId)
        .firstOrNull;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到可见的思维导图节点')),
      );
      return;
    }
    _centerLayoutNode(target, viewportSize);
    setState(() {
      _selectedIds
        ..clear()
        ..add(taskId);
    });
  }

  void _focusNearestTask(Size viewportSize, {bool showSnackBar = true}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _LayoutNode? nearest;
    int? nearestDiff;

    for (final node in _cachedPendingNodes) {
      final timestamp = node.task.startDate ?? node.task.dueDate;
      if (timestamp == null) continue;
      final diff = (timestamp - now).abs();
      if (nearestDiff == null || diff < nearestDiff) {
        nearest = node;
        nearestDiff = diff;
      }
    }

    if (nearest == null) {
      // fallback：定位到第一个节点
      if (_cachedPendingNodes.isNotEmpty) {
        nearest = _cachedPendingNodes.first;
      } else {
        if (showSnackBar) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有带时间的任务节点')),
          );
        }
        return;
      }
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有带时间的任务节点')),
        );
      }
    }

    _centerLayoutNode(nearest, viewportSize);
    setState(() {
      _selectedIds
        ..clear()
        ..add(nearest!.task.id);
    });
  }

  // ─── 右键点击连线删除 ───
  void _handleLineRightClick(
      BuildContext context, Offset nodeSpacePos, Offset globalPos) {
    final posMap = _buildPendingPositionMap();

    _ConnectorLine? nearest;
    double nearestDist = 24.0;

    for (final line in _cachedPendingLines) {
      final parentPos = posMap[line.parentId];
      final childPos = posMap[line.childId];
      if (parentPos == null || childPos == null) continue;

      final startX = parentPos.dx + _kNodeWidth;
      final startY = parentPos.dy + _kNodeHeight / 2;
      final endX = childPos.dx;
      final endY = childPos.dy + _kNodeHeight / 2;
      final midX = (startX + endX) / 2;
      final midY = (startY + endY) / 2;

      final dist = (nodeSpacePos - Offset(midX, midY)).distance;
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = line;
      }
    }

    if (nearest == null) return;
    final found = nearest;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          globalPos.dx, globalPos.dy, globalPos.dx, globalPos.dy),
      items: [
        const PopupMenuItem(
          value: 'disconnect',
          child: Row(
            children: [
              Icon(Icons.link_off, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('断开连接', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'disconnect') {
        widget.onMoveToParent(found.childId, null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedPendingNodes.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildMindMapCanvas(
      _cachedPendingNodes,
      _cachedPendingLines,
      _cachedPendingCanvasSize,
      _buildNodePositionMap(_cachedPendingNodes),
      isCompleted: false,
    );
  }

  Widget _buildMindMapCanvas(
    List<_LayoutNode> nodes,
    List<_ConnectorLine> lines,
    Size canvasSize,
    Map<String, Offset> nodePositions, {
    required bool isCompleted,
  }) {
    Widget buildNodeCard(_LayoutNode node) {
      final nodeCompleted = node.task.status == 2;
      return RepaintBoundary(
        child: _MindMapNodeCard(
          node: node,
          projectName: widget.projectNames[node.task.projectId],
          projects: widget.projects,
          progress: widget.taskProgress[node.task.id] ?? 0,
          isCompleted: nodeCompleted,
          freeDragMode: _freeDragMode,
          onDragStart: _freeDragMode
              ? (id) {
                  if (_selectedIds.contains(id) && _selectedIds.length > 1) {
                    _draggedIds.addAll(_selectedIds);
                  } else {
                    _draggedIds.add(id);
                    if (!_selectedIds.contains(id)) _selectedIds.clear();
                  }
                  setState(() => _nodeDragging = true);
                }
              : null,
          onDragUpdate: _freeDragMode
              ? (id, delta) {
                  final ids = (_selectedIds.contains(id) && _selectedIds.length > 1)
                      ? _selectedIds
                      : {id};
                  for (final mid in ids) {
                    final notifier = _positionNotifiers[mid];
                    if (notifier != null) {
                      notifier.value = notifier.value + delta;
                    }
                  }
                }
              : null,
          onDragEnd: _freeDragMode
              ? (_) {
                  _saveOffsets();
                  // 连线模式期间保持 _nodeDragging=true，不重置
                  if (_nodeDragging && _connectingFromId == null) {
                    setState(() => _nodeDragging = false);
                  }
                }
              : null,
          onTap: () => widget.onTaskTap(node.task.id),
          onToggle: () => widget.onTaskToggle(node.task.id),
          onDelete: () => widget.onTaskDelete(node.task.id),
          onToggleExpand: node.hasChildren
              ? () => widget.onToggleExpand(node.task.id)
              : null,
          onMoveToParent: widget.onMoveToParent,
          onAddSubtask: () => widget.onAddSubtask(node.task.id),
          onConnectStart: (id) {
            setState(() {
              _connectingFromId = id;
              _connectingEndPos = null;
              _nodeDragging = true;
            });
          },
          onConnectUpdate: (id, localPos) {
            final nodePos = _positionNotifiers[id]?.value;
            if (nodePos == null) return;
            setState(() {
              _connectingEndPos = Offset(
                nodePos.dx + (_kNodeWidth - 2) + localPos.dx,
                nodePos.dy + (_kNodeHeight / 2 - 14) + localPos.dy,
              );
            });
          },
          onConnectEnd: (id, localPos) {
            final nodePos = _positionNotifiers[id]?.value;
            if (nodePos != null) {
              final canvasPos = Offset(
                nodePos.dx + (_kNodeWidth - 2) + localPos.dx,
                nodePos.dy + (_kNodeHeight / 2 - 14) + localPos.dy,
              );
              final targetId = _hitTestNode(canvasPos);
              if (targetId != null && targetId != id) {
                widget.onMoveToParent(targetId, id);
              }
            }
            setState(() {
              _connectingFromId = null;
              _connectingEndPos = null;
              _nodeDragging = false;
            });
          },
          onConnectCancel: () {
            setState(() {
              _connectingFromId = null;
              _connectingEndPos = null;
              _nodeDragging = false;
            });
          },
          allTasks: widget.tasks,
          isSelected: _selectedIds.contains(node.task.id),
        ),
      );
    }

    // 连线 + 节点层（pending 节点统一用 AnimatedBuilder + ValueListenableBuilder，
    // 每个节点有稳定的 ValueNotifier，拖拽期间 widget 树不重建，手势不中断）
    Widget canvasContent() {
      final listenables = isCompleted
          ? <Listenable>[]
          : _positionNotifiers.values.toList();
      return AnimatedBuilder(
        animation: Listenable.merge(listenables),
        builder: (context, _) {
          final effectivePositions = isCompleted
              ? nodePositions
              : _buildPendingPositionMap();

          // 偏移后坐标（确保所有节点在固定大画布内）
          final shiftedPositions = effectivePositions
              .map((k, v) => MapEntry(k, v + const Offset(_kCanvasShift, _kCanvasShift)));

          // 橡皮筋连线端点（shifted 坐标系）
          Offset? cFrom;
          Offset? cTo;
          if (_connectingFromId != null) {
            final fp = effectivePositions[_connectingFromId];
            if (fp != null) {
              cFrom = Offset(
                fp.dx + _kNodeWidth + _kCanvasShift,
                fp.dy + _kNodeHeight / 2 + _kCanvasShift,
              );
            }
            if (_connectingEndPos != null) {
              cTo = _connectingEndPos! + const Offset(_kCanvasShift, _kCanvasShift);
            }
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onSecondaryTapUp: (details) {
              final nodePos = details.localPosition -
                  const Offset(_kCanvasShift, _kCanvasShift);
              _handleLineRightClick(context, nodePos, details.globalPosition);
            },
            child: SizedBox(
            width: _kCanvasSize,
            height: _kCanvasSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [

                CustomPaint(
                  size: const Size(_kCanvasSize, _kCanvasSize),
                  painter: _MindMapLinesPainter(
                    lines: lines,
                    nodePositions: shiftedPositions,
                    connectingFrom: cFrom,
                    connectingTo: cTo,
                  ),
                ),
                if (_isSelecting && _selectionRect != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _SelectionRectPainter(
                            rect: _selectionRect!.shift(const Offset(
                                _kCanvasShift, _kCanvasShift))),
                      ),
                    ),
                  ),
                ...nodes.map((node) {
                  final notifier = _positionNotifiers[node.task.id];
                  if (notifier != null) {
                    return ValueListenableBuilder<Offset>(
                      valueListenable: notifier,
                      builder: (_, pos, child) => Positioned(
                          left: pos.dx + _kCanvasShift,
                          top: pos.dy + _kCanvasShift,
                          child: child!),
                      child: buildNodeCard(node),
                    );
                  }
                  final pos = effectivePositions[node.task.id] ??
                      Offset(node.x, node.y);
                  return Positioned(
                    left: pos.dx + _kCanvasShift,
                    top: pos.dy + _kCanvasShift,
                    child: buildNodeCard(node),
                  );
                }),
                // Ctrl+框选覆盖层
                ValueListenableBuilder<bool>(
                  valueListenable: _ctrlPressed,
                  builder: (context, ctrlDown, _) {
                    return IgnorePointer(
                      ignoring: !ctrlDown,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanStart:
                            ctrlDown ? _onSelectionPanStart : null,
                        onPanUpdate:
                            ctrlDown ? _onSelectionPanUpdate : null,
                        onPanEnd: ctrlDown ? _onSelectionPanEnd : null,
                      ),
                    );
                  },
                ),
              ],
            ),
          ), // SizedBox
          ); // GestureDetector
        },
      );
    }

    final viewer = InteractiveViewer(
      transformationController: _transformController,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.15,
      maxScale: 3.0,
      panEnabled: !_nodeDragging,
      child: DragTarget<String>(
        onAcceptWithDetails: (details) {
          final draggedId = details.data;
          final task =
              widget.tasks.where((t) => t.id == draggedId).firstOrNull;
          if (task == null || task.parentId == null) return;
          widget.onMoveToParent(draggedId, null);
        },
        builder: (context, candidateData, rejectedData) {
          return canvasContent();
        },
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize =
            Size(constraints.maxWidth, constraints.maxHeight);
        // 初始自动定位：offsets 加载完成且节点存在时定位一次
        if (!_initialFocusDone && _offsetsLoaded && _cachedPendingNodes.isNotEmpty) {
          _initialFocusDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focusNearestTask(viewportSize, showSnackBar: false);
          });
        }
        final focusTaskId = widget.focusTaskId;
        final focusRequestToken = widget.focusRequestToken;
        if (focusTaskId != null &&
            focusRequestToken != null &&
            _handledFocusRequestToken != focusRequestToken) {
          _handledFocusRequestToken = focusRequestToken;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focusTask(focusTaskId, viewportSize);
          });
        }
        return Stack(
          children: [
        // 背景点击取消框选：Listener 放在 InteractiveViewer 外层，
        // 绕过 InteractiveViewer 内部的 ScaleGestureRecognizer 拦截
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            _bgPointerDownPos = e.localPosition;
          },
          onPointerUp: (e) {
            final down = _bgPointerDownPos;
            _bgPointerDownPos = null;
            if (down != null &&
                (e.localPosition - down).distance < 8 &&
                _selectedIds.isNotEmpty) {
              setState(() => _selectedIds.clear());
            }
          },
          child: viewer,
        ),
        Positioned(
          right: 80,
          top: 16,
          child: FloatingActionButton.small(
            heroTag: 'focus_nearest_task',
            backgroundColor: AppTheme.bgCard,
            tooltip: '自动锁定',
            onPressed: () => _focusNearestTask(viewportSize),
            child: Icon(
              Icons.center_focus_strong_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 16,
          child: FloatingActionButton.small(
            heroTag: 'reset_layout',
            backgroundColor: AppTheme.bgCard,
            tooltip: '重置布局',
            onPressed: () {
              _draggedIds.clear();
              _selectedIds.clear();
              for (final node in _cachedPendingNodes) {
                _positionNotifiers[node.task.id]?.value =
                    Offset(node.x, node.y);
              }
              _saveOffsets();
            },
            child: Icon(
              Icons.restart_alt_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ),
        ),
          ],
        );
      },
    );
  }

  Widget _buildCompletedSection(
    List<_LayoutNode> nodes,
    List<_ConnectorLine> lines,
    Size canvasSize,
    Map<String, Offset> nodePositions,
    int count,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 18, color: AppTheme.success),
            const SizedBox(width: 8),
            Text('已完成 ($count)',
                style: TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary)),
          ],
        ),
        initiallyExpanded: false,
        children: [
          SizedBox(
            height: math.min(canvasSize.height, 300),
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.3,
              maxScale: 2.0,
              child: SizedBox(
                width: canvasSize.width,
                height: canvasSize.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: canvasSize,
                      painter: _MindMapLinesPainter(
                        lines: lines,
                        nodePositions: nodePositions,
                      ),
                    ),
                    ...nodes.map((node) {
                      final pos = nodePositions[node.task.id] ??
                          Offset(node.x, node.y);
                      return Positioned(
                        left: pos.dx,
                        top: pos.dy,
                        child: _MindMapNodeCard(
                          node: node,
                          projectName:
                              widget.projectNames[node.task.projectId],
                          projects: widget.projects,
                          progress:
                              widget.taskProgress[node.task.id] ?? 100,
                          isCompleted: true,
                          freeDragMode: false,
                          onDragStart: null,
                          onDragUpdate: null,
                          onDragEnd: null,
                          onTap: () => widget.onTaskTap(node.task.id),
                          onToggle: () =>
                              widget.onTaskToggle(node.task.id),
                          onDelete: () =>
                              widget.onTaskDelete(node.task.id),
                          onToggleExpand: null,
                          onMoveToParent: widget.onMoveToParent,
                          onAddSubtask: () =>
                              widget.onAddSubtask(node.task.id),
                          allTasks: widget.tasks,
                          isSelected: false,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    String message;
    IconData icon;

    if (widget.selectedFilter == 'today') {
      message = '今天没有任务';
      icon = Icons.today_rounded;
    } else if (widget.selectedFilter == 'important') {
      message = '没有重要任务';
      icon = Icons.star_outline_rounded;
    } else {
      message = '还没有任务\n点击右下角 + 创建';
      icon = Icons.checklist_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textHint, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─── 连线数据 ───
class _ConnectorLine {
  final String parentId;
  final String childId;
  const _ConnectorLine({required this.parentId, required this.childId});
}

// ─── 贝塞尔曲线连接线 ───
class _MindMapLinesPainter extends CustomPainter {
  final List<_ConnectorLine> lines;
  final Map<String, Offset> nodePositions;
  final Offset? connectingFrom; // 橡皮筋起点（shifted 坐标）
  final Offset? connectingTo;   // 橡皮筋终点（shifted 坐标）

  const _MindMapLinesPainter({
    required this.lines,
    required this.nodePositions,
    this.connectingFrom,
    this.connectingTo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      final parentPos = nodePositions[line.parentId];
      final childPos = nodePositions[line.childId];
      if (parentPos == null || childPos == null) continue;

      final startX = parentPos.dx + _kNodeWidth;
      final startY = parentPos.dy + _kNodeHeight / 2;
      final endX = childPos.dx;
      final endY = childPos.dy + _kNodeHeight / 2;

      final paint = Paint()
        ..color = AppTheme.primaryColor.withValues(alpha: 0.35)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final midX = (startX + endX) / 2;
      final path = Path()
        ..moveTo(startX, startY)
        ..cubicTo(
          midX, startY,
          midX, endY,
          endX, endY,
        );
      canvas.drawPath(path, paint);

      // 箭头
      const arrowSize = 6.0;
      final arrowPaint = Paint()
        ..color = AppTheme.primaryColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;

      final arrowPath = Path()
        ..moveTo(endX, endY)
        ..lineTo(endX - arrowSize, endY - arrowSize / 2)
        ..lineTo(endX - arrowSize, endY + arrowSize / 2)
        ..close();
      canvas.drawPath(arrowPath, arrowPaint);
    }

    // 橡皮筋连线（拖拽连接中）
    if (connectingFrom != null && connectingTo != null) {
      final from = connectingFrom!;
      final to = connectingTo!;
      final midX = (from.dx + to.dx) / 2;

      final rubberPath = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(midX, from.dy, midX, to.dy, to.dx, to.dy);

      final rubberPaint = Paint()
        ..color = AppTheme.primaryColor.withValues(alpha: 0.8)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      _drawDashedPath(canvas, rubberPath, rubberPaint);

      // 终点圆点
      canvas.drawCircle(
        to,
        5,
        Paint()
          ..color = AppTheme.primaryColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLength = 8.0;
    const gapLength = 4.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      bool drawing = true;
      while (dist < metric.length) {
        final segLen = drawing ? dashLength : gapLength;
        final end = math.min(dist + segLen, metric.length);
        if (drawing) canvas.drawPath(metric.extractPath(dist, end), paint);
        dist = end;
        drawing = !drawing;
      }
    }
  }

  @override
  bool shouldRepaint(_MindMapLinesPainter old) =>
      old.lines != lines ||
      old.nodePositions != nodePositions ||
      old.connectingFrom != connectingFrom ||
      old.connectingTo != connectingTo;
}

// ─── 节点卡片 ───
class _MindMapNodeCard extends StatelessWidget {
  final _LayoutNode node;
  final String? projectName;
  final List<Project> projects;
  final int progress;
  final bool isCompleted;
  final bool freeDragMode;
  final void Function(String id)? onDragStart;
  final void Function(String id, Offset delta)? onDragUpdate;
  final void Function(String id)? onDragEnd;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onToggleExpand;
  final void Function(String taskId, String? newParentId) onMoveToParent;
  final VoidCallback onAddSubtask;
  final void Function(String nodeId)? onConnectStart;
  final void Function(String nodeId, Offset localPos)? onConnectUpdate;
  final void Function(String nodeId, Offset localPos)? onConnectEnd;
  final VoidCallback? onConnectCancel;
  final List<Task> allTasks;
  final bool isSelected;

  const _MindMapNodeCard({
    required this.node,
    this.projectName,
    this.projects = const [],
    required this.progress,
    required this.isCompleted,
    this.freeDragMode = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.onToggleExpand,
    required this.onMoveToParent,
    required this.onAddSubtask,
    this.onConnectStart,
    this.onConnectUpdate,
    this.onConnectEnd,
    this.onConnectCancel,
    required this.allTasks,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final task = node.task;
    final priorityColor = _priorityColorByInt(task.priority);
    final progressPercent = progress.clamp(0, 100).toInt();

    // 自由拖拽模式：GestureDetector 处理位置移动 + LongPressDraggable 处理父子关系
    if (freeDragMode && onDragUpdate != null) {
      return DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          final draggedId = details.data;
          if (draggedId == task.id) return false;
          if (_isDescendant(draggedId, task.id)) return false;
          return true;
        },
        onAcceptWithDetails: (details) {
          final draggedId = details.data;
          if (draggedId == task.id) return;
          onMoveToParent(draggedId, task.id);
        },
        builder: (context, candidateData, rejectedData) {
          final isDragOver = candidateData.isNotEmpty;

          return LongPressDraggable<String>(
            data: task.id,
            delay: const Duration(milliseconds: 400),
            feedback: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: _kNodeWidth,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor),
                ),
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _buildCardContent(
                  context, task, priorityColor, progressPercent, false, isSelected),
            ),
            child: GestureDetector(
              // onPanDown 在指针按下时立即触发，比 onPanStart 更早，能尽早设置
              // _nodeDragging=true，防止 InteractiveViewer 同步进入手势竞技场
              onPanDown: (_) => onDragStart?.call(task.id),
              onPanUpdate: (details) =>
                  onDragUpdate?.call(task.id, details.delta),
              onPanEnd: (_) => onDragEnd?.call(task.id),
              onPanCancel: () => onDragEnd?.call(task.id),
              child: _buildCardContent(
                  context, task, priorityColor, progressPercent, isDragOver, isSelected),
            ),
          );
        },
      );
    }

    // 非自由拖拽模式：DragTarget + Draggable（用于将任务拖到另一个父节点）
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final draggedId = details.data;
        if (draggedId == task.id) return false;
        if (_isDescendant(draggedId, task.id)) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        final draggedId = details.data;
        if (draggedId == task.id) return;
        onMoveToParent(draggedId, task.id);
      },
      builder: (context, candidateData, rejectedData) {
        final isDragOver = candidateData.isNotEmpty;

        return Draggable<String>(
          data: task.id,
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: _kNodeWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor),
              ),
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildCardContent(
                context, task, priorityColor, progressPercent, false, isSelected),
          ),
          child: _buildCardContent(
              context, task, priorityColor, progressPercent, isDragOver, isSelected),
        );
      },
    );
  }

  Widget _buildCardContent(BuildContext context, Task task, Color priorityColor,
      int progressPercent, bool isDragOver,
      [bool isSelected = false]) {
    return SizedBox(
      width: _kNodeWidth + 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 主卡片
          GestureDetector(
            onSecondaryTapUp: (details) =>
                _showContextMenu(context, details.globalPosition),
            child: Container(
              width: _kNodeWidth,
              constraints: const BoxConstraints(minHeight: _kNodeHeight),
              decoration: BoxDecoration(
                color: isDragOver
                    ? AppTheme.primaryColor.withValues(alpha: 0.08)
                    : (isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.05)
                        : isCompleted
                            ? Colors.grey.shade200
                            : AppTheme.bgCard),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDragOver
                      ? AppTheme.primaryColor.withValues(alpha: 0.5)
                      : (isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.7)
                          : isCompleted
                              ? Colors.grey.shade300
                              : AppTheme.borderSubtle),
                  width: (isDragOver || isSelected) ? 2 : 1,
                ),
                boxShadow: isCompleted
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 第一行：优先级 + 复选框
                      Row(
                        children: [
                          _PriorityDot(
                            priority: task.priority,
                            color: isCompleted
                                ? AppTheme.textHint
                                : priorityColor,
                            label: _priorityShortLabel(task.priority),
                            onSelected: (p) {
                              context.read<TaskNewBloc>().add(
                                    UpdateTask(id: task.id, priority: p),
                                  );
                            },
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: onToggle,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isCompleted
                                      ? AppTheme.primaryColor
                                      : AppTheme.textHint,
                                  width: 2,
                                ),
                              ),
                              child: isCompleted
                                  ? const Icon(Icons.check,
                                      size: 12, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 项目名（可点击切换）
                      _buildProjectChip(context, task),
                      // 标题 + 展开/收缩按钮
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isCompleted
                                    ? AppTheme.textHint
                                    : AppTheme.textPrimary,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          if (node.hasChildren && onToggleExpand != null) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: onToggleExpand,
                              child: Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  node.isExpanded
                                      ? Icons.remove_rounded
                                      : Icons.add_rounded,
                                  size: 14,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // 时间行（开始和结束分开点击编辑）
                      if (task.startDate != null || task.dueDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 11,
                                color: (task.dueDate != null && _isOverdue(task.dueDate!))
                                    ? AppTheme.error
                                    : AppTheme.textHint),
                            const SizedBox(width: 3),
                            if (task.startDate != null)
                              GestureDetector(
                                onTap: () => _editSingleDate(context, task, isStart: true),
                                child: Text(
                                  _formatDate(task.startDate!),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textHint,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppTheme.textHint.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            if (task.startDate != null && task.dueDate != null)
                              Text(
                                ' → ',
                                style: TextStyle(fontSize: 10, color: AppTheme.textHint),
                              ),
                            if (task.dueDate != null)
                              GestureDetector(
                                onTap: () => _editSingleDate(context, task, isStart: false),
                                child: Text(
                                  _formatDate(task.dueDate!),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _isOverdue(task.dueDate!)
                                        ? AppTheme.error
                                        : AppTheme.textHint,
                                    decoration: TextDecoration.underline,
                                    decorationColor: (_isOverdue(task.dueDate!)
                                        ? AppTheme.error
                                        : AppTheme.textHint).withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      // 进度条
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progressPercent / 100,
                                minHeight: 3,
                                backgroundColor:
                                    AppTheme.borderSubtle.withValues(alpha: 0.6),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isCompleted
                                      ? AppTheme.success
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$progressPercent%',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textHint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 右上角 "-" 删除按钮
          Positioned(
            top: -6,
            right: 22,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(Icons.remove, size: 14, color: Colors.white),
              ),
            ),
          ),
          // 右侧中间 "+" 添加子任务 / 长按拖出连线
          if (!isCompleted)
            Positioned(
              top: _kNodeHeight / 2 - 14,
              left: _kNodeWidth - 2,
              child: GestureDetector(
                onTap: onAddSubtask,
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) => onConnectStart?.call(task.id),
                onLongPressMoveUpdate: (d) =>
                    onConnectUpdate?.call(task.id, d.localPosition),
                onLongPressEnd: (d) =>
                    onConnectEnd?.call(task.id, d.localPosition),
                onLongPressCancel: () => onConnectCancel?.call(),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectChip(BuildContext context, Task task) {
    if (projectName == null && projects.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: projects.isNotEmpty
          ? () {
              final renderBox = context.findRenderObject() as RenderBox;
              final offset = renderBox.localToGlobal(Offset.zero);
              showMenu<String>(
                context: context,
                position: RelativeRect.fromLTRB(
                  offset.dx, offset.dy + 40, offset.dx + 100, offset.dy + 60,
                ),
                items: projects
                    .map((p) => PopupMenuItem<String>(
                          value: p.id,
                          height: 36,
                          child: Row(
                            children: [
                              Text(p.name, style: const TextStyle(fontSize: 13)),
                              if (p.id == task.projectId) ...[
                                const Spacer(),
                                Icon(Icons.check,
                                    size: 14, color: AppTheme.primaryColor),
                              ],
                            ],
                          ),
                        ))
                    .toList(),
              ).then((value) {
                if (value != null && value != task.projectId) {
                  context.read<TaskNewBloc>().add(
                        UpdateTask(id: task.id, projectId: value),
                      );
                }
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              projectName ?? '未分配',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isCompleted ? AppTheme.textHint : AppTheme.primaryColor,
              ),
            ),
            if (projects.isNotEmpty) ...[
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down, size: 12,
                  color: isCompleted ? AppTheme.textHint : AppTheme.primaryColor),
            ],
          ],
        ),
      ),
    );
  }

  bool _isDescendant(String ancestorId, String targetId) {
    String? current = targetId;
    final visited = <String>{};
    while (current != null && visited.add(current)) {
      if (current == ancestorId) return true;
      final task = allTasks.where((t) => t.id == current).firstOrNull;
      current = task?.parentId;
    }
    return false;
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 8),
              Text('编辑'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') onTap();
      if (value == 'delete') onDelete();
    });
  }

  Future<void> _editSingleDate(BuildContext context, Task task, {required bool isStart}) async {
    final now = DateTime.now();
    final current = isStart
        ? (task.startDate != null ? DateTime.fromMillisecondsSinceEpoch(task.startDate!) : now)
        : (task.dueDate != null ? DateTime.fromMillisecondsSinceEpoch(task.dueDate!) : now);
    final picked = await showCalendarDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      title: isStart ? '选择开始时间' : '选择结束时间',
    );
    if (picked == null || !context.mounted) return;

    final candidateStart = isStart
        ? picked
        : (task.startDate != null ? DateTime.fromMillisecondsSinceEpoch(task.startDate!) : null);
    final candidateEnd = isStart
        ? (task.dueDate != null ? DateTime.fromMillisecondsSinceEpoch(task.dueDate!) : null)
        : picked;

    if (candidateStart != null &&
        candidateEnd != null &&
        candidateEnd.isAfter(candidateStart) &&
        !TaskConflictService.isRangeMultiDay(candidateStart, candidateEnd)) {
      final bloc = context.read<TaskNewBloc>();
      final svc = TaskConflictService(taskRepository: bloc.taskRepository);
      final conflict = await svc.checkConflict(
        candidateStart,
        candidateEnd,
        excludeTaskId: task.id,
      );
      if (conflict != null && context.mounted) {
        final choice = await showTaskConflictDialog(
          context,
          conflict: conflict,
          newStart: candidateStart,
          newEnd: candidateEnd,
        );
        if (!context.mounted) return;
        switch (choice) {
          case ConflictChoice.cancel:
          case null:
            return;
          case ConflictChoice.parallel:
            break;
          case ConflictChoice.autoDelay:
            final delayed = await svc.calcDelayedSlot(
              candidateStart,
              candidateEnd,
              conflict.conflictEnd,
              excludeTaskId: task.id,
            );
            if (delayed != null && context.mounted) {
              bloc.add(UpdateTask(
                id: task.id,
                startDate: delayed.start.millisecondsSinceEpoch,
                dueDate: delayed.end.millisecondsSinceEpoch,
              ));
              return;
            }
          case ConflictChoice.autoInsert:
            final shifts = await svc.calcInsertedShifts(
              candidateStart,
              candidateEnd,
              excludeTaskId: task.id,
            );
            if (context.mounted) {
              bloc.add(UpdateTask(
                id: task.id,
                startDate: candidateStart.millisecondsSinceEpoch,
                dueDate: candidateEnd.millisecondsSinceEpoch,
                shiftedTasks: shifts,
              ));
              return;
            }
        }
      }
    }

    if (!context.mounted) return;
    final millis = picked.millisecondsSinceEpoch;
    if (isStart) {
      context.read<TaskNewBloc>().add(UpdateTask(id: task.id, startDate: millis));
    } else {
      context.read<TaskNewBloc>().add(UpdateTask(id: task.id, dueDate: millis));
    }
  }

  static Color _priorityColorByInt(int priority) {
    switch (priority) {
      case 5:
        return AppTheme.priorityP0;
      case 3:
        return AppTheme.priorityP1;
      case 1:
        return AppTheme.priorityP3;
      default:
        return AppTheme.borderSubtle;
    }
  }

  static String _priorityShortLabel(int p) {
    switch (p) {
      case 5:
        return '高';
      case 3:
        return '中';
      case 1:
        return '低';
      default:
        return '无';
    }
  }

  static bool _isOverdue(int timestamp) {
    final now = DateTime.now();
    final due = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return due.isBefore(now);
  }

  static String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (target == today) return '今天 $time';
    if (target == today.add(const Duration(days: 1))) return '明天 $time';
    if (target == today.subtract(const Duration(days: 1))) return '昨天 $time';
    return '${date.month}/${date.day} $time';
  }

}

// ─── 优先级胶囊（紧凑版） ───
class _PriorityDot extends StatelessWidget {
  final int priority;
  final Color color;
  final String label;
  final ValueChanged<int> onSelected;

  const _PriorityDot({
    required this.priority,
    required this.color,
    required this.label,
    required this.onSelected,
  });

  static final _options = [
    (0, '无', AppTheme.textHint),
    (1, '低', AppTheme.priorityP3),
    (3, '中', AppTheme.priorityP1),
    (5, '高', AppTheme.priorityP0),
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '优先级',
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (_) => _options
          .map((o) => PopupMenuItem<int>(
                value: o.$1,
                height: 36,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: o.$3, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(o.$2, style: const TextStyle(fontSize: 13)),
                    if (priority == o.$1) ...[
                      const Spacer(),
                      Icon(Icons.check,
                          size: 14, color: AppTheme.primaryColor),
                    ],
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 框选矩形绘制器 ───
class _SelectionRectPainter extends CustomPainter {
  final Rect rect;
  const _SelectionRectPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, border);
  }

  @override
  bool shouldRepaint(_SelectionRectPainter old) => old.rect != rect;
}
