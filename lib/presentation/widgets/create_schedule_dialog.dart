import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';
import 'calendar_date_picker.dart';

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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late DateTime _startDate;
  late DateTime _endDate;
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
      initialStart.hour,
      initialStart.minute,
    );
    _endDate = DateTime(
      initialEnd.year,
      initialEnd.month,
      initialEnd.day,
      initialEnd.hour,
      initialEnd.minute,
    );
    _priority = widget.initialPriority ?? 'P2';

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

  DateTime get startDateTime => _startDate;
  DateTime get endDateTime => _endDate;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 拖拽手柄
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
                // 标题
                Text(
                  widget.isEditing ? '编辑日程' : '新建日程',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                // ── 日程标题 ──
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '日程标题',
                    hintText: '输入日程名称',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请输入标题' : null,
                ),
                const SizedBox(height: 12),
                // ── 描述 ──
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: '描述（选填）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                // ── 开始时间 / 结束时间 ──
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
                        label: '结束时间',
                        date: _endDate,
                        onTap: () => _pickDateTime(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── 优先级 ──
                Row(
                  children: [
                    const Text('优先级：', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    ..._buildPriorityChips(),
                  ],
                ),
                const SizedBox(height: 12),
                // ── 提醒设置 ──
                _buildReminderSection(),
                const SizedBox(height: 12),
                // ── 操作按钮 ──
                if (widget.isEditing) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.pop(context, 'add_subtask'),
                          icon:
                              const Icon(Icons.add_task_rounded, size: 18),
                          label: const Text('添加子任务'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context, 'delete'),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('删除'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('保存', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
            secondary: Icon(
              Icons.notifications_active,
              size: 20,
              color: _reminderEnabled
                  ? AppTheme.primaryColor
                  : AppTheme.textHint,
            ),
            title: Text(
              '启用提醒',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              _reminderEnabled ? '将在日程开始前通知您' : '不会发送提醒',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            value: _reminderEnabled,
            onChanged: (v) => setState(() => _reminderEnabled = v),
          ),
          if (_reminderEnabled) ...[
            const Divider(height: 1, indent: 52),
            // ── 提前时间选择 ──
            _buildDropdownTile(
              icon: Icons.timer_outlined,
              label: '提前提醒',
              value: _remindBeforeMinutes,
              options: _remindBeforeOptions,
              onChanged: (v) => setState(() => _remindBeforeMinutes = v),
            ),
            const Divider(height: 1, indent: 52),
            // ── 重复/一次性 ──
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: Icon(
                Icons.repeat,
                size: 20,
                color: _isRepeating ? AppTheme.warning : AppTheme.textHint,
              ),
              title: Text(
                '重复提醒',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                _isRepeating ? '将按间隔重复提醒直到您处理' : '仅提醒一次',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              value: _isRepeating,
              onChanged: (v) => setState(() => _isRepeating = v),
            ),
            if (_isRepeating) ...[
              const Divider(height: 1, indent: 52),
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
        style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      ),
      subtitle: Text(
        selectedLabel,
        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      ),
      trailing: Icon(Icons.arrow_drop_down, size: 20, color: AppTheme.textHint),
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

  List<Widget> _buildPriorityChips() {
    final priorities = [
      ('P0', '紧急', AppTheme.priorityP0),
      ('P1', '重要', AppTheme.priorityP1),
      ('P2', '普通', AppTheme.priorityP2),
      ('P3', '低', AppTheme.priorityP3),
    ];
    return priorities.map((p) {
      final isSelected = _priority == p.$1;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(p.$2, style: const TextStyle(fontSize: 12)),
          selected: isSelected,
          onSelected: (v) => setState(() => _priority = p.$1),
          selectedColor: p.$3,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
          visualDensity: VisualDensity.compact,
        ),
      );
    }).toList();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showCalendarDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate.add(const Duration(minutes: 15)))) {
          _endDate = picked.add(const Duration(hours: 1));
        }
      } else {
        _endDate = picked;
      }
    });
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      showAppSnackBar(context, '请输入标题');
      return;
    }
    if (!_endDate.isAfter(_startDate.add(const Duration(minutes: 14)))) {
      showAppSnackBar(context, '结束时间必须晚于开始时间至少 15 分钟');
      return;
    }
    Navigator.pop(context, {
      'title': _titleController.text.trim(),
      'description':
          _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      'startTime': startDateTime,
      'endTime': endDateTime,
      'priority': _priority,
      'reminderEnabled': _reminderEnabled,
      'remindBeforeMinutes': _remindBeforeMinutes,
      'isRepeating': _isRepeating,
      'repeatInterval': _isRepeating ? _repeatInterval : null,
      'reminderType': _isRepeating ? 'repeat' : 'once',
    });
  }
}

/// 日期时间选择按钮（对齐 TaskCreateSheet 的 _DateButton 风格）
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
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.textHint),
            ),
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
