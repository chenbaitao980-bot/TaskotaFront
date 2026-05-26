import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database/app_database.dart';
import '../../../blocs/task_new/task_bloc.dart';
import '../../../blocs/task_new/task_event.dart';
import '../../../blocs/task_new/task_state.dart';
import '../../../widgets/calendar_date_picker.dart';
import 'widgets/checklist_section.dart';
import 'widgets/subtask_tree_section.dart';

class TaskDetailPage extends StatefulWidget {
  final Task task;

  const TaskDetailPage({super.key, required this.task});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  late int _priority;
  late String _selectedProjectId;
  late int _status;
  late int _savedStatus;
  List<ChecklistItem> _checklistItems = [];
  bool _hasChanges = false;
  bool _allowPop = false;
  bool _isClosing = false;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t.title);
    _descController = TextEditingController(text: t.description);
    _startDateTime = t.startDate != null
        ? DateTime.fromMillisecondsSinceEpoch(t.startDate!)
        : DateTime.now();
    _endDateTime = t.dueDate != null
        ? DateTime.fromMillisecondsSinceEpoch(t.dueDate!)
        : _startDateTime.add(const Duration(hours: 1));
    _priority = t.priority;
    _selectedProjectId = t.projectId;
    _status = t.status;
    _savedStatus = t.status;
    _loadChecklist();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _loadChecklist() {
    context.read<TaskNewBloc>().add(LoadChecklistItems(taskId: widget.task.id));
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 700), _saveTask);
  }

  void _refreshTaskList() {
    final state = context.read<TaskNewBloc>().state;
    context.read<TaskNewBloc>().add(
      LoadTasks(
        projectId: state is TaskNewLoaded ? state.selectedProjectId : null,
        filter: state is TaskNewLoaded ? state.selectedFilter : null,
      ),
    );
  }

  Future<void> _closePage() async {
    if (_isClosing) return;
    _isClosing = true;
    _autoSaveTimer?.cancel();

    final canClose = _saveTask(showErrors: true);
    if (!canClose) {
      _isClosing = false;
      return;
    }

    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TaskNewBloc>();
    final state = bloc.state;
    final projects = state is TaskNewLoaded ? state.projects : <Project>[];

    return BlocListener<TaskNewBloc, TaskNewState>(
      listener: (context, state) {
        if (state is TaskNewLoaded) {
          final items = state.checklistItems[widget.task.id] ?? [];
          if (items != _checklistItems) {
            setState(() => _checklistItems = items);
          }
        }
      },
      child: PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            _refreshTaskList();
          } else {
            _closePage();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _closePage,
            ),
            title: Text(
              '编辑任务',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outlined, color: AppTheme.error),
                onPressed: _deleteTask,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              // 标题 — 可编辑
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: TextFormField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (_) => _markChanged(),
                ),
              ),
              const SizedBox(height: 4),
              // 状态切换
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _status = _status == 2 ? 0 : 2;
                        });
                        _markChanged();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _status == 2
                              ? AppTheme.success.withValues(alpha: 0.1)
                              : AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _status == 2
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 16,
                              color: _status == 2
                                  ? AppTheme.success
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _status == 2 ? '已完成' : '待完成',
                              style: TextStyle(
                                fontSize: 13,
                                color: _status == 2
                                    ? AppTheme.success
                                    : AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 项目、优先级、日期 — 全部可编辑
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    // 项目
                    _dropdownTile(
                      icon: Icons.folder_outlined,
                      label: '项目',
                      value: _selectedProjectId,
                      items: projects
                          .map(
                            (p) => DropdownMenuItem<String>(
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
                        setState(() => _selectedProjectId = v);
                        _markChanged();
                      },
                    ),
                    _divider(),
                    // 优先级
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flag_outlined,
                            size: 18,
                            color: AppTheme.textHint,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '优先级',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          _priorityChip(0, '无'),
                          const SizedBox(width: 6),
                          _priorityChip(1, '低'),
                          const SizedBox(width: 6),
                          _priorityChip(3, '中'),
                          const SizedBox(width: 6),
                          _priorityChip(5, '高'),
                        ],
                      ),
                    ),
                    _divider(),
                    // 开始时间
                    _dateTile(
                      icon: Icons.calendar_today,
                      label: '开始时间',
                      dateTime: _startDateTime,
                      onTap: () => _pickDateTime(true),
                    ),
                    _divider(),
                    // 截止时间
                    _dateTile(
                      icon: Icons.event,
                      label: '截止时间',
                      dateTime: _endDateTime,
                      onTap: () => _pickDateTime(false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 描述 — 可编辑
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: '添加描述...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (_) => _markChanged(),
                ),
              ),
              const SizedBox(height: 16),
              // 子任务树
              SubtaskTreeSection(
                task: widget.task,
                projectId: _selectedProjectId,
              ),
              const SizedBox(height: 16),
              // 检查项
              ChecklistSection(
                items: _checklistItems,
                taskId: widget.task.id,
                onToggle: (id) {
                  context.read<TaskNewBloc>().add(
                    ToggleChecklistItem(id: id, taskId: widget.task.id),
                  );
                },
                onDelete: (id) {
                  context.read<TaskNewBloc>().add(
                    DeleteChecklistItem(id: id, taskId: widget.task.id),
                  );
                },
                onEdit: (id, title) {
                  context.read<TaskNewBloc>().add(
                    UpdateChecklistItem(id: id, title: title),
                  );
                },
                onAdd: (data) {
                  final (taskId, title) = data;
                  context.read<TaskNewBloc>().add(
                    AddChecklistItem(taskId: taskId, title: title),
                  );
                },
                onSetObsidianUri: (id, obsidianUri) {
                  context.read<TaskNewBloc>().add(
                    SetChecklistItemObsidianUri(
                      id: id,
                      taskId: widget.task.id,
                      obsidianUri: obsidianUri,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle);

  Widget _dropdownTile({
    required IconData icon,
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textHint),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              isDense: true,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              icon: const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: AppTheme.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateTile({
    required IconData icon,
    required String label,
    required DateTime dateTime,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textHint),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              _dateTimeLabel(dateTime),
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _priorityChip(int value, String label) {
    final isSelected = _priority == value;
    Color chipColor;
    switch (value) {
      case 5:
        chipColor = AppTheme.priorityP0;
        break;
      case 3:
        chipColor = AppTheme.priorityP1;
        break;
      case 1:
        chipColor = AppTheme.priorityP3;
        break;
      default:
        chipColor = AppTheme.textHint;
    }
    return GestureDetector(
      onTap: () {
        setState(() => _priority = value);
        _markChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? chipColor : AppTheme.borderSubtle,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? chipColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  String _dateTimeLabel(DateTime dt) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final wd = weekdays[dt.weekday - 1];
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    return '${dt.month}月${dt.day}日 $wd${isToday ? '（今天）' : ''}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDateTime(bool isStart) async {
    final picked = await showCalendarDatePicker(
      context: context,
      initialDate: isStart ? _startDateTime : _endDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDateTime = picked;
          if (_endDateTime.isBefore(_startDateTime)) {
            _endDateTime = _startDateTime.add(const Duration(hours: 1));
          }
        } else {
          _endDateTime = picked;
        }
      });
      _markChanged();
    }
  }

  bool _saveTask({bool showErrors = false}) {
    if (!_hasChanges && _status == _savedStatus) return true;

    if (_titleController.text.trim().isEmpty) {
      if (showErrors) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入任务标题')));
      }
      return false;
    }
    if (!_endDateTime.isAfter(_startDateTime)) {
      if (showErrors) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('截止时间必须晚于开始时间')));
      }
      return false;
    }

    final bloc = context.read<TaskNewBloc>();
    if (_status != _savedStatus) {
      bloc.add(ToggleTaskStatus(id: widget.task.id));
      _savedStatus = _status;
    }
    bloc.add(
      UpdateTask(
        id: widget.task.id,
        title: _titleController.text.trim(),
        projectId: _selectedProjectId,
        description: _descController.text.trim(),
        priority: _priority,
        startDate: _startDateTime.millisecondsSinceEpoch,
        dueDate: _endDateTime.millisecondsSinceEpoch,
      ),
    );
    _hasChanges = false;
    return true;
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除"${_titleController.text}"吗？此操作不可恢复。'),
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
    if (confirm == true && mounted) {
      _autoSaveTimer?.cancel();
      context.read<TaskNewBloc>().add(DeleteTask(id: widget.task.id));
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }
}
