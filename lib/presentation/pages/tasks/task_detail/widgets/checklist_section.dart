import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/database/app_database.dart';

class ChecklistSection extends StatefulWidget {
  final List<ChecklistItem> items;
  final String taskId;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onEdit;
  final ValueChanged<(String, String)> onAdd;

  const ChecklistSection({
    super.key,
    required this.items,
    required this.taskId,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onAdd,
  });

  @override
  State<ChecklistSection> createState() => _ChecklistSectionState();
}

class _ChecklistSectionState extends State<ChecklistSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.items.where((i) => i.status == 1).length;
    final total = widget.items.length;

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
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.checklist_rounded,
                    size: 20, color: AppTheme.textPrimary),
                const SizedBox(width: 8),
                Text(
                  '检查项',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (total > 0)
                  Text(
                    '$completed/$total',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textHint,
                    ),
                  ),
              ],
            ),
          ),
          // 进度条
          if (total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completed / total,
                  backgroundColor: AppTheme.borderSubtle,
                  color: AppTheme.success,
                  minHeight: 4,
                ),
              ),
            ),
          const SizedBox(height: 4),
          // 列表
          ...widget.items.map((item) => _buildItem(item)),
          // 添加输入框
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '添加检查项...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        widget.onAdd((widget.taskId, value.trim()));
                        _controller.clear();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(ChecklistItem item) {
    final isCompleted = item.status == 1;
    return InkWell(
      onTap: () => widget.onToggle(item.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            // 复选框
            GestureDetector(
              onTap: () => widget.onToggle(item.id),
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? AppTheme.success : Colors.transparent,
                  border: Border.all(
                    color: isCompleted ? AppTheme.success : AppTheme.textHint,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            // 标题
            Expanded(
              child: GestureDetector(
                onDoubleTap: () => _editItem(item),
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isCompleted
                        ? AppTheme.textHint
                        : AppTheme.textPrimary,
                    decoration:
                        isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
            // 删除
            GestureDetector(
              onTap: () => widget.onDelete(item.id),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close, size: 16, color: AppTheme.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editItem(ChecklistItem item) {
    final controller = TextEditingController(text: item.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑检查项'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入新标题',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.onEdit(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
