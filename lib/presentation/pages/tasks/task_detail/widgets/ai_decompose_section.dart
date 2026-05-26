import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/database/app_database.dart';
import '../../../../../services/task_attachment_service.dart';
import '../../../../../services/task_decomposition_service.dart';
import '../../../../blocs/task_new/task_bloc.dart';
import '../../../../blocs/task_new/task_event.dart';
import '../../../../blocs/task_new/task_state.dart';

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

  /// Minimal fuzzy duplicate check (mirrors service logic).
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
      // 1. Collect attachment content
      final attachmentContents = <String>[];
      final attachments = await _attachmentService.getAttachments(widget.task.id);
      for (final a in attachments) {
        final content = await _attachmentService.readFileContent(a.filePath);
        if (content.isNotEmpty) {
          attachmentContents.add(content.length > 3000 ? content.substring(0, 3000) : content);
        }
      }

      // 2. Get existing subtask titles for dedup
      final bloc = context.read<TaskNewBloc>();
      final existingTitles = <String>[];
      final state = bloc.state;
      if (state is TaskNewLoaded) {
        final descendants = await bloc.taskRepository.getDescendants(widget.task.id);
        existingTitles.addAll(descendants.map((t) => t.title.trim()));
      }

      // 3. Call AI to decompose (with existing titles to avoid duplicates)
      final descToUse = widget.currentDescription.isNotEmpty
          ? widget.currentDescription
          : widget.task.description;
      final result = await _decompositionService.decompose(
        widget.task.title,
        descToUse,
        attachmentContents,
        existingTaskTitles: existingTitles,
      );

      final tree = result.nodes;

      // 4. Handle empty / all-duplicates cases
      if (tree.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.allDuplicates
                ? '子任务已完整，无需重复分解'
                : 'AI 分解失败，请重试')),
          );
        }
        return;
      }

      // 5. Create level-1 subtasks (already deduped by the service)
      int created = 0;
      for (final node in tree) {
        // Double-check: fuzzy dedup guard
        if (_isSimilarToAny(node.title.trim(), existingTitles)) continue;
        bloc.add(AddSubTask(
          parentId: widget.task.id,
          title: node.title,
          projectId: widget.projectId,
        ));
        existingTitles.add(node.title.trim());
        created++;
      }

      // 6. Wait then create level-2+ children
      final hasDeepChildren = tree.any((n) => n.children.isNotEmpty);
      if (hasDeepChildren) {
        await Future.delayed(const Duration(milliseconds: 800));
        final currentState = bloc.state;
        if (currentState is TaskNewLoaded) {
          final descendants = await bloc.taskRepository.getDescendants(widget.task.id);
          final childExisting = descendants.map((t) => t.title.trim()).toList();
          for (final node in tree) {
            if (node.children.isEmpty) continue;
            final parent = descendants.where((t) => t.title.trim() == node.title.trim()).firstOrNull;
            if (parent != null) {
              for (final child in node.children) {
                if (_isSimilarToAny(child.title.trim(), childExisting)) continue;
                bloc.add(AddSubTask(
                  parentId: parent.id,
                  title: child.title,
                  projectId: widget.projectId,
                ));
                childExisting.add(child.title.trim());
                created++;
              }
            }
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            created > 0 ? '新增 $created 个子任务' : '子任务已完整，无需重复分解')),
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
                const Icon(Icons.auto_awesome_rounded, size: 20, color: AppTheme.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'AI 拆分子任务',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.call_split_rounded, size: 18),
                label: Text(_isDecomposing ? 'AI 拆解中...' : '一键拆分子任务'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
