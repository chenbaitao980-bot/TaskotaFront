import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/entities/task_breakdown.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/notification_service.dart';
import 'create_task_page.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskId;

  const TaskDetailPage({super.key, required this.taskId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final LocalStorageService _storage = LocalStorageService();
  TaskBreakdown? _task;
  TaskBreakdown? _parentTask;
  List<TaskBreakdown> _children = [];
  bool _loaded = false;
  int _remindBeforeMinutes = 15;
  bool _reminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    await _storage.init();
    final tasks = _storage.getTasks();
    final task = tasks.where((t) => t.id == widget.taskId).firstOrNull;
    TaskBreakdown? parent;
    if (task?.parentTaskId != null) {
      parent = tasks.where((t) => t.id == task!.parentTaskId).firstOrNull;
    }
    setState(() {
      _task = task;
      _parentTask = parent;
      _children = task == null ? [] : _storage.getTasks(parentTaskId: task.id);
      _loaded = true;
      if (task != null) {
        _remindBeforeMinutes = task.remindBeforeMinutes;
        _reminderEnabled = task.reminderEnabled;
      }
    });
  }

  Future<void> _editTask() async {
    if (_task == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateTaskPage(existingTask: _task)),
    );
    if (result == true) _loadTask();
  }

  Future<void> _createSubtask() async {
    if (_task == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateTaskPage(parentTask: _task)),
    );
    if (result == true) _loadTask();
  }

  Future<void> _openChild(TaskBreakdown child) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: child.id)),
    );
    await _loadTask();
  }

  Future<void> _openParent() async {
    if (_parentTask == null) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: _parentTask!.id)),
    );
    await _loadTask();
  }

  void _backToCalendar() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _updateReminderSettings() async {
    if (_task == null) return;
    final updated = _task!.copyWith(
      remindBeforeMinutes: _remindBeforeMinutes,
      reminderEnabled: _reminderEnabled,
      updatedAt: DateTime.now(),
    );
    await _storage.updateTask(updated);
    _task = updated;
    if (_reminderEnabled && _task!.startDate != null) {
      NotificationService().scheduleReminderForSchedule(
        scheduleId: _task!.id,
        title: _task!.title,
        startTime: _task!.startDate!,
        description: _task!.description,
        remindBeforeMinutes: _remindBeforeMinutes,
      );
    }
  }

  Future<void> _deleteTask() async {
    if (_task == null) return;
    if (_children.isNotEmpty || _storage.hasChildTasks(widget.taskId)) {
      showAppSnackBar(context, '该任务仍有子任务，请先删除子任务');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: const Text('确定要删除这个任务吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _storage.deleteTask(widget.taskId);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_task == null) return;
    final previousStatus = _task!.status;
    final updated = _task!.copyWith(
      status: status,
      progress: status == 'completed'
          ? 100
          : (status == 'pending' ? 0 : _task!.progress),
    );
    await _storage.updateTask(updated);

    // 自动完成/回退父任务
    if (status == 'completed') {
      await _storage.checkAndAutoCompleteParent(widget.taskId);
    } else if (previousStatus == 'completed') {
      await _storage.revertParentOnChildIncomplete(widget.taskId);
    }

    _loadTask();
    if (mounted) {
      showAppSnackBar(context, '已设为${_statusLabel(status)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('任务详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('任务详情')),
        body: const Center(child: Text('任务不存在')),
      );
    }

    final task = _task!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
        actions: [
          TextButton.icon(
            onPressed: _backToCalendar,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: const Text('返回日历', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _deleteTask();
              } else {
                _updateStatus(value);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'pending', child: Text('设为待办')),
              PopupMenuItem(value: 'in_progress', child: Text('设为进行中')),
              PopupMenuItem(value: 'completed', child: Text('设为已完成')),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Text('删除', style: TextStyle(color: AppTheme.error)),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editTask,
          ),
          IconButton(
            tooltip: '添加子任务',
            icon: const Icon(Icons.add_task_rounded),
            onPressed: _createSubtask,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteTask,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge(
                  _priorityLabel(task.priority),
                  _priorityColor(task.priority),
                ),
                _badge(_statusLabel(task.status), _statusColor(task.status)),
              ],
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              task.title,
              style: GoogleFonts.interTextTheme().headlineLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (task.description != null) ...[
              const SizedBox(height: 10),
              Text(
                task.description!,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 28),

            // Hierarchy （滴答清单风格树形结构）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '层级结构',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Parent task breadcrumb
                  if (_parentTask != null)
                    InkWell(
                      onTap: _openParent,
                      child: Row(
                        children: [
                          Icon(Icons.subdirectory_arrow_right,
                              size: 18, color: AppTheme.primaryColor),
                          const SizedBox(width: 6),
                          Icon(Icons.folder_outlined,
                              size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            _parentTask!.title,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  if (_parentTask != null)
                    const SizedBox(height: 6),
                  // Current task
                  Row(
                    children: [
                      if (_parentTask != null)
                        Padding(
                          padding: EdgeInsets.only(left: 28),
                          child: Icon(Icons.arrow_downward,
                              size: 14, color: AppTheme.textHint),
                        ),
                      if (_parentTask != null)
                        const SizedBox(width: 6),
                      Icon(Icons.circle,
                          size: 10, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  if (task.startDate != null) ...[
                    _infoRow(
                      Icons.calendar_today,
                      '开始时间',
                      _dateTimeLabel(task.startDate!),
                    ),
                    Divider(height: 1, color: AppTheme.borderSubtle),
                  ],
                  if (task.endDate != null) ...[
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.event,
                      '结束时间',
                      _dateTimeLabel(task.endDate!),
                    ),
                    Divider(height: 1, color: AppTheme.borderSubtle),
                  ],
                  const SizedBox(height: 8),
                  _infoRow(Icons.layers, '层级', task.level),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 提醒设置
            _buildReminderSection(),
            const SizedBox(height: 28),

            // Progress
            Text('进度', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (_storage.calculateTaskProgress(task.id)) / 100,
                backgroundColor: AppTheme.bgInput,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_storage.calculateTaskProgress(task.id)}% 完成',
              style: GoogleFonts.jetBrainsMonoTextTheme().bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('子任务',
                    style: Theme.of(context).textTheme.titleLarge),
                Text('${_children.length}项',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textHint)),
              ],
            ),
            const SizedBox(height: 12),
            if (_children.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    Icon(Icons.account_tree_outlined,
                        size: 28, color: AppTheme.textHint),
                    const SizedBox(height: 8),
                    Text(
                      '暂无子任务',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _createSubtask,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('添加子任务'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  ..._children.map((child) {
                    final isChildCompleted = child.status == 'completed';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: isChildCompleted,
                            onChanged: (checked) async {
                              final newStatus = checked == true
                                  ? 'completed'
                                  : 'pending';
                              await _storage.updateTask(
                                child.copyWith(status: newStatus,
                                    progress: newStatus == 'completed'
                                        ? 100
                                        : 0),
                              );
                              _loadTask();
                            },
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        title: Text(
                          child.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            decoration: isChildCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isChildCompleted
                                ? AppTheme.textHint
                                : AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${_statusLabel(child.status)} · ${_dateRangeLabel(child.startDate, child.endDate)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Icon(Icons.chevron_right,
                            size: 18, color: AppTheme.textHint),
                        onTap: () => _openChild(child),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _createSubtask,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加子任务'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 28),

            // Status actions
            Text('状态操作', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusAction('待办', 'pending', Icons.check_circle_outline),
                _statusAction('进行中', 'in_progress', Icons.timelapse),
                _statusAction('已完成', 'completed', Icons.done_all),
                OutlinedButton.icon(
                  onPressed: _editTask,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('编辑'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _deleteTask,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('删除'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            isThreeLine: true,
            secondary: Icon(
              Icons.notifications_active,
              size: 20,
              color: _reminderEnabled ? AppTheme.primaryColor : AppTheme.textHint,
            ),
            title: const Text('启用提醒',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text(
              _reminderEnabled ? '将在任务开始前通知您' : '不会发送提醒',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            value: _reminderEnabled,
            onChanged: (v) {
              setState(() => _reminderEnabled = v);
              _updateReminderSettings();
            },
          ),
          if (_reminderEnabled) ...[
            Divider(height: 0.5, color: AppTheme.borderSubtle),
            _remindDropdownTile(
              icon: Icons.timer_outlined,
              label: '提前提醒',
              value: _remindBeforeMinutes,
              options: const [5, 10, 15, 30, 60, 120, 1440],
              optionLabels: const ['5分钟', '10分钟', '15分钟', '30分钟', '1小时', '2小时', '1天'],
              onChanged: (v) {
                setState(() => _remindBeforeMinutes = v);
                _updateReminderSettings();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _remindDropdownTile({
    required IconData icon,
    required String label,
    required int value,
    required List<int> options,
    required List<String> optionLabels,
    required ValueChanged<int> onChanged,
  }) {
    final idx = options.indexOf(value);
    final displayLabel = idx >= 0 ? optionLabels[idx] : '$value分钟';
    return ListTile(
      minVerticalPadding: 8,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: AppTheme.primaryColor),
      title: Text(label,
          style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
      subtitle: Text(displayLabel,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      trailing: Icon(Icons.arrow_drop_down, size: 20, color: AppTheme.textHint),
      onTap: () => _showRemindPicker(options, optionLabels, value, onChanged),
    );
  }

  void _showRemindPicker(List<int> options, List<String> labels, int current, ValueChanged<int> onChanged) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('提前提醒'),
        children: List.generate(options.length, (i) {
          return RadioListTile<int>(
            title: Text(labels[i]),
            value: options[i],
            groupValue: current,
            onChanged: (v) {
              if (v != null) {
                onChanged(v);
                Navigator.pop(ctx);
              }
            },
          );
        }),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _statusAction(String label, String status, IconData icon) {
    final selected = _task?.status == status;
    return selected
        ? FilledButton.icon(
            onPressed: null,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: _statusColor(status),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: () => _updateStatus(status),
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: _statusColor(status),
              side: BorderSide(color: _statusColor(status)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _dateRangeLabel(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '未设置日期';
    if (start == null) return '截止 ${_shortDate(end!)}';
    if (end == null) return '开始 ${_shortDate(start)}';
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return _shortDate(start);
    }
    return '${_shortDate(start)} - ${_shortDate(end)}';
  }

  String _dateTimeLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String _shortDate(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String _priorityLabel(String p) => switch (p) {
    'P0' => '紧急',
    'P1' => '重要',
    'P2' => '普通',
    _ => '低',
  };
  String _statusLabel(String s) => switch (s) {
    'pending' => '待办',
    'in_progress' => '进行中',
    'completed' => '已完成',
    'failed' => '失败',
    _ => s,
  };

  Color _priorityColor(String p) => switch (p) {
    'P0' => AppTheme.priorityP0,
    'P1' => AppTheme.priorityP1,
    'P2' => AppTheme.priorityP2,
    _ => AppTheme.priorityP3,
  };
  Color _statusColor(String s) => switch (s) {
    'pending' => AppTheme.textSecondary,
    'in_progress' => AppTheme.info,
    'completed' => AppTheme.success,
    'failed' => AppTheme.error,
    _ => AppTheme.textSecondary,
  };
}
