import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/project_repository.dart';
import '../../../widgets/calendar_date_picker.dart';

class TaskCreateSheet extends StatefulWidget {
  final String? initialProjectId;
  final ProjectRepository projectRepository;
  final List<Task> availableParentTasks;
  final int? initialStartDateMillis;
  final int? initialDueDateMillis;

  const TaskCreateSheet({
    super.key,
    this.initialProjectId,
    required this.projectRepository,
    this.availableParentTasks = const [],
    this.initialStartDateMillis,
    this.initialDueDateMillis,
  });

  @override
  State<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends State<TaskCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late Future<List<Project>> _projectsFuture;
  String? _selectedProjectId;
  int _priority = 0;
  DateTime? _startDate;
  DateTime? _dueDate;
  String? _parentTaskId;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
    if (widget.initialStartDateMillis != null) {
      _startDate =
          DateTime.fromMillisecondsSinceEpoch(widget.initialStartDateMillis!);
    } else {
      _startDate = DateTime.now();
    }
    if (widget.initialDueDateMillis != null) {
      _dueDate =
          DateTime.fromMillisecondsSinceEpoch(widget.initialDueDateMillis!);
    } else {
      _dueDate = _startDate!.add(const Duration(hours: 1));
    }
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '新建任务',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '任务标题',
                  hintText: '输入任务名称',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '请输入标题' : null,
              ),
              const SizedBox(height: 12),
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
                    onChanged: (v) => setState(() => _selectedProjectId = v),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (widget.availableParentTasks.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _parentTaskId,
                  decoration: const InputDecoration(
                    labelText: '父任务（可选）',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('无（根任务）'),
                    ),
                    ...widget.availableParentTasks.map((t) =>
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => _parentTaskId = v),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('优先级：', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  ..._buildPriorityChips(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      label: '开始时间',
                      date: _startDate,
                      onTap: () => _pickDateTime(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateButton(
                      label: '截止时间',
                      date: _dueDate,
                      onTap: () => _pickDateTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: '描述（选填）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('保存任务', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  List<Widget> _buildPriorityChips() {
    final priorities = [
      (0, '无'),
      (1, '低'),
      (3, '中'),
      (5, '高'),
    ];
    return priorities.map((p) {
      final isSelected = _priority == p.$1;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(p.$2, style: const TextStyle(fontSize: 12)),
          selected: isSelected,
          onSelected: (v) => setState(() => _priority = p.$1),
          selectedColor: _chipColor(p.$1),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
          visualDensity: VisualDensity.compact,
        ),
      );
    }).toList();
  }

  Color _chipColor(int priority) {
    switch (priority) {
      case 5:
        return AppTheme.priorityP0;
      case 3:
        return AppTheme.priorityP1;
      case 1:
        return AppTheme.priorityP3;
      default:
        return AppTheme.textHint;
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart ? _startDate : _dueDate;
    final picked = await showCalendarDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _dueDate = picked;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请选择开始时间')));
      return;
    }
    if (_dueDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请选择截止时间')));
      return;
    }
    if (!_dueDate!.isAfter(_startDate!)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('截止时间必须晚于开始时间')));
      return;
    }
    Navigator.pop(context, {
      'title': _titleController.text.trim(),
      'projectId': _selectedProjectId,
      'description': _descController.text.trim(),
      'priority': _priority,
      'startDate': _startDate!.millisecondsSinceEpoch,
      'dueDate': _dueDate!.millisecondsSinceEpoch,
      'parentId': _parentTaskId,
    });
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderSubtle),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? '${date!.month}/${date!.day} '
                      '${date!.hour.toString().padLeft(2, '0')}:${date!.minute.toString().padLeft(2, '0')}'
                  : '选择时间',
              style: TextStyle(
                fontSize: 14,
                color: date != null ? AppTheme.textPrimary : AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
