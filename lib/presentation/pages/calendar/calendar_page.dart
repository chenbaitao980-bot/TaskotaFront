import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../services/holiday_service.dart';
import '../../../services/subtask_scheduler.dart';
import '../../../models/node_template_payload.dart';
import '../../../services/local_storage_service.dart';
import '../../blocs/task_new/task_bloc.dart';
import '../../blocs/task_new/task_event.dart';
import '../../blocs/task_new/task_state.dart';
import '../../widgets/project_picker_content.dart';
import '../tasks/task_detail/task_detail_page.dart';
import '../tasks/widgets/task_create_sheet.dart';
import 'day_task_lane_layout.dart';
import 'task_time_range_guard.dart';
import 'package:drift/drift.dart' show Value;

class CalendarPage extends StatefulWidget {
  final ValueChanged<Task>? onJumpToMindMap;

  const CalendarPage({super.key, this.onJumpToMindMap});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final ScrollController _weekScrollController = ScrollController();
  bool _didAutoScrollWeek = false;
  int _displayDayCount = isMobile ? 3 : 7;
  // H6: 双指缩放高频写入，用 ValueNotifier 只重建周视图网格子树
  final ValueNotifier<double> _hourHeightNotifier = ValueNotifier<double>(80);
  double get _hourHeight => _hourHeightNotifier.value;
  static const double _timeColumnWidth = 48;
  static const double _minHourHeight = 32;
  static const double _maxHourHeight = 120;
  static const double _zoomStep = 8;
  String? _editingTaskId;
  final Map<int, Offset> _activePointers = {};
  double? _pinchBaseDistance;
  double? _pinchBaseHourHeight;
  final GlobalKey _timelineListenerKey = GlobalKey();
  // H1: 翻周拖拽偏移高频写入，用 ValueNotifier 只重建 Transform.translate 子树
  final ValueNotifier<double> _dragOffset = ValueNotifier<double>(0);
  double _cachedDayWidth = 100;
  // H3: 拖拽开关铁律，禁止 setState
  final ValueNotifier<bool> _isTaskDragging = ValueNotifier<bool>(false);
  bool _dragSkipped = false; // onPointerMove 因拖拽任务跳过时置 true，阻止 onPointerUp 翻页
  double? _dragStartX;
  final Set<String> _collapsedMultiDayGroups = {};

