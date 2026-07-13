import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class LazyLogProjectOption {
  final String id;
  final String name;

  const LazyLogProjectOption({required this.id, required this.name});
}

class LazyLogParentOption {
  final String id;
  final String title;
  final String? projectId;

  const LazyLogParentOption({
    required this.id,
    required this.title,
    this.projectId,
  });
}

class LazyLogTaskEdit {
  final String title;
  final String description;
  final String priority;
  final List<String> checklist;
  final List<PlatformFile> attachments;
  final DateTime start;
  final DateTime end;

  const LazyLogTaskEdit({
    required this.title,
    required this.description,
    required this.priority,
    this.checklist = const [],
    this.attachments = const [],
    required this.start,
    required this.end,
  });

  LazyLogTaskEdit copyWith({
    String? title,
    String? description,
    String? priority,
    List<String>? checklist,
    List<PlatformFile>? attachments,
    DateTime? start,
    DateTime? end,
  }) {
    return LazyLogTaskEdit(
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      checklist: checklist ?? this.checklist,
      attachments: attachments ?? this.attachments,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}

class LazyLogCreationPlan {
  final String? projectId;
  final String? parentTaskId;
  final String parentTitle;
  final List<LazyLogTaskEdit> tasks;

  const LazyLogCreationPlan({
    this.projectId,
    this.parentTaskId,
    this.parentTitle = '',
    required this.tasks,
  });

  bool get createParent =>
      parentTaskId == null && parentTitle.trim().isNotEmpty;

  LazyLogCreationPlan copyWith({
    String? projectId,
    bool clearProjectId = false,
    String? parentTaskId,
    bool clearParentTaskId = false,
    String? parentTitle,
    List<LazyLogTaskEdit>? tasks,
  }) {
    return LazyLogCreationPlan(
      projectId: clearProjectId ? null : projectId ?? this.projectId,
      parentTaskId: clearParentTaskId
          ? null
          : parentTaskId ?? this.parentTaskId,
      parentTitle: parentTitle ?? this.parentTitle,
      tasks: tasks ?? this.tasks,
    );
  }
}

class LazyLogCreationDialog extends StatefulWidget {
  final String summary;
  final List<String> completed;
  final List<String> blockers;
  final List<String> nextActions;
  final bool usedFallback;
  final LazyLogCreationPlan initialPlan;
  final List<LazyLogProjectOption> projects;
  final List<LazyLogParentOption> parents;

  const LazyLogCreationDialog({
    super.key,
    required this.summary,
    required this.completed,
    required this.blockers,
    required this.nextActions,
    required this.usedFallback,
    required this.initialPlan,
    required this.projects,
    required this.parents,
  });

  @override
  State<LazyLogCreationDialog> createState() => _LazyLogCreationDialogState();
}

class _LazyLogCreationDialogState extends State<LazyLogCreationDialog> {
  late LazyLogCreationPlan _plan;
  late final TextEditingController _parentController;
  late final List<TextEditingController> _titleControllers;
  late final List<TextEditingController> _descriptionControllers;
  late final List<TextEditingController> _checklistControllers;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    _parentController = TextEditingController(text: _plan.parentTitle);
    _titleControllers = [
      for (final task in _plan.tasks) TextEditingController(text: task.title),
    ];
    _descriptionControllers = [
      for (final task in _plan.tasks)
        TextEditingController(text: task.description),
    ];
    _checklistControllers = [
      for (final task in _plan.tasks)
        TextEditingController(text: task.checklist.join('\n')),
    ];
  }

  @override
  void dispose() {
    _parentController.dispose();
    for (final controller in _titleControllers) {
      controller.dispose();
    }
    for (final controller in _descriptionControllers) {
      controller.dispose();
    }
    for (final controller in _checklistControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentOptions = _filteredParents();
    final selectedParentId =
        _plan.parentTaskId != null &&
            parentOptions.any((parent) => parent.id == _plan.parentTaskId)
        ? _plan.parentTaskId!
        : '';

    return AlertDialog(
      title: Row(
        children: [
          const Text('确认创建'),
          if (widget.usedFallback) ...[
            const SizedBox(width: 8),
            Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
          ],
        ],
      ),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.summary.trim().isNotEmpty) ...[
                Text(
                  widget.summary,
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
              ],
              _previewSection('进展', widget.completed),
              _previewSection('问题', widget.blockers),
              _previewSection('下一步', widget.nextActions),
              if (widget.projects.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: _projectValue(),
                  decoration: const InputDecoration(
                    labelText: '项目',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: [
                    for (final project in widget.projects)
                      DropdownMenuItem(
                        value: project.id,
                        child: Text(project.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _plan = _plan.copyWith(
                        projectId: value,
                        clearParentTaskId: true,
                      );
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'lazy-parent-${_plan.projectId}-${_plan.parentTaskId ?? ''}',
                ),
                initialValue: selectedParentId,
                decoration: const InputDecoration(
                  labelText: '关联已有父任务',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('不关联已有父任务')),
                  for (final parent in parentOptions)
                    DropdownMenuItem(
                      value: parent.id,
                      child: Text(parent.title),
                    ),
                ],
                onChanged: (value) {
                  final selected = parentOptions
                      .where((parent) => parent.id == value)
                      .firstOrNull;
                  setState(() {
                    _plan = _plan.copyWith(
                      parentTaskId: selected?.id,
                      clearParentTaskId: selected == null,
                      parentTitle: selected == null
                          ? _parentController.text
                          : selected.title,
                    );
                    if (selected != null) {
                      _parentController.text = selected.title;
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _parentController,
                decoration: const InputDecoration(
                  labelText: '新父任务/上下文',
                  prefixIcon: Icon(Icons.edit_note_outlined),
                  helperText: '留空则不创建父任务；选择已有父任务时使用已有父任务',
                ),
                onChanged: (value) {
                  _plan = _plan.copyWith(parentTitle: value.trim());
                },
              ),
              const SizedBox(height: 12),
              Text(
                '将创建任务',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _plan.tasks.length; i++) _taskEditor(i),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _plan.tasks.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _plan.copyWith(parentTitle: _parentController.text.trim()),
                ),
          child: Text(
            '创建 ${_plan.createParent ? _plan.tasks.length + 1 : _plan.tasks.length} 个任务',
          ),
        ),
      ],
    );
  }

  String? _projectValue() {
    if (widget.projects.isEmpty) return null;
    final selected = _plan.projectId;
    if (selected != null &&
        widget.projects.any((project) => project.id == selected)) {
      return selected;
    }
    return widget.projects.first.id;
  }

  List<LazyLogParentOption> _filteredParents() {
    final projectId = _plan.projectId;
    return widget.parents
        .where((parent) => projectId == null || parent.projectId == projectId)
        .toList();
  }

  Widget _previewSection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item'),
            ),
        ],
      ),
    );
  }

