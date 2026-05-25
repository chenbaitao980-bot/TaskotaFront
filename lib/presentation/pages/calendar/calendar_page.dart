import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/entities/task_breakdown.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/notification_service.dart';
import '../../widgets/create_schedule_dialog.dart';
import '../task/create_task_page.dart';
import '../task/task_detail_page.dart';

class CalendarPage extends StatefulWidget {
  final int refreshToken;

  const CalendarPage({super.key, this.refreshToken = 0});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final LocalStorageService _storage = LocalStorageService();
  final ScrollController _weekScrollController = ScrollController();
  List<dynamic> _events = [];
  List<TaskBreakdown> _rangeTasks = [];
  bool _initialized = false;
  bool _didAutoScrollWeek = false;
  double _hourHeight = 56;
  static const double _timeColumnWidth = 48;
  static const double _minHourHeight = 32;
  static const double _maxHourHeight = 120;
  static const double _zoomStep = 8;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _initStorage();
  }

  @override
  void didUpdateWidget(covariant CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadEvents();
    }
  }

  @override
  void dispose() {
    _weekScrollController.dispose();
    super.dispose();
  }

  Future<void> _initStorage() async {
    await _storage.init();
    _loadEvents();
    setState(() => _initialized = true);
  }

  Future<void> _ensureStorageReady() async {
    if (_initialized) return;
    await _storage.init();
    if (mounted) {
      setState(() => _initialized = true);
    } else {
      _initialized = true;
    }
  }

  void _loadEvents() {
    final rangeStart = _calendarFormat == CalendarFormat.week
        ? _startOfWeek(_focusedDay)
        : DateTime(_focusedDay.year, _focusedDay.month, 1);
    final rangeEnd = _calendarFormat == CalendarFormat.week
        ? rangeStart.add(const Duration(days: 7))
        : DateTime(_focusedDay.year, _focusedDay.month + 1, 0, 23, 59, 59);
    _events = _storage.getSchedules(startDate: rangeStart, endDate: rangeEnd);
    _rangeTasks = _storage.getTasks(
      startDate: rangeStart,
      endDate: rangeEnd,
      excludeParent: true,
    );
    if (mounted) setState(() {});
  }

  /// 获取子任务的父任务名称
  String _parentLabel(TaskBreakdown task) {
    if (task.parentTaskId == null) return '';
    final allTasks = _storage.getTasks();
    final parent = allTasks.where((t) => t.id == task.parentTaskId).firstOrNull;
    if (parent == null) return '';
    return '📁 ${parent.title}';
  }

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

  DateTime _startOfWeek(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return date.subtract(Duration(days: date.weekday % 7));
  }

  bool _eventOverlapsDay(dynamic event, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final start = event.startTime as DateTime;
    final end = event.endTime as DateTime;
    return start.isBefore(dayEnd) && end.isAfter(dayStart);
  }

  String _getUserId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is LocalAuthenticated) return authState.email;
    if (authState is Authenticated) return authState.user.id;
    return 'local_user';
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events.where((e) => _eventOverlapsDay(e, day)).toList();
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isMultiDaySchedule(dynamic event) {
    final start = event.startTime as DateTime;
    final end = event.endTime as DateTime;
    return !_isSameDate(start, end) || end.difference(start).inHours >= 24;
  }

  bool _isMultiDayTask(TaskBreakdown task) {
    final start = task.startDate;
    final end = task.endDate;
    if (start == null || end == null) return false;
    return !_isSameDate(start, end);
  }

  Future<void> _createSchedule() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreateScheduleDialog(
        initialDate: _selectedDay,
        initialStartTime: _selectedDay != null
            ? DateTime(
                _selectedDay!.year,
                _selectedDay!.month,
                _selectedDay!.day,
                9,
              )
            : null,
        initialEndTime: _selectedDay != null
            ? DateTime(
                _selectedDay!.year,
                _selectedDay!.month,
                _selectedDay!.day,
                10,
              )
            : null,
      ),
    );

    if (result != null) {
      try {
        await _ensureStorageReady();
        final newSchedule = await _storage.createSchedule(
          userId: _getUserId(),
          title: result['title'] as String,
          description: result['description'] as String?,
          startTime: result['startTime'] as DateTime,
          endTime: result['endTime'] as DateTime,
          priority: result['priority'] as String,
        );
        await NotificationService().scheduleReminderForSchedule(
          scheduleId: newSchedule.id,
          title: newSchedule.title,
          startTime: newSchedule.startTime,
          description: newSchedule.description,
        );
        _loadEvents();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('日程已创建')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('创建日程失败：$e')));
        }
      }
    }
  }

  Future<void> _editSchedule(dynamic schedule) async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (context) => CreateScheduleDialog(
        initialTitle: schedule.title as String,
        initialDate: schedule.startTime as DateTime,
        initialStartTime: schedule.startTime as DateTime,
        initialEndTime: schedule.endTime as DateTime,
        initialPriority: schedule.priority as String,
        isEditing: true,
      ),
    );

    if (result == 'delete') {
      await _deleteSchedule(schedule);
      return;
    }

    if (result == 'add_subtask') {
      await _createSubtaskForSchedule(schedule);
      return;
    }

    if (result != null && result is Map<String, dynamic>) {
      final updated = schedule.copyWith(
        title: result['title'] as String,
        description: result['description'] as String?,
        startTime: result['startTime'] as DateTime,
        endTime: result['endTime'] as DateTime,
        priority: result['priority'] as String,
      );
      await _storage.updateSchedule(updated);
      _loadEvents();
    }
  }

  Future<void> _createSubtaskForSchedule(dynamic schedule) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTaskPage(
          parentScheduleId: schedule.id as String,
          initialStartDate: schedule.startTime as DateTime,
          initialEndDate: schedule.endTime as DateTime,
        ),
      ),
    );
    if (created == true) {
      await _ensureStorageReady();
      _loadEvents();
    }
  }

  Future<void> _openTaskDetail(TaskBreakdown task) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: task.id)),
    );
    await _ensureStorageReady();
    _loadEvents();
  }

  Future<void> _deleteSchedule(dynamic schedule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日程'),
        content: Text('确定要删除"${schedule.title}"吗？'),
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

    if (confirm == true) {
      await _storage.deleteSchedule(schedule.id as String);
      _loadEvents();
    }
  }

  Future<void> _moveTimelineItem(Object item, DateTime newStart) async {
    if (item is TaskBreakdown) {
      await _moveTask(item, newStart);
      return;
    }
    await _moveSchedule(item, newStart);
  }

  Future<void> _resizeTimelineStart(Object item, DateTime newStart) async {
    if (item is TaskBreakdown) {
      await _resizeTaskStart(item, newStart);
      return;
    }
    await _resizeScheduleStart(item, newStart);
  }

  Future<void> _resizeTimelineEnd(Object item, DateTime newEnd) async {
    if (item is TaskBreakdown) {
      await _resizeTaskEnd(item, newEnd);
      return;
    }
    await _resizeScheduleEnd(item, newEnd);
  }

  Future<void> _moveSchedule(dynamic schedule, DateTime newStart) async {
    try {
      await _ensureStorageReady();
      final start = schedule.startTime as DateTime;
      final end = schedule.endTime as DateTime;
      final duration = end.difference(start);
      final updated = schedule.copyWith(
        startTime: newStart,
        endTime: newStart.add(duration),
      );
      await _storage.updateSchedule(updated);
      _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新时间失败：$e')));
      }
    }
  }

  Future<void> _moveTask(TaskBreakdown task, DateTime newStart) async {
    try {
      await _ensureStorageReady();
      final start = task.startDate ?? DateTime.now();
      final end = task.endDate ?? start.add(const Duration(hours: 1));
      final duration = end.difference(start);
      await _storage.updateTask(
        task.copyWith(startDate: newStart, endDate: newStart.add(duration)),
      );
      _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update task failed: $e')));
      }
    }
  }

  Future<void> _resizeScheduleStart(dynamic schedule, DateTime newStart) async {
    final end = schedule.endTime as DateTime;
    if (!newStart.isBefore(end.subtract(const Duration(minutes: 15)))) {
      _showInvalidRangeMessage();
      return;
    }
    await _updateScheduleRange(
      schedule,
      newStart,
      end,
      successMessage: '开始时间已更新',
    );
  }

  Future<void> _resizeScheduleEnd(dynamic schedule, DateTime newEnd) async {
    final start = schedule.startTime as DateTime;
    if (!newEnd.isAfter(start.add(const Duration(minutes: 15)))) {
      _showInvalidRangeMessage();
      return;
    }
    await _updateScheduleRange(
      schedule,
      start,
      newEnd,
      successMessage: '结束时间已更新',
    );
  }

  Future<void> _resizeTaskStart(TaskBreakdown task, DateTime newStart) async {
    final end =
        task.endDate ??
        (task.startDate ?? newStart).add(const Duration(hours: 1));
    if (!newStart.isBefore(end.subtract(const Duration(minutes: 15)))) {
      _showInvalidRangeMessage();
      return;
    }
    await _updateTaskRange(
      task,
      newStart,
      end,
      successMessage: 'Task start updated',
    );
  }

  Future<void> _resizeTaskEnd(TaskBreakdown task, DateTime newEnd) async {
    final start = task.startDate ?? newEnd.subtract(const Duration(hours: 1));
    if (!newEnd.isAfter(start.add(const Duration(minutes: 15)))) {
      _showInvalidRangeMessage();
      return;
    }
    await _updateTaskRange(
      task,
      start,
      newEnd,
      successMessage: 'Task end updated',
    );
  }

  Future<void> _updateTaskRange(
    TaskBreakdown task,
    DateTime start,
    DateTime end, {
    required String successMessage,
  }) async {
    try {
      await _ensureStorageReady();
      await _storage.updateTask(task.copyWith(startDate: start, endDate: end));
      _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update task failed: $e')));
      }
    }
  }

  Future<void> _updateScheduleRange(
    dynamic schedule,
    DateTime start,
    DateTime end, {
    required String successMessage,
  }) async {
    try {
      await _ensureStorageReady();
      final updated = schedule.copyWith(startTime: start, endTime: end);
      await _storage.updateSchedule(updated);
      _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新时间失败：$e')));
      }
    }
  }

  void _showInvalidRangeMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('结束时间必须晚于开始时间至少15分钟')));
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

  Future<void> _updateTaskStatus(TaskBreakdown task, bool isCompleted) async {
    try {
      await _ensureStorageReady();
      await _storage.updateTask(
        task.copyWith(
          status: isCompleted ? 'completed' : 'in_progress',
          progress: isCompleted
              ? 100
              : (task.progress >= 100 ? 0 : task.progress),
        ),
      );
      _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update task failed: $e')));
      }
    }
  }

  Future<void> _updateScheduleStatus(dynamic schedule, bool isCompleted) async {
    try {
      await _ensureStorageReady();
      await _storage.updateSchedule(
        schedule.copyWith(status: isCompleted ? 'completed' : 'in_progress'),
      );
      _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新时间失败：$e')));
      }
    }
  }

  void _showTaskContextMenu(TaskBreakdown task) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: const Text('确定要删除这个任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _ensureStorageReady();
                await _storage.deleteTask(task.id);
                _loadEvents();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showScheduleContextMenu(dynamic schedule) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          schedule.title as String,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: const Text('确定要删除这个日程吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _ensureStorageReady();
                await _storage.deleteSchedule(schedule.id as String);
                _loadEvents();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  String _priorityLabel(String p) {
    return switch (p) {
      'P0' => '紧急',
      'P1' => '重要',
      'P2' => '普通',
      _ => '低',
    };
  }

  Color _priorityColor(String p) {
    return switch (p) {
      'P0' => AppTheme.priorityP0,
      'P1' => AppTheme.priorityP1,
      'P2' => AppTheme.priorityP2,
      _ => AppTheme.priorityP3,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
        actions: [
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
              _loadEvents();
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
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
              _loadEvents();
            },
          ),
        ],
      ),
      body: _calendarFormat == CalendarFormat.week
          ? _buildWeekTimeline()
          : _buildMonthCalendar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSchedule,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMonthCalendar() {
    return Column(
      children: [
        _buildTableCalendar(CalendarFormat.month),
        const Divider(height: 1),
        Expanded(child: _buildEventList()),
      ],
    );
  }

  Widget _buildTableCalendar(CalendarFormat format) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: format,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (newFormat) {
        setState(() => _calendarFormat = newFormat);
        _loadEvents();
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
        _loadEvents();
      },
      eventLoader: _getEventsForDay,
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
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
    );
  }

  Widget _buildWeekTimeline() {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    _scrollWeekToCurrentTime();

    final weekStart = _startOfWeek(_focusedDay);
    final days = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    final totalHeight = _hourHeight * 24;

    return Column(
      children: [
        _buildTableCalendar(CalendarFormat.week),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dayWidth =
                  (constraints.maxWidth - _timeColumnWidth).clamp(320, 2400) /
                  7;
              return Column(
                children: [
                  _buildMultiDayLane(days, dayWidth),
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
                                width: dayWidth * 7,
                                height: totalHeight,
                                child: Stack(
                                  children: [
                                    for (
                                      var dayIndex = 0;
                                      dayIndex < days.length;
                                      dayIndex++
                                    )
                                      Positioned(
                                        left: dayIndex * dayWidth,
                                        top: 0,
                                        width: dayWidth,
                                        height: totalHeight,
                                        child: _buildDayDropColumn(
                                          days[dayIndex],
                                          dayWidth,
                                        ),
                                      ),
                                    for (
                                      var dayIndex = 0;
                                      dayIndex < days.length;
                                      dayIndex++
                                    )
                                      ..._buildEventBlocksForDay(
                                        days[dayIndex],
                                        dayIndex,
                                        dayWidth,
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

  Widget _buildMultiDayLane(List<DateTime> days, double dayWidth) {
    final weekStart = DateTime(
      days.first.year,
      days.first.month,
      days.first.day,
    );
    final weekEnd = weekStart.add(const Duration(days: 7));
    final items = <_MultiDayItem>[
      for (final event in _events.where(_isMultiDaySchedule))
        _MultiDayItem(
          title: event.title as String,
          start: event.startTime as DateTime,
          end: event.endTime as DateTime,
          color: event.status == 'completed'
              ? Colors.grey.shade500
              : _priorityColor(event.priority as String),
          isCompleted: event.status == 'completed',
          onTap: () => _editSchedule(event),
          onToggle: (checked) => _updateScheduleStatus(event, checked),
        ),
      for (final task in _rangeTasks.where(_isMultiDayTask))
        _MultiDayItem(
          title: task.parentTaskId != null
              ? '${_parentLabel(task)} → ${task.title}'
              : task.title,
          start: task.startDate!,
          end: task.endDate!.add(const Duration(days: 1)),
          color: task.status == 'completed'
              ? Colors.grey.shade500
              : _priorityColor(task.priority),
          isCompleted: task.status == 'completed',
          onTap: () => _openTaskDetail(task),
          onToggle: (checked) => _updateTaskStatus(task, checked),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    const laneHeight = 36.0;
    final height = (items.length * laneHeight).clamp(40.0, 144.0);
    return Container(
      height: height,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Row(
        children: [
          const SizedBox(width: _timeColumnWidth),
          SizedBox(
            width: dayWidth * 7,
            child: Stack(
              children: [
                for (var i = 0; i < items.length; i++)
                  _buildMultiDayBar(
                    items[i],
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
    _MultiDayItem item,
    int row,
    DateTime weekStart,
    DateTime weekEnd,
    double dayWidth,
    double laneHeight,
  ) {
    final start = item.start.isBefore(weekStart) ? weekStart : item.start;
    final end = item.end.isAfter(weekEnd) ? weekEnd : item.end;
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = end.hour == 0 && end.minute == 0 && end.second == 0
        ? DateTime(end.year, end.month, end.day)
        : DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    final startOffset = startDay.difference(weekStart).inDays.clamp(0, 6);
    final spanDays = endDay
        .difference(startDay)
        .inDays
        .clamp(1, 7 - startOffset);
    return Positioned(
      left: startOffset * dayWidth + 4,
      top: row * laneHeight + 4,
      width: dayWidth * spanDays - 8,
      height: laneHeight - 8,
      child: Material(
        color: item.color.withValues(alpha: item.isCompleted ? 0.62 : 0.9),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: item.isCompleted,
                    onChanged: (checked) => item.onToggle(checked == true),
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
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ).copyWith(
                          color: item.isCompleted
                              ? Colors.white.withValues(alpha: 0.72)
                              : Colors.white,
                          decoration: item.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: Colors.white.withValues(alpha: 0.72),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
              switch (details.data.kind) {
                case _TimelineDragKind.move:
                  _moveTimelineItem(details.data.item, target);
                case _TimelineDragKind.resizeStart:
                  _resizeTimelineStart(details.data.item, target);
                case _TimelineDragKind.resizeEnd:
                  _resizeTimelineEnd(details.data.item, target);
              }
            },
            builder: (context, candidateData, rejectedData) {
              final hovering = candidateData.isNotEmpty;
              return Container(
                height: _hourHeight,
                width: dayWidth,
                decoration: BoxDecoration(
                  color: hovering
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08)
                      : null,
                  border: Border(
                    right: BorderSide(color: AppTheme.borderSubtle),
                    bottom: BorderSide(color: AppTheme.borderSubtle),
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

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

  List<Widget> _buildEventBlocksForDay(
    DateTime day,
    int dayIndex,
    double dayWidth,
  ) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayEvents = _events
        .where(
          (event) =>
              _eventOverlapsDay(event, day) && !_isMultiDaySchedule(event),
        )
        .toList();
    final dayTasks = _rangeTasks
        .where((task) => _taskOverlapsDay(task, day) && !_isMultiDayTask(task))
        .toList();

    final blocks = <Widget>[];
    for (final event in dayEvents) {
      final start = event.startTime as DateTime;
      final end = event.endTime as DateTime;
      final segmentStart = start.isAfter(dayStart) ? start : dayStart;
      final segmentEnd = end.isBefore(dayEnd) ? end : dayEnd;
      final top =
          segmentStart.difference(dayStart).inMinutes / 60 * _hourHeight;
      final height =
          (segmentEnd.difference(segmentStart).inMinutes / 60 * _hourHeight)
              .clamp(28.0, _hourHeight * 24);

      blocks.add(
        Positioned(
          left: dayIndex * dayWidth + 3,
          top: top + 2,
          width: dayWidth - 6,
          height: height - 4,
          child: _buildDraggableEventBlock(event, start, end, segmentStart),
        ),
      );
    }

    for (final task in dayTasks) {
      final start = task.startDate ?? dayStart;
      final end = task.endDate ?? start.add(const Duration(hours: 1));
      final segmentStart = start.isAfter(dayStart) ? start : dayStart;
      final segmentEnd = end.isBefore(dayEnd) ? end : dayEnd;
      final top =
          segmentStart.difference(dayStart).inMinutes / 60 * _hourHeight;
      final height =
          (segmentEnd.difference(segmentStart).inMinutes / 60 * _hourHeight)
              .clamp(28.0, _hourHeight * 24);
      blocks.add(
        Positioned(
          left: dayIndex * dayWidth + 3,
          top: top + 2,
          width: dayWidth - 6,
          height: height - 4,
          child: _buildDraggableTaskBlock(task, start, end, segmentStart),
        ),
      );
    }

    return blocks;
  }

  bool _taskOverlapsDay(TaskBreakdown task, DateTime day) {
    final start = task.startDate;
    final end = task.endDate;
    if (start == null && end == null) return false;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final effectiveStart = start ?? end!;
    final effectiveEnd = end ?? start!.add(const Duration(hours: 1));
    return effectiveStart.isBefore(dayEnd) && effectiveEnd.isAfter(dayStart);
  }

  Widget _buildTaskBlock(TaskBreakdown task, DateTime start, DateTime end) {
    final isCompleted = task.status == 'completed';
    final color = isCompleted
        ? Colors.grey.shade500
        : _priorityColor(task.priority);
    final textColor = isCompleted
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.white;
    final parentLabel = task.parentTaskId != null ? _parentLabel(task) : '';
    return Material(
      color: color.withValues(alpha: isCompleted ? 0.62 : 0.88),
      elevation: isCompleted ? 0 : 2,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => _openTaskDetail(task),
        onSecondaryTap: () => _showTaskContextMenu(task),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: isCompleted,
                  onChanged: (checked) =>
                      _updateTaskStatus(task, checked == true),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (parentLabel.isNotEmpty)
                      Text(
                        parentLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.75),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ).copyWith(
                            color: textColor,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: textColor,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_timeLabel(start)} - ${_timeLabel(end)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableTaskBlock(
    TaskBreakdown task,
    DateTime start,
    DateTime end,
    DateTime segmentStart,
  ) {
    final block = _buildTaskBlock(task, start, end);
    return Builder(
      builder: (eventContext) => DragTarget<_TimelineDragData>(
        onWillAcceptWithDetails: (details) =>
            details.data.kind != _TimelineDragKind.move,
        onAcceptWithDetails: (details) {
          final box = eventContext.findRenderObject() as RenderBox?;
          final local = box?.globalToLocal(details.offset) ?? Offset.zero;
          final minuteOffset = (local.dy / _hourHeight * 60).round();
          final snappedMinute = (minuteOffset / 15).round() * 15;
          final target = segmentStart.add(Duration(minutes: snappedMinute));
          switch (details.data.kind) {
            case _TimelineDragKind.move:
              _moveTimelineItem(details.data.item, target);
            case _TimelineDragKind.resizeStart:
              _resizeTimelineStart(details.data.item, target);
            case _TimelineDragKind.resizeEnd:
              _resizeTimelineEnd(details.data.item, target);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Draggable<_TimelineDragData>(
                data: _TimelineDragData(_TimelineDragKind.move, task),
                feedback: SizedBox(width: 120, height: 48, child: block),
                childWhenDragging: Opacity(opacity: 0.35, child: block),
                child: block,
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 12,
                child: _ResizeHandle(
                  data: _TimelineDragData(_TimelineDragKind.resizeStart, task),
                  alignment: Alignment.topCenter,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 12,
                child: _ResizeHandle(
                  data: _TimelineDragData(_TimelineDragKind.resizeEnd, task),
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDraggableEventBlock(
    dynamic event,
    DateTime start,
    DateTime end,
    DateTime segmentStart,
  ) {
    final isCompleted = event.status == 'completed';
    final color = isCompleted
        ? Colors.grey.shade500
        : _priorityColor(event.priority as String);
    final textColor = isCompleted
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.white;
    final block = Material(
      color: color.withValues(alpha: isCompleted ? 0.62 : 0.9),
      elevation: isCompleted ? 0 : 2,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => _editSchedule(event),
        onSecondaryTap: () => _showScheduleContextMenu(event),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: event.status == 'completed',
                  onChanged: (checked) =>
                      _updateScheduleStatus(event, checked == true),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.title as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ).copyWith(
                            color: textColor,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: textColor,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_timeLabel(start)} - ${_timeLabel(end)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Builder(
      builder: (eventContext) => DragTarget<_TimelineDragData>(
        onWillAcceptWithDetails: (details) =>
            details.data.kind != _TimelineDragKind.move,
        onAcceptWithDetails: (details) {
          final box = eventContext.findRenderObject() as RenderBox?;
          final local = box?.globalToLocal(details.offset) ?? Offset.zero;
          final minuteOffset = (local.dy / _hourHeight * 60).round();
          final snappedMinute = (minuteOffset / 15).round() * 15;
          final target = segmentStart.add(Duration(minutes: snappedMinute));
          switch (details.data.kind) {
            case _TimelineDragKind.move:
              _moveTimelineItem(details.data.item, target);
            case _TimelineDragKind.resizeStart:
              _resizeTimelineStart(details.data.item, target);
            case _TimelineDragKind.resizeEnd:
              _resizeTimelineEnd(details.data.item, target);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Draggable<_TimelineDragData>(
                data: _TimelineDragData(_TimelineDragKind.move, event),
                feedback: SizedBox(width: 120, height: 48, child: block),
                childWhenDragging: Opacity(opacity: 0.35, child: block),
                child: block,
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 12,
                child: _ResizeHandle(
                  data: _TimelineDragData(_TimelineDragKind.resizeStart, event),
                  alignment: Alignment.topCenter,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 12,
                child: _ResizeHandle(
                  data: _TimelineDragData(_TimelineDragKind.resizeEnd, event),
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _timeLabel(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Widget _buildEventList() {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final dayEvents = _getEventsForDay(_selectedDay ?? DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${_selectedDay?.month}月${_selectedDay?.day}日 日程',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (dayEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('暂无日程', style: TextStyle(color: AppTheme.textHint)),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: dayEvents.length,
              itemBuilder: (context, index) {
                final event = dayEvents[index];
                final isCompleted = event.status == 'completed';
                return Card(
                  color: isCompleted
                      ? Colors.grey.shade100
                      : Theme.of(context).cardColor,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Checkbox(
                      value: isCompleted,
                      onChanged: (checked) =>
                          _updateScheduleStatus(event, checked == true),
                    ),
                    title: Text(
                      event.title as String,
                      style: TextStyle(
                        color: isCompleted
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    subtitle: Text(
                      '${(event.startTime as DateTime).hour}:${(event.startTime as DateTime).minute.toString().padLeft(2, '0')} - '
                      '${(event.endTime as DateTime).hour}:${(event.endTime as DateTime).minute.toString().padLeft(2, '0')}  '
                      '${_priorityLabel(event.priority as String)}',
                      style: TextStyle(
                        color: isCompleted
                            ? AppTheme.textHint
                            : AppTheme.textSecondary,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') _editSchedule(event);
                        if (action == 'delete') _deleteSchedule(event);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('编辑'),
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
}

enum _TimelineDragKind { move, resizeStart, resizeEnd }

class _TimelineDragData {
  final _TimelineDragKind kind;
  final Object item;

  const _TimelineDragData(this.kind, this.item);
}

class _ResizeHandle extends StatelessWidget {
  final _TimelineDragData data;
  final Alignment alignment;

  const _ResizeHandle({required this.data, required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Draggable<_TimelineDragData>(
      data: data,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 96,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      child: Align(
        alignment: alignment,
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _MultiDayItem {
  final String title;
  final DateTime start;
  final DateTime end;
  final Color color;
  final bool isCompleted;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  const _MultiDayItem({
    required this.title,
    required this.start,
    required this.end,
    required this.color,
    required this.isCompleted,
    required this.onTap,
    required this.onToggle,
  });
}
