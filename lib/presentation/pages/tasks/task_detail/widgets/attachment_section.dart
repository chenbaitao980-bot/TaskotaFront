import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/database/app_database.dart';
import '../../../../../services/task_attachment_service.dart';

class AttachmentSection extends StatefulWidget {
  final Task task;

  const AttachmentSection({super.key, required this.task});

  @override
  State<AttachmentSection> createState() => _AttachmentSectionState();
}

class _AttachmentSectionState extends State<AttachmentSection> {
  final _service = TaskAttachmentService();
  List<TaskAttachment> _attachments = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final attachments = await _service.getAttachments(widget.task.id);
    if (mounted) setState(() => _attachments = attachments);
  }

  Future<void> _pickFile() async {
    final file = await _service.pickFile();
    if (file == null) return;
    setState(() => _loading = true);
    await _service.saveAttachment(widget.task.id, file);
    await _load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteFile(TaskAttachment attachment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除附件'),
        content: Text('确定要删除"${attachment.fileName}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteAttachment(widget.task.id, attachment.filePath);
      await _load();
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
                const Icon(Icons.attach_file_rounded, size: 20, color: AppTheme.textPrimary),
                const SizedBox(width: 8),
                Text(
                  '附件',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loading ? null : _pickFile,
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_rounded, size: 16),
                  label: const Text('上传'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          if (_attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                '暂无附件',
                style: TextStyle(color: AppTheme.textHint, fontSize: 13),
              ),
            )
          else
            ..._attachments.map((a) => _buildAttachmentRow(a)),
        ],
      ),
    );
  }

  Widget _buildAttachmentRow(TaskAttachment attachment) {
    final isText = attachment.fileName.endsWith('.md') ||
        attachment.fileName.endsWith('.txt') ||
        attachment.fileName.endsWith('.json');
    final icon = isText ? Icons.description_outlined : Icons.insert_drive_file_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: () => _deleteFile(attachment),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.close, size: 16, color: AppTheme.textHint),
            ),
          ),
        ],
      ),
    );
  }
}