  Widget _taskEditor(int index) {
    final task = _plan.tasks[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderSubtle),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _titleControllers[index],
                decoration: const InputDecoration(
                  labelText: '任务标题',
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
                onChanged: (value) {
                  _updateTask(
                    index,
                    _plan.tasks[index].copyWith(title: value.trim()),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionControllers[index],
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '描述',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                onChanged: (value) {
                  _updateTask(
                    index,
                    _plan.tasks[index].copyWith(description: value.trim()),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _checklistControllers[index],
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '检查点',
                  prefixIcon: Icon(Icons.fact_check_outlined),
                  helperText: '每行一个检查点',
                ),
                onChanged: (value) {
                  _updateTask(
                    index,
                    _plan.tasks[index].copyWith(
                      checklist: _splitChecklist(value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text('开始 ${_formatDateTime(task.start)}'),
                      onPressed: () async {
                        final picked = await _pickDateTime(task.start);
                        if (picked == null) return;
                        final current = _plan.tasks[index];
                        final end = current.end.isAfter(picked)
                            ? current.end
                            : picked.add(const Duration(hours: 1));
                        _updateTask(
                          index,
                          current.copyWith(start: picked, end: end),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined),
                      label: Text('结束 ${_formatDateTime(task.end)}'),
                      onPressed: () async {
                        final picked = await _pickDateTime(task.end);
                        if (picked == null) return;
                        final current = _plan.tasks[index];
                        final end = picked.isAfter(current.start)
                            ? picked
                            : current.start.add(const Duration(hours: 1));
                        _updateTask(index, current.copyWith(end: end));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('上传图片'),
                    onPressed: () => _pickAttachment(index, imageOnly: true),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.attach_file_outlined),
                    label: const Text('上传附件'),
                    onPressed: () => _pickAttachment(index),
                  ),
                ],
              ),
              if (task.attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (
                      var fileIndex = 0;
                      fileIndex < task.attachments.length;
                      fileIndex++
                    )
                      InputChip(
                        avatar: Icon(
                          _isImage(task.attachments[fileIndex].name)
                              ? Icons.image_outlined
                              : Icons.insert_drive_file_outlined,
                          size: 18,
                        ),
                        label: Text(task.attachments[fileIndex].name),
                        onDeleted: () {
                          final files = [...task.attachments]
                            ..removeAt(fileIndex);
                          _updateTask(index, task.copyWith(attachments: files));
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _updateTask(int index, LazyLogTaskEdit task) {
    final tasks = [..._plan.tasks];
    tasks[index] = task;
    setState(() => _plan = _plan.copyWith(tasks: tasks));
  }

  Future<void> _pickAttachment(int index, {bool imageOnly = false}) async {
    final file = imageOnly
        ? await TaskAttachmentPicker.pickImage()
        : await TaskAttachmentPicker.pickFile();
    if (file == null || !mounted) return;
    final task = _plan.tasks[index];
    _updateTask(index, task.copyWith(attachments: [...task.attachments, file]));
  }

  List<String> _splitChecklist(String value) {
    return value
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim().replaceFirst(RegExp(r'^[-*•]\s*'), ''))
        .where((line) => line.isNotEmpty)
        .toList();
  }

  bool _isImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDateTime(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class TaskAttachmentPicker {
  static Future<PlatformFile?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  static Future<PlatformFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }
}
