import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/project_repository.dart';
import '../../../widgets/calendar_date_picker.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

class TaskEditPage extends StatefulWidget {
  final Task task;
  final ProjectRepository projectRepository;
  final ValueChanged<Map<String, dynamic>>? onAutoSave;

  const TaskEditPage({
    super.key,
    required this.task,
    required this.projectRepository,
    this.onAutoSave,
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
  bool _hasChanges = false;
  bool _allowPop = false;
  bool _isClosing = false;
  Timer? _autoSaveTimer;

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
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _markChanged() {
    _hasChanges = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 700), _saveChanges);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closePage();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('编辑任务')),
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
                onChanged: (_) => _markChanged(),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '请输入标题' : null,
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Project>>(
                future: _projectsFuture,
                builder: (context, snapshot) {
                  final projects = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedProjectId,
                    decoration: const InputDecoration(
                      labelText: '所属项目',
                      border: OutlineInputBorder(),
                    ),
                    items: projects
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      int.parse(
                                        p.color.replaceFirst('#', '0xFF'),
                                      ),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(p.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(
                        () => _selectedProjectId = v ?? _selectedProjectId,
                      );
                      _markChanged();
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('优先级', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [(0, '无'), (1, '低'), (3, '中'), (5, '高')]
                    .map(
                      (p) => ChoiceChip(
                        label: Text(p.$2),
                        selected: _priority == p.$1,
                        onSelected: (v) {
                          setState(() => _priority = p.$1);
                          _markChanged();
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: '开始时间',
                      date: _startDate,
                      onTap: () => _pickDateTime(true),
                      onClear: () {
                        setState(() => _startDate = null);
                        _markChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: '截止时间',
                      date: _dueDate,
                      onTap: () => _pickDateTime(false),
                      onClear: () {
                        setState(() => _dueDate = null);
                        _markChanged();
                      },
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
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  alignLabelWithHint: true,
                ),
                minLines: 6,
                maxLines: 12,
                onChanged: (_) => _markChanged(),
              ),
            ],
          ),
        ),
      ),
    );
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
    _markChanged();
  }

  Future<void> _closePage() async {
    if (_isClosing) return;
    _isClosing = true;
    _autoSaveTimer?.cancel();
    final hadChanges = _hasChanges;
    final saved = _saveChanges(showErrors: true);
    if (!saved) {
      _isClosing = false;
      return;
    }

    if (!mounted) return;
    setState(() => _allowPop = true);
    if (widget.onAutoSave == null && hadChanges) {
      Navigator.pop(context, _payload());
    } else {
      Navigator.pop(context);
    }
  }

  bool _saveChanges({bool showErrors = false}) {
    if (!_hasChanges) return true;
    if (showErrors && !_formKey.currentState!.validate()) return false;
    if (!showErrors && _titleController.text.trim().isEmpty) return false;
    if (_startDate == null) {
      if (showErrors) {
        showAppSnackBar(context, '请选择开始时间');
      }
      return false;
    }
    if (_dueDate == null) {
      if (showErrors) {
        showAppSnackBar(context, '请选择截止时间');
      }
      return false;
    }
    if (!_dueDate!.isAfter(_startDate!)) {
      if (showErrors) {
        showAppSnackBar(context, '截止时间必须晚于开始时间');
      }
      return false;
    }

    if (widget.onAutoSave == null) return true;

    widget.onAutoSave!.call(_payload());
    _hasChanges = false;
    return true;
  }

  Map<String, dynamic> _payload() {
    return {
      'title': _titleController.text.trim(),
      'projectId': _selectedProjectId,
      'description': _descController.text.trim(),
      'priority': _priority,
      'startDate': _startDate!.millisecondsSinceEpoch,
      'dueDate': _dueDate!.millisecondsSinceEpoch,
    };
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
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textHint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null
                        ? '${date!.month}/${date!.day} '
                              '${date!.hour.toString().padLeft(2, '0')}:${date!.minute.toString().padLeft(2, '0')}'
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
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: AppTheme.textHint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
