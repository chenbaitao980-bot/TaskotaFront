import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/entities/task_breakdown.dart';
import '../../../services/local_storage_service.dart';
import '../../blocs/auth/auth_bloc.dart';

class CreateTaskPage extends StatefulWidget {
  final TaskBreakdown? existingTask;
  final TaskBreakdown? parentTask;
  final String? parentScheduleId;
  final String? initialTitle;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const CreateTaskPage({
    super.key,
    this.existingTask,
    this.parentTask,
    this.parentScheduleId,
    this.initialTitle,
    this.initialStartDate,
    this.initialEndDate,
  });

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
  late bool _isParent;
  String? _parentTaskId;
  String? _parentTaskName;
  bool _isEditing = false;
  final LocalStorageService _storage = LocalStorageService();

  TimeOfDay get _startTime => TimeOfDay.fromDateTime(_startDate);
  TimeOfDay get _endTime => TimeOfDay.fromDateTime(_endDate);

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingTask != null;
    if (_isEditing) {
      final t = widget.existingTask!;
      _titleController.text = t.title;
      _descriptionController.text = t.description ?? '';
      _startDate = t.startDate ?? DateTime.now();
      _endDate = t.endDate ?? _defaultEndDate(_startDate);
      _priority = t.priority;
      _focusRequired = t.focusRequired;
      _isParent = t.isParent;
    } else {
      _titleController.text = widget.initialTitle ?? '';
      _startDate = widget.initialStartDate ?? DateTime.now();
      _endDate = _defaultEndDate(_startDate, widget.initialEndDate);
      _priority = 'P2';
      _focusRequired = false;
      _isParent = false;
    }
    // 初始化父任务信息
    if (_isEditing && widget.existingTask!.parentTaskId != null) {
      _parentTaskId = widget.existingTask!.parentTaskId;
    } else if (widget.parentTask != null) {
      _parentTaskId = widget.parentTask!.id;
    }
    _storage.init().then((_) {
      if (_parentTaskId != null) {
        final p = _storage.getTasks().where((t) => t.id == _parentTaskId).firstOrNull;
        if (mounted) setState(() => _parentTaskName = p?.title);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectParentTask() async {
    final allTasks = _storage.getTasks(excludeParent: true);
    final selected = await showDialog<Object?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择父任务'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: allTasks.isEmpty
              ? const Center(child: Text('没有可选的任务'))
              : ListView.builder(
                  itemCount: allTasks.length,
                  itemBuilder: (context, index) {
                    final t = allTasks[index];
                    return ListTile(
                      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(t.status == 'completed' ? '已完成' : '待办'),
                      selected: t.id == _parentTaskId,
                      onTap: () => Navigator.pop(context, t),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          if (_parentTaskId != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'clear'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text('清除父任务'),
            ),
        ],
      ),
    );
    if (selected is String && selected == 'clear') {
      setState(() {
        _parentTaskId = null;
        _parentTaskName = null;
      });
    } else if (selected is TaskBreakdown) {
      setState(() {
        _parentTaskId = selected.id;
        _parentTaskName = selected.title;
      });
    }
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
          _startDate = _combineDateTime(date, _startTime);
        } else {
          _endDate = _combineDateTime(date, _endTime);
        }
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = _combineDateTime(_startDate, picked);
        } else {
          _endDate = _combineDateTime(_endDate, picked);
        }
      });
    }
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  DateTime _defaultEndDate(DateTime start, [DateTime? preferredEnd]) {
    if (preferredEnd != null &&
        _isSameDate(start, preferredEnd) &&
        preferredEnd.isAfter(start)) {
      return preferredEnd;
    }
    return start.add(const Duration(hours: 1));
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入任务标题')));
      return;
    }
    if (!_endDate.isAfter(_startDate)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('结束时间必须晚于开始时间')));
      return;
    }

    // 非父任务：检测时间冲突
    if (!_isParent) {
      final conflict = _storage.detectTaskTimeConflict(
        _startDate,
        _endDate,
        excludeId: widget.existingTask?.id,
      );
      if (conflict) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('时间冲突'),
            content: const Text('该时间段与已有日程或其他任务重叠，是否仍然保存？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('仍然保存'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    if (_isEditing) {
      final updated = widget.existingTask!.copyWith(
        title: title,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        priority: _priority,
        focusRequired: _focusRequired,
        isParent: _isParent,
        parentTaskId: _parentTaskId,
      );
      await _storage.updateTask(updated);
    } else {
      await _storage.createTask(
        userId: _getUserId(),
        title: title,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        level: _isParent
            ? 'task'
            : (_parentTaskId != null || widget.parentScheduleId != null
                  ? 'subtask'
                  : 'task'),
        startDate: _startDate,
        endDate: _endDate,
        priority: _priority,
        parentTaskId: _parentTaskId,
        parentScheduleId: widget.parentScheduleId,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? '编辑任务'
              : (widget.parentTask == null && widget.parentScheduleId == null
                    ? '新建任务'
                    : '新建子任务'),
        ),
        actions: [
          TextButton(
            onPressed: _saveTask,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '任务标题',
                hintText: '输入任务标题',
              ),
            ),
            const SizedBox(height: 16),
            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '添加任务描述（可选）',
              ),
            ),
            const SizedBox(height: 16),

            // Parent Task （滴答清单风格）
            Text('所属父任务', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.cardShadow,
              ),
              child: ListTile(
                leading: Icon(
                  _parentTaskId != null
                      ? Icons.account_tree_outlined
                      : Icons.link_off,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
                title: Text(
                  _parentTaskName ?? '无父任务',
                  style: TextStyle(
                    fontSize: 14,
                    color: _parentTaskId != null
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                    fontWeight: _parentTaskId != null
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_parentTaskId != null)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _parentTaskId = null;
                            _parentTaskName = null;
                          });
                        },
                        child: Icon(Icons.close, size: 18, color: AppTheme.textHint),
                      ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 20, color: AppTheme.textHint),
                  ],
                ),
                onTap: _selectParentTask,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Date section
            Text('日期范围', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  _datePickerTile(
                    Icons.calendar_today,
                    '开始日期',
                    _startDate,
                    () => _selectDate(true),
                  ),
                  const Divider(
                    height: 0.5,
                    indent: 52,
                    color: AppTheme.borderSubtle,
                  ),
                  _timePickerTile(
                    Icons.access_time,
                    '开始时间',
                    _startDate,
                    () => _selectTime(true),
                  ),
                  const Divider(
                    height: 0.5,
                    indent: 52,
                    color: AppTheme.borderSubtle,
                  ),
                  _datePickerTile(
                    Icons.event,
                    '截止日期',
                    _endDate,
                    () => _selectDate(false),
                  ),
                  const Divider(
                    height: 0.5,
                    indent: 52,
                    color: AppTheme.borderSubtle,
                  ),
                  _timePickerTile(
                    Icons.access_time_filled,
                    '结束时间',
                    _endDate,
                    () => _selectTime(false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Priority
            Text('优先级', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildPriorityChip('P0', '紧急', AppTheme.priorityP0),
                _buildPriorityChip('P1', '重要', AppTheme.priorityP1),
                _buildPriorityChip('P2', '普通', AppTheme.priorityP2),
                _buildPriorityChip('P3', '低', AppTheme.priorityP3),
              ],
            ),
            const SizedBox(height: 28),

            // 任务类型
            Text('任务类型', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.cardShadow,
              ),
              child: SwitchListTile(
                title: const Text(
                  '标记为父任务（容器）',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  '父任务不出现在日历时间线上',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                value: _isParent,
                onChanged: (value) => setState(() => _isParent = value),
                activeThumbColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Focus switch
            Container(
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.cardShadow,
              ),
              child: SwitchListTile(
                title: const Text(
                  '需要专注',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  '此任务需要全神贯注完成',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                value: _focusRequired,
                onChanged: (value) => setState(() => _focusRequired = value),
                activeThumbColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePickerTile(
    IconData icon,
    String label,
    DateTime date,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      ),
      subtitle: Text(
        _dateLabel(date),
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: AppTheme.textHint,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _timePickerTile(
    IconData icon,
    String label,
    DateTime date,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      ),
      subtitle: Text(
        _timeLabel(date),
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: AppTheme.textHint,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Widget _buildPriorityChip(String value, String label, Color color) {
    final selected = _priority == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? color : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.12),
      backgroundColor: AppTheme.bgInput,
      side: BorderSide(
        color: selected ? color : AppTheme.borderSubtle,
        width: selected ? 1.5 : 0.5,
      ),
      onSelected: (s) {
        if (s) setState(() => _priority = value);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
