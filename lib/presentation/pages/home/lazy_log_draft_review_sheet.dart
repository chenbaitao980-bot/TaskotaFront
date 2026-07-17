import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/lazy_log_draft_repository.dart';
import '../../../models/assistant/lazy_log_review_models.dart';
import 'lazy_log_creation_dialog.dart';

class LazyLogDraftReviewSheet extends StatefulWidget {
  final LazyLogDraftRepository repository;
  final List<LazyLogProjectOption> projects;
  final List<LazyLogParentOption> parents;
  final Future<void> Function(List<LazyLogDraft> drafts) onApprove;
  final Future<void> Function(LazyLogDraft draft) onRetry;

  const LazyLogDraftReviewSheet({
    super.key,
    required this.repository,
    required this.projects,
    required this.parents,
    required this.onApprove,
    required this.onRetry,
  });

  @override
  State<LazyLogDraftReviewSheet> createState() =>
      _LazyLogDraftReviewSheetState();
}

class _LazyLogDraftReviewSheetState extends State<LazyLogDraftReviewSheet> {
  final Set<String> _selectedIds = {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LazyLogDraft>>(
      stream: widget.repository.watchReviewable(),
      builder: (context, snapshot) {
        final drafts = snapshot.data ?? const <LazyLogDraft>[];
        final approvable = drafts
            .where((d) => d.status == LazyLogDraftStatus.pendingReview)
            .toList();
        _selectedIds.removeWhere(
          (id) => !approvable.any((draft) => draft.id == id),
        );
        final selectedDrafts = approvable
            .where((draft) => _selectedIds.contains(draft.id))
            .toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              children: [
                _buildHeader(approvable, selectedDrafts),
                const SizedBox(height: 12),
                Expanded(
                  child: drafts.isEmpty
                      ? const Center(child: Text('暂无待审核任务'))
                      : ListView.separated(
                          itemCount: drafts.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final draft = drafts[index];
                            return _DraftReviewCard(
                              draft: draft,
                              selected: _selectedIds.contains(draft.id),
                              projects: widget.projects,
                              parents: widget.parents,
                              repository: widget.repository,
                              onSelected:
                                  draft.status ==
                                      LazyLogDraftStatus.pendingReview
                                  ? (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedIds.add(draft.id);
                                        } else {
                                          _selectedIds.remove(draft.id);
                                        }
                                      });
                                    }
                                  : null,
                              onRetry: draft.status == LazyLogDraftStatus.failed
                                  ? () => widget.onRetry(draft)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    List<LazyLogDraft> approvable,
    List<LazyLogDraft> selectedDrafts,
  ) {
    final approvableCount = approvable.length;
    final allSelected =
        approvableCount > 0 && selectedDrafts.length == approvableCount;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '懒人日志待审核',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                selectedDrafts.isEmpty
                    ? '检查 AI 生成的任务，确认后才会正式创建'
                    : '已选择 ${selectedDrafts.length} 个任务',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _busy || approvableCount == 0
              ? null
              : () {
                  setState(() {
                    if (allSelected) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds
                        ..clear()
                        ..addAll(approvable.map((draft) => draft.id));
                    }
                  });
                },
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          label: Text(allSelected ? '取消全选' : '全选'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _busy || selectedDrafts.isEmpty
              ? null
              : () => _approve(selectedDrafts),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: const Text('审核通过'),
        ),
      ],
    );
  }

