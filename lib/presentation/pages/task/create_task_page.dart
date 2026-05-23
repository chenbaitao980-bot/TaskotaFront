import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/entities/task_breakdown.dart';
import '../../../services/local_storage_service.dart';
import '../../blocs/auth/auth_bloc.dart';

class CreateTaskPage extends StatefulWidget {
  final TaskBreakdown? existingTask;

  const CreateTaskPage({super.key, this.existingTask});

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  late String _priority;
  late bool _focusRequired;
  bool _isEditing = false;
  final LocalStorageService _storage = LocalStorageService();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingTask != null;
    if (_isEditing) {
      final t = widget.existingTask!;
      _titleController.text = t.title;
      _descriptionController.text = t.description ?? '';
      _startDate = t.startDate ?? DateTime.now();
      _endDate = t.endDate ?? DateTime.now().add(const Duration(days: 7));
      _priority = t.priority;
      _focusRequired = t.focusRequired;
    } else {
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 7));
      _priority = 'P2';
      _focusRequired = false;
    }
    _storage.init();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _getUserId() {
    final state = context.read<AuthBloc>().state;
    if (state is LocalAuthenticated) return state.email;
    if (state is Authenticated) return state.user.id;
    return 'local_user';
  }

  Future<void> _selectDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入任务标题')),
      );
      return;
    }

    if (_isEditing) {
      final updated = widget.existingTask!.copyWith(
        title: title,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        priority: _priority,
        focusRequired: _focusRequired,
      );
      await _storage.updateTask(updated);
    } else {
      await _storage.createTask(
        userId: _getUserId(),
        title: title,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        level: 'weekly',
        startDate: _startDate,
        endDate: _endDate,
        priority: _priority,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑任务' : '新建任务'),
        actions: [
          TextButton(onPressed: _saveTask, child: const Text('保存')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '任务标题',
                hintText: '输入任务标题',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '添加任务描述（可选）',
              ),
            ),
            const SizedBox(height: 24),
            Text('日期范围', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('开始日期'),
              subtitle: Text('${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}'),
              onTap: () => _selectDate(true),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('截止日期'),
              subtitle: Text('${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}'),
              onTap: () => _selectDate(false),
            ),
            const SizedBox(height: 24),
            Text('优先级', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildPriorityChip('P0', '紧急', Colors.red),
                _buildPriorityChip('P1', '重要', Colors.orange),
                _buildPriorityChip('P2', '普通', Colors.green),
                _buildPriorityChip('P3', '低', Colors.blue),
              ],
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('需要专注'),
              subtitle: const Text('此任务需要全神贯注完成'),
              value: _focusRequired,
              onChanged: (value) => setState(() => _focusRequired = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String value, String label, Color color) {
    final selected = _priority == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (s) { if (s) setState(() => _priority = value); },
    );
  }
}
