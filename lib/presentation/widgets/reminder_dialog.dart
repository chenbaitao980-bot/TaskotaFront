import 'package:flutter/material.dart';

/// 桌面端任务提醒持久弹窗
///
/// 不会自动消失，用户必须主动点击按钮才能关闭。
class ReminderDialog extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback? onMarkDone;
  final void Function(Duration delay)? onSnooze;

  const ReminderDialog({
    super.key,
    required this.title,
    required this.body,
    this.onMarkDone,
    this.onSnooze,
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
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.alarm, color: Color(0xFF6750A4), size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.body, style: const TextStyle(fontSize: 14)),
            if (_showSnoozeOptions) ...[
              const SizedBox(height: 16),
              const Text(
                '选择提醒延迟时间：',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              ..._snoozeOptions.map(
                (opt) => ListTile(
                  dense: true,
                  title: Text(opt.label),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onSnooze?.call(opt.duration);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: _showSnoozeOptions
          ? [
              TextButton(
                onPressed: () => setState(() => _showSnoozeOptions = false),
                child: const Text('取消'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => setState(() => _showSnoozeOptions = true),
                child: const Text('稍后提醒'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onMarkDone?.call();
                },
                child: const Text('标记完成'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
    );
  }
}
