import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/database/app_database.dart';
import '../../../../../services/local_storage_service.dart';
import '../../../../../services/notification_service.dart';
import '../../../../../services/subtask_scheduler.dart';
import '../../../../../services/task_attachment_service.dart';
import '../../../../../services/task_decomposition_service.dart';
import '../../../../blocs/task_new/task_bloc.dart';
import '../../../../blocs/task_new/task_event.dart';

class AiDecomposeSection extends StatefulWidget {
  final Task task;
  final String projectId;
  final String currentDescription;

  const AiDecomposeSection({
    super.key,
    required this.task,
    required this.projectId,
    this.currentDescription = '',
  });

  @override
  State<AiDecomposeSection> createState() => _AiDecomposeSectionState();
}

class _AiDecomposeSectionState extends State<AiDecomposeSection> {
  final _attachmentService = TaskAttachmentService();
  final _decompositionService = TaskDecompositionService();
  bool _isDecomposing = false;

  bool _isSimilarToAny(String title, List<String> existing) {
    final t = title.trim();
    if (t.isEmpty) return true;
    for (final e in existing) {
      if (e.trim() == t) return true;
      if (e.contains(t) || t.contains(e)) return true;
    }
    return false;
  }

  Future<void> _decompose() async {
    setState(() => _isDecomposing = true);

    try {
      final bloc = context.read<TaskNewBloc>();
      final repo = bloc.taskRepository;

      // 1) 收集附件
      final attachmentContents = <String>[];
      final attachments =
          await _attachmentService.getAttachments(widget.task.id);
      for (final a in attachments) {
        final content = await _attachmentService.readFileContent(a.filePath);
        if (content.isNotEmpty) {
          attachmentContents.add(content.length > 3000
              ? content.substring(0, 3000)
              : content);
        }
      }

      // 2) 现有后代用于 dedup
      final existingDescendants = await repo.getDescendants(widget.task.id);
      final existingTitles =
          existingDescendants.map((t) => t.title.trim()).toList();

      // 3) 调 AI
      final descToUse = widget.currentDescription.isNotEmpty
          ? widget.currentDescription
          : widget.task.description;
      final result = await _decompositionService.decompose(
        widget.task.title,
        descToUse,
        attachmentContents,
        existingTaskTitles: existingTitles,
      );

      if (result.nodes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.allDuplicates
                ? '子任务已完整，无需重复分解'
                : 'AI 分解失败，请重试'),
          ));
        }
        return;
      }

      // 4) 把整棵树直接通过 repo 创建（同步获得 id）
      // 返回：parentTaskIds（有子任务的节点）/ leaves（叶子）
      final createdLeaves = <_CreatedLeaf>[];
      final parentToLeafIds = <String, List<String>>{};
      int created = 0;

      Future<void> walk(SubtaskNode node, String parentId) async {
        if (_isSimilarToAny(node.title.trim(), existingTitles)) return;
        final isLeaf = node.children.isEmpty;
        final t = await repo.create(
          projectId: widget.projectId,
          title: node.title.trim(),
          parentId: parentId,
          estimatedMinutes: isLeaf ? node.estimatedMinutes : null,
        );
        existingTitles.add(node.title.trim());
        created++;
        if (isLeaf) {
          createdLeaves.add(_CreatedLeaf(
            id: t.id,
            minutes: node.estimatedMinutes ?? 60,
          ));
        } else {
          parentToLeafIds[t.id] = [];
          for (final child in node.children) {
            final beforeLen = createdLeaves.length;
            await walk(child, t.id);
            // 收集本层及更深层新加的叶子
            for (int i = beforeLen; i < createdLeaves.length; i++) {
              parentToLeafIds[t.id]!.add(createdLeaves[i].id);
            }
          }
        }
      }

      for (final node in result.nodes) {
        await walk(node, widget.task.id);
      }

      // 顶层根任务（widget.task）也要被识别为父任务
      parentToLeafIds[widget.task.id] = createdLeaves.map((e) => e.id).toList();

      if (createdLeaves.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('新增 $created 个子任务（无叶子，无需排程）')),
          );
          context.read<TaskNewBloc>().add(LoadSubTree(rootTaskId: widget.task.id));
        }
        return;
      }

      // 5) 排程：避让所有已有 task 时段；本次新建的叶子不参与避让
      final storage = LocalStorageService();
      await storage.init();
      final skipWeekends = storage.skipWeekends;

      final allTasks = await repo.getAll();
      final ignoreIds = createdLeaves.map((e) => e.id).toSet();
      final scheduler = SubtaskScheduler(
        existingTasks: allTasks,
        skipWeekends: skipWeekends,
        ignoreTaskIds: ignoreIds,
      );
      final slots = scheduler.scheduleLeaves(
        createdLeaves
            .map((e) => LeafToSchedule(taskId: e.id, minutes: e.minutes))
            .toList(),
      );

      // 6) 回写叶子任务时间 + 开提醒
      for (final s in slots) {
        await repo.update(
          s.taskId,
          startDate: s.start.millisecondsSinceEpoch,
          dueDate: s.end.millisecondsSinceEpoch,
          reminderEnabled: 1,
          remindBeforeMinutes: 5,
        );
        // 调度本地通知
        try {
          await NotificationService().scheduleReminderForSchedule(
            scheduleId: s.taskId,
            title: '即将开始：${_titleOf(s.taskId, createdLeaves, result.nodes) ?? '子任务'}',
            startTime: s.start,
            description: null,
            remindBeforeMinutes: 5,
            isRepeating: false,
            repeatInterval: null,
          );
        } catch (_) {}
      }

      // 7) 回写父任务（含根任务）跨天范围
      final parentSpans = computeParentSpans(
        parentToLeafIds: parentToLeafIds,
        slots: slots,
      );
      parentSpans.forEach((pid, span) async {
        await repo.update(
          pid,
          startDate: span.start.millisecondsSinceEpoch,
          dueDate: span.end.millisecondsSinceEpoch,
        );
      });

      // 8) 刷新视图
      if (mounted) {
        context.read<TaskNewBloc>().add(LoadTasks());
        context.read<TaskNewBloc>().add(LoadSubTree(rootTaskId: widget.task.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('新增 $created 个子任务，已自动排到日历')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拆解失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDecomposing = false);
    }
  }

  String? _titleOf(String id, List<_CreatedLeaf> leaves, List<SubtaskNode> tree) {
    // 简化：从 leaves 里找不到就返回 null（提醒用，缺失也不影响排程）
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 20, color: AppTheme.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'AI 拆分子任务',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDecomposing ? null : _decompose,
                icon: _isDecomposing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.call_split_rounded, size: 18),
                label: Text(_isDecomposing ? 'AI 拆解中...' : '一键拆分子任务'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatedLeaf {
  final String id;
  final int minutes;
  const _CreatedLeaf({required this.id, required this.minutes});
}
