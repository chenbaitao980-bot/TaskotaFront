import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/native_file_ops.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/project_group_repository.dart';
import '../../../../data/repositories/project_repository.dart';
import '../../../../data/repositories/task_repository.dart';
import '../../../../data/repositories/node_template_repository.dart';
import '../../../../models/node_template_payload.dart';
import '../../../../services/subtask_scheduler.dart';
import '../../../../services/task_conflict_service.dart';
import '../../../../services/task_attachment_service.dart';
import '../../../widgets/calendar_date_picker.dart';
import '../../../widgets/task_conflict_dialog.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

class TaskCreateSheet extends StatefulWidget {
  final String? initialProjectId;
  final ProjectRepository projectRepository;
  final ProjectGroupRepository? projectGroupRepository;
  final TaskRepository? taskRepository;
  final NodeTemplateRepository? nodeTemplateRepository;
  final List<Project> templateProjects;
  final List<Task> availableParentTasks;
  final int? initialStartDateMillis;
  final int? initialDueDateMillis;
  final String? initialParentId;
  final bool isTemplateMode;

  const TaskCreateSheet({
    super.key,
    this.initialProjectId,
    required this.projectRepository,
    this.projectGroupRepository,
    this.taskRepository,
    this.nodeTemplateRepository,
    this.templateProjects = const [],
    this.availableParentTasks = const [],
    this.initialStartDateMillis,
    this.initialDueDateMillis,
    this.initialParentId,
    this.isTemplateMode = false,
  });

  @override
  State<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends State<TaskCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late Future<List<Project>> _projectsFuture;
  late Future<List<ProjectGroup>> _groupsFuture;
  String? _selectedProjectId;
  String? _selectedGroupId;
  int _priority = 1; // 默认"低"
  DateTime? _startDate;
  DateTime? _dueDate;
  String? _parentTaskId;
  bool get _showLegacyPickers => false;
  final List<PlatformFile> _pendingImages = [];
  final _attachSvc = TaskAttachmentService();
  late Future<List<NodeTemplate>> _templatesFuture;
  NodeTemplate? _selectedTemplate;
  NodeTemplatePayload _selectedTemplatePayload = NodeTemplatePayload.empty;
  Project? _selectedTemplateProject;

  // 时长滑块
  bool _durationModeIsHours = true; // true=小时, false=天
  double _durationValue = 1.0;

  // 提醒状态
  bool _reminderEnabled = true;
  int _remindBeforeMinutes = 15;

