import 'package:flutter/material.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({super.key});

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));
  String _priority = 'P2';
  bool _focusRequired = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startTime : _endTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          isStart ? _startTime : _endTime,
        ),
      );

      if (time != null) {
        setState(() {
          final newDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          if (isStart) {
            _startTime = newDateTime;
          } else {
            _endTime = newDateTime;
          }
        });
      }
    }
  }

  void _saveTask() {
    // TODO: 保存任务到数据库
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新建任务'),
        actions: [
          TextButton(
            onPressed: _saveTask,
            child: const Text('保存'),
          ),
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
            Text(
              '时间',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('开始时间'),
              subtitle: Text(_formatDateTime(_startTime)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectDateTime(true),
            ),
            ListTile(
              leading: const Icon(Icons.access_time_filled),
              title: const Text('结束时间'),
              subtitle: Text(_formatDateTime(_endTime)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectDateTime(false),
            ),
            const SizedBox(height: 24),
            Text(
              '优先级',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
              onChanged: (value) {
                setState(() {
                  _focusRequired = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String value, String label, Color color) {
    final isSelected = _priority == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _priority = value;
          });
        }
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
