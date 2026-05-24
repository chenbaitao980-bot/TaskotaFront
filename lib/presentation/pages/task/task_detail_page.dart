import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/entities/task_breakdown.dart';
import '../../../services/local_storage_service.dart';
import 'create_task_page.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskId;

  const TaskDetailPage({super.key, required this.taskId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final LocalStorageService _storage = LocalStorageService();
  TaskBreakdown? _task;
  List<TaskBreakdown> _children = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    await _storage.init();
    final tasks = _storage.getTasks();
    final task = tasks.where((t) => t.id == widget.taskId).firstOrNull;
    setState(() {
      _task = task;
      _children = task == null ? [] : _storage.getTasks(parentTaskId: task.id);
      _loaded = true;
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

  Future<void> _deleteTask() async {
    if (_task == null) return;
    if (_children.isNotEmpty || _storage.hasChildTasks(widget.taskId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('该任务仍有子任务，请先删除子任务'),
          action: SnackBarAction(
            label: '知道了',
            onPressed: () {},
          ),
        ),
      );
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
    final updated = _task!.copyWith(
      status: status,
      progress: status == 'completed'
          ? 100
          : (status == 'pending' ? 0 : _task!.progress),
    );
    await _storage.updateTask(updated);
    _loadTask();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已设为${_statusLabel(status)}')));
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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _deleteTask();
              } else {
                _updateStatus(value);
              }
            },
            itemBuilder: (context) => const [
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
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 28),

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
                    const Divider(height: 1, color: AppTheme.borderSubtle),
                  ],
                  if (task.endDate != null) ...[
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.event,
                      '结束时间',
                      _dateTimeLabel(task.endDate!),
                    ),
                    const Divider(height: 1, color: AppTheme.borderSubtle),
                  ],
                  const SizedBox(height: 8),
                  _infoRow(Icons.layers, '层级', task.level),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Progress
            Text('进度', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: task.progress / 100,
                backgroundColor: AppTheme.bgInput,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${task.progress}% 完成',
              style: GoogleFonts.jetBrainsMonoTextTheme().bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 28),

            Text('子任务', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_children.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: const Text(
                  '暂无子任务',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ..._children.map((child) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    tileColor: AppTheme.bgCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(
                      Icons.account_tree_outlined,
                      color: _statusColor(child.status),
                    ),
                    title: Text(
                      child.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_statusLabel(child.status)} · ${_dateRangeLabel(child.startDate, child.endDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _openChild(child),
                  ),
                );
              }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _createSubtask,
                icon: const Icon(Icons.add_task_rounded, size: 18),
                label: const Text('添加子任务'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
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
                    side: const BorderSide(color: AppTheme.primaryColor),
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
                    side: const BorderSide(color: AppTheme.error),
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
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
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
