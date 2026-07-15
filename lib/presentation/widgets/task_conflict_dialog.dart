import 'package:flutter/material.dart';
import '../../services/task_conflict_service.dart';

Future<ConflictChoice?> showTaskConflictDialog(
  BuildContext context, {
  required ConflictInfo conflict,
  required DateTime newStart,
  required DateTime newEnd,
  String cancelLabel = '取消',
  String parallelLabel = '并行',
  String autoInsertLabel = '自动插入',
  String autoDelayLabel = '自动延后',
  bool showParallel = true,
}) {
  String fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return showDialog<ConflictChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('时间冲突'),
      content: Text(
        '「${conflict.title}」已安排 ${fmt(conflict.start)}—${fmt(conflict.end)}，'
        '与当前时段（${fmt(newStart)}—${fmt(newEnd)}）重叠。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, ConflictChoice.cancel),
          child: Text(cancelLabel),
        ),
        if (showParallel)
          TextButton(
            onPressed: () => Navigator.pop(ctx, ConflictChoice.parallel),
            child: Text(parallelLabel),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ConflictChoice.autoInsert),
          child: Text(autoInsertLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ConflictChoice.autoDelay),
          child: Text(autoDelayLabel),
        ),
      ],
    ),
  );
}
