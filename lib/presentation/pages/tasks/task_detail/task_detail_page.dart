import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database/app_database.dart';
import '../../../../services/task_conflict_service.dart';
import '../../../../services/subtask_scheduler.dart';
import '../../../blocs/task_new/task_bloc.dart';
import '../../../blocs/task_new/task_event.dart';
import '../../../blocs/task_new/task_state.dart';
import '../../../widgets/calendar_date_picker.dart';
import '../../../widgets/task_conflict_dialog.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/task_attachment_service.dart';
import 'widgets/checklist_section.dart';
import 'widgets/subtask_tree_section.dart';
import 'widgets/attachment_section.dart';
import 'widgets/ai_decompose_section.dart';
import 'widgets/markdown_description_section.dart';
import 'widgets/markdown_editor_page.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

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
  late int _remindBeforeMinutes;
  late bool _reminderEnabled;
  List<ChecklistItem> _checklistItems = [];
  bool _hasChanges = false;
  bool _allowPop = false;
  bool _isClosing = false;
  bool _cascadeChildrenOnComplete = false;
  int _attachmentRefreshToken = 0;
  Timer? _autoSaveTimer;
  bool _hasChildren = false;
  bool _isRoot = false;
  List<ScheduledTaskShift> _pendingShiftedTasks = const [];

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _isRoot = t.parentId == null;
    context.read<TaskNewBloc>().taskRepository.hasChildren(t.id).then((v) {
      if (mounted) setState(() => _hasChildren = v);
    });
    _titleController = TextEditingController(text: t.title);
    _descController = TextEditingController(text: t.description);
    _startDateTime = t.startDate != null
        ? DateTime.fromMillisecondsSinceEpoch(t.startDate!)
        : DateTime.now();
    _remindBeforeMinutes = t.remindBeforeMinutes;
    _reminderEnabled = t.reminderEnabled > 0;
    _endDateTime = t.dueDate != null
        ? DateTime.fromMillisecondsSinceEpoch(t.dueDate!)
        : _startDateTime.add(const Duration(hours: 1));
    _priority = t.priority;
    _selectedProjectId = t.projectId;
    _status = t.status;
    _savedStatus = t.status;
    final bloc = context.read<TaskNewBloc>();
    final currentState = bloc.state;
    if (currentState is TaskNewLoaded) {
      _checklistItems = currentState.checklistItems[widget.task.id] ?? [];
    }
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
    _hasChanges = true;
    _scheduleAutoSave();
  }

  void _markTextChanged() {
    _hasChanges = true;
    _autoSaveTimer?.cancel();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 700), _saveTask);
  }

  void _refreshTaskList() {
    final state = context.read<TaskNewBloc>().state;
    context.read<TaskNewBloc>().add(
      LoadTasks(
        projectIds: state is TaskNewLoaded
            ? state.selectedProjectIds
            : const {},
        filter: state is TaskNewLoaded ? state.selectedFilter : null,
        statusFilter: state is TaskNewLoaded
            ? state.selectedStatusFilter
            : null,
        dateFrom: state is TaskNewLoaded ? state.dateFrom : null,
        dateTo: state is TaskNewLoaded ? state.dateTo : null,
      ),
    );
  }

  Future<void> _toggleCompletionStatus() async {
    final nextStatus = _status == 2 ? 0 : 2;
    var cascade = false;
    if (nextStatus == 2) {
      final children = await context
          .read<TaskNewBloc>()
          .taskRepository
          .getSubTasks(widget.task.id);
      if (children.isNotEmpty && mounted) {
        final choice = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('完成子任务'),
            content: const Text('这个任务包含子任务，是否同时全部完成？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('仅完成父任务'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('全部完成'),
              ),
            ],
          ),
        );
        if (choice == null) return;
        cascade = choice;
      }
    }
    if (!mounted) return;
    setState(() {
      _status = nextStatus;
      _cascadeChildrenOnComplete = cascade;
    });
    _markChanged();
  }

  Future<void> _pickDescriptionImage() async {
    final service = TaskAttachmentService();
    final file = await service.pickImageFile();
    if (file == null) return;
    await service.saveAttachment(widget.task.id, file);
    if (!mounted) return;
    setState(() => _attachmentRefreshToken++);
  }

  Future<void> _handleDroppedDescriptionImages(DropDoneDetails detail) async {
    var saved = 0;
    for (final file in detail.files) {
      final name = file.name.isNotEmpty ? file.name : file.path.split('/').last;
      if (!TaskAttachmentService.isImageFile(name, null)) continue;
      final bytes = await file.readAsBytes();
      await TaskAttachmentService().saveImageBytes(
        widget.task.id,
        fileName: name,
        bytes: bytes,
      );
      saved++;
    }
    if (!mounted) return;
    if (saved == 0) {
      showAppSnackBar(context, '只支持拖入图片文件');
      return;
    }
    setState(() => _attachmentRefreshToken++);
    showAppSnackBar(context, '已添加 $saved 张图片');
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
      listenWhen: (prev, curr) {
        if (prev is! TaskNewLoaded || curr is! TaskNewLoaded) return true;
        return prev.checklistItems[widget.task.id] !=
            curr.checklistItems[widget.task.id];
      },
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
                icon: const Icon(Icons.archive_outlined),
                tooltip: '归档',
                onPressed: _archiveTask,
              ),
              IconButton(
                icon: Icon(Icons.delete_outlined, color: AppTheme.error),
                onPressed: _deleteTask,
              ),
            ],
          ),
          body: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              // 标题 — 可编辑 + 完成复选框
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // 完成复选框
                    GestureDetector(
                      onTap: _toggleCompletionStatus,
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _status == 2
                              ? AppTheme.success
                              : Colors.transparent,
                          border: Border.all(
                            color: _status == 2
                                ? AppTheme.success
                                : AppTheme.textHint,
                            width: 2.5,
                          ),
                        ),
                        child: _status == 2
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _titleController,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: _status == 2
                              ? AppTheme.textHint
                              : AppTheme.textPrimary,
                          decoration: _status == 2
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: (_) => _markTextChanged(),
                        onTapOutside: (_) => _saveTask(),
                        onEditingComplete: _saveTask,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // 状态切换
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleCompletionStatus,
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
              const SizedBox(height: 12),
              // 紧凑 meta 行：项目/优先级/时间/提醒/AI 拆分
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMetaChipsBar(projects),
              ),
              const SizedBox(height: 12),
              // 主体布局：宽屏左列(描述+检查项) + 右列(子任务) + 底部附件条
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (ctx, cons) {
                    final wide = cons.maxWidth >= 720;
                    final maxH = MediaQuery.of(context).size.height * 0.5;

                    final desc = _buildDescriptionBox();

                    final checklist = RepaintBoundary(
                      child: ChecklistSection(
                        items: _checklistItems,
                        taskId: widget.task.id,
                        maxListHeight: wide ? 480 : 420,
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
                        onReorder: (orderedIds) {
                          context.read<TaskNewBloc>().add(
                            ReorderChecklistItems(
                              taskId: widget.task.id,
                              orderedIds: orderedIds,
                            ),
                          );
                        },
                      ),
                    );

                    final subtask = ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxH),
                      child: RepaintBoundary(
                        child: SubtaskTreeSection(
                          task: widget.task,
                          projectId: _selectedProjectId,
                        ),
                      ),
                    );

                    final attach = RepaintBoundary(
                      child: AttachmentSection(
                        key: ValueKey(
                          'attach-${widget.task.id}-$_attachmentRefreshToken',
                        ),
                        task: widget.task,
                      ),
                    );

                    if (wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    desc,
                                    const SizedBox(height: 12),
                                    checklist,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(flex: 2, child: subtask),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 100),
                            child: attach,
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        desc,
                        const SizedBox(height: 8),
                        checklist,
                        const SizedBox(height: 8),
                        subtask,
                        const SizedBox(height: 8),
                        attach,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionBox() {
    return DropTarget(
      onDragDone: _handleDroppedDescriptionImages,
      child: MarkdownDescriptionSection(
        controller: _descController,
        onTextChanged: _markTextChanged,
        onEditingComplete: _saveTask,
        onEnterEdit: _openFullEditor,
        imageStrip: AttachmentImageStrip(
          key: ValueKey(
            'desc-images-${widget.task.id}-$_attachmentRefreshToken',
          ),
          taskId: widget.task.id,
          maxHeight: 160,
          showDeleteButton: true,
        ),
        trailingActions: [
          IconButton(
            tooltip: '上传图片',
            onPressed: _pickDescriptionImage,
            icon: Icon(
              Icons.add_photo_alternate_outlined,
              size: 18,
              color: AppTheme.primaryColor,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  void _openFullEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarkdownEditorPage(
          controller: _descController,
          onTextChanged: _markTextChanged,
          onEditingComplete: _saveTask,
          taskId: widget.task.id,
          onAttachmentChanged: () {
            if (mounted) setState(() => _attachmentRefreshToken++);
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
        _saveTask();
      }
    });
  }

  Widget _buildMetaChipsBar(List<Project> projects) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (_hasChildren)
            _parentBadge(),
          const SizedBox(width: 6),
          _projectChip(projects),
          const SizedBox(width: 6),
          _priorityChipPill(),
          const SizedBox(width: 6),
          _timeChip(),
          const SizedBox(width: 6),
          _reminderChip(),
          const SizedBox(width: 6),
          _aiDecomposeChip(),
        ],
      ),
    );
  }

  Widget _chipContainer({
    required Widget child,
    VoidCallback? onTap,
    Color? bgColor,
    Color? borderColor,
  }) {
    final container = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? AppTheme.bgInput,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppTheme.borderSubtle),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [child]),
    );
    if (onTap == null) return container;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: container,
    );
  }

  Widget _projectChip(List<Project> projects) {
    final p = projects.where((p) => p.id == _selectedProjectId).firstOrNull;
    final color = p != null
        ? Color(int.parse(p.color.replaceFirst('#', '0xFF')))
        : AppTheme.textHint;
    final canEdit = _isRoot;
    final chip = _chipContainer(
      bgColor: !canEdit ? AppTheme.bgCard : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            p?.name ?? '未分配',
            style: TextStyle(
              fontSize: 12,
              color: canEdit ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
          if (canEdit)
            Icon(Icons.arrow_drop_down, size: 14, color: AppTheme.textHint),
        ],
      ),
    );
    if (!canEdit) return chip;
    return PopupMenuButton<String>(
      tooltip: '项目',
      onSelected: (v) {
        setState(() => _selectedProjectId = v);
        _markChanged();
      },
      itemBuilder: (_) => projects
          .map(
            (proj) => PopupMenuItem(
              value: proj.id,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(
                        int.parse(proj.color.replaceFirst('#', '0xFF')),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(proj.name),
                ],
              ),
            ),
          )
          .toList(),
      child: chip,
    );
  }

  Widget _parentBadge() {
    return _chipContainer(
      bgColor: AppTheme.primaryColor.withValues(alpha: 0.08),
      borderColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_outlined, size: 12, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            '父任务',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorityChipPill() {
    final opts = [
      (0, '无', AppTheme.textHint),
      (1, '低', AppTheme.priorityP3),
      (3, '中', AppTheme.priorityP1),
      (5, '高', AppTheme.priorityP0),
    ];
    final cur = opts.firstWhere(
      (o) => o.$1 == _priority,
      orElse: () => opts[0],
    );
    return PopupMenuButton<int>(
      tooltip: '优先级',
      onSelected: (v) {
        setState(() => _priority = v);
        _markChanged();
      },
      itemBuilder: (_) => opts
          .map(
            (o) => PopupMenuItem(
              value: o.$1,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: o.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(o.$2),
                ],
              ),
            ),
          )
          .toList(),
      child: _chipContainer(
        bgColor: cur.$3.withValues(alpha: 0.10),
        borderColor: cur.$3.withValues(alpha: 0.35),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_rounded, size: 12, color: cur.$3),
            const SizedBox(width: 4),
            Text(
              cur.$2,
              style: TextStyle(
                fontSize: 12,
                color: cur.$3,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 14, color: cur.$3),
          ],
        ),
      ),
    );
  }

  Widget _timeChip() {
    String fmt(DateTime d) =>
        '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    // 父任务时间不可手动编辑，由子任务自动确定
    if (_hasChildren) {
      return _chipContainer(
        bgColor: AppTheme.bgCard,
        borderColor: AppTheme.borderSubtle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 12,
              color: AppTheme.textHint,
            ),
            const SizedBox(width: 4),
            Text(
              '${fmt(_startDateTime)} ~ ${fmt(_endDateTime)}',
              style: TextStyle(fontSize: 12, color: AppTheme.textHint),
            ),
            const SizedBox(width: 4),
            Text(
              '(子任务)',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textHint,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }
    return _chipContainer(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 12,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _pickDateTime(true),
            child: Text(
              fmt(_startDateTime),
              style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 10,
              color: AppTheme.textHint,
            ),
          ),
          InkWell(
            onTap: () => _pickDateTime(false),
            child: Text(
              fmt(_endDateTime),
              style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderChip() {
    final enabled = _reminderEnabled;
    final label = enabled ? '$_remindBeforeMinutes 分钟' : '关';
    return PopupMenuButton<int>(
      tooltip: '提前提醒',
      onSelected: (v) {
        setState(() {
          if (v < 0) {
            _reminderEnabled = false;
          } else {
            _reminderEnabled = true;
            _remindBeforeMinutes = v;
          }
        });
        _markChanged();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: -1, child: Text('关闭提醒')),
        PopupMenuItem(value: 5, child: Text('提前 5 分钟')),
        PopupMenuItem(value: 10, child: Text('提前 10 分钟')),
        PopupMenuItem(value: 15, child: Text('提前 15 分钟')),
        PopupMenuItem(value: 30, child: Text('提前 30 分钟')),
        PopupMenuItem(value: 60, child: Text('提前 1 小时')),
        PopupMenuItem(value: 1440, child: Text('提前 1 天')),
      ],
      child: _chipContainer(
        bgColor: enabled
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : AppTheme.bgInput,
        borderColor: enabled
            ? AppTheme.primaryColor.withValues(alpha: 0.30)
            : AppTheme.borderSubtle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_outlined,
              size: 12,
              color: enabled ? AppTheme.primaryColor : AppTheme.textHint,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? AppTheme.primaryColor : AppTheme.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: enabled ? AppTheme.primaryColor : AppTheme.textHint,
            ),
          ],
        ),
      ),
    );
  }

  bool _aiBusy = false;
  Widget _aiDecomposeChip() {
    return _chipContainer(
      onTap: _aiBusy
          ? () {}
          : () async {
              final config = await showDecomposeConfigSheet(context);
              if (config == null || !mounted) return;
              setState(() => _aiBusy = true);
              await runAiDecompose(
                context: context,
                task: widget.task,
                projectId: _selectedProjectId,
                currentDescription: _descController.text,
                maxDepth: config.maxDepth,
                maxChildrenPerNode: config.maxChildrenPerNode,
              );
              if (mounted) {
                setState(() {
                  _aiBusy = false;
                  _hasChildren = true;
                });
                context.read<TaskNewBloc>().add(
                  LoadSubTree(rootTaskId: widget.task.id),
                );
              }
            },
      bgColor: AppTheme.primaryColor.withValues(alpha: 0.10),
      borderColor: AppTheme.primaryColor.withValues(alpha: 0.35),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _aiBusy
              ? SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                )
              : Icon(
                  Icons.auto_awesome_rounded,
                  size: 12,
                  color: AppTheme.primaryColor,
                ),
          const SizedBox(width: 4),
          Text(
            _aiBusy ? '拆解中…' : 'AI 拆分',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle);

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
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
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
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              icon: Icon(
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
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const Spacer(),
            Text(
              _dateTimeLabel(dateTime),
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.bgInput.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
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
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _reminderEnabled ? '将在任务开始前通知您' : '不会发送提醒',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            value: _reminderEnabled,
            onChanged: (v) {
              setState(() => _reminderEnabled = v);
              _markChanged();
            },
          ),
          if (_reminderEnabled) ...[
            Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            _remindDropdownTile(
              icon: Icons.timer_outlined,
              label: '提前提醒',
              value: _remindBeforeMinutes,
              options: const [5, 10, 15, 30, 60, 120, 1440],
              optionLabels: const [
                '5分钟',
                '10分钟',
                '15分钟',
                '30分钟',
                '1小时',
                '2小时',
                '1天',
              ],
              onChanged: (v) {
                setState(() => _remindBeforeMinutes = v);
                _markChanged();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _remindDropdownTile({
    required IconData icon,
    required String label,
    required int value,
    required List<int> options,
    required List<String> optionLabels,
    required ValueChanged<int> onChanged,
  }) {
    final idx = options.indexOf(value);
    final displayLabel = idx >= 0 ? optionLabels[idx] : '$value分钟';
    return ListTile(
      minVerticalPadding: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, size: 20, color: AppTheme.primaryColor),
      title: Text(
        label,
        style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      ),
      subtitle: Text(
        displayLabel,
        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      ),
      trailing: Icon(Icons.arrow_drop_down, size: 20, color: AppTheme.textHint),
      onTap: () => _showRemindPicker(options, optionLabels, value, onChanged),
    );
  }

  void _showRemindPicker(
    List<int> options,
    List<String> labels,
    int current,
    ValueChanged<int> onChanged,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('提前提醒'),
        children: List.generate(options.length, (i) {
          return RadioListTile<int>(
            title: Text(labels[i]),
            value: options[i],
            groupValue: current,
            onChanged: (v) {
              if (v != null) {
                onChanged(v);
                Navigator.pop(ctx);
              }
            },
          );
        }),
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
    if (picked == null || !mounted) return;

    var candidateStart = isStart ? picked : _startDateTime;
    var candidateEnd = isStart ? _endDateTime : picked;
    if (isStart && candidateEnd.isBefore(candidateStart)) {
      candidateEnd = candidateStart.add(const Duration(hours: 1));
    }

    if (candidateEnd.isAfter(candidateStart) &&
        !TaskConflictService.isRangeMultiDay(candidateStart, candidateEnd)) {
      final bloc = context.read<TaskNewBloc>();
      final svc = TaskConflictService(taskRepository: bloc.taskRepository);
      final conflict = await svc.checkConflict(
        candidateStart,
        candidateEnd,
        excludeTaskId: widget.task.id,
      );
      if (conflict != null && mounted) {
        final choice = await showTaskConflictDialog(
          context,
          conflict: conflict,
          newStart: candidateStart,
          newEnd: candidateEnd,
        );
        if (!mounted) return;
        switch (choice) {
          case ConflictChoice.cancel:
          case null:
            return;
          case ConflictChoice.parallel:
            break;
          case ConflictChoice.autoDelay:
            final delayed = await svc.calcDelayedSlot(
              candidateStart,
              candidateEnd,
              conflict.conflictEnd,
              excludeTaskId: widget.task.id,
            );
            if (delayed != null) {
              candidateStart = delayed.start;
              candidateEnd = delayed.end;
            }
          case ConflictChoice.autoInsert:
            final shifts = await svc.calcInsertedShifts(
              candidateStart,
              candidateEnd,
              excludeTaskId: widget.task.id,
            );
            _pendingShiftedTasks = shifts;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _startDateTime = candidateStart;
      _endDateTime = candidateEnd;
    });
    _markChanged();
  }

  bool _saveTask({bool showErrors = false}) {
    if (!_hasChanges && _status == _savedStatus) return true;

    if (_titleController.text.trim().isEmpty) {
      if (showErrors) {
        showAppSnackBar(context, '请输入任务标题');
      }
      return false;
    }
    if (!_endDateTime.isAfter(_startDateTime)) {
      if (showErrors) {
        showAppSnackBar(context, '截止时间必须晚于开始时间');
      }
      return false;
    }

    final bloc = context.read<TaskNewBloc>();
    if (_status != _savedStatus) {
      bloc.add(
        ToggleTaskStatus(
          id: widget.task.id,
          cascadeChildren: _cascadeChildrenOnComplete,
        ),
      );
      _savedStatus = _status;
      _cascadeChildrenOnComplete = false;
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
        remindBeforeMinutes: _remindBeforeMinutes,
        reminderEnabled: _reminderEnabled ? 1 : 0,
        shiftedTasks: _pendingShiftedTasks,
      ),
    );
    _pendingShiftedTasks = const [];
    // 调度提醒通知
    if (_reminderEnabled) {
      NotificationService().scheduleReminderForSchedule(
        scheduleId: widget.task.id,
        title: widget.task.title,
        startTime: _startDateTime,
        description: _descController.text.trim(),
        remindBeforeMinutes: _remindBeforeMinutes,
      );
    } else {
      unawaited(
        NotificationService().cancelReminderForSchedule(widget.task.id),
      );
    }
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

  Future<void> _archiveTask() async {
    // 先检查是否有未完成子任务
    final repo = context.read<TaskNewBloc>().taskRepository;
    final allDone = await repo.allDescendantsCompleted(widget.task.id);
    if (!mounted) return;
    if (!allDone) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('无法归档'),
          content: const Text('该任务还有未完成的子任务，请先完成所有子任务后再归档。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归档任务'),
        content: Text('确定要归档"${_titleController.text}"吗？归档后可在「已归档」区查看和恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      _autoSaveTimer?.cancel();
      context.read<TaskNewBloc>().add(ArchiveTask(id: widget.task.id));
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }
}
