import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/database/app_database.dart' hide TaskAttachment;
import '../../../../../services/attachment_sync_service.dart';
import '../../../../../services/task_attachment_service.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

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
  StreamSubscription<void>? _syncSub;
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _load();
    _syncSub = AttachmentSyncService.instance.changes.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _openAttachment(TaskAttachment att) async {
    setState(() => _openingId = att.id);
    try {
      final file = await _service.ensureLocalFile(att);
      if (file == null) {
        if (mounted) {
          showAppSnackBar(context, '附件下载失败');
        }
        return;
      }
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        showAppSnackBar(context, '打开失败：${result.message}');
      }
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
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
      await _service.deleteAttachment(widget.task.id, attachment.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 紧凑头部
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
            child: Row(
              children: [
                Icon(Icons.attach_file_rounded, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '附件 (${_attachments.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : _pickFile,
                  icon: _loading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_rounded, size: 16),
                  color: AppTheme.primaryColor,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: '上传',
                ),
              ],
            ),
          ),
          if (_attachments.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(
                '暂无附件',
                style: TextStyle(color: AppTheme.textHint, fontSize: 11),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                children: _attachments.map((a) => _buildAttachmentRow(a)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentRow(TaskAttachment attachment) {
    final isText = attachment.fileName.endsWith('.md') ||
        attachment.fileName.endsWith('.txt') ||
        attachment.fileName.endsWith('.json');
    final icon = isText ? Icons.description_outlined : Icons.insert_drive_file_outlined;

    final opening = _openingId == attachment.id;
    return InkWell(
      onTap: opening ? null : () => _openAttachment(attachment),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            opening
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
              ),
            ),
            GestureDetector(
              onTap: () => _deleteFile(attachment),
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 12, color: AppTheme.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
