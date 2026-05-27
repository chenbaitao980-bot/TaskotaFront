import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// 提前时间选项
const List<Map<String, dynamic>> _remindBeforeOptions = [
  {'label': '5 分钟', 'value': 5},
  {'label': '10 分钟', 'value': 10},
  {'label': '15 分钟', 'value': 15},
  {'label': '30 分钟', 'value': 30},
  {'label': '1 小时', 'value': 60},
  {'label': '2 小时', 'value': 120},
  {'label': '1 天', 'value': 1440},
];

/// 重复间隔选项
const List<Map<String, dynamic>> _repeatIntervalOptions = [
  {'label': '每 5 分钟', 'value': 5},
  {'label': '每 10 分钟', 'value': 10},
  {'label': '每 15 分钟', 'value': 15},
  {'label': '每 30 分钟', 'value': 30},
  {'label': '每 1 小时', 'value': 60},
];

class CreateScheduleDialog extends StatefulWidget {
  final String? initialTitle;
  final DateTime? initialDate;
  final DateTime? initialStartTime;
  final DateTime? initialEndTime;
  final String? initialPriority;
  final bool isEditing;

  // 提醒相关初始值（编辑时使用）
  final int? initialRemindBeforeMinutes;
  final bool? initialReminderEnabled;
  final bool? initialIsRepeating;
  final int? initialRepeatInterval;

  const CreateScheduleDialog({
    super.key,
    this.initialTitle,
    this.initialDate,
    this.initialStartTime,
    this.initialEndTime,
    this.initialPriority,
    this.isEditing = false,
    this.initialRemindBeforeMinutes,
    this.initialReminderEnabled,
    this.initialIsRepeating,
    this.initialRepeatInterval,
  });

  @override
  State<CreateScheduleDialog> createState() => _CreateScheduleDialogState();
}

