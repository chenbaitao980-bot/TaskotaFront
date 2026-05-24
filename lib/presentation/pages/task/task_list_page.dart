import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/entities/schedule.dart';
import '../../../models/entities/task_breakdown.dart';
import '../../../services/local_storage_service.dart';
import 'task_detail_page.dart';
import 'create_task_page.dart';

class TaskListPage extends StatefulWidget {
  final String status;
  final String title;

  const TaskListPage({super.key, required this.status, required this.title});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final LocalStorageService _storage = LocalStorageService();
  List<TaskBreakdown> _tasks = [];
  List<Schedule> _pendingSchedules = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    await _storage.init();
    final tasks = _storage.getTasks(status: widget.status, rootOnly: true);
    final pendingSchedules = widget.status == 'pending'
        ? _storage.getSchedules()
        : <Schedule>[];
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _pendingSchedules = pendingSchedules;
      _loaded = true;
    });
  }

  Future<void> _openTask(TaskBreakdown task) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: task.id)),
    );
    await _loadTasks();
  }

  Future<void> _createTask() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateTaskPage()),
    );
    if (result == true) _loadTasks();
  }

  Future<void> _editTask(TaskBreakdown task) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateTaskPage(existingTask: task)),
    );
    if (result == true) _loadTasks();
  }

  Future<void> _updateTaskStatus(TaskBreakdown task, String status) async {
    await _storage.updateTask(
      task.copyWith(
        status: status,
        progress: status == 'completed' ? 100 : task.progress,
      ),
    );
    await _loadTasks();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已设为${_statusLabel(status)}')));
  }

  Future<void> _deleteTask(TaskBreakdown task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定删除"${task.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.deleteTask(task.id);
    await _loadTasks();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('任务已删除')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty && _pendingSchedules.isEmpty
          ? _EmptyTaskState(title: widget.title)
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final task in _tasks) ...[
                    _TaskCard(
                      task: task,
                      statusIcon: _statusIcon(task.status),
                      statusLabel: _statusLabel(task.status),
                      priorityColor: _priorityColor(task.priority),
                      priorityLabel: _priorityLabel(task.priority),
                      dateLabel: task.endDate == null
                          ? null
                          : _dateLabel(task.endDate!),
                      onTap: () => _openTask(task),
                      onSetStatus: (status) => _updateTaskStatus(task, status),
                      onDelete: () => _deleteTask(task),
                      onEdit: () => _editTask(task),
                    ),
                    const SizedBox(height: 8),
                  ],
                  for (final schedule in _pendingSchedules) ...[
                    _SchedulePendingCard(
                      schedule: schedule,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请在日历中编辑日程')),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTask,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _dateLabel(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _priorityLabel(String priority) => switch (priority) {
    'P0' => '紧急',
    'P1' => '重要',
    'P2' => '普通',
    _ => '低',
  };

  String _statusLabel(String status) => switch (status) {
    'pending' => '待办',
    'in_progress' => '进行中',
    'completed' => '已完成',
    'failed' => '失败',
    _ => status,
  };

  IconData _statusIcon(String status) => switch (status) {
    'pending' => Icons.check_circle_outline,
    'in_progress' => Icons.timelapse,
    'completed' => Icons.done_all,
    _ => Icons.assignment_outlined,
  };

  Color _priorityColor(String priority) => switch (priority) {
    'P0' => AppTheme.priorityP0,
    'P1' => AppTheme.priorityP1,
    'P2' => AppTheme.priorityP2,
    _ => AppTheme.priorityP3,
  };
}

class _TaskCard extends StatelessWidget {
  final TaskBreakdown task;
  final IconData statusIcon;
  final String statusLabel;
  final Color priorityColor;
  final String priorityLabel;
  final String? dateLabel;
  final VoidCallback onTap;
  final ValueChanged<String> onSetStatus;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TaskCard({
    required this.task,
    required this.statusIcon,
    required this.statusLabel,
    required this.priorityColor,
    required this.priorityLabel,
    required this.dateLabel,
    required this.onTap,
    required this.onSetStatus,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Color bar
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(statusIcon, color: priorityColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    priorityLabel,
                                    style: TextStyle(
                                      color: priorityColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  statusLabel,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                if (dateLabel != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '截止 $dateLabel',
                                    style: const TextStyle(
                                      color: AppTheme.textHint,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          } else if (value == 'delete') {
                            onDelete();
                          } else {
                            onSetStatus(value);
                          }
                        },
                        icon: const Icon(
                          Icons.more_horiz,
                          color: AppTheme.textHint,
                          size: 20,
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: AppTheme.textPrimary,
                                ),
                                SizedBox(width: 8),
                                Text('编辑'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'pending',
                            child: Text('设为待办'),
                          ),
                          const PopupMenuItem(
                            value: 'in_progress',
                            child: Text('设为进行中'),
                          ),
                          const PopupMenuItem(
                            value: 'completed',
                            child: Text('设为已完成'),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              '删除',
                              style: TextStyle(color: AppTheme.error),
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
        ],
      ),
    );
  }
}

class _SchedulePendingCard extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback onTap;

  const _SchedulePendingCard({required this.schedule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: AppTheme.success,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.event_note,
                          color: AppTheme.success,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule.title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '日程 · ${_timeLabel(schedule.startTime)} - ${_timeLabel(schedule.endTime)}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppTheme.textHint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime time) =>
      '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _EmptyTaskState extends StatelessWidget {
  final String title;

  const _EmptyTaskState({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 56, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(
              '$title暂无任务',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
