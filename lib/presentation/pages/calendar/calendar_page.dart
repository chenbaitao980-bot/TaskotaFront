import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../blocs/task_new/task_bloc.dart';
import '../../blocs/task_new/task_event.dart';
import '../../blocs/task_new/task_state.dart';
import '../tasks/task_detail/task_detail_page.dart';
import '../tasks/widgets/task_create_sheet.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final ScrollController _weekScrollController = ScrollController();
  bool _didAutoScrollWeek = false;
  int _displayDayCount = 7; // 周视图显示天数，默认 7 天（周一～周日）
  double _hourHeight = 56;
  static const double _timeColumnWidth = 48;
  static const double _minHourHeight = 32;
  static const double _maxHourHeight = 120;
  static const double _zoomStep = 8;

  List<Task> _allTasks = [];
  List<Project> _allProjects = [];
  String? _selectedProjectId;
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
  }

  Future<void> _reloadData() async {
    // 等待 repo 就绪（_initRepos 可能在 BlocListener 之后才执行）
    if (_taskRepo == null || _projectRepo == null) {
      // 如果 repo 还没就绪，等下一帧重试
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_initialized) _reloadData();
      });
      return;
    }
    try {
      final tasks = await _taskRepo!.getAll();
      final projects = await _projectRepo!.getActive();
      if (mounted) {
        setState(() {
          _allTasks = tasks;
          _allProjects = projects;
          _initialized = true;
        });
      }
    } catch (e) {
      // 偶发性数据库未就绪，重试一次
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
    if (_selectedProjectId != null) {
      tasks = tasks.where((t) => t.projectId == _selectedProjectId).toList();
    }
    return tasks;
  }

  bool _isMultiDayTask(Task task) {
    final s = task.startDate;
    final d = task.dueDate;
    if (s == null || d == null) return false;
    final start = DateTime.fromMillisecondsSinceEpoch(s);
    final end = DateTime.fromMillisecondsSinceEpoch(d);
    return !_isSameDate(start, end);
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

  void _setHourHeight(double height) {
    final nextHeight = height.clamp(_minHourHeight, _maxHourHeight).toDouble();
    if (nextHeight == _hourHeight) return;
    final position = _weekScrollController.hasClients
        ? _weekScrollController.position
        : null;
    final viewportCenterHour = position == null
        ? null
        : (position.pixels + position.viewportDimension / 2) / _hourHeight;
    setState(() => _hourHeight = nextHeight);
    if (viewportCenterHour == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_weekScrollController.hasClients) return;
      final nextPosition = _weekScrollController.position;
      final nextOffset =
          viewportCenterHour * _hourHeight - nextPosition.viewportDimension / 2;
      _weekScrollController.jumpTo(
        nextOffset.clamp(0.0, nextPosition.maxScrollExtent),
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
    final delta = event.scrollDelta.dy < 0 ? -_zoomStep : _zoomStep;
    _setHourHeight(_hourHeight + delta);
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

  Future<void> _toggleTaskStatus(Task task) async {
    if (_taskRepo == null) return;
    await _taskRepo!.toggleStatus(task.id);
    _reloadData();
    _notifyBloc();
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
    context.read<TaskNewBloc>().add(LoadTasks());
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
        availableParentTasks: parentTasks,
        initialStartDateMillis: startDate.millisecondsSinceEpoch,
        initialDueDateMillis:
            startDate.add(const Duration(hours: 1)).millisecondsSinceEpoch,
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<TaskNewBloc, TaskNewState>(
      listener: (context, state) {
        if (state is TaskNewLoaded) {
          _reloadData();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _calendarFormat == CalendarFormat.week
            ? _buildWeekTimeline()
            : _buildMonthCalendar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final projectName = _selectedProjectId != null
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
        const SizedBox(width: 4),
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
        const SizedBox(width: 4),
        if (_calendarFormat == CalendarFormat.week)
          _buildDayCountDropdown(),
        const SizedBox(width: 4),
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
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.today),
          onPressed: () {
            setState(() {
              _focusedDay = DateTime.now();
              _selectedDay = DateTime.now();
              _didAutoScrollWeek = false;
            });
          },
        ),
      ],
    );
  }

  Widget _buildProjectFilter() {
    final hasProjects = _allProjects.isNotEmpty;
    return PopupMenuButton<String?>(
      tooltip: '筛选项目',
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _selectedProjectId == null
                ? Icons.filter_list
                : Icons.filter_list_rounded,
            size: 20,
            color: _selectedProjectId != null
                ? AppTheme.primaryColor
                : AppTheme.textSecondary,
          ),
        ],
      ),
      onSelected: (value) {
        setState(() => _selectedProjectId = value == '__all__' ? null : value);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String?>(
          value: '__all__',
          child: Row(
            children: [
              Icon(
                _selectedProjectId == null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: _selectedProjectId == null
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text('全部项目'),
            ],
          ),
        ),
        if (hasProjects) const PopupMenuDivider(),
        for (final project in _allProjects)
          PopupMenuItem<String?>(
            value: project.id,
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Color(
                      int.tryParse(project.color.replaceFirst('#', '0xFF')) ??
                          0xFF4772FA,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                Text(project.name),
                const Spacer(),
                if (_selectedProjectId == project.id)
                  Icon(Icons.check, size: 18, color: AppTheme.primaryColor),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDayCountDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: _displayDayCount,
        isDense: true,
        icon: const Icon(Icons.arrow_drop_down, size: 16),
        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
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
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      eventLoader: (day) =>
          tasks.where((t) => _taskOverlapsDay(t, day)).toList(),
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
              ? const Center(
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
                    return Card(
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
                        subtitle: task.startDate != null && task.dueDate != null
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
                                  Icon(Icons.delete, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('删除', style: TextStyle(color: Colors.red)),
                                ],
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

  // ── 周时间线视图 ──

  Widget _buildWeekTimeline() {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    _scrollWeekToCurrentTime();

    final weekStart = _startOfWeek(_focusedDay);
    final days = List.generate(
      _displayDayCount,
      (index) => weekStart.add(Duration(days: index)),
    );
    final totalHeight = _hourHeight * 24;
    final tasks = _filteredTasks();

    final multiDayTasks = tasks.where(_isMultiDayTask).toList();
    final singleDayTasks = tasks.where((t) => !_isMultiDayTask(t)).toList();

    return Column(
      children: [
        _buildTableCalendar(CalendarFormat.week, tasks),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dayWidth =
                  (constraints.maxWidth - _timeColumnWidth).clamp(320, 2400) /
                  _displayDayCount;
              return Column(
                children: [
                  _buildMultiDayLane(days, dayWidth, multiDayTasks),
                  Expanded(
                    child: Listener(
                      onPointerSignal: _handleTimelinePointerSignal,
                      child: SingleChildScrollView(
                        controller: _weekScrollController,
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
                                    _buildCurrentTimeIndicator(days, dayWidth),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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

    const laneHeight = 36.0;
    final height = (tasks.length * laneHeight).clamp(40.0, 144.0);
    return Container(
      height: height,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Row(
        children: [
          const SizedBox(width: _timeColumnWidth),
          SizedBox(
            width: dayWidth * _displayDayCount,
            child: Stack(
              children: [
                for (var i = 0; i < tasks.length; i++)
                  _buildMultiDayBar(
                    tasks[i],
                    i,
                    weekStart,
                    weekEnd,
                    dayWidth,
                    laneHeight,
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
    double laneHeight,
  ) {
    final s = DateTime.fromMillisecondsSinceEpoch(task.startDate!);
    final d = DateTime.fromMillisecondsSinceEpoch(task.dueDate!);
    final start = s.isBefore(weekStart) ? weekStart : s;
    final end = d.isAfter(weekEnd) ? weekEnd : d;
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = end.hour == 0 && end.minute == 0
        ? DateTime(end.year, end.month, end.day)
        : DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final startOffset = startDay.difference(weekStart).inDays.clamp(0, _displayDayCount - 1);
    final spanDays = endDay
        .difference(startDay)
        .inDays
        .clamp(1, _displayDayCount - startOffset);

    final isCompleted = task.status == 2;
    final color = isCompleted
        ? Colors.grey.shade500
        : _priorityColor(task.priority);

    return Positioned(
      left: startOffset * dayWidth + 4,
      top: row * laneHeight + 4,
      width: dayWidth * spanDays - 8,
      height: laneHeight - 8,
      child: _EditableMultiDayBar(
        task: task,
        color: color,
        isCompleted: isCompleted,
        dayWidth: dayWidth,
        laneHeight: laneHeight,
        onTap: () => _openTaskDetail(task),
        onToggle: () => _toggleTaskStatus(task),
        onMoveDay: (deltaDays) {
          final newStart = s.add(Duration(days: deltaDays));
          final newEnd = d.add(Duration(days: deltaDays));
          _moveTaskMultiDay(task, newStart, newEnd);
        },
        onResizeStartDay: (deltaDays) {
          final newStart = s.add(Duration(days: deltaDays));
          if (newStart.isBefore(d)) {
            _moveTaskMultiDay(task, newStart, d);
          }
        },
        onResizeEndDay: (deltaDays) {
          final newEnd = d.add(Duration(days: deltaDays));
          if (newEnd.isAfter(s)) {
            _moveTaskMultiDay(task, s, newEnd);
          }
        },
      ),
    );
  }

  Future<void> _moveTaskMultiDay(
    Task task,
    DateTime newStart,
    DateTime newEnd,
  ) async {
    if (_taskRepo == null) return;
    await _taskRepo!.update(
      task.id,
      startDate: newStart.millisecondsSinceEpoch,
      dueDate: newEnd.millisecondsSinceEpoch,
    );
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
      dayTasksWithRange.add(_DayTaskRange(
        task: task,
        start: s,
        end: d,
        segmentStart: segmentStart,
        segmentEnd: segmentEnd,
        top: segmentStart.difference(dayStart).inMinutes / 60 * _hourHeight,
        height: (segmentEnd.difference(segmentStart).inMinutes / 60 * _hourHeight)
            .clamp(28.0, _hourHeight * 24),
      ));
    }

    if (dayTasksWithRange.isEmpty) return [];

    // 按开始时间排序
    dayTasksWithRange.sort((a, b) => a.segmentStart.compareTo(b.segmentStart));

    // 贪心 lane 分配：laneEnds[idx] = 该 lane 上最后任务的 segmentEnd
    final laneEnds = <DateTime>[];
    final laneAssignments = <int>[]; // 每个任务分配到哪个 lane
    for (final tr in dayTasksWithRange) {
      int assigned = -1;
      for (int i = 0; i < laneEnds.length; i++) {
        if (!tr.segmentStart.isBefore(laneEnds[i])) {
          // 该 lane 空闲
          laneEnds[i] = tr.segmentEnd;
          assigned = i;
          break;
        }
      }
      if (assigned == -1) {
        // 新建一个 lane
        laneEnds.add(tr.segmentEnd);
        assigned = laneEnds.length - 1;
      }
      laneAssignments.add(assigned);
    }

    final totalLanes = laneEnds.length;
    const double horizontalMargin = 3.0;
    final perLaneWidth = (dayWidth - horizontalMargin * 2) / totalLanes;

    final blocks = <Widget>[];
    for (int i = 0; i < dayTasksWithRange.length; i++) {
      final tr = dayTasksWithRange[i];
      final lane = laneAssignments[i];
      blocks.add(
        Positioned(
          left: dayIndex * dayWidth + horizontalMargin + lane * perLaneWidth,
          top: tr.top + 2,
          width: perLaneWidth - 2, // lane 间留 2px 间隙
          height: (tr.height - 4).clamp(28.0, _hourHeight * 24),
          child: _buildDraggableTaskBlock(tr.task, tr.start, tr.end, tr.segmentStart),
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
  ) {
    return _ResizableTaskBlock(
      task: task,
      start: start,
      end: end,
      segmentStart: segmentStart,
      hourHeight: _hourHeight,
      priorityColor: _priorityColor(task.priority),
      isCompleted: task.status == 2,
      timeLabel: _timeLabel,
      parentLabel: _parentLabel(task),
      onOpenDetail: () => _openTaskDetail(task),
      onToggle: () => _toggleTaskStatus(task),
      onDelete: () => _deleteTask(task),
      onMove: (target) => _moveTask(task, target),
      onResizeStart: (target) => _resizeTaskStart(task, target),
      onResizeEnd: (target) => _resizeTaskEnd(task, target),
    );
  }

  // ── Drop Column ──

  Widget _buildDayDropColumn(DateTime day, double dayWidth) {
    return Column(
      children: List.generate(24, (hour) {
        return Builder(
          builder: (cellContext) => DragTarget<_TimelineDragData>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) {
              final box = cellContext.findRenderObject() as RenderBox?;
              final local = box?.globalToLocal(details.offset) ?? Offset.zero;
              final minuteOffset = (local.dy / _hourHeight * 60).round().clamp(
                0,
                59,
              );
              final snappedSlot = (minuteOffset / 15)
                  .round()
                  .clamp(0, 3)
                  .toInt();
              final snappedMinute = snappedSlot * 15;
              final target = DateTime(
                day.year,
                day.month,
                day.day,
                hour,
                snappedMinute,
              );
              final task = _allTasks
                  .where((t) => t.id == details.data.taskId)
                  .firstOrNull;
              if (task == null) return;
              switch (details.data.kind) {
                case _TimelineDragKind.move:
                  _moveTask(task, target);
                case _TimelineDragKind.resizeStart:
                  _resizeTaskStart(task, target);
                case _TimelineDragKind.resizeEnd:
                  _resizeTaskEnd(task, target);
              }
            },
            builder: (context, candidateData, rejectedData) {
              final hovering = candidateData.isNotEmpty;
              return GestureDetector(
                onSecondaryTap: () => _openCreateTaskFromTimeline(day, hour),
                child: Container(
                  height: _hourHeight,
                  width: dayWidth,
                  decoration: BoxDecoration(
                    color: hovering
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08)
                        : null,
                    border: Border(
                      right:
                          const BorderSide(color: AppTheme.borderSubtle),
                      bottom:
                          const BorderSide(color: AppTheme.borderSubtle),
                    ),
                  ),
                ),
              );
            },
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

enum _TimelineDragKind { move, resizeStart, resizeEnd }

class _TimelineDragData {
  final _TimelineDragKind kind;
  final String taskId;
  const _TimelineDragData(this.kind, this.taskId);
}

/// 支持实时拖拽预览的任务时间块
class _ResizableTaskBlock extends StatefulWidget {
  final Task task;
  final DateTime start;
  final DateTime end;
  final DateTime segmentStart;
  final double hourHeight;
  final Color priorityColor;
  final bool isCompleted;
  final String Function(DateTime) timeLabel;
  final String? parentLabel;
  final VoidCallback onOpenDetail;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final void Function(DateTime target) onMove;
  final void Function(DateTime target) onResizeStart;
  final void Function(DateTime target) onResizeEnd;

  const _ResizableTaskBlock({
    required this.task,
    required this.start,
    required this.end,
    required this.segmentStart,
    required this.hourHeight,
    required this.priorityColor,
    required this.isCompleted,
    required this.timeLabel,
    required this.parentLabel,
    required this.onOpenDetail,
    required this.onToggle,
    required this.onDelete,
    required this.onMove,
    required this.onResizeStart,
    required this.onResizeEnd,
  });

  @override
  State<_ResizableTaskBlock> createState() => _ResizableTaskBlockState();
}

class _ResizableTaskBlockState extends State<_ResizableTaskBlock> {
  double? _resizeTopDelta;
  double? _resizeBottomDelta;

  double get _currentTopDelta => _resizeTopDelta ?? 0;
  double get _currentBottomDelta => _resizeBottomDelta ?? 0;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final color = w.isCompleted ? Colors.grey.shade500 : w.priorityColor;
    final textColor = w.isCompleted
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.white;
    final effectiveBottom = _currentBottomDelta;

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          // 任务块主体 - 用 Transform 实现实时预览
          Positioned(
            left: 0,
            right: 0,
            top: _currentTopDelta,
            bottom: -effectiveBottom,
            child: Draggable<_TimelineDragData>(
              data: _TimelineDragData(_TimelineDragKind.move, widget.task.id),
              feedback: SizedBox(
                width: 120,
                height: 48,
                child: _buildBlockContent(color, textColor),
              ),
              childWhenDragging: _buildBlockContent(color, textColor),
              child: _buildBlockContent(color, textColor),
            ),
          ),
          // 顶部拖拽热区（拉开始时间）
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 8,
            child: _ResizeHotZone(
              alignment: Alignment.topCenter,
              onPanUpdate: (delta) {
                setState(() {
                  _resizeTopDelta = (_resizeTopDelta ?? 0) + delta.dy;
                });
              },
              onPanEnd: () {
                final delta = _resizeTopDelta;
                if (delta == null) return;
                setState(() => _resizeTopDelta = null);
                if (delta == 0) return;
                final minuteDelta = (delta / w.hourHeight * 60).round();
                final snapped = (minuteDelta / 15).round() * 15;
                if (snapped == 0) return;
                final target = w.segmentStart.add(Duration(minutes: snapped));
                w.onResizeStart(target);
              },
            ),
          ),
          // 底部拖拽热区（拉结束时间）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 8,
            child: _ResizeHotZone(
              alignment: Alignment.bottomCenter,
              onPanUpdate: (delta) {
                setState(() {
                  _resizeBottomDelta = (_resizeBottomDelta ?? 0) + delta.dy;
                });
              },
              onPanEnd: () {
                final delta = _resizeBottomDelta;
                if (delta == null) return;
                setState(() => _resizeBottomDelta = null);
                if (delta == 0) return;
                final minuteDelta = (delta / w.hourHeight * 60).round();
                final snapped = (minuteDelta / 15).round() * 15;
                if (snapped == 0) return;
                final target = w.end.add(Duration(minutes: snapped));
                w.onResizeEnd(target);
              },
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
      child: InkWell(
        onTap: w.onOpenDetail,
        onSecondaryTap: w.onDelete,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
              Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value: w.isCompleted,
                      onChanged: (_) => w.onToggle(),
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
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      w.task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
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
              const SizedBox(height: 2),
              Text(
                '${w.timeLabel(w.start)} - ${w.timeLabel(w.end)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  final Alignment alignment;
  final void Function(Offset delta) onPanUpdate;
  final VoidCallback onPanEnd;

  const _ResizeHotZone({
    required this.alignment,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) => onPanUpdate(details.delta),
        onPanEnd: (_) => onPanEnd(),
        child: SizedBox(
          width: 44,
          height: 8,
          child: Center(
            child: Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
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
  final double _handleWidth = 18.0;

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
          // 主体（可拖拽移动）
          Positioned(
            left: (_startDayDelta ?? 0),
            right: (_endDayDelta != null ? -(_endDayDelta!) : 0),
            child: Draggable<_TimelineDragData>(
              data: _TimelineDragData(_TimelineDragKind.move, w.task.id),
              feedback: SizedBox(
                width: w.dayWidth * 2,
                height: w.laneHeight - 8,
                child: _buildBar(color, isCompleted),
              ),
              childWhenDragging: Opacity(
                opacity: 0.35,
                child: _buildBar(color, isCompleted),
              ),
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
                onPanUpdate: (details) {
                  setState(() {
                    _startDayDelta = (_startDayDelta ?? 0) + details.delta.dx;
                  });
                },
                onPanEnd: (_) {
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
                onPanUpdate: (details) {
                  setState(() {
                    _endDayDelta = (_endDayDelta ?? 0) + details.delta.dx;
                  });
                },
                onPanEnd: (_) {
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
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: isCompleted,
                  onChanged: (_) => w.onToggle(),
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
