import 'package:flutter/material.dart';
import '../../services/task_conflict_service.dart';

Future<ConflictChoice?> showTaskConflictDialog(
  BuildContext context, {
  required ConflictInfo conflict,
  required DateTime newStart,
  required DateTime newEnd,
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
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ConflictChoice.parallel),
          child: const Text('并行'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ConflictChoice.autoInsert),
          child: const Text('自动插入'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ConflictChoice.autoDelay),
          child: const Text('自动延后'),
        ),
      ],
    ),
  );
}