  @override
  void initState() {
    super.initState();
    _parentTaskId = widget.initialParentId;
    _selectedProjectId =
        widget.initialProjectId ?? _projectIdOfParent(_parentTaskId);
    if (widget.initialStartDateMillis != null) {
      _startDate = DateTime.fromMillisecondsSinceEpoch(
        widget.initialStartDateMillis!,
      );
    } else {
      _startDate = DateTime.now();
    }
    if (widget.initialDueDateMillis != null) {
      _dueDate = DateTime.fromMillisecondsSinceEpoch(
        widget.initialDueDateMillis!,
      );
    } else {
      _dueDate = _startDate!.add(const Duration(hours: 1));
    }
    _projectsFuture = widget.projectRepository.getActive();
    _groupsFuture =
        widget.projectGroupRepository?.getAll() ??
        Future.value(<ProjectGroup>[]);
    _templatesFuture =
        widget.nodeTemplateRepository?.getAll() ??
        Future.value(<NodeTemplate>[]);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String? _projectIdOfParent(String? parentTaskId) {
    if (parentTaskId == null) return null;
    for (final task in widget.availableParentTasks) {
      if (task.id == parentTaskId) return task.projectId;
    }
    return null;
  }

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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
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
                if (!widget.isTemplateMode) _buildProjectPickers(),
                if (!widget.isTemplateMode && _showLegacyPickers)
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
                        onChanged: (v) =>
                            setState(() => _selectedProjectId = v),
                      );
                    },
                  ),
                if (!widget.isTemplateMode) ...[
                  const SizedBox(height: 12),
                  _buildTemplatePicker(),
                ],
                const SizedBox(height: 12),
                _buildParentPicker(),
                if (_showLegacyPickers &&
                    widget.availableParentTasks.isNotEmpty)
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
                      ...widget.availableParentTasks.map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _parentTaskId = v;
                      final parentProjectId = _projectIdOfParent(v);
                      if (parentProjectId != null) {
                        _selectedProjectId = parentProjectId;
                      }
                    }),
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
                const SizedBox(height: 8),
                _buildDurationSlider(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: '描述（选填）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                // ── 提醒设置 ──
                _buildReminderSection(),
                const SizedBox(height: 8),
                // 图片预览 + 添加按钮
                if (_pendingImages.isNotEmpty) ...[
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pendingImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final img = _pendingImages[i];
                        final path = img.path;
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: path != null
                                  ? SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: imageFromFile(
                                        fileFromPath(path),
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      width: 80,
                                      height: 80,
                                      color: AppTheme.bgInput,
                                      child: const Icon(Icons.image_outlined),
                                    ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _pendingImages.removeAt(i)),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final file = await _attachSvc.pickImageFile();
                      if (file != null && mounted) {
                        setState(() => _pendingImages.add(file));
                      }
                    },
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('添加图片'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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

  Widget _buildProjectPickers() {
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([_groupsFuture, _projectsFuture]),
      builder: (context, snapshot) {
        final groups = snapshot.hasData
            ? snapshot.data![0] as List<ProjectGroup>
            : <ProjectGroup>[];
        final projects = snapshot.hasData
            ? snapshot.data![1] as List<Project>
            : <Project>[];
        final selectedProject = projects
            .where((project) => project.id == _selectedProjectId)
            .firstOrNull;
        final effectiveGroupId = _selectedGroupId ?? selectedProject?.groupId;
        final filteredProjects = effectiveGroupId == null
            ? projects
            : projects
                  .where((project) => project.groupId == effectiveGroupId)
                  .toList();

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: effectiveGroupId,
                    decoration: const InputDecoration(
                      labelText: '项目分组',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('全部分组'),
                      ),
                      ...groups.map(
                        (group) => DropdownMenuItem<String?>(
                          value: group.id,
                          child: Text(group.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedGroupId = value;
                        final selectedStillVisible =
                            value == null ||
                            projects
                                .where((p) => p.id == _selectedProjectId)
                                .any((p) => p.groupId == value);
                        if (!selectedStillVisible) _selectedProjectId = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '新建分组',
                  onPressed: widget.projectGroupRepository == null
                      ? null
                      : _createProjectGroup,
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value:
                        filteredProjects.any((p) => p.id == _selectedProjectId)
                        ? _selectedProjectId
                        : null,
                    decoration: const InputDecoration(
                      labelText: '所属项目',
                      border: OutlineInputBorder(),
                    ),
                    items: filteredProjects
                        .map(
                          (project) => DropdownMenuItem(
                            value: project.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      int.parse(
                                        project.color.replaceFirst('#', '0xFF'),
                                      ),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(project.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedProjectId = value;
                      _parentTaskId = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '新建项目',
                  onPressed: _createProject,
                  icon: const Icon(Icons.add_box_outlined),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTemplatePicker() {
    if (widget.templateProjects.isNotEmpty) {
      return _buildTemplateProjectPicker();
    }
    if (widget.nodeTemplateRepository == null) return const SizedBox.shrink();
    return FutureBuilder<List<NodeTemplate>>(
      future: _templatesFuture,
      builder: (context, snapshot) {
        final templates = snapshot.data ?? const <NodeTemplate>[];
        if (templates.isEmpty) return const SizedBox.shrink();
        return DropdownButtonFormField<String?>(
          value: _selectedTemplate?.id,
          decoration: const InputDecoration(
            labelText: '复用模板',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('不使用模板')),
            ...templates.map(
              (template) => DropdownMenuItem<String?>(
                value: template.id,
                child: Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (value) {
            final template = templates
                .where((item) => item.id == value)
                .firstOrNull;
            setState(() {
              _selectedTemplate = template;
              _selectedTemplatePayload = template == null
                  ? NodeTemplatePayload.empty
                  : widget.nodeTemplateRepository!.payloadOf(template);
              if (template != null) {
                _titleController.text = template.title;
                _descController.text = template.description;
                _priority = template.priority;
              }
            });
          },
        );
      },
    );
  }

  Widget _buildTemplateProjectPicker() {
    return FutureBuilder<List<Task>>(
      future: widget.taskRepository?.getAll() ?? Future.value(<Task>[]),
      builder: (context, snapshot) {
        final allTasks = snapshot.data ?? const <Task>[];
        return DropdownButtonFormField<String?>(
          value: _selectedTemplateProject?.id,
          decoration: const InputDecoration(
            labelText: '复用模板',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('不使用模板')),
            ...widget.templateProjects.map(
              (project) => DropdownMenuItem<String?>(
                value: project.id,
                child: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (value) {
            final project = widget.templateProjects
                .where((p) => p.id == value)
                .firstOrNull;
            setState(() {
              _selectedTemplateProject = project;
              _selectedTemplate = null;
              _selectedTemplatePayload = NodeTemplatePayload.empty;
              if (project != null) {
                final rootTasks = allTasks
                    .where((t) =>
                        t.projectId == project.id && t.parentId == null)
                    .toList();
                if (rootTasks.isNotEmpty) {
                  final root = rootTasks.first;
                  _titleController.text = root.title;
                  _descController.text = root.description;
                  _priority = root.priority;
                  if (root.startDate != null && root.dueDate != null) {
                    final duration = root.dueDate! - root.startDate!;
                    _dueDate = _startDate?.add(
                      Duration(milliseconds: duration),
                    );
                  }
                }
              }
            });
          },
        );
      },
    );
  }

  Widget _buildParentPicker() {
    final parents = widget.availableParentTasks
        .where(
          (task) =>
              _selectedProjectId == null ||
              task.projectId == _selectedProjectId,
        )
        .toList();
    if (parents.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      value: parents.any((task) => task.id == _parentTaskId)
          ? _parentTaskId
          : null,
      decoration: const InputDecoration(
        labelText: '父任务（可选）',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('无（根任务）')),
        ...parents.map(
          (task) => DropdownMenuItem(
            value: task.id,
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) => setState(() {
        _parentTaskId = value;
        final parentProjectId = _projectIdOfParent(value);
        if (parentProjectId != null) _selectedProjectId = parentProjectId;
      }),
    );
  }

  Future<void> _createProjectGroup() async {
    final name = await _promptName('新建项目分组', '分组名称');
    if (name == null || widget.projectGroupRepository == null) return;
    final group = await widget.projectGroupRepository!.create(name: name);
    setState(() {
      _selectedGroupId = group.id;
      _groupsFuture = widget.projectGroupRepository!.getAll();
    });
  }

  Future<void> _createProject() async {
    final name = await _promptName('新建项目', '项目名称');
    if (name == null) return;
    final project = await widget.projectRepository.create(
      name: name,
      groupId: _selectedGroupId,
    );
    setState(() {
      _selectedProjectId = project.id;
      _projectsFuture = widget.projectRepository.getActive();
    });
  }

  Future<String?> _promptName(String title, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result == null || result.isEmpty ? null : result;
  }

  List<Widget> _buildPriorityChips() {
    final priorities = [(0, '无'), (1, '低'), (3, '中'), (5, '高')];
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

  void _syncDurationFromDates() {
    if (_startDate == null || _dueDate == null) return;
    final totalHours = _dueDate!.difference(_startDate!).inMinutes / 60.0;
    if (_durationModeIsHours) {
      _durationValue = (totalHours).clamp(0.5, 12.0);
      _durationValue = (_durationValue * 2).roundToDouble() / 2;
    } else {
      _durationValue = (totalHours / 24.0).clamp(1.0, 15.0);
      _durationValue = _durationValue.roundToDouble();
    }
  }

  void _applyDurationToEnd() {
    if (_startDate == null) return;
    if (_durationModeIsHours) {
      _dueDate = _startDate!.add(
        Duration(minutes: (_durationValue * 60).round()),
      );
    } else {
      _dueDate = _startDate!.add(
        Duration(days: _durationValue.round()),
      );
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
        _applyDurationToEnd();
      } else {
        _dueDate = picked;
        _syncDurationFromDates();
      }
    });
  }

  Widget _buildDurationSlider() {
    final min = _durationModeIsHours ? 0.5 : 1.0;
    final max = _durationModeIsHours ? 12.0 : 15.0;
    final divisions = _durationModeIsHours ? 23 : 14;
    final label = _durationModeIsHours
        ? (_durationValue % 1 == 0
            ? '${_durationValue.toInt()} 小时'
            : '${_durationValue} 小时')
        : '${_durationValue.toInt()} 天';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderSubtle),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              _durationModeChip('小时', true),
              const SizedBox(width: 6),
              _durationModeChip('天', false),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              thumbColor: AppTheme.primaryColor,
              overlayColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _durationValue.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: (v) {
                setState(() {
                  _durationValue = v;
                  _applyDurationToEnd();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationModeChip(String text, bool isHours) {
    final selected = _durationModeIsHours == isHours;
    return GestureDetector(
      onTap: () {
        if (selected) return;
        setState(() {
          final oldHours = _durationModeIsHours
              ? _durationValue
              : _durationValue * 24;
          _durationModeIsHours = isHours;
          if (_durationModeIsHours) {
            _durationValue = oldHours.clamp(0.5, 12.0);
            _durationValue = (_durationValue * 2).roundToDouble() / 2;
          } else {
            _durationValue = (oldHours / 24.0).clamp(1.0, 15.0);
            _durationValue = _durationValue.roundToDouble();
          }
          _applyDurationToEnd();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.bgInput,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      showAppSnackBar(context, '请选择开始时间');
      return;
    }
    if (_dueDate == null) {
      showAppSnackBar(context, '请选择截止时间');
      return;
    }
    if (!_dueDate!.isAfter(_startDate!)) {
      showAppSnackBar(context, '截止时间必须晚于开始时间');
      return;
    }

    var finalStart = _startDate!;
    var finalEnd = _dueDate!;
    var shiftedTasks = const <ScheduledTaskShift>[];

    // 子任务才做冲突检测
    if (widget.taskRepository != null &&
        !TaskConflictService.isRangeMultiDay(finalStart, finalEnd)) {
      final svc = TaskConflictService(taskRepository: widget.taskRepository!);
      final conflict = await svc.checkConflict(
        finalStart,
        finalEnd,
        excludeParentId: _parentTaskId,
      );
      if (conflict != null && mounted) {
        final choice = await showTaskConflictDialog(
          context,
          conflict: conflict,
          newStart: finalStart,
          newEnd: finalEnd,
        );
        if (!mounted) return;
        switch (choice) {
          case ConflictChoice.cancel:
            return;
          case ConflictChoice.parallel:
            break; // 保持原时间
          case ConflictChoice.autoDelay:
            final delayed = await svc.calcDelayedSlot(
              finalStart,
              finalEnd,
              conflict.conflictEnd,
              excludeParentId: _parentTaskId,
            );
            if (delayed != null) {
              finalStart = delayed.start;
              finalEnd = delayed.end;
            }
          case ConflictChoice.autoInsert:
            shiftedTasks = await svc.calcInsertedShifts(
              finalStart,
              finalEnd,
              excludeParentId: _parentTaskId,
            );
          case null:
            return; // 弹窗关闭视为取消
        }
      }
    }

    if (!mounted) return;
    Navigator.pop(context, {
      'title': _titleController.text.trim(),
      'projectId': _selectedProjectId,
      'description': _descController.text.trim(),
      'priority': _priority,
      'startDate': finalStart.millisecondsSinceEpoch,
      'dueDate': finalEnd.millisecondsSinceEpoch,
      'parentId': _parentTaskId,
      'shiftedTasks': shiftedTasks,
      'pendingImages': List<PlatformFile>.from(_pendingImages),
      'templatePayload': _selectedTemplatePayload,
      if (_selectedTemplateProject != null)
        'templateProjectId': _selectedTemplateProject!.id,
      'remindBeforeMinutes':
          _reminderEnabled ? _remindBeforeMinutes : null,
      'reminderEnabled': _reminderEnabled ? 1 : 0,
    });
  }

  /// 跨天任务（start/end 不在同一日历日）不参与冲突校验和占用计算。
  static bool _isMultiDay(Task t) {
    if (t.startDate == null || t.dueDate == null) return false;
    final s = DateTime.fromMillisecondsSinceEpoch(t.startDate!);
    final e = DateTime.fromMillisecondsSinceEpoch(t.dueDate!);
    return !(s.year == e.year && s.month == e.month && s.day == e.day);
  }

  // ── 提醒设置 ──

  static const List<Map<String, dynamic>> _remindBeforeOptions = [
    {'label': '5 分钟', 'value': 5},
    {'label': '10 分钟', 'value': 10},
    {'label': '15 分钟', 'value': 15},
    {'label': '30 分钟', 'value': 30},
    {'label': '1 小时', 'value': 60},
    {'label': '2 小时', 'value': 120},
    {'label': '1 天', 'value': 1440},
  ];

  Widget _buildReminderSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgInput.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
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
              _reminderEnabled ? '将在任务开始前通知您' : '不会发送提醒',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            value: _reminderEnabled,
            onChanged: (v) => setState(() => _reminderEnabled = v),
          ),
          if (_reminderEnabled) ...[
            const Divider(height: 1, indent: 52),
            _buildDropdownTile(
              icon: Icons.timer_outlined,
              label: '提前提醒',
              value: _remindBeforeMinutes,
              options: _remindBeforeOptions,
              onChanged: (v) => setState(() => _remindBeforeMinutes = v),
            ),
          ],
        ],
      ),
    );
  }

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
}

@visibleForTesting
bool isSubtaskTimingOccupantForTaskCreateSheet(Task t, {String? parentTaskId}) {
  if (t.startDate == null || t.dueDate == null) return false;
  if (t.status == 2 || t.deleted != 0) return false;
  if (t.id == parentTaskId) return false;
  if (_TaskCreateSheetState._isMultiDay(t)) return false;
  return true;
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