  Future<void> _approve(List<LazyLogDraft> drafts) async {
    setState(() => _busy = true);
    try {
      await widget.onApprove(drafts);
      if (mounted) {
        setState(() => _selectedIds.removeAll(drafts.map((d) => d.id)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _DraftReviewCard extends StatefulWidget {
  final LazyLogDraft draft;
  final bool selected;
  final List<LazyLogProjectOption> projects;
  final List<LazyLogParentOption> parents;
  final LazyLogDraftRepository repository;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onRetry;

  const _DraftReviewCard({
    required this.draft,
    required this.selected,
    required this.projects,
    required this.parents,
    required this.repository,
    required this.onSelected,
    required this.onRetry,
  });

  @override
  State<_DraftReviewCard> createState() => _DraftReviewCardState();
}

class _DraftReviewCardState extends State<_DraftReviewCard> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title);
  }

  @override
  void didUpdateWidget(covariant _DraftReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.id != widget.draft.id ||
        oldWidget.draft.title != widget.draft.title) {
      _titleController.text = widget.draft.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final canEdit = draft.status == LazyLogDraftStatus.pendingReview ||
        draft.status == LazyLogDraftStatus.failed;
    final start = DateTime.fromMillisecondsSinceEpoch(draft.startDate);
    final end = DateTime.fromMillisecondsSinceEpoch(draft.dueDate);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: widget.selected
              ? AppTheme.primaryColor
              : AppTheme.borderSubtle,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: widget.selected,
                  onChanged: widget.onSelected == null
                      ? null
                      : (value) => widget.onSelected!(value ?? false),
                ),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    enabled: canEdit,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) =>
                        widget.repository.updateDraft(draft.id, title: value),
                  ),
                ),
                _StatusChip(status: draft.status),
              ],
            ),
            if (draft.status == LazyLogDraftStatus.failed &&
                (draft.errorMessage ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 8),
                child: Text(
                  draft.errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ProjectDropdown(
                  value: draft.projectId,
                  projects: widget.projects,
                  enabled: canEdit,
                  onChanged: (value) => widget.repository.updateDraft(
                    draft.id,
                    projectId: value,
                    clearProjectId: value == null,
                  ),
                ),
                _ParentDropdown(
                  value: draft.parentTaskId,
                  parents: widget.parents,
                  enabled: canEdit,
                  onChanged: (value) => widget.repository.updateDraft(
                    draft.id,
                    parentTaskId: value,
                    clearParentTaskId: value == null,
                  ),
                ),
                _PriorityDropdown(
                  value: draft.priority,
                  enabled: canEdit,
                  onChanged: (value) =>
                      widget.repository.updateDraft(draft.id, priority: value),
                ),
                OutlinedButton.icon(
                  onPressed: canEdit
                      ? () => _pickRange(context, draft, start, end)
                      : null,
                  icon: const Icon(Icons.schedule_rounded, size: 16),
                  label: Text('${_fmt(start)} - ${_fmt(end)}'),
                ),
                TextButton.icon(
                  onPressed: () => _showDetail(context, draft, canEdit),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('详情'),
                ),
                if (widget.onRetry != null)
                  TextButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('重试'),
                  ),
                TextButton.icon(
                  onPressed: () => widget.repository.dismiss(draft.id),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('删除'),
                ),
              ],
            ),
            if (draft.description.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 8),
                child: Text(
                  draft.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    LazyLogDraft draft,
    DateTime start,
    DateTime end,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(start.year - 1),
      lastDate: DateTime(start.year + 2),
    );
    if (date == null || !context.mounted) return;
    final startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (startTime == null || !context.mounted) return;
    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(end),
    );
    if (endTime == null) return;
    final nextStart = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
    var nextEnd = DateTime(
      date.year,
      date.month,
      date.day,
      endTime.hour,
      endTime.minute,
    );
    if (!nextEnd.isAfter(nextStart)) {
      nextEnd = nextStart.add(const Duration(hours: 1));
    }
    await widget.repository.updateDraft(
      draft.id,
      start: nextStart,
      end: nextEnd,
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    LazyLogDraft draft,
    bool canEdit,
  ) async {
    final description = TextEditingController(text: draft.description);
    final checklist = TextEditingController(
      text: LazyLogDraftRepository.checklistOf(draft).join('\n'),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('草稿详情'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: description,
                enabled: canEdit,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '描述'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: checklist,
                enabled: canEdit,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Checklist（每行一条）'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('关闭'),
          ),
          if (canEdit)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
        ],
      ),
    );
    final nextDescription = description.text;
    final nextChecklist = checklist.text;
    description.dispose();
    checklist.dispose();
    if (saved == true) {
      await widget.repository.updateDraft(
        draft.id,
        description: nextDescription,
        checklist: nextChecklist.split('\n'),
      );
    }
  }

  String _fmt(DateTime value) {
    final day = '${value.month}/${value.day}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$day $time';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LazyLogDraftStatus.running => ('创建中', Colors.blue),
      LazyLogDraftStatus.failed => ('失败', Colors.redAccent),
      LazyLogDraftStatus.pendingReview => ('待审核', AppTheme.primaryColor),
      _ => ('已处理', AppTheme.textSecondary),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }
}

class _ProjectDropdown extends StatelessWidget {
  final String? value;
  final List<LazyLogProjectOption> projects;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _ProjectDropdown({
    required this.value,
    required this.projects,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: projects.any((project) => project.id == value) ? value : null,
      hint: const Text('项目'),
      onChanged: enabled ? onChanged : null,
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('不指定项目')),
        for (final project in projects)
          DropdownMenuItem<String?>(
            value: project.id,
            child: Text('${project.groupName} / ${project.name}'),
          ),
      ],
    );
  }
}

class _ParentDropdown extends StatelessWidget {
  final String? value;
  final List<LazyLogParentOption> parents;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _ParentDropdown({
    required this.value,
    required this.parents,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: parents.any((parent) => parent.id == value) ? value : null,
      hint: const Text('父任务'),
      onChanged: enabled ? onChanged : null,
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('无父任务')),
        for (final parent in parents)
          DropdownMenuItem<String?>(
            value: parent.id,
            child: Text(parent.title),
          ),
      ],
    );
  }
}

class _PriorityDropdown extends StatelessWidget {
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _PriorityDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = {'P0', 'P1', 'P2', 'P3'}.contains(value) ? value : 'P2';
    return DropdownButton<String>(
      value: normalized,
      onChanged: enabled ? (value) => onChanged(value ?? 'P2') : null,
      items: const [
        DropdownMenuItem(value: 'P0', child: Text('P0')),
        DropdownMenuItem(value: 'P1', child: Text('P1')),
        DropdownMenuItem(value: 'P2', child: Text('P2')),
        DropdownMenuItem(value: 'P3', child: Text('P3')),
      ],
    );
  }
}
