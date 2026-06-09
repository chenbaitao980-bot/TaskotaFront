import 'package:flutter/material.dart';

/// 桌面端任务提醒持久卡片（通过 Overlay 显示在屏幕右下角，不会自动消失）
class ReminderDialog extends StatefulWidget {
  final String title;
  final String body;
  /// 关闭卡片（移除 OverlayEntry + 处理队列），所有按钮操作前均须调用
  final VoidCallback onClose;
  final VoidCallback? onMarkDone;
  final void Function(Duration delay)? onSnooze;
  /// "查看详情"：关闭后导航到对应任务
  final VoidCallback? onViewDetail;

  const ReminderDialog({
    super.key,
    required this.title,
    required this.body,
    required this.onClose,
    this.onMarkDone,
    this.onSnooze,
    this.onViewDetail,
  });

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  bool _showSnoozeOptions = false;

  static const _snoozeOptions = [
    (label: '5 分钟后', duration: Duration(minutes: 5)),
    (label: '15 分钟后', duration: Duration(minutes: 15)),
    (label: '30 分钟后', duration: Duration(minutes: 30)),
    (label: '60 分钟后', duration: Duration(minutes: 60)),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: colorScheme.surface,
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.alarm, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.body,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (_showSnoozeOptions) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 4),
                ..._snoozeOptions.map(
                  (opt) => InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      widget.onClose();
                      widget.onSnooze?.call(opt.duration);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, size: 16),
                          const SizedBox(width: 8),
                          Text(opt.label, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_showSnoozeOptions)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () =>
                          setState(() => _showSnoozeOptions = false),
                      child: const Text('取消'),
                    ),
                  ],
                )
              else
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () =>
                          setState(() => _showSnoozeOptions = true),
                      child: const Text('稍后提醒'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        widget.onClose();
                        widget.onMarkDone?.call();
                      },
                      child: const Text('标记完成'),
                    ),
                    if (widget.onViewDetail != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          widget.onClose();
                          widget.onViewDetail?.call();
                        },
                        child: const Text('查看详情'),
                      ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: widget.onClose,
                      child: const Text('知道了'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
