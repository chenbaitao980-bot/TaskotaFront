import 'package:flutter/material.dart';
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

  Future<void> _deleteTask() async {
    if (_task == null) return;
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                child: Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.edit), onPressed: _editTask),
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
            Row(
              children: [
                _badge(
                  _priorityLabel(task.priority),
                  _priorityColor(task.priority),
                ),
                const SizedBox(width: 8),
                _badge(_statusLabel(task.status), _statusColor(task.status)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              task.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (task.description != null) ...[
              const SizedBox(height: 8),
              Text(
                task.description!,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (task.startDate != null) ...[
                      _infoRow(
                        Icons.calendar_today,
                        '开始日期',
                        '${task.startDate!.year}-${task.startDate!.month.toString().padLeft(2, '0')}-${task.startDate!.day.toString().padLeft(2, '0')}',
                      ),
                      const Divider(),
                    ],
                    if (task.endDate != null) ...[
                      _infoRow(
                        Icons.event,
                        '截止日期',
                        '${task.endDate!.year}-${task.endDate!.month.toString().padLeft(2, '0')}-${task.endDate!.day.toString().padLeft(2, '0')}',
                      ),
                      const Divider(),
                    ],
                    _infoRow(Icons.layers, '层级', task.level),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('进度', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: task.progress / 100,
              backgroundColor: Colors.grey[200],
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${task.progress}% 完成',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Text('状态操作', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusAction('待办', 'pending', Icons.check_circle_outline),
                _statusAction('进行中', 'in_progress', Icons.timelapse),
                _statusAction('已完成', 'completed', Icons.done_all),
                OutlinedButton.icon(
                  onPressed: _editTask,
                  icon: const Icon(Icons.edit),
                  label: const Text('编辑'),
                ),
                OutlinedButton.icon(
                  onPressed: _deleteTask,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
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
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: () => _updateStatus(status),
            icon: Icon(icon),
            label: Text(label),
          );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }

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
    'P0' => Colors.red,
    'P1' => Colors.orange,
    'P2' => Colors.green,
    _ => Colors.blue,
  };
  Color _statusColor(String s) => switch (s) {
    'pending' => Colors.grey,
    'in_progress' => Colors.blue,
    'completed' => Colors.green,
    'failed' => Colors.red,
    _ => Colors.grey,
  };
}