class _CreateScheduleDialogState extends State<CreateScheduleDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String _priority;

  // 提醒状态
  late bool _reminderEnabled;
  late int _remindBeforeMinutes;
  late bool _isRepeating;
  late int? _repeatInterval;

  @override
  void initState() {
    super.initState();
    final initialStart =
        widget.initialStartTime ??
        DateTime(
          widget.initialDate?.year ?? DateTime.now().year,
          widget.initialDate?.month ?? DateTime.now().month,
          widget.initialDate?.day ?? DateTime.now().day,
          DateTime.now().hour,
          DateTime.now().minute,
        );
    final initialEnd =
        widget.initialEndTime ?? initialStart.add(const Duration(hours: 1));

    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _descController = TextEditingController();
    _startDate = DateTime(
      initialStart.year,
      initialStart.month,
      initialStart.day,
    );
    _endDate = DateTime(initialEnd.year, initialEnd.month, initialEnd.day);
    _startTime = TimeOfDay.fromDateTime(initialStart);
    _endTime = TimeOfDay.fromDateTime(initialEnd);
    _priority = widget.initialPriority ?? 'P2';

    // 提醒初始化：编辑时有初始值，新建时用默认值
    _reminderEnabled = widget.initialReminderEnabled ?? true;
    _remindBeforeMinutes = widget.initialRemindBeforeMinutes ?? 15;
    _isRepeating = widget.initialIsRepeating ?? false;
    _repeatInterval = widget.initialRepeatInterval;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  DateTime get startDateTime => DateTime(
    _startDate.year,
    _startDate.month,
    _startDate.day,
    _startTime.hour,
    _startTime.minute,
  );

  DateTime get endDateTime => DateTime(
    _endDate.year,
    _endDate.month,
    _endDate.day,
    _endTime.hour,
    _endTime.minute,
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.isEditing ? Icons.edit_outlined : Icons.add,
              size: 20,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.isEditing ? '编辑日程' : '新建日程',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // ── 标题 ──
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '输入日程标题',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              // ── 描述 ──
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: '描述（可选）',
                  hintText: '添加描述',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              // ── 时间区块 ──
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgInput.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _tile(
                      Icons.calendar_today,
                      '开始日期',
                      _dateLabel(_startDate),
                      () => _pickDate(isStart: true),
                    ),
                    const Divider(
                      height: 0.5,
                      indent: 52,
                      color: AppTheme.borderSubtle,
                    ),
                    _tile(
                      Icons.access_time,
                      '开始时间',
                      _timeLabel(_startTime),
                      () => _pickTime(isStart: true),
                    ),
                    const Divider(
                      height: 0.5,
                      indent: 52,
                      color: AppTheme.borderSubtle,
                    ),
                    _tile(
                      Icons.event_available,
                      '结束日期',
                      _dateLabel(_endDate),
                      () => _pickDate(isStart: false),
                    ),
                    const Divider(
                      height: 0.5,
                      indent: 52,
                      color: AppTheme.borderSubtle,
                    ),
                    _tile(
                      Icons.access_time_filled,
                      '结束时间',
                      _timeLabel(_endTime),
                      () => _pickTime(isStart: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // ── 优先级 ──
              Row(
                children: [
                  const Text(
                    '优先级',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _priorityChip('P0', '紧急', AppTheme.priorityP0),
                        _priorityChip('P1', '重要', AppTheme.priorityP1),
                        _priorityChip('P2', '普通', AppTheme.priorityP2),
                        _priorityChip('P3', '低', AppTheme.priorityP3),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ── 提醒设置区块 ──
              _buildReminderSection(),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.isEditing)
          TextButton.icon(
            onPressed: () => Navigator.pop(context, 'add_subtask'),
            icon: const Icon(Icons.add_task_rounded, size: 18),
            label: const Text('添加子任务'),
          ),
        if (widget.isEditing)
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }

  /// 提醒配置 UI
  Widget _buildReminderSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgInput.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // ── 启用提醒 ──
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            isThreeLine: true,
            secondary: Icon(
              Icons.notifications_active,
              size: 20,
              color: _reminderEnabled
                  ? AppTheme.primaryColor
                  : AppTheme.textHint,
            ),
            title: const Text(
              '启用提醒',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              _reminderEnabled ? '将在日程开始前通知您' : '不会发送提醒',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            value: _reminderEnabled,
            onChanged: (v) => setState(() => _reminderEnabled = v),
          ),
          if (_reminderEnabled) ...[
            const Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            // ── 提前时间选择 ──
            _buildDropdownTile(
              icon: Icons.timer_outlined,
              label: '提前提醒',
              value: _remindBeforeMinutes,
              options: _remindBeforeOptions,
              onChanged: (v) => setState(() => _remindBeforeMinutes = v),
            ),
            const Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            // ── 重复/一次性 ──
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              isThreeLine: true,
              secondary: Icon(
                Icons.repeat,
                size: 20,
                color: _isRepeating
                    ? AppTheme.warning
                    : AppTheme.textHint,
              ),
              title: const Text(
                '重复提醒',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                _isRepeating ? '将按间隔重复提醒直到您处理' : '仅提醒一次',
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              value: _isRepeating,
              onChanged: (v) => setState(() => _isRepeating = v),
            ),
            if (_isRepeating) ...[
              const Divider(
                  height: 0.5, indent: 52, color: AppTheme.borderSubtle),
              _buildDropdownTile(
                icon: Icons.hourglass_bottom,
                label: '重复间隔',
                value: _repeatInterval ?? 5,
                options: _repeatIntervalOptions,
                onChanged: (v) => setState(() => _repeatInterval = v),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// 带下拉菜单的 ListTile
  Widget _buildDropdownTile({
    required IconData icon,
    required String label,
    required int value,
    required List<Map<String, dynamic>> options,
    required ValueChanged<int> onChanged,
  }) {
    final selectedLabel =
        options.firstWhere((o) => o['value'] == value)['label'] as String;
    return ListTile(
      minVerticalPadding: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, size: 20, color: AppTheme.primaryColor),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      ),
      subtitle: Text(
        selectedLabel,
        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      ),
      trailing: const Icon(
        Icons.arrow_drop_down,
        size: 20,
        color: AppTheme.textHint,
      ),
      onTap: () => _showDropdownPicker(
        label: label,
        value: value,
        options: options,
        onChanged: onChanged,
      ),
    );
  }

  /// 弹出下拉选择器
  void _showDropdownPicker({
    required String label,
    required int value,
    required List<Map<String, dynamic>> options,
    required ValueChanged<int> onChanged,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(label),
        children: options.map((opt) {
          final optValue = opt['value'] as int;
          final optLabel = opt['label'] as String;
          return RadioListTile<int>(
            title: Text(optLabel),
            value: optValue,
            groupValue: value,
            onChanged: (v) {
              if (v != null) {
                onChanged(v);
                Navigator.pop(ctx);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (endDateTime.isBefore(
          startDateTime.add(const Duration(minutes: 15)),
        )) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
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
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }
    if (!endDateTime.isAfter(startDateTime.add(const Duration(minutes: 14)))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('结束时间必须晚于开始时间至少 15 分钟')));
      return;
    }
    Navigator.pop(context, {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      'startTime': startDateTime,
      'endTime': endDateTime,
      'priority': _priority,
      // 提醒字段
      'reminderEnabled': _reminderEnabled,
      'remindBeforeMinutes': _remindBeforeMinutes,
      'isRepeating': _isRepeating,
      'repeatInterval': _isRepeating ? _repeatInterval : null,
      'reminderType': _isRepeating ? 'repeat' : 'once',
    });
  }

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _timeLabel(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Widget _tile(IconData icon, String label, String value, VoidCallback onTap) {
    return ListTile(
      minVerticalPadding: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, size: 20, color: AppTheme.primaryColor),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: AppTheme.textHint,
      ),
      onTap: onTap,
    );
  }

  Widget _priorityChip(String value, String label, Color color) {
    final selected = _priority == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : color,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      onSelected: (s) {
        if (s) setState(() => _priority = value);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
