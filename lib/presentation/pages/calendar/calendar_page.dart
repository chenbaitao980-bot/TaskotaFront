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
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final LocalStorageService _storage = LocalStorageService();
  List<dynamic> _events = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _initStorage();
  }

  Future<void> _initStorage() async {
    await _storage.init();
    _loadEvents();
    setState(() => _initialized = true);
  }

  void _loadEvents() {
    final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0, 23, 59, 59);
    _events = _storage.getSchedules(startDate: startOfMonth, endDate: endOfMonth);
    if (mounted) setState(() {});
  }

  String _getUserId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is LocalAuthenticated) return authState.email;
    if (authState is Authenticated) return authState.user.id;
    return 'local_user';
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events.where((e) {
      final start = e.startTime as DateTime;
      return start.year == day.year && start.month == day.month && start.day == day.day;
    }).toList();
  }

  Future<void> _createSchedule() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreateScheduleDialog(
        initialDate: _selectedDay,
        initialStartTime: _selectedDay != null
            ? DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, 9)
            : null,
        initialEndTime: _selectedDay != null
            ? DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, 10)
            : null,
      ),
    );

    if (result != null) {
      final newSchedule = await _storage.createSchedule(
        userId: _getUserId(),
        title: result['title'] as String,
        description: result['description'] as String?,
        startTime: result['startTime'] as DateTime,
        endTime: result['endTime'] as DateTime,
        priority: result['priority'] as String,
      );
      NotificationService().scheduleReminderForSchedule(
        scheduleId: newSchedule.id,
        title: newSchedule.title,
        startTime: newSchedule.startTime,
        description: newSchedule.description,
      );
      _loadEvents();
    }
  }

  Future<void> _editSchedule(dynamic schedule) async {
    final result = await showDialog<Map<String, dynamic>>(
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

    if (result != null) {
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
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

  String _priorityLabel(String p) {
    return switch (p) { 'P0' => '紧急', 'P1' => '重要', 'P2' => '普通', _ => '低' };
  }

  Color _priorityColor(String p) {
    return switch (p) { 'P0' => Colors.red, 'P1' => Colors.orange, 'P2' => Colors.green, _ => Colors.blue };
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
            onSelectionChanged: (v) => setState(() => _calendarFormat = v.first),
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
              });
              _loadEvents();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
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
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSchedule,
        child: const Icon(Icons.add),
      ),
    );
  }

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
            child: Center(child: Text('暂无日程', style: TextStyle(color: Colors.grey))),
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
                    leading: CircleAvatar(
                      backgroundColor: _priorityColor(event.priority as String).withValues(alpha: 0.2),
                      radius: 4,
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
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('编辑')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('删除', style: TextStyle(color: Colors.red))])),
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
