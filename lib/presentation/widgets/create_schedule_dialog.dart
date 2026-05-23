import 'package:flutter/material.dart';

class CreateScheduleDialog extends StatefulWidget {
  final String? initialTitle;
  final DateTime? initialDate;
  final DateTime? initialStartTime;
  final DateTime? initialEndTime;
  final String? initialPriority;
  final bool isEditing;

  const CreateScheduleDialog({
    super.key,
    this.initialTitle,
    this.initialDate,
    this.initialStartTime,
    this.initialEndTime,
    this.initialPriority,
    this.isEditing = false,
  });

  @override
  State<CreateScheduleDialog> createState() => _CreateScheduleDialogState();
}

class _CreateScheduleDialogState extends State<CreateScheduleDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String _priority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _descController = TextEditingController();
    _date = widget.initialDate ?? DateTime.now();
    _startTime = widget.initialStartTime != null
        ? TimeOfDay.fromDateTime(widget.initialStartTime!)
        : TimeOfDay.fromDateTime(DateTime.now());
    _endTime = widget.initialEndTime != null
        ? TimeOfDay.fromDateTime(widget.initialEndTime!)
        : TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
    _priority = widget.initialPriority ?? 'P2';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  DateTime get startDateTime => DateTime(
        _date.year, _date.month, _date.day, _startTime.hour, _startTime.minute);

  DateTime get endDateTime => DateTime(
        _date.year, _date.month, _date.day, _endTime.hour, _endTime.minute);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? '编辑日程' : '新建日程'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '输入日程标题',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                hintText: '添加描述',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('日期'),
              subtitle: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: const Text('开始时间'),
              subtitle: Text(_startTime.format(context)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _startTime,
                );
                if (picked != null) setState(() => _startTime = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time_filled),
              title: const Text('结束时间'),
              subtitle: Text(_endTime.format(context)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _endTime,
                );
                if (picked != null) setState(() => _endTime = picked);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('优先级: '),
                const SizedBox(width: 8),
                _priorityChip('P0', '紧急', Colors.red),
                _priorityChip('P1', '重要', Colors.orange),
                _priorityChip('P2', '普通', Colors.green),
                _priorityChip('P3', '低', Colors.blue),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (_titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入标题')),
              );
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
            });
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _priorityChip(String value, String label, Color color) {
    final selected = _priority == value;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
        selected: selected,
        selectedColor: color,
        onSelected: (s) {
          if (s) setState(() => _priority = value);
        },
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
