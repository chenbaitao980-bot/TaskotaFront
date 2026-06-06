import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/database/app_database.dart';
import '../../../../../services/local_storage_service.dart';
import '../../../../../services/notification_service.dart';
import '../../../../../services/subscription_service.dart';
import '../../../../../services/subtask_scheduler.dart';
import '../../../../../services/task_attachment_service.dart';
import '../../../../../services/task_decomposition_service.dart';
import '../../../../blocs/task_new/task_bloc.dart';
import '../../../../blocs/task_new/task_event.dart';
import '../../../../blocs/task_new/task_state.dart';
import '../../../../widgets/upgrade_dialog.dart';
import '../../../../widgets/vip_badge.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

class DecomposeConfig {
  final int maxDepth;
  final int maxChildrenPerNode;
  const DecomposeConfig({this.maxDepth = 3, this.maxChildrenPerNode = 5});
}

Future<DecomposeConfig?> showDecomposeConfigSheet(BuildContext context) {
  int maxDepth = 3;
  int maxChildren = 5;
  return showModalBottomSheet<DecomposeConfig>(
    context: context,
    backgroundColor: AppTheme.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'AI 拆分设置',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('拆分层级', style: Theme.of(ctx).textTheme.bodyMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: maxDepth,
                      isDense: true,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                      items: List.generate(5, (i) => i + 1)
                          .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text('$v 级'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => maxDepth = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('每级最多子任务', style: Theme.of(ctx).textTheme.bodyMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: maxChildren,
                      isDense: true,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                      items: List.generate(9, (i) => i + 2)
                          .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text('$v 个'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => maxChildren = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: AppTheme.borderSubtle),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(
                      ctx,
                      DecomposeConfig(maxDepth: maxDepth, maxChildrenPerNode: maxChildren),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('开始拆分'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String _subtaskTitleKey(String title) {
  var value = title.trim().toLowerCase();
  value = value.replaceAll(RegExp(r'^\s*(\d+|[一二三四五六七八九十]+)[\.、\)、\s-]*'), '');
  value = value.replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');
  const prefixes = ['完成', '进行', '处理', '整理', '准备', '实现', '优化', '修复'];
  for (final prefix in prefixes) {
    if (value.startsWith(prefix) && value.length > prefix.length + 2) {
      value = value.substring(prefix.length);
      break;
    }
  }
  return value;
}

bool _subtaskTitleMatches(String title, Iterable<String> existing) {
  final key = _subtaskTitleKey(title);
  if (key.isEmpty) return true;
  for (final raw in existing) {
    final existingKey = _subtaskTitleKey(raw);
    if (existingKey.isEmpty) continue;
    if (existingKey == key) return true;
    if (existingKey.contains(key) || key.contains(existingKey)) return true;
    final chars = key.split('').toSet();
    final other = existingKey.split('').toSet();
    final union = chars.union(other).length;
    if (union > 0 && chars.intersection(other).length / union >= 0.72) {
      return true;
    }
  }
  return false;
}

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
    return _subtaskTitleMatches(title, existing);
  }

  Future<void> _decompose() async {
    if (!SubscriptionService.instance.canUseAiDecompose()) {
      if (mounted) {
        UpgradeDialog.show(context, message: 'AI智能拆分为VIP专属功能，升级VIP解锁');
      }
      return;
    }

    final config = await showDecomposeConfigSheet(context);
    if (config == null || !mounted) return;

    setState(() => _isDecomposing = true);

    try {
      final bloc = context.read<TaskNewBloc>();
      final repo = bloc.taskRepository;

      // 1) 收集附件
      final attachmentContents = <String>[];
      final attachments = await _attachmentService.getAttachments(
        widget.task.id,
      );
      for (final a in attachments) {
        // 仅读取已下载到本地的；未下载的此处跳过（AI 不需要）
        if (a.localPath == null) continue;
        final content = await _attachmentService.readFileContent(a.localPath!);
        if (content.isNotEmpty) {
          attachmentContents.add(
            content.length > 3000 ? content.substring(0, 3000) : content,
          );
        }
      }

      // 2) 现有后代用于 dedup
      final existingDescendants = await repo.getDescendants(widget.task.id);
      final existingTitles = existingDescendants
          .map((t) => t.title.trim())
          .toList();

      // 3) 调 AI
      final descToUse = widget.currentDescription.isNotEmpty
          ? widget.currentDescription
          : widget.task.description;
      final result = await _decompositionService.decompose(
        widget.task.title,
        descToUse,
        attachmentContents,
        existingTaskTitles: existingTitles,
        maxDepth: config.maxDepth,
        maxChildrenPerNode: config.maxChildrenPerNode,
      );

      if (result.nodes.isEmpty) {
        if (mounted) {
          showAppSnackBar(
            context,
            result.allDuplicates ? '子任务已完整，无需重复分解' : 'AI 分解失败，请重试',
          );
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
          priority: 1, // 默认"低"
          estimatedMinutes: isLeaf ? node.estimatedMinutes : null,
        );
        existingTitles.add(node.title.trim());
        created++;
        if (isLeaf) {
          createdLeaves.add(
            _CreatedLeaf(id: t.id, minutes: node.estimatedMinutes ?? 60),
          );
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
          showAppSnackBar(context, '新增 $created 个子任务（无叶子，无需排程）');
          context.read<TaskNewBloc>().add(
            LoadSubTree(rootTaskId: widget.task.id),
          );
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
            title:
                '即将开始：${_titleOf(s.taskId, createdLeaves, result.nodes) ?? '子任务'}',
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
        final s = context.read<TaskNewBloc>().state;
        context.read<TaskNewBloc>().add(LoadTasks(
          statusFilter: s is TaskNewLoaded ? s.selectedStatusFilter : null,
        ));
        context.read<TaskNewBloc>().add(
          LoadSubTree(rootTaskId: widget.task.id),
        );
        showAppSnackBar(context, '新增 $created 个子任务，已自动排到日历');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, '拆解失败：$e');
      }
    } finally {
      if (mounted) setState(() => _isDecomposing = false);
    }
  }

  String? _titleOf(
    String id,
    List<_CreatedLeaf> leaves,
    List<SubtaskNode> tree,
  ) {
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
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: AppTheme.textPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI 拆分子任务',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!SubscriptionService.instance.isVip) ...[
                  const SizedBox(width: 6),
                  const VipLockIcon(size: 16),
                ],
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.call_split_rounded, size: 18),
                label: Text(_isDecomposing ? 'AI 拆解中...' : '一键拆分子任务'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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

/// 公共入口：供其他 UI（如 task_detail 顶部 chip 按钮）触发 AI 拆分。
/// 返回新增的叶子数；过程中失败/无可拆会 SnackBar 提示。
Future<int> runAiDecompose({
  required BuildContext context,
  required Task task,
  required String projectId,
  String currentDescription = '',
  int maxDepth = 3,
  int maxChildrenPerNode = 5,
}) async {
  final attachmentService = TaskAttachmentService();
  final decomposition = TaskDecompositionService();
  final bloc = context.read<TaskNewBloc>();
  final repo = bloc.taskRepository;

  bool isSimilarToAny(String title, List<String> existing) {
    return _subtaskTitleMatches(title, existing);
  }

  try {
    // 1) 收集附件文本
    final attachmentContents = <String>[];
    final attachments = await attachmentService.getAttachments(task.id);
    for (final a in attachments) {
      if (a.localPath == null) continue;
      final content = await attachmentService.readFileContent(a.localPath!);
      if (content.isNotEmpty) {
        attachmentContents.add(
          content.length > 3000 ? content.substring(0, 3000) : content,
        );
      }
    }

    final existingDescendants = await repo.getDescendants(task.id);
    final existingTitles = existingDescendants
        .map((t) => t.title.trim())
        .toList();

    final descToUse = currentDescription.isNotEmpty
        ? currentDescription
        : task.description;
    final result = await decomposition.decompose(
      task.title,
      descToUse,
      attachmentContents,
      existingTaskTitles: existingTitles,
      maxDepth: maxDepth,
      maxChildrenPerNode: maxChildrenPerNode,
    );

    if (result.nodes.isEmpty) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          result.allDuplicates ? '子任务已完整，无需重复分解' : 'AI 分解失败，请重试',
        );
      }
      return 0;
    }

    final createdLeaves = <_CreatedLeaf>[];
    final parentToLeafIds = <String, List<String>>{};
    int created = 0;

    Future<void> walk(SubtaskNode node, String parentId) async {
      if (isSimilarToAny(node.title.trim(), existingTitles)) return;
      final isLeaf = node.children.isEmpty;
      final t = await repo.create(
        projectId: projectId,
        title: node.title.trim(),
        parentId: parentId,
        priority: 1,
        estimatedMinutes: isLeaf ? node.estimatedMinutes : null,
      );
      existingTitles.add(node.title.trim());
      created++;
      if (isLeaf) {
        createdLeaves.add(
          _CreatedLeaf(id: t.id, minutes: node.estimatedMinutes ?? 60),
        );
      } else {
        parentToLeafIds[t.id] = [];
        for (final child in node.children) {
          final beforeLen = createdLeaves.length;
          await walk(child, t.id);
          for (int i = beforeLen; i < createdLeaves.length; i++) {
            parentToLeafIds[t.id]!.add(createdLeaves[i].id);
          }
        }
      }
    }

    for (final node in result.nodes) {
      await walk(node, task.id);
    }
    parentToLeafIds[task.id] = createdLeaves.map((e) => e.id).toList();

    if (createdLeaves.isEmpty) {
      if (context.mounted) {
        showAppSnackBar(context, '新增 $created 个子任务（无叶子，无需排程）');
        context.read<TaskNewBloc>().add(LoadSubTree(rootTaskId: task.id));
      }
      return created;
    }

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

    for (final s in slots) {
      await repo.update(
        s.taskId,
        startDate: s.start.millisecondsSinceEpoch,
        dueDate: s.end.millisecondsSinceEpoch,
        reminderEnabled: 1,
        remindBeforeMinutes: 5,
      );
      try {
        await NotificationService().scheduleReminderForSchedule(
          scheduleId: s.taskId,
          title: '即将开始：子任务',
          startTime: s.start,
          description: null,
          remindBeforeMinutes: 5,
          isRepeating: false,
          repeatInterval: null,
        );
      } catch (_) {}
    }

    final parentSpans = computeParentSpans(
      parentToLeafIds: parentToLeafIds,
      slots: slots,
    );
    for (final entry in parentSpans.entries) {
      await repo.update(
        entry.key,
        startDate: entry.value.start.millisecondsSinceEpoch,
        dueDate: entry.value.end.millisecondsSinceEpoch,
      );
    }

    if (context.mounted) {
      final s = context.read<TaskNewBloc>().state;
      context.read<TaskNewBloc>().add(LoadTasks(
        statusFilter: s is TaskNewLoaded ? s.selectedStatusFilter : null,
      ));
      context.read<TaskNewBloc>().add(LoadSubTree(rootTaskId: task.id));
      showAppSnackBar(context, '新增 $created 个子任务，已自动排到日历');
    }
    return created;
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, '拆解失败：$e');
    }
    return 0;
  }
}