  DateTime? _lastReloadTime;
  List<Task> _allTasks = [];
  // H2: parentId 集合，随 _allTasks 装载重建，_hasChildren O(1) 查询
  Set<String> _parentIdSet = const {};
  // M1/M2: 任务按天分桶缓存，数据源/筛选变化时置空失效
  Map<DateTime, List<Task>>? _tasksByDayCache;
  List<Project> _allProjects = [];
  List<ProjectGroup> _allGroups = [];
  final Set<String> _selectedProjectIds = {};
  String? get _selectedProjectId =>
      _selectedProjectIds.length == 1 ? _selectedProjectIds.first : null;
  HolidayCountry _selectedHolidayCountry = HolidayCountry.china;
  final Map<int, Map<String, HolidayInfo>> _holidayCache = {};
  final Set<int> _holidayLoadingYears = {};
  final LocalStorageService _storage = LocalStorageService();
  bool _initialized = false;
  TaskRepository? _taskRepo;
  ProjectRepository? _projectRepo;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRepos();
    });
  }

  void _initRepos() {
    if (!mounted) return;
    final bloc = context.read<TaskNewBloc>();
    _taskRepo = bloc.taskRepository;
    _projectRepo = bloc.projectRepository;
    // 直接从数据库加载日历数据，不依赖 BlocListener 时序
    _reloadData();
    _loadHolidaysForYears({_focusedDay.year});
  }

  Future<void> _loadHolidaysForYears(Set<int> years) async {
    final pending = years
        .where(
          (year) =>
              !_holidayCache.containsKey(year) &&
              !_holidayLoadingYears.contains(year),
        )
        .toList();
    if (pending.isEmpty) return;

    setState(() => _holidayLoadingYears.addAll(pending));
    final country = _selectedHolidayCountry;
    for (final year in pending) {
      final holidays = await HolidayService.fetchHolidays(country, year);
      if (!mounted || country != _selectedHolidayCountry) return;
      setState(() {
        _holidayCache[year] = holidays;
        _holidayLoadingYears.remove(year);
      });
    }
  }

  Future<void> _reloadData({
    List<Project>? cachedProjects,
    List<ProjectGroup>? cachedGroups,
    bool force = false,
  }) async {
    if (_taskRepo == null || _projectRepo == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_initialized) _reloadData();
      });
      return;
    }
    final now = DateTime.now();
    if (!force &&
        _initialized &&
        _lastReloadTime != null &&
        now.difference(_lastReloadTime!) < const Duration(seconds: 2)) {
      return;
    }
    _lastReloadTime = now;
    try {
      await _storage.init();
      final excludedProjectIds = _storage.excludedProjectIds;
      final tasks = (await _taskRepo!.getAll())
          .where((task) => !excludedProjectIds.contains(task.projectId))
          .toList();
      final projects = cachedProjects ?? await _projectRepo!.getActive();
      final List<ProjectGroup> groups = cachedGroups ??
          await (context.read<TaskNewBloc>().projectGroupRepository?.getAll() ??
              Future.value(<ProjectGroup>[]));
      if (mounted) {
        setState(() {
          _allTasks = tasks;
          _allProjects = projects;
          _allGroups = groups;
          _parentIdSet =
              tasks.map((t) => t.parentId).whereType<String>().toSet();
          _tasksByDayCache = null;
          _initialized = true;
        });
      }
    } catch (e) {
      if (!_initialized && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_initialized) _reloadData();
        });
      } else if (mounted) {
        setState(() => _initialized = true);
      }
    }
  }

  @override
  void dispose() {
    _weekScrollController.dispose();
    _hourHeightNotifier.dispose();
    _dragOffset.dispose();
    _isTaskDragging.dispose();
    super.dispose();
  }

  // ── 帮助方法 ──

  Color _priorityColor(int priority) {
    if (priority >= 4) return AppTheme.priorityP0;
    if (priority == 3) return AppTheme.priorityP1;
    if (priority == 2) return AppTheme.priorityP2;
    return AppTheme.priorityP3;
  }

  String _priorityLabel(int priority) {
    if (priority >= 4) return 'P0';
    if (priority == 3) return 'P1';
    if (priority == 2) return 'P2';
    return 'P3';
  }

  List<Task> _filteredTasks() {
    var tasks = _allTasks
        .where((t) => t.startDate != null || t.dueDate != null)
        .toList();
    if (_selectedProjectIds.isNotEmpty) {
      tasks = tasks
          .where((t) => _selectedProjectIds.contains(t.projectId))
          .toList();
    }
    return tasks;
  }

  bool _isMultiDayTask(Task task) {
    // 有子任务的"父任务"无条件显示为顶部跨天长条
    if (_hasChildren(task)) return true;
    final s = task.startDate;
    final d = task.dueDate;
    if (s == null || d == null) return false;
    final start = DateTime.fromMillisecondsSinceEpoch(s);
    final end = DateTime.fromMillisecondsSinceEpoch(d);
    return !_isSameDate(start, end);
  }

  bool _hasChildren(Task task) {
    return _parentIdSet.contains(task.id);
  }

  /// M1/M2: 已筛选任务按天分桶（键为当天零点），懒计算 + 数据变化时失效
  Map<DateTime, List<Task>> get _tasksByDay =>
      _tasksByDayCache ??= _bucketTasksByDay(_filteredTasks());

  Map<DateTime, List<Task>> _bucketTasksByDay(List<Task> tasks) {
    final map = <DateTime, List<Task>>{};
    for (final task in tasks) {
      final s = task.startDate;
      final d = task.dueDate;
      if (s == null && d == null) continue;
      final start = s != null
          ? DateTime.fromMillisecondsSinceEpoch(s)
          : DateTime.fromMillisecondsSinceEpoch(d!);
      final end = d != null
          ? DateTime.fromMillisecondsSinceEpoch(d)
          : start.add(const Duration(hours: 1));
      // 与 _taskOverlapsDay 同语义：start < dayEnd && end > dayStart
      var day = DateTime(start.year, start.month, start.day);
      while (day.isBefore(end)) {
        map.putIfAbsent(day, () => []).add(task);
        day = DateTime(day.year, day.month, day.day + 1);
      }
    }
    return map;
  }


  /// 任务的 [startDate, dueDate] 是否与 [rangeStart, rangeEndExclusive) 相交
  bool _taskOverlapsRange(
    Task task,
    DateTime rangeStart,
    DateTime rangeEndExclusive,
  ) {
    final s = task.startDate;
    final d = task.dueDate;
    if (s == null && d == null) return false;
    final start = s != null
        ? DateTime.fromMillisecondsSinceEpoch(s)
        : DateTime.fromMillisecondsSinceEpoch(d!);
    final end = d != null
        ? DateTime.fromMillisecondsSinceEpoch(d)
        : start.add(const Duration(hours: 1));
    return start.isBefore(rangeEndExclusive) && end.isAfter(rangeStart);
  }

  bool _taskOverlapsDay(Task task, DateTime day) {
    final s = task.startDate;
    final d = task.dueDate;
    if (s == null && d == null) return false;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final start = s != null
        ? DateTime.fromMillisecondsSinceEpoch(s)
        : DateTime.fromMillisecondsSinceEpoch(d!);
    final end = d != null
        ? DateTime.fromMillisecondsSinceEpoch(d)
        : start.add(const Duration(hours: 1));
    return start.isBefore(dayEnd) && end.isAfter(dayStart);
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfWeek(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return date.subtract(Duration(days: date.weekday - 1)); // 周一基准
  }

  String _timeLabel(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String? _parentLabel(Task task) {
    if (task.parentId == null) return null;
    final parent = _allTasks.where((t) => t.id == task.parentId).firstOrNull;
    if (parent == null) return null;
    return '📁 ${parent.title}';
  }

  _HolidayDisplay? _holidayDisplayFor(DateTime day) {
    final holiday = HolidayService.getHoliday(
      _holidayCache[day.year] ?? {},
      day,
    );
    if (holiday != null) {
      switch (holiday.type) {
        case HolidayType.makeupWork:
          return _HolidayDisplay(
            label: '补班',
            name: holiday.name,
            color: Colors.orange.shade700,
            backgroundColor: Colors.orange.shade50,
            isWorkday: true,
          );
        case HolidayType.statutory:
        case HolidayType.traditional:
          return _HolidayDisplay(
            label: holiday.name,
            name: holiday.name,
            color: Colors.red.shade600,
            backgroundColor: Colors.red.shade50,
            isWorkday: false,
          );
        case HolidayType.observance:
          return _HolidayDisplay(
            label: holiday.name,
            name: holiday.name,
            color: Colors.blue.shade700,
            backgroundColor: Colors.blue.shade50,
            isWorkday: true,
          );
      }
    }
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      return _HolidayDisplay(
        label: '休',
        name: '周末休息日',
        color: Colors.green.shade700,
        backgroundColor: Colors.green.shade50,
        isWorkday: false,
      );
    }
    return null;
  }

  void _onFocusedDayChanged(DateTime focusedDay) {
    final prev = _selectedDay ?? focusedDay;
    final lastDay = DateTime(focusedDay.year, focusedDay.month + 1, 0).day;
    final targetDay = prev.day > lastDay ? lastDay : prev.day;
    setState(() {
      _focusedDay = focusedDay;
      _selectedDay = DateTime(focusedDay.year, focusedDay.month, targetDay);
    });
    _loadHolidaysForYears({focusedDay.year});
  }

  // ── 滚动 ──

  void _scrollWeekToCurrentTime() {
    if (_calendarFormat != CalendarFormat.week || _didAutoScrollWeek) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_weekScrollController.hasClients) return;
      final now = DateTime.now();
      final offset = ((now.hour + now.minute / 60) * _hourHeight - 180).clamp(
        0.0,
        _weekScrollController.position.maxScrollExtent,
      );
      _weekScrollController.jumpTo(offset);
      _didAutoScrollWeek = true;
    });
  }

  void _setHourHeight(double height, {double? focalPointOffset}) {
    final nextHeight = height.clamp(_minHourHeight, _maxHourHeight).toDouble();
    if (nextHeight == _hourHeight) return;
    final position = _weekScrollController.hasClients
        ? _weekScrollController.position
        : null;
    // 如果提供了焦点偏移，围绕焦点缩放；否则回退到 viewport 中心
    final double? anchorHour;
    if (focalPointOffset != null && position != null) {
      anchorHour = (position.pixels + focalPointOffset) / _hourHeight;
    } else if (position != null) {
      anchorHour =
          (position.pixels + position.viewportDimension / 2) / _hourHeight;
    } else {
      anchorHour = null;
    }
    _hourHeightNotifier.value = nextHeight; // H6: 只重建周视图网格 VLB 子树
    if (anchorHour == null) return;
    final capturedAnchor = anchorHour;
    final capturedFocal = focalPointOffset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_weekScrollController.hasClients) return;
      final nextPosition = _weekScrollController.position;
      final double newFocalOffset;
      if (capturedFocal != null) {
        newFocalOffset = capturedAnchor * _hourHeight;
      } else {
        newFocalOffset =
            capturedAnchor * _hourHeight - nextPosition.viewportDimension / 2;
      }
      _weekScrollController.jumpTo(
        newFocalOffset.clamp(0.0, nextPosition.maxScrollExtent),
      );
    });
  }

  bool get _isCtrlPressed {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
  }

  void _handleTimelinePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_isCtrlPressed) return;
    final delta = event.scrollDelta.dy < 0 ? _zoomStep : -_zoomStep;
    _setHourHeight(_hourHeight + delta);
  }

  void _onPointerDown(PointerDownEvent e) {
    _activePointers[e.pointer] = e.position;
    if (_activePointers.length == 2) {
      final pts = _activePointers.values.toList();
      _pinchBaseDistance = (pts[0] - pts[1]).distance;
      _pinchBaseHourHeight = _hourHeight;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    _activePointers[e.pointer] = e.position;
    if (_activePointers.length == 2 && _pinchBaseDistance != null) {
      final pts = _activePointers.values.toList();
      final currentDistance = (pts[0] - pts[1]).distance;
      final scale = currentDistance / _pinchBaseDistance!;

      // 双指中心的屏幕 Y 坐标
      final focalScreenY = (pts[0].dy + pts[1].dy) / 2;
      // Listener 在屏幕上的 Y 坐标
      final listenerBox =
          _timelineListenerKey.currentContext?.findRenderObject() as RenderBox?;
      final listenerScreenY = listenerBox?.localToGlobal(Offset.zero).dy ?? 0.0;
      // 双指中心相对于 Listener 顶部的偏移 + 当前滚动偏移 = 内容偏移
      final scrollOffset = _weekScrollController.hasClients
          ? _weekScrollController.offset
          : 0.0;
      final focalPointOffset = focalScreenY - listenerScreenY + scrollOffset;

      _setHourHeight(
        _pinchBaseHourHeight! * scale,
        focalPointOffset: focalPointOffset,
      );
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _activePointers.remove(e.pointer);
    if (_activePointers.length < 2) {
      _pinchBaseDistance = null;
      _pinchBaseHourHeight = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _activePointers.remove(e.pointer);
    if (_activePointers.length < 2) {
      _pinchBaseDistance = null;
      _pinchBaseHourHeight = null;
    }
  }

  // ── 任务操作 ──

  Future<void> _openTaskDetail(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<TaskNewBloc>(),
          child: TaskDetailPage(task: task),
        ),
      ),
    );
    _reloadData();
  }

  void _jumpToMindMap(Task task) {
    widget.onJumpToMindMap?.call(task);
  }

  Future<void> _showTaskContextActions(Task task) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('跳转思维导图'),
              onTap: () => Navigator.pop(context, 'mindmap'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('归档'),
              onTap: () => Navigator.pop(context, 'archive'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'mindmap') _jumpToMindMap(task);
    if (action == 'edit') await _openTaskDetail(task);
    if (action == 'archive') {
      context.read<TaskNewBloc>().add(ArchiveTask(id: task.id));
    }
    if (action == 'delete') await _deleteTask(task);
  }

  Future<void> _toggleTaskStatus(Task task) async {
    if (_taskRepo == null) return;
    final shouldCascade = await _confirmCascadeComplete(task);
    if (shouldCascade == null) return;

    // 乐观更新：立即更新本地状态，不等 DB
    final newStatus = task.status == 2 ? 0 : 2;
    if (shouldCascade) {
      final affectedIds = {task.id, ..._allTasks.where((t) => t.parentId == task.id).map((t) => t.id)};
      setState(() {
        _tasksByDayCache = null;
        for (var i = 0; i < _allTasks.length; i++) {
          if (affectedIds.contains(_allTasks[i].id)) {
            _allTasks[i] = _allTasks[i].copyWith(status: 2);
          }
        }
      });
      _taskRepo!.setStatusCascade(task.id, 2, includeDescendants: true).then((_) {
        _reloadData();
        _notifyBloc();
      });
    } else {
      setState(() {
        _tasksByDayCache = null;
        final idx = _allTasks.indexWhere((t) => t.id == task.id);
        if (idx != -1) {
          _allTasks[idx] = _allTasks[idx].copyWith(status: newStatus);
        }
      });
      _taskRepo!.toggleStatus(task.id).then((_) {
        _reloadData();
        _notifyBloc();
      });
    }
  }

  Future<bool?> _confirmCascadeComplete(Task task) async {
    if (task.status == 2) return false;
    final children = _allTasks.where((t) => t.parentId == task.id).toList();
    if (children.isEmpty || !mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完成子任务'),
        content: const Text('这个任务包含子任务，是否同时全部完成？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('仅完成父任务'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('全部完成'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除"${task.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true && _taskRepo != null) {
      await _taskRepo!.delete(task.id);
      _reloadData();
      _notifyBloc();
    }
  }

  void _notifyBloc() {
    if (!mounted) return;
    final bloc = context.read<TaskNewBloc>();
    final state = bloc.state;
    if (state is TaskNewLoaded && state.showArchivedView) {
      bloc.add(LoadArchivedTasks(statusFilter: state.selectedStatusFilter));
    } else {
      bloc.add(LoadTasks());
    }
  }

  Future<void> _moveTask(Task task, DateTime newStart) async {
    if (_taskRepo == null) return;
    final s = task.startDate != null
        ? DateTime.fromMillisecondsSinceEpoch(task.startDate!)
        : DateTime.now();
    final d = task.dueDate != null
        ? DateTime.fromMillisecondsSinceEpoch(task.dueDate!)
        : s.add(const Duration(hours: 1));
    final duration = d.difference(s);
    await _taskRepo!.update(
      task.id,
      startDate: newStart.millisecondsSinceEpoch,
      dueDate: newStart.add(duration).millisecondsSinceEpoch,
    );
    await _taskRepo!.expandAncestorDates(
      task.parentId,
      newStart.millisecondsSinceEpoch,
      newStart.add(duration).millisecondsSinceEpoch,
    );
    setState(() {
      _tasksByDayCache = null;
      final idx = _allTasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        _allTasks[idx] = task.copyWith(
          startDate: Value(newStart.millisecondsSinceEpoch),
          dueDate: Value(newStart.add(duration).millisecondsSinceEpoch),
        );
      }
    });
    _reloadData();
    _notifyBloc();
  }

  Future<void> _resizeTaskStart(Task task, DateTime newStart) async {
    if (_taskRepo == null) return;
    final d = task.dueDate != null
        ? DateTime.fromMillisecondsSinceEpoch(task.dueDate!)
        : (task.startDate != null
                  ? DateTime.fromMillisecondsSinceEpoch(task.startDate!)
                  : DateTime.now())
              .add(const Duration(hours: 1));
    if (!newStart.isBefore(d.subtract(const Duration(minutes: 15)))) {
      _showInvalidRangeMessage();
      return;
    }
    await _taskRepo!.update(
      task.id,
      startDate: newStart.millisecondsSinceEpoch,
      dueDate: d.millisecondsSinceEpoch,
    );
    await _taskRepo!.expandAncestorDates(
      task.parentId,
      newStart.millisecondsSinceEpoch,
      d.millisecondsSinceEpoch,
    );
    setState(() {
      _tasksByDayCache = null;
      final idx = _allTasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        _allTasks[idx] = task.copyWith(
          startDate: Value(newStart.millisecondsSinceEpoch),
          dueDate: Value(d.millisecondsSinceEpoch),
        );
      }
    });
    _reloadData();
    _notifyBloc();
  }

  Future<void> _resizeTaskEnd(Task task, DateTime newEnd) async {
    if (_taskRepo == null) return;
    final s = task.startDate != null
        ? DateTime.fromMillisecondsSinceEpoch(task.startDate!)
        : newEnd.subtract(const Duration(hours: 1));
    if (!newEnd.isAfter(s.add(const Duration(minutes: 15)))) {
      _showInvalidRangeMessage();
      return;
    }
    await _taskRepo!.update(
      task.id,
      startDate: s.millisecondsSinceEpoch,
      dueDate: newEnd.millisecondsSinceEpoch,
    );
    await _taskRepo!.expandAncestorDates(
      task.parentId,
      s.millisecondsSinceEpoch,
      newEnd.millisecondsSinceEpoch,
    );
    setState(() {
      _tasksByDayCache = null;
      final idx = _allTasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        _allTasks[idx] = task.copyWith(
          startDate: Value(s.millisecondsSinceEpoch),
          dueDate: Value(newEnd.millisecondsSinceEpoch),
        );
      }
    });
    _reloadData();
    _notifyBloc();
  }

  Future<void> _openCreateTaskFromTimeline(DateTime day, int hour) async {
    if (_projectRepo == null) return;
    final startDate = DateTime(day.year, day.month, day.day, hour);
    final bloc = context.read<TaskNewBloc>();
    final blocState = bloc.state;
    final parentTasks = blocState is TaskNewLoaded
        ? blocState.tasks.where((t) => t.status == 0).toList()
        : <Task>[];
    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskCreateSheet(
        projectRepository: _projectRepo!,
        projectGroupRepository: bloc.projectGroupRepository,
        taskRepository: _taskRepo,
        nodeTemplateRepository: bloc.nodeTemplateRepository,
        availableParentTasks: parentTasks,
        initialStartDateMillis: startDate.millisecondsSinceEpoch,
        initialDueDateMillis: startDate
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      ),
    );
    if (result != null && mounted) {
      context.read<TaskNewBloc>().add(
        CreateTask(
          projectId: (result['projectId'] as String?) ?? 'inbox',
          title: result['title'] as String,
          description: result['description'] as String? ?? '',
          priority: result['priority'] as int? ?? 0,
          startDate: result['startDate'] as int?,
          dueDate: result['dueDate'] as int?,
          parentId: result['parentId'] as String?,
          shiftedTasks:
              (result['shiftedTasks'] as List<ScheduledTaskShift>?) ?? const [],
          pendingImages:
              (result['pendingImages'] as List<PlatformFile>?) ?? const [],
          templatePayload:
              (result['templatePayload'] as NodeTemplatePayload?) ??
              NodeTemplatePayload.empty,
          remindBeforeMinutes: result['remindBeforeMinutes'] as int? ?? 15,
          reminderEnabled: result['reminderEnabled'] as int? ?? 1,
        ),
      );
    }
    _reloadData();
    _notifyBloc();
  }

  void _showInvalidRangeMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('结束时间必须晚于开始时间至少15分钟')));
  }

  // ── Build ──

  void _showParentRangeMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('父任务时间必须覆盖所有子任务时间段')));
  }

  bool _parentRangeCoversDescendants(
    Task task,
    DateTime newStart,
    DateTime newEnd,
  ) {
    if (!_hasChildren(task)) return true;
    final childRange = descendantTaskTimeRange(parent: task, tasks: _allTasks);
    if (childRange == null) return true;
    // 归一化到日期边界，避免毫秒级精度错配
    final normStart = DateTime(newStart.year, newStart.month, newStart.day);
    final normEnd = DateTime(newEnd.year, newEnd.month, newEnd.day);
    final normChildStart = DateTime(
      childRange.start.year, childRange.start.month, childRange.start.day,
    );
    final normChildEnd = DateTime(
      childRange.end.year, childRange.end.month, childRange.end.day,
    );
    return !normStart.isAfter(normChildStart) &&
        !normEnd.isBefore(normChildEnd);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TaskNewBloc, TaskNewState>(
      listener: (context, state) {
        if (state is TaskNewLoaded) {
          _reloadData(
            cachedProjects: state.projects,
            cachedGroups: state.groups,
            force: true,
          );
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: _buildAppBar(),
        body: _calendarFormat == CalendarFormat.week
            ? _buildWeekTimeline()
            : _buildMonthCalendar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final projectName = _selectedProjectIds.length > 1
        ? '${_selectedProjectIds.length} 个项目'
        : _selectedProjectId != null
        ? _allProjects
                  .where((p) => p.id == _selectedProjectId)
                  .firstOrNull
                  ?.name ??
              '日历'
        : '日历';

    return AppBar(
      title: Text(projectName),
      actions: [
        // 项目筛选
        _buildProjectFilter(),
        const SizedBox(width: 2),
        _buildHolidayCountryDropdown(),
        const SizedBox(width: 2),
        SegmentedButton<CalendarFormat>(
          segments: const [
            ButtonSegment(value: CalendarFormat.week, label: Text('周')),
            ButtonSegment(value: CalendarFormat.month, label: Text('月')),
          ],
          selected: {_calendarFormat},
          onSelectionChanged: (v) {
            setState(() {
              _calendarFormat = v.first;
              _didAutoScrollWeek = false;
            });
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 2),
        if (_calendarFormat == CalendarFormat.week) _buildDayCountDropdown(),
        const SizedBox(width: 2),
        IconButton(
          icon: const Icon(Icons.zoom_out, size: 22),
          tooltip: '缩小时间线',
          onPressed: () => _setHourHeight(_hourHeight - _zoomStep),
        ),
        IconButton(
          icon: const Icon(Icons.zoom_in, size: 22),
          tooltip: '放大时间线',
          onPressed: () => _setHourHeight(_hourHeight + _zoomStep),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.today),
          onPressed: () {
            final today = DateTime.now();
            setState(() {
              _focusedDay = today;
              _selectedDay = today;
              _didAutoScrollWeek = false;
            });
            _loadHolidaysForYears({today.year});
          },
        ),
      ],
    );
  }

  Widget _buildHolidayCountryDropdown() {
    final loading = _holidayLoadingYears.isNotEmpty;
    return PopupMenuButton<HolidayCountry>(
      tooltip: '切换节假日国家',
      onSelected: (country) {
        if (country == _selectedHolidayCountry) return;
        setState(() {
          _selectedHolidayCountry = country;
          _holidayCache.clear();
          _holidayLoadingYears.clear();
        });
        _loadHolidaysForYears({_focusedDay.year});
      },
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.textSecondary,
              ),
            )
          else
            Icon(Icons.public, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            _selectedHolidayCountry.code,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
      itemBuilder: (context) => [
        for (final country in HolidayCountry.values)
          PopupMenuItem<HolidayCountry>(
            value: country,
            child: Row(
              children: [
                Expanded(child: Text(country.label)),
                if (_selectedHolidayCountry == country)
                  Icon(Icons.check, size: 18, color: AppTheme.primaryColor),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProjectFilter() {
    return IconButton(
      tooltip: '筛选项目',
      icon: Icon(
        _selectedProjectIds.isEmpty
            ? Icons.filter_list
            : Icons.filter_list_rounded,
        size: 20,
        color: _selectedProjectIds.isNotEmpty
            ? AppTheme.primaryColor
            : AppTheme.textSecondary,
      ),
      onPressed: _allProjects.isEmpty ? null : _showProjectFilterDialog,
    );
  }

  Future<void> _showProjectFilterDialog() async {
    final draft = Set<String>.from(_selectedProjectIds);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('筛选项目'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: buildProjectPickerContent(
                projects: _allProjects,
                groups: _allGroups,
                draft: draft,
                setDialogState: setDialogState,
                extraHeader: CheckboxListTile(
                  value: draft.isEmpty,
                  title: const Text('全部项目'),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (_) => setDialogState(draft.clear),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, draft),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedProjectIds
        ..clear()
        ..addAll(result);
      _tasksByDayCache = null;
    });
  }

  Widget _buildDayCountDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: _displayDayCount,
        isDense: true,
        icon: const Icon(Icons.arrow_drop_down, size: 16),
        style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
        selectedItemBuilder: (context) => List.generate(15, (i) {
          return Align(
            alignment: Alignment.center,
            child: Text(
              '${i + 1}天',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          );
        }),
        items: List.generate(15, (i) {
          return DropdownMenuItem<int>(
            value: i + 1,
            child: Text('${i + 1} 天', style: const TextStyle(fontSize: 12)),
          );
        }),
        onChanged: (v) {
          if (v != null) {
            setState(() {
              _displayDayCount = v;
              if (v <= 3) {
                _focusedDay = DateTime.now();
              }
              _didAutoScrollWeek = false;
            });
          }
        },
      ),
    );
  }

  // ── 月视图 ──

  Widget _buildMonthCalendar() {
    final tasks = _filteredTasks();
    final dayTasks = _selectedDay != null
        ? tasks.where((t) => _taskOverlapsDay(t, _selectedDay!)).toList()
        : <Task>[];

    return Column(
      children: [
        _buildTableCalendar(CalendarFormat.month, tasks),
        const Divider(height: 1),
        Expanded(child: _buildTaskList(dayTasks)),
      ],
    );
  }

  Widget _buildTableCalendar(CalendarFormat format, List<Task> tasks) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: format,
      startingDayOfWeek: StartingDayOfWeek.monday,
      locale: 'zh_CN',
      daysOfWeekHeight: 28,
      daysOfWeekStyle: DaysOfWeekStyle(
        dowTextFormatter: (date, locale) {
          const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
          return weekdays[date.weekday - 1];
        },
      ),
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (newFormat) {
        setState(() => _calendarFormat = newFormat);
      },
      onPageChanged: _onFocusedDayChanged,
      eventLoader: (day) =>
          _tasksByDay[DateTime(day.year, day.month, day.day)] ?? const <Task>[],
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) =>
            _buildMonthDayCell(day, focusedDay),
        todayBuilder: (context, day, focusedDay) =>
            _buildMonthDayCell(day, focusedDay, isToday: true),
        selectedBuilder: (context, day, focusedDay) =>
            _buildMonthDayCell(day, focusedDay, isSelected: true),
        outsideBuilder: (context, day, focusedDay) =>
            _buildMonthDayCell(day, focusedDay, isOutside: true),
      ),
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        markerDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          shape: BoxShape.circle,
        ),
        tablePadding: const EdgeInsets.only(top: 4),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
    );
  }

  Widget _buildMonthDayCell(
    DateTime day,
    DateTime focusedDay, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final holiday = _holidayDisplayFor(day);
    final primary = Theme.of(context).colorScheme.primary;
    final dayColor = isSelected
        ? Colors.white
        : isOutside
        ? AppTheme.textHint
        : holiday?.color ?? AppTheme.textPrimary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? primary
                    : isToday
                    ? primary.withValues(alpha: 0.18)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: dayColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 16,
              child: holiday == null
                  ? const SizedBox.shrink()
                  : Container(
                      constraints: const BoxConstraints(maxWidth: 58),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: holiday.backgroundColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        holiday.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color: holiday.color,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> dayTasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${_selectedDay?.month}月${_selectedDay?.day}日 任务',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: dayTasks.isEmpty
              ? Center(
                  child: Text(
                    '暂无任务',
                    style: TextStyle(color: AppTheme.textHint),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: dayTasks.length,
                  itemBuilder: (context, index) {
                    final task = dayTasks[index];
                    final isCompleted = task.status == 2;
                    final parentLabel = _parentLabel(task);
                    return GestureDetector(
                      onSecondaryTap: () => _showTaskContextActions(task),
                      child: Card(
                        color: isCompleted
                            ? Colors.grey.shade100
                            : Theme.of(context).cardColor,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Checkbox(
                            value: isCompleted,
                            onChanged: (checked) => _toggleTaskStatus(task),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (parentLabel != null)
                                Text(
                                  parentLabel,
                                  style: TextStyle(
                                    color: isCompleted
                                        ? AppTheme.textHint
                                        : AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              Text(
                                task.title,
                                style: TextStyle(
                                  color: isCompleted
                                      ? AppTheme.textSecondary
                                      : AppTheme.textPrimary,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                          subtitle:
                              task.startDate != null && task.dueDate != null
                              ? Text(
                                  '${_timeLabel(DateTime.fromMillisecondsSinceEpoch(task.startDate!))} - '
                                  '${_timeLabel(DateTime.fromMillisecondsSinceEpoch(task.dueDate!))}  '
                                  '${_priorityLabel(task.priority)}',
                                  style: TextStyle(
                                    color: isCompleted
                                        ? AppTheme.textHint
                                        : AppTheme.textSecondary,
                                  ),
                                )
                              : null,
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'edit') _openTaskDetail(task);
                              if (action == 'delete') _deleteTask(task);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('详情'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '删除',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── 日条头部 ──

  Widget _buildDayStripHeader(List<DateTime> days, List<Task> tasks) {
    const weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        // 月份导航行
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: () {
                  final nextFocusedDay = _focusedDay.subtract(
                    Duration(days: _displayDayCount),
                  );
                  setState(() {
                    _focusedDay = nextFocusedDay;
                    _didAutoScrollWeek = false;
                  });
                  _loadHolidaysForYears({nextFocusedDay.year});
                },
              ),
              Text(
                '${_focusedDay.year}年${_focusedDay.month}月',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: () {
                  final nextFocusedDay = _focusedDay.add(
                    Duration(days: _displayDayCount),
                  );
                  setState(() {
                    _focusedDay = nextFocusedDay;
                    _didAutoScrollWeek = false;
                  });
                  _loadHolidaysForYears({nextFocusedDay.year});
                },
              ),
            ],
          ),
        ),
        // 星期 + 日期行（跟随 _dragOffset 与下方网格同步平移）
        // H1: VLB 只重建 Transform，日期条内容作 child 传入不重建
        ClipRect(
          child: ValueListenableBuilder<double>(
            valueListenable: _dragOffset,
            builder: (context, dragOffset, child) => Transform.translate(
              offset: Offset(dragOffset, 0),
              child: child,
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: _timeColumnWidth),
                  ...days.map((day) {
                    final isToday = _isSameDate(day, today);
                    final isSelected =
                        _selectedDay != null && _isSameDate(day, _selectedDay!);
                    final hasTasks =
                        (_tasksByDay[DateTime(day.year, day.month, day.day)] ??
                                const <Task>[])
                            .isNotEmpty;
                    final holiday = _holidayDisplayFor(day);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDay = day;
                            _focusedDay = day;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Column(
                            children: [
                              Text(
                                weekdayNames[day.weekday - 1],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : isToday
                                      ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.3)
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isToday || isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : isToday
                                        ? Theme.of(context).colorScheme.primary
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 14,
                                child: holiday == null
                                    ? (hasTasks
                                          ? Center(
                                              child: Container(
                                                width: 5,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.secondary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink())
                                    : Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 62,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: holiday.backgroundColor,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          holiday.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            height: 1,
                                            fontWeight: FontWeight.w600,
                                            color: holiday.color,
                                          ),
                                        ),
                                      ),
                              ),
                              if (holiday != null && hasTasks)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 1),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 周时间线视图 ──

  Widget _buildWeekTimeline() {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    _scrollWeekToCurrentTime();

    final weekStart = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    );
    final days = List.generate(
      _displayDayCount,
      (index) => weekStart.add(Duration(days: index)),
    );
    final missingHolidayYears = days
        .map((day) => day.year)
        .where(
          (year) =>
              !_holidayCache.containsKey(year) &&
              !_holidayLoadingYears.contains(year),
        )
        .toSet();
    if (missingHolidayYears.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadHolidaysForYears(missingHolidayYears);
      });
    }
    final tasks = _filteredTasks();

    final weekEndExclusive = weekStart.add(Duration(days: _displayDayCount));
    final multiDayTasks = tasks
        .where(
          (t) =>
              _isMultiDayTask(t) &&
              _taskOverlapsRange(t, weekStart, weekEndExclusive),
        )
        .toList();
    final singleDayTasks = tasks.where((t) => !_isMultiDayTask(t)).toList();

    return Column(
      children: [
        _buildDayStripHeader(days, tasks),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dayWidth =
                  (constraints.maxWidth - _timeColumnWidth).clamp(320, 2400) /
                  _displayDayCount;
              _cachedDayWidth = dayWidth;
              final totalHeight = _hourHeight * 24;
              // Listener 绕过手势竞技场；内层任务块设 _isTaskDragging=true 时跳过翻周
              return Listener(
                onPointerDown: (e) {
                  _dragStartX = e.position.dx;
                  _dragSkipped = false;
                },
                onPointerMove: (e) {
                  // H3: 直接读 .value，不触发重建
                  if (_isTaskDragging.value || _editingTaskId != null) {
                    _dragSkipped = true;
                    return;
                  }
                  if (_dragStartX == null) return;
                  // H1: 只驱动 VLB 包裹的 Transform.translate，不再整页 setState
                  _dragOffset.value = e.position.dx - _dragStartX!;
                },
                onPointerUp: (e) {
                  if (_dragSkipped || _editingTaskId != null) {
                    _dragOffset.value = 0;
                    _dragStartX = null;
                    _dragSkipped = false;
                    return;
                  }
                  if (_dragStartX == null) return;
                  final dx = e.position.dx - _dragStartX!;
                  _dragStartX = null;
                  if (dx.abs() < 2) {
                    _dragOffset.value = 0;
                    return;
                  }
                  final daysToShift = -(dx / _cachedDayWidth).round();
                  _dragOffset.value = 0;
                  if (daysToShift != 0) {
                    // 翻周确实需要整页重建（天数列表变化）
                    setState(() {
                      _focusedDay =
                          _focusedDay.add(Duration(days: daysToShift));
                      _didAutoScrollWeek = false;
                    });
                  }
                },
                onPointerCancel: (e) {
                  _dragOffset.value = 0;
                  _dragStartX = null;
                  _dragSkipped = false;
                },
                // H1: VLB 只重建 Transform，网格整列作 child 传入不重建
                child: ValueListenableBuilder<double>(
                  valueListenable: _dragOffset,
                  builder: (context, dragOffset, child) => Transform.translate(
                    offset: Offset(dragOffset, 0),
                    child: child,
                  ),
                  child: Column(
                    children: [
                      _buildMultiDayLane(days, dayWidth, multiDayTasks),
                      Expanded(
                        child: RepaintBoundary(
                          child: Listener(
                            key: _timelineListenerKey,
                            onPointerSignal: _handleTimelinePointerSignal,
                            onPointerDown: _onPointerDown,
                            onPointerMove: _onPointerMove,
                            onPointerUp: _onPointerUp,
                            onPointerCancel: _onPointerCancel,
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (_) =>
                                  _isTaskDragging.value || _editingTaskId != null,
                              child: SingleChildScrollView(
                              controller: _weekScrollController,
                              physics: _editingTaskId != null || _isTaskDragging.value
                                  ? const NeverScrollableScrollPhysics()
                                  : null,
                              child: SizedBox(
                                height: totalHeight,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTimeColumn(totalHeight),
                                    SizedBox(
                                      width: dayWidth * _displayDayCount,
                                      height: totalHeight,
                                      child: Stack(
                                        children: [
                                          for (var i = 0; i < days.length; i++)
                                            Positioned(
                                              left: i * dayWidth,
                                              top: 0,
                                              width: dayWidth,
                                              height: totalHeight,
                                              child: _buildDayDropColumn(
                                                days[i],
                                                dayWidth,
                                              ),
                                            ),
                                          for (var i = 0; i < days.length; i++)
                                            ..._buildTaskBlocksForDay(
                                              days[i],
                                              i,
                                              dayWidth,
                                              singleDayTasks,
                                            ),
                                          _buildCurrentTimeIndicator(
                                            days,
                                            dayWidth,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ), // close SingleChildScrollView
                            ), // close NotificationListener
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeColumn(double totalHeight) {
    return SizedBox(
      width: _timeColumnWidth,
      height: totalHeight,
      child: Column(
        children: List.generate(24, (hour) {
          return SizedBox(
            height: _hourHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: GoogleFonts.jetBrainsMonoTextTheme().bodySmall?.copyWith(
                  fontSize: 11,
                  color: AppTheme.textHint,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── 多日长条 ──

  Widget _buildMultiDayLane(
    List<DateTime> days,
    double dayWidth,
    List<Task> tasks,
  ) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final weekStart = DateTime(
      days.first.year,
      days.first.month,
      days.first.day,
    );
    final weekEnd = weekStart.add(Duration(days: _displayDayCount));

    // ── 分组：按组根（在 lane 内无父的最顶层任务）聚合 ──
    final taskIds = tasks.map((t) => t.id).toSet();

    Task groupRoot(Task task) {
      var cur = task;
      final visited = <String>{};
      while (cur.parentId != null &&
          taskIds.contains(cur.parentId!) &&
          visited.add(cur.id)) {
        final parent = tasks.where((t) => t.id == cur.parentId).firstOrNull;
        if (parent == null) break;
        cur = parent;
      }
      return cur;
    }

    final Map<String, Task> rootById = {};
    final Map<String, List<Task>> childrenByRoot = {};
    for (final task in tasks) {
      final root = groupRoot(task);
      rootById[root.id] = root;
      childrenByRoot.putIfAbsent(root.id, () => []);
      if (task.id != root.id) {
        childrenByRoot[root.id]!.add(task);
      }
    }

    // 组间按父任务跨度降序（最长在上）；父任务无日期时取子任务最大跨度兜底
    int spanMs(Task t) {
      final s = t.startDate;
      final d = t.dueDate;
      if (s == null || d == null) return 0;
      return d - s;
    }

    int effectiveGroupSpan(String rootId) {
      final rootSpan = spanMs(rootById[rootId]!);
      if (rootSpan > 0) return rootSpan;
      final children = childrenByRoot[rootId] ?? [];
      return children.map(spanMs).fold(0, (a, b) => a > b ? a : b);
    }

    final sortedRootIds = rootById.keys.toList()
      ..sort((a, b) => effectiveGroupSpan(b).compareTo(effectiveGroupSpan(a)));

    // 组内：DFS 递归，保证父节点永远在子节点上面
    List<Task> dfsChildren(List<Task> allChildren, String parentId) {
      final direct = allChildren
          .where((t) => t.parentId == parentId)
          .toList()
        ..sort((a, b) {
          final so = a.sortOrder.compareTo(b.sortOrder);
          if (so != 0) return so;
          return (a.startDate ?? 0).compareTo(b.startDate ?? 0);
        });
      final result = <Task>[];
      for (final child in direct) {
        result.add(child);
        result.addAll(dfsChildren(allChildren, child.id));
      }
      return result;
    }

    // 展开可见行：父行在上，未折叠时跟随子行（递归有序）
    final orderedRows = <Task>[];
    for (final rootId in sortedRootIds) {
      orderedRows.add(rootById[rootId]!);
      if (!_collapsedMultiDayGroups.contains(rootId)) {
        orderedRows.addAll(dfsChildren(childrenByRoot[rootId]!, rootId));
      }
    }

    const laneHeight = 24.0;
    const maxVisibleLanes = 4;
    final totalRows = orderedRows.length;
    final visibleRows = totalRows.clamp(1, maxVisibleLanes);
    final contentHeight = totalRows * laneHeight;
    final visibleHeight = visibleRows * laneHeight;

    // 全局折叠/展开：仅考虑有子任务的组
    final groupsWithChildren =
        sortedRootIds.where((id) => childrenByRoot[id]!.isNotEmpty).toList();
    final allCollapsed = groupsWithChildren.isNotEmpty &&
        groupsWithChildren.every((id) => _collapsedMultiDayGroups.contains(id));

    return Container(
      height: visibleHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Row(
        children: [
          const SizedBox(width: _timeColumnWidth),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    width: dayWidth * _displayDayCount,
                    height: contentHeight,
                    child: Stack(
                      children: [
                        for (var i = 0; i < orderedRows.length; i++)
                          _buildMultiDayBar(
                            orderedRows[i],
                            i,
                            weekStart,
                            weekEnd,
                            dayWidth,
                            laneHeight,
                            onCollapseToggle:
                                childrenByRoot[orderedRows[i].id]?.isNotEmpty == true
                                    ? () {
                                        final rootId = orderedRows[i].id;
                                        setState(() {
                                          if (_collapsedMultiDayGroups.contains(rootId)) {
                                            _collapsedMultiDayGroups.remove(rootId);
                                          } else {
                                            _collapsedMultiDayGroups.add(rootId);
                                          }
                                        });
                                      }
                                    : null,
                            isGroupCollapsed:
                                _collapsedMultiDayGroups.contains(orderedRows[i].id),
                          ),
                      ],
                    ),
                  ),
                ),
                // 全部折叠 / 全部展开按钮
                Positioned(
                  right: 2,
                  top: 2,
                  child: Tooltip(
                    message: allCollapsed ? '展开全部' : '折叠全部',
                    child: Material(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            if (allCollapsed) {
                              _collapsedMultiDayGroups.clear();
                            } else {
                              _collapsedMultiDayGroups.addAll(groupsWithChildren);
                            }
                          });
                        },
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: Icon(
                            allCollapsed
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiDayBar(
    Task task,
    int row,
    DateTime weekStart,
    DateTime weekEnd,
    double dayWidth,
    double laneHeight, {
    VoidCallback? onCollapseToggle,
    bool isGroupCollapsed = false,
  }) {
    final s = DateTime.fromMillisecondsSinceEpoch(task.startDate!);
    final d = DateTime.fromMillisecondsSinceEpoch(task.dueDate!);
    final start = s.isBefore(weekStart) ? weekStart : s;
    final end = d.isAfter(weekEnd) ? weekEnd : d;
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = end.hour == 0 && end.minute == 0
        ? DateTime(end.year, end.month, end.day)
        : DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final rawStartOffset = startDay.difference(weekStart).inDays;
    final rawSpanDays = endDay.difference(startDay).inDays;
    // 防御：任务不在当前周（理论上 _buildWeekTimeline 已过滤，这里兜底）
    if (rawStartOffset >= _displayDayCount || rawSpanDays <= 0) {
      return const SizedBox.shrink();
    }
    final startOffset = rawStartOffset.clamp(0, _displayDayCount - 1);
    final spanDays = rawSpanDays.clamp(1, _displayDayCount - startOffset);

    final isCompleted = task.status == 2;
    final color = isCompleted
        ? Colors.grey.shade500
        : _priorityColor(task.priority);

    final bar = Listener(
      onPointerDown: (_) => _isTaskDragging.value = true,
      onPointerUp: (_) => _isTaskDragging.value = false,
      onPointerCancel: (_) => _isTaskDragging.value = false,
      child: _EditableMultiDayBar(
        task: task,
        color: color,
        isCompleted: isCompleted,
        dayWidth: dayWidth,
        laneHeight: laneHeight,
        onTap: () => _openTaskDetail(task),
        onSecondaryTap: () => _showTaskContextActions(task),
        onToggle: () => _toggleTaskStatus(task),
        onMoveDay: (deltaDays) {
          final newStart = s.add(Duration(days: deltaDays));
          final newEnd = d.add(Duration(days: deltaDays));
          _moveTaskMultiDay(task, newStart, newEnd);
        },
        onResizeStartDay: (deltaDays) {
          var newStart = s.add(Duration(days: deltaDays));
          if (!newStart.isBefore(d)) {
            newStart = DateTime(d.year, d.month, d.day, d.hour - 1, d.minute);
          }
          _moveTaskMultiDay(task, newStart, d);
        },
        onResizeEndDay: (deltaDays) {
          var newEnd = d.add(Duration(days: deltaDays));
          if (!newEnd.isAfter(s)) {
            newEnd = DateTime(s.year, s.month, s.day, s.hour + 1, s.minute);
          }
          _moveTaskMultiDay(task, s, newEnd);
        },
      ),
    );

    return Positioned(
      left: startOffset * dayWidth + 4,
      top: row * laneHeight + 4,
      width: dayWidth * spanDays - 8,
      height: laneHeight - 8,
      child: onCollapseToggle != null
          ? Stack(
              children: [
                bar,
                Positioned(
                  right: 2,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: onCollapseToggle,
                      child: Icon(
                        isGroupCollapsed
                            ? Icons.keyboard_arrow_right
                            : Icons.keyboard_arrow_down,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : bar,
    );
  }

  Future<void> _moveTaskMultiDay(
    Task task,
    DateTime newStart,
    DateTime newEnd,
  ) async {
    if (_taskRepo == null) return;
    if (!_parentRangeCoversDescendants(task, newStart, newEnd)) {
      _showParentRangeMessage();
      return;
    }
    await _taskRepo!.update(
      task.id,
      startDate: newStart.millisecondsSinceEpoch,
      dueDate: newEnd.millisecondsSinceEpoch,
    );
    setState(() {
      _tasksByDayCache = null;
      final idx = _allTasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        _allTasks[idx] = task.copyWith(
          startDate: Value(newStart.millisecondsSinceEpoch),
          dueDate: Value(newEnd.millisecondsSinceEpoch),
        );
      }
    });
    _reloadData();
    _notifyBloc();
  }

  // ── 单日时间块 ──

  List<Widget> _buildTaskBlocksForDay(
    DateTime day,
    int dayIndex,
    double dayWidth,
    List<Task> singleDayTasks,
  ) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // 收集当前日所有任务及其时间范围
    final dayTasksWithRange = <_DayTaskRange>[];
    for (final task in singleDayTasks) {
      if (!_taskOverlapsDay(task, day)) continue;
      final s = task.startDate != null
          ? DateTime.fromMillisecondsSinceEpoch(task.startDate!)
          : dayStart;
      final d = task.dueDate != null
          ? DateTime.fromMillisecondsSinceEpoch(task.dueDate!)
          : s.add(const Duration(hours: 1));
      final segmentStart = s.isAfter(dayStart) ? s : dayStart;
      final segmentEnd = d.isBefore(dayEnd) ? d : dayEnd;
      dayTasksWithRange.add(
        _DayTaskRange(
          task: task,
          start: s,
          end: d,
          segmentStart: segmentStart,
          segmentEnd: segmentEnd,
          top: segmentStart.difference(dayStart).inMinutes / 60 * _hourHeight,
          height:
              (segmentEnd.difference(segmentStart).inMinutes / 60 * _hourHeight)
                  .clamp(28.0, _hourHeight * 24),
        ),
      );
    }

    if (dayTasksWithRange.isEmpty) return [];

    // 按开始时间排序
    final overlapLaneAssignments = assignDayTaskLanes([
      for (final tr in dayTasksWithRange)
        DayTaskLaneInput(
          item: tr,
          segmentStart: tr.segmentStart,
          segmentEnd: tr.segmentEnd,
        ),
    ]);

    const double horizontalMargin = 3.0;
    final blocks = <Widget>[];
    for (final assignment in overlapLaneAssignments) {
      final tr = assignment.item;
      final perLaneWidth =
          (dayWidth - horizontalMargin * 2) / assignment.laneCount;
      blocks.add(
        Positioned(
          left:
              dayIndex * dayWidth +
              horizontalMargin +
              assignment.laneIndex * perLaneWidth,
          top: tr.top + 2,
          width: perLaneWidth - 2, // lane 间留 2px 间隙
          height: (tr.height - 4).clamp(28.0, _hourHeight * 24),
          child: _buildDraggableTaskBlock(
            tr.task,
            tr.start,
            tr.end,
            tr.segmentStart,
            dayWidth,
          ),
        ),
      );
    }
    return blocks;
  }

  Widget _buildDraggableTaskBlock(
    Task task,
    DateTime start,
    DateTime end,
    DateTime segmentStart,
    double dayWidth,
  ) {
    return Listener(
      onPointerDown: (_) => _isTaskDragging.value = true,
      onPointerUp: (_) => _isTaskDragging.value = false,
      onPointerCancel: (_) => _isTaskDragging.value = false,
      child: _ResizableTaskBlock(
      task: task,
      start: start,
      end: end,
      segmentStart: segmentStart,
      hourHeight: _hourHeight,
      dayWidth: dayWidth,
      priorityColor: _priorityColor(task.priority),
      isCompleted: task.status == 2,
      isEditMode: _editingTaskId == task.id,
      timeLabel: _timeLabel,
      parentLabel: _parentLabel(task),
      onOpenDetail: () {
        if (_editingTaskId != null) {
          setState(() => _editingTaskId = null);
        } else {
          _openTaskDetail(task);
        }
      },
      onToggle: () => _toggleTaskStatus(task),
      onSecondaryTap: () => _showTaskContextActions(task),
      onDelete: () => _deleteTask(task),
      onMove: (target) => _moveTask(task, target),
      onResizeStart: (target) => _resizeTaskStart(task, target),
      onResizeEnd: (target) => _resizeTaskEnd(task, target),
      onEditModeChanged: (editing) {
        setState(() => _editingTaskId = editing ? task.id : null);
      },
      ), // close _ResizableTaskBlock
    ); // close Listener
  }

  // ── Drop Column ──

  Widget _buildDayDropColumn(DateTime day, double dayWidth) {
    // 改为纯背景网格 + 右键创建。拖动改由块自身的 Listener 处理（B2）
    return Column(
      children: List.generate(24, (hour) {
        return GestureDetector(
          onTap: _editingTaskId != null
              ? () => setState(() => _editingTaskId = null)
              : null,
          onSecondaryTap: () => _openCreateTaskFromTimeline(day, hour),
          child: Container(
            height: _hourHeight,
            width: dayWidth,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: AppTheme.borderSubtle),
                bottom: BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── 当前时间指示器 ──

  Widget _buildCurrentTimeIndicator(List<DateTime> days, double dayWidth) {
    final now = DateTime.now();
    final dayIndex = days.indexWhere(
      (day) =>
          day.year == now.year && day.month == now.month && day.day == now.day,
    );
    if (dayIndex == -1) return const SizedBox.shrink();

    final top = (now.hour + now.minute / 60) * _hourHeight;
    return Positioned(
      left: dayIndex * dayWidth,
      top: top,
      width: dayWidth,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(child: Container(height: 2, color: Colors.redAccent)),
          ],
        ),
      ),
    );
  }
}

// ── 可拖拽调整的时间块组件 ──

/// 支持实时拖拽预览的任务时间块（纯 Listener 实现，原尺寸跟手 + 5min 吸附 + 跨日）
class _ResizableTaskBlock extends StatefulWidget {
  final Task task;
  final DateTime start;
  final DateTime end;
  final DateTime segmentStart;
  final double hourHeight;
  final double dayWidth;
  final Color priorityColor;
  final bool isCompleted;
  final bool isEditMode;
  final String Function(DateTime) timeLabel;
  final String? parentLabel;
  final VoidCallback onOpenDetail;
  final VoidCallback onSecondaryTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final void Function(DateTime target) onMove;
  final void Function(DateTime target) onResizeStart;
  final void Function(DateTime target) onResizeEnd;
  final ValueChanged<bool> onEditModeChanged;

  const _ResizableTaskBlock({
    required this.task,
    required this.start,
    required this.end,
    required this.segmentStart,
    required this.hourHeight,
    required this.dayWidth,
    required this.priorityColor,
    required this.isCompleted,
    required this.isEditMode,
    required this.timeLabel,
    required this.parentLabel,
    required this.onOpenDetail,
    required this.onSecondaryTap,
    required this.onToggle,
    required this.onDelete,
    required this.onMove,
    required this.onResizeStart,
    required this.onResizeEnd,
    required this.onEditModeChanged,
  });

  @override
  State<_ResizableTaskBlock> createState() => _ResizableTaskBlockState();
}

class _ResizableTaskBlockState extends State<_ResizableTaskBlock> {
  double? _resizeTopDelta;
  double? _resizeBottomDelta;

  // 整块移动：拖动偏移
  Offset? _moveDelta;

  // Checkbox 区域命中标志：阻止 EagerPan 的小位移误判为 tap→openDetail
  bool _checkboxHit = false;

  // 移动端长按检测（使用 Listener 绕过手势竞技场，避免被 _EagerPanGestureRecognizer 抢占）
  Timer? _longPressTimer;
  Offset? _pointerDownPosition;
  bool _longPressActivated = false; // 长按 Timer 触发后置 true，onEnd 用于区分"长按松手"和"点击"

  double get _currentTopDelta => _resizeTopDelta ?? 0;
  double get _currentBottomDelta => _resizeBottomDelta ?? 0;

  bool get _isMobile => isMobile;

  void _exitEditMode() {
    if (widget.isEditMode) widget.onEditModeChanged(false);
  }

  void _startLongPressTimer(Offset position) {
    _cancelLongPressTimer();
    _longPressActivated = false; // 每次新手势开始时重置
    if (!widget.isEditMode && _isMobile) {
      _pointerDownPosition = position;
      _longPressTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          _longPressActivated = true; // 标记本次手势由长按触发编辑模式
          widget.onEditModeChanged(true);
        }
      });
    }
  }

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _pointerDownPosition = null;
    // 注意：不重置 _longPressActivated，它需要在 onEnd 中读取
  }

  void _onPointerDown(PointerDownEvent event) {
    _startLongPressTimer(event.position);
  }

  void _onPointerMove(PointerMoveEvent event) {
    // 移动超过 12px 视为拖拽，取消长按检测
    if (_pointerDownPosition != null) {
      final dist = (event.position - _pointerDownPosition!).distance;
      if (dist > 12) {
        _cancelLongPressTimer();
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _cancelLongPressTimer();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _cancelLongPressTimer();
  }

  @override
  void dispose() {
    _cancelLongPressTimer();
    super.dispose();
  }

  /// 把像素 delta(dx, dy) 转成目标时间（5 分钟吸附）
  DateTime _targetFromDelta(Offset delta) {
    final w = widget;
    final dayDelta = (delta.dx / w.dayWidth).round();
    final minuteDelta = (delta.dy / w.hourHeight * 60 / 5).round() * 5;
    return w.start
        .add(Duration(days: dayDelta))
        .add(Duration(minutes: minuteDelta));
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final color = w.isCompleted ? Colors.grey.shade500 : w.priorityColor;
    final textColor = w.isCompleted
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.white;
    final effectiveBottom = _currentBottomDelta;
    final showResize = w.isEditMode || !_isMobile;
    final move = _moveDelta ?? Offset.zero;

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          // 主体：移动端用 EagerPan 立即赢得竞技场，防止 ScrollView 抢走手势
          Positioned(
            left: 0,
            right: 0,
            top: _currentTopDelta,
            bottom: -effectiveBottom,
            child: Transform.translate(
              offset: move,
              child: _isMobile
                  ? Listener(
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      onPointerCancel: _onPointerCancel,
                      child: RawGestureDetector(
                        behavior: HitTestBehavior.opaque,
                        gestures: <Type, GestureRecognizerFactory>{
                          _EagerPanGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                _EagerPanGestureRecognizer
                              >(
                                () => _EagerPanGestureRecognizer(),
                                (_EagerPanGestureRecognizer instance) {
                                  instance
                                    ..onStart = (details) {
                                      setState(() {
                                        _moveDelta = Offset.zero;
                                      });
                                    }
                                    ..onUpdate = (details) {
                                      setState(() {
                                        _moveDelta =
                                            (_moveDelta ?? Offset.zero) +
                                            details.delta;
                                      });
                                    }
                                    ..onEnd = (details) {
                                      final delta = _moveDelta;
                                      setState(() {
                                        _moveDelta = null;
                                      });
                                      if (delta == null || delta.distance < 3) {
                                        if (_checkboxHit) {
                                          _checkboxHit = false;
                                          w.onToggle();
                                          return;
                                        }
                                        if (_longPressActivated) {
                                          // 长按激活编辑模式后松手，不视为点击
                                          _longPressActivated = false;
                                          return;
                                        }
                                        // 移动距离极小，视为点击
                                        w.onOpenDetail();
                                        return;
                                      }
                                      _checkboxHit = false;
                                      _longPressActivated = false;
                                      final target = _targetFromDelta(delta);
                                      if (target != w.start) {
                                        w.onMove(target);
                                      }
                                    }
                                    ..onCancel = () {
                                      _checkboxHit = false;
                                      _longPressActivated = false;
                                      setState(() {
                                        _moveDelta = null;
                                      });
                                    };
                                },
                              ),
                        },
                        child: _buildBlockContent(color, textColor),
                      ),
                    )
                  : GestureDetector(
                      onSecondaryTap: w.onSecondaryTap,
                      child: RawGestureDetector(
                        behavior: HitTestBehavior.opaque,
                        gestures: <Type, GestureRecognizerFactory>{
                          _EagerPanGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                _EagerPanGestureRecognizer
                              >(
                                () => _EagerPanGestureRecognizer(),
                                (_EagerPanGestureRecognizer instance) {
                                  instance
                                    ..onStart = (details) {
                                      setState(() {
                                        _moveDelta = Offset.zero;
                                      });
                                    }
                                    ..onUpdate = (details) {
                                      setState(() {
                                        _moveDelta =
                                            (_moveDelta ?? Offset.zero) +
                                            details.delta;
                                      });
                                    }
                                    ..onEnd = (details) {
                                      final delta = _moveDelta;
                                      setState(() {
                                        _moveDelta = null;
                                      });
                                      if (delta == null || delta.distance < 3) {
                                        if (_checkboxHit) {
                                          _checkboxHit = false;
                                          w.onToggle();
                                          return;
                                        }
                                        w.onOpenDetail();
                                        return;
                                      }
                                      _checkboxHit = false;
                                      final target = _targetFromDelta(delta);
                                      if (target != w.start) {
                                        w.onMove(target);
                                      }
                                    }
                                    ..onCancel = () {
                                      _checkboxHit = false;
                                      setState(() {
                                        _moveDelta = null;
                                      });
                                    };
                                },
                              ),
                        },
                        child: _buildBlockContent(color, textColor),
                      ),
                    ),
            ),
          ),
          // resize hot zones（在 Stack 顶层）
          if (showResize) ...[
            Positioned(
              left: 0,
              right: 0,
              top: _isMobile ? -16 : -12,
              height: _isMobile ? 32 : 24,
              child: _ResizeHotZone(
                isMobileEditMode: _isMobile && w.isEditMode,
                onPanUpdate: (delta) {
                  setState(() {
                    _resizeTopDelta = (_resizeTopDelta ?? 0) + delta.dy;
                  });
                },
                onPanEnd: () {
                  final delta = _resizeTopDelta;
                  if (delta == null) return;
                  setState(() => _resizeTopDelta = null);
                  _exitEditMode();
                  if (delta == 0) return;
                  final minuteDelta =
                      (delta / w.hourHeight * 60 / 5).round() * 5;
                  if (minuteDelta == 0) return;
                  final target = w.segmentStart.add(
                    Duration(minutes: minuteDelta),
                  );
                  w.onResizeStart(target);
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _isMobile ? -16 : -16,
              height: _isMobile ? 32 : 24,
              child: _ResizeHotZone(
                isMobileEditMode: _isMobile && w.isEditMode,
                onPanUpdate: (delta) {
                  setState(() {
                    _resizeBottomDelta = (_resizeBottomDelta ?? 0) + delta.dy;
                  });
                },
                onPanEnd: () {
                  final delta = _resizeBottomDelta;
                  if (delta == null) return;
                  setState(() => _resizeBottomDelta = null);
                  _exitEditMode();
                  if (delta == 0) return;
                  final minuteDelta =
                      (delta / w.hourHeight * 60 / 5).round() * 5;
                  if (minuteDelta == 0) return;
                  final target = w.end.add(Duration(minutes: minuteDelta));
                  w.onResizeEnd(target);
                },
              ),
            ),
          ],
          if (w.isEditMode)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlockContent(Color color, Color textColor) {
    final w = widget;
    return Material(
      color: color.withValues(alpha: w.isCompleted ? 0.62 : 0.88),
      elevation: w.isCompleted ? 0 : 2,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.hardEdge,
      // 注意：外层 Listener 已处理 tap → onOpenDetail，这里不再设 onTap，避免双触发
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (w.parentLabel != null)
              Text(
                w.parentLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.75),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            Expanded(
              child: Row(
                children: [
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => _checkboxHit = true,
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: IgnorePointer(
                        child: Checkbox(
                          value: w.isCompleted,
                          onChanged: null,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: Colors.white, width: 1.4),
                          checkColor: Colors.grey,
                          fillColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      w.task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        decoration: w.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${w.timeLabel(w.start)} - ${w.timeLabel(w.end)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _HolidayDisplay {
  const _HolidayDisplay({
    required this.label,
    required this.name,
    required this.color,
    required this.backgroundColor,
    required this.isWorkday,
  });

  final String label;
  final String name;
  final Color color;
  final Color backgroundColor;
  final bool isWorkday;
}

/// 单日任务时间范围数据，用于 lane 分配
class _DayTaskRange {
  final Task task;
  final DateTime start;
  final DateTime end;
  final DateTime segmentStart;
  final DateTime segmentEnd;
  final double top;
  final double height;

  const _DayTaskRange({
    required this.task,
    required this.start,
    required this.end,
    required this.segmentStart,
    required this.segmentEnd,
    required this.top,
    required this.height,
  });
}

/// 拖拽热区：响应 pan 手势，显示细线
class _ResizeHotZone extends StatelessWidget {
  final void Function(Offset delta) onPanUpdate;
  final VoidCallback onPanEnd;
  final bool isMobileEditMode;

  const _ResizeHotZone({
    required this.onPanUpdate,
    required this.onPanEnd,
    this.isMobileEditMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => onPanUpdate(details.delta),
      onPanEnd: (_) => onPanEnd(),
      child: Center(
        child: isMobileEditMode
            ? Container(
                width: 40,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
              )
            : Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
      ),
    );
  }
}

/// 可拖拽调整的跨日任务条
class _EditableMultiDayBar extends StatefulWidget {
  final Task task;
  final Color color;
  final bool isCompleted;
  final double dayWidth;
  final double laneHeight;
  final VoidCallback onTap;
  final VoidCallback onSecondaryTap;
  final VoidCallback onToggle;
  final void Function(int deltaDays) onMoveDay;
  final void Function(int deltaDays) onResizeStartDay;
  final void Function(int deltaDays) onResizeEndDay;

  const _EditableMultiDayBar({
    required this.task,
    required this.color,
    required this.isCompleted,
    required this.dayWidth,
    required this.laneHeight,
    required this.onTap,
    required this.onSecondaryTap,
    required this.onToggle,
    required this.onMoveDay,
    required this.onResizeStartDay,
    required this.onResizeEndDay,
  });

  @override
  State<_EditableMultiDayBar> createState() => _EditableMultiDayBarState();
}

class _EditableMultiDayBarState extends State<_EditableMultiDayBar> {
  double? _startDayDelta;
  double? _endDayDelta;
  double? _moveDeltaX;
  final double _handleWidth = 32.0;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final color = w.color;
    final isCompleted = w.isCompleted;

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          // 主体（横向拖动按整天移动；使用 onHorizontalDrag 而非 onPan，
          // 与翻页手势同一 Recognizer 类型，内层深度优先赢得竞技场）
          Positioned(
            left: (_startDayDelta ?? 0) + (_moveDeltaX ?? 0),
            right:
                (_endDayDelta != null ? -(_endDayDelta!) : 0) +
                (_moveDeltaX != null ? -(_moveDeltaX!) : 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: w.onTap,
              onSecondaryTap: w.onSecondaryTap,
              onHorizontalDragStart: (_) {
                setState(() => _moveDeltaX = 0);
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _moveDeltaX = (_moveDeltaX ?? 0) + details.delta.dx;
                });
              },
              onHorizontalDragEnd: (_) {
                final dx = _moveDeltaX;
                setState(() => _moveDeltaX = null);
                if (dx == null || dx.abs() < 3) return;
                final days = (dx / w.dayWidth).round();
                if (days != 0) w.onMoveDay(days);
              },
              onHorizontalDragCancel: () {
                setState(() => _moveDeltaX = null);
              },
              child: _buildBar(color, isCompleted),
            ),
          ),
          // 左侧拖拽热区（调整开始日期）
          if (!isCompleted)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _handleWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _startDayDelta = (_startDayDelta ?? 0) + details.delta.dx;
                  });
                },
                onHorizontalDragEnd: (_) {
                  if (_startDayDelta == null) return;
                  final days = (_startDayDelta! / w.dayWidth).round();
                  if (days != 0) w.onResizeStartDay(days);
                  setState(() => _startDayDelta = null);
                },
                child: Center(
                  child: Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          // 右侧拖拽热区（调整结束日期）
          if (!isCompleted)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: _handleWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _endDayDelta = (_endDayDelta ?? 0) + details.delta.dx;
                  });
                },
                onHorizontalDragEnd: (_) {
                  if (_endDayDelta == null) return;
                  final days = (_endDayDelta! / w.dayWidth).round();
                  if (days != 0) w.onResizeEndDay(days);
                  setState(() => _endDayDelta = null);
                },
                child: Center(
                  child: Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBar(Color color, bool isCompleted) {
    final w = widget;
    return Material(
      color: color.withValues(alpha: isCompleted ? 0.62 : 0.9),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: w.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: w.onToggle,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: IgnorePointer(
                    child: Checkbox(
                      value: isCompleted,
                      onChanged: null,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      checkColor: Colors.grey,
                      fillColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  w.task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCompleted
                        ? Colors.white.withValues(alpha: 0.72)
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 移动端专用：立即赢得手势竞技场的 PanGestureRecognizer。
/// 防止 SingleChildScrollView 的 VerticalDragRecognizer 抢走任务块的拖拽手势。
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
