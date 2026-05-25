import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/project_repository.dart';

class TaskEditPage extends StatefulWidget {
  final Task task;
  final ProjectRepository projectRepository;

  const TaskEditPage({
    super.key,
    required this.task,
    required this.projectRepository,
  });

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late Future<List<Project>> _projectsFuture;
  late String _selectedProjectId;
  late int _priority;
  DateTime? _startDate;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task.title);
    _descController = TextEditingController(text: task.description);
    _selectedProjectId = task.projectId;
    _priority = task.priority;
    _startDate = task.startDate != null
        ? DateTime.fromMillisecondsSinceEpoch(task.startDate!)
        : null;
    _dueDate = task.dueDate != null
        ? DateTime.fromMillisecondsSinceEpoch(task.dueDate!)
        : null;
    _projectsFuture = widget.projectRepository.getActive();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑任务'),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '任务标题',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '请输入标题' : null,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Project>>(
              future: _projectsFuture,
              builder: (context, snapshot) {
                final projects = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  value: _selectedProjectId,
                  decoration: const InputDecoration(
                    labelText: '所属项目',
                    border: OutlineInputBorder(),
                  ),
                  items: projects
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(
                                        p.color.replaceFirst('#', '0xFF'))),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(p.name),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedProjectId = v ?? _selectedProjectId),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('优先级', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                (0, '无'),
                (1, '低'),
                (3, '中'),
                (5, '高'),
              ]
                  .map((p) => ChoiceChip(
                        label: Text(p.$2),
                        selected: _priority == p.$1,
                        onSelected: (v) =>
                            setState(() => _priority = p.$1),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: '开始时间',
                    date: _startDate,
                    onTap: () => _pickDate(true),
                    onClear: () => setState(() => _startDate = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: '截止时间',
                    date: _dueDate,
                    onTap: () => _pickDate(false),
                    onClear: () => setState(() => _dueDate = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '描述（选填）',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart ? _startDate : _dueDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate ?? now),
    );
    if (pickedTime == null) return;
    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      if (isStart) {
        _startDate = combined;
      } else {
        _dueDate = combined;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'title': _titleController.text.trim(),
      'projectId': _selectedProjectId,
      'description': _descController.text.trim(),
      'priority': _priority,
      'startDate': _startDate?.millisecondsSinceEpoch,
      'dueDate': _dueDate?.millisecondsSinceEpoch,
    });
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderSubtle),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textHint)),
                  const SizedBox(height: 4),
                  Text(
                    date != null
                        ? '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')} ${date!.hour.toString().padLeft(2, '0')}:${date!.minute.toString().padLeft(2, '0')}'
                        : '选择',
                    style: TextStyle(
                      fontSize: 14,
                      color: date != null
                          ? AppTheme.textPrimary
                          : AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 16, color: AppTheme.textHint),
              ),
          ],
        ),
      ),
    );
  }
}
