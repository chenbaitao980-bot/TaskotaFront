import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/desktop/desktop_floating_tab_controller.dart';
import '../../core/theme/app_theme.dart';

class DesktopFloatingTaskTab extends StatelessWidget {
  final DesktopFloatingTaskSummary task;
  final VoidCallback onTap;
  final Future<void> Function() onClose;

  const DesktopFloatingTaskTab({
    super.key,
    required this.task,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) async {
        final overlay = Overlay.maybeOf(context);
        final renderBox =
            overlay?.context.findRenderObject() as RenderBox?;
        if (overlay == null || renderBox == null) return;
        final selection = await showMenu<String>(
          context: context,
          position: RelativeRect.fromRect(
            Rect.fromLTWH(
              details.globalPosition.dx,
              details.globalPosition.dy,
              1,
              1,
            ),
            Offset.zero & renderBox.size,
          ),
          items: const [
            PopupMenuItem<String>(value: 'close', child: Text('关闭页签')),
          ],
        );
        if (selection == 'close') {
          await onClose();
        }
      },
      child: DragToMoveArea(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppTheme.bgCard.withValues(alpha: 0.96),
                border: Border.all(
                  color: _priorityColor(
                    task.priority,
                  ).withValues(alpha: 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _priorityColor(task.priority),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '当前进行中',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Tooltip(
                          message: task.title,
                          waitDuration: const Duration(milliseconds: 400),
                          child: Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle(task),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (task.extraTaskCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '+${task.extraTaskCount}',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Icon(
                        Icons.open_in_full_rounded,
                        size: 18,
                        color: AppTheme.textHint,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(DesktopFloatingTaskSummary task) {
    final date = task.dueDate ?? task.anchorDate;
    final dueText =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${_priorityLabel(task.priority)} · $dueText';
  }

  String _priorityLabel(int priority) {
    return switch (priority) {
      5 => 'P0 紧急',
      3 => 'P1 重要',
      1 => 'P2 普通',
      _ => 'P3 稍后',
    };
  }

  Color _priorityColor(int priority) {
    return switch (priority) {
      5 => AppTheme.priorityP0,
      3 => AppTheme.priorityP1,
      1 => AppTheme.priorityP2,
      _ => AppTheme.priorityP3,
    };
  }
}
