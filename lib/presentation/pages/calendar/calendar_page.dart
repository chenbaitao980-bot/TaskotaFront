import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/notification_service.dart';
import '../../widgets/create_schedule_dialog.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

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
  bool _initialized = false;
  bool _didAutoScrollWeek = false;
  static const double _hourHeight = 56;
  static const double _timeColumnWidth = 48;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _initStorage();
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
    if (mounted) setState(() {});
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日程时间已更新')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新时间失败：$e')));
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
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
      'P0' => const Color(0xFFE53935),
      'P1' => const Color(0xFFFF9800),
      'P2' => const Color(0xFF43A047),
      _ => const Color(0xFF1E88E5),
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
              return SingleChildScrollView(
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
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          );
        }),
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
                  _moveSchedule(details.data.schedule, target);
                case _TimelineDragKind.resizeStart:
                  _resizeScheduleStart(details.data.schedule, target);
                case _TimelineDragKind.resizeEnd:
                  _resizeScheduleEnd(details.data.schedule, target);
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
                    right: BorderSide(color: Colors.grey.shade200),
                    bottom: BorderSide(color: Colors.grey.shade200),
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
        .where((event) => _eventOverlapsDay(event, day))
        .toList();

    return dayEvents.map((event) {
      final start = event.startTime as DateTime;
      final end = event.endTime as DateTime;
      final segmentStart = start.isAfter(dayStart) ? start : dayStart;
      final segmentEnd = end.isBefore(dayEnd) ? end : dayEnd;
      final top =
          segmentStart.difference(dayStart).inMinutes / 60 * _hourHeight;
      final height =
          (segmentEnd.difference(segmentStart).inMinutes / 60 * _hourHeight)
              .clamp(28.0, _hourHeight * 24);

      return Positioned(
        left: dayIndex * dayWidth + 3,
        top: top + 2,
        width: dayWidth - 6,
        height: height - 4,
        child: _buildDraggableEventBlock(event, start, end, segmentStart),
      );
    }).toList();
  }

  Widget _buildDraggableEventBlock(
    dynamic event,
    DateTime start,
    DateTime end,
    DateTime segmentStart,
  ) {
    final color = _priorityColor(event.priority as String);
    final block = Material(
      color: color.withValues(alpha: 0.9),
      elevation: 2,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => _editSchedule(event),
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
                  onChanged: (checked) {
                    final newStatus = checked == true ? 'completed' : 'in_progress';
                    event.copyWith(status: newStatus);
                    _storage.updateSchedule(event.copyWith(status: newStatus));
                    _loadEvents();
                  },
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_timeLabel(start)} - ${_timeLabel(end)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
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
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) {
          final box = eventContext.findRenderObject() as RenderBox?;
          final local = box?.globalToLocal(details.offset) ?? Offset.zero;
          final minuteOffset = (local.dy / _hourHeight * 60).round();
          final snappedMinute = (minuteOffset / 15).round() * 15;
          final target = segmentStart.add(Duration(minutes: snappedMinute));
          switch (details.data.kind) {
            case _TimelineDragKind.move:
              _moveSchedule(details.data.schedule, target);
            case _TimelineDragKind.resizeStart:
              _resizeScheduleStart(details.data.schedule, target);
            case _TimelineDragKind.resizeEnd:
              _resizeScheduleEnd(details.data.schedule, target);
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
              child: Text('暂无日程', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: dayEvents.length,
              itemBuilder: (context, index) {
                final event = dayEvents[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Checkbox(
                      value: event.status == 'completed',
                      onChanged: (checked) {
                        final newStatus = checked == true ? 'completed' : 'in_progress';
                        _storage.updateSchedule(event.copyWith(status: newStatus));
                        _loadEvents();
                      },
                    ),
                    title: Text(event.title as String),
                    subtitle: Text(
                      '${(event.startTime as DateTime).hour}:${(event.startTime as DateTime).minute.toString().padLeft(2, '0')} - '
                      '${(event.endTime as DateTime).hour}:${(event.endTime as DateTime).minute.toString().padLeft(2, '0')}  '
                      '${_priorityLabel(event.priority as String)}',
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
  final Object schedule;

  const _TimelineDragData(this.kind, this.schedule);
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
