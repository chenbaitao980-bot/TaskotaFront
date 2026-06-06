import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../common/image_preview_page.dart';
import '../../../../../data/database/app_database.dart' hide TaskAttachment;
import '../../../../../services/attachment_sync_service.dart';
import '../../../../../services/task_attachment_service.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

class AttachmentImageStrip extends StatefulWidget {
  final String taskId;
  final double maxHeight;
  final bool showDeleteButton;
  final bool showCopyButton;

  const AttachmentImageStrip({
    super.key,
    required this.taskId,
    this.maxHeight = 180,
    this.showDeleteButton = false,
    this.showCopyButton = false,
  });

  @override
  State<AttachmentImageStrip> createState() => _AttachmentImageStripState();
}

class _AttachmentImageStripState extends State<AttachmentImageStrip> {
  final _service = TaskAttachmentService();
  List<TaskAttachment> _images = [];
  StreamSubscription<void>? _syncSub;

  @override
  void initState() {
    super.initState();
    _load();
    _syncSub = AttachmentSyncService.instance.changes.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant AttachmentImageStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) _load();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final attachments = await _service.getAttachments(widget.taskId);
    if (mounted) {
      setState(() => _images = attachments.where((a) => a.isImage).toList());
    }
  }

  Future<void> _open(TaskAttachment attachment) async {
    final file = await _service.ensureLocalFile(attachment);
    if (file == null || !mounted) return;
    final files = _images
        .map((img) {
          final p = img.localPath;
          return p == null ? null : File(p);
        })
        .where((f) => f != null && f.existsSync())
        .cast<File>()
        .toList();
    final tappedIndex = files.indexWhere((f) => f.path == file.path);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewPage(
          images: files.isEmpty ? [file] : files,
          initialIndex: tappedIndex >= 0 ? tappedIndex : 0,
        ),
      ),
    );
  }

  Future<void> _delete(TaskAttachment attachment) async {
    await _service.deleteAttachment(widget.taskId, attachment.id);
    await _load();
  }

  Future<void> _copy(TaskAttachment attachment) async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      if (mounted) showAppSnackBar(context, '剪贴板不可用');
      return;
    }
    final file = await _service.ensureLocalFile(attachment);
    if (file == null || !file.existsSync()) {
      if (mounted) showAppSnackBar(context, '图片文件不可用');
      return;
    }
    final bytes = await file.readAsBytes();
    final item = DataWriterItem(suggestedName: attachment.fileName);
    final name = attachment.fileName.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      item.add(Formats.jpeg(bytes));
    } else if (name.endsWith('.gif')) {
      item.add(Formats.gif(bytes));
    } else if (name.endsWith('.webp')) {
      item.add(Formats.webp(bytes));
    } else {
      item.add(Formats.png(bytes));
    }
    await clipboard.write([item]);
    if (mounted) showAppSnackBar(context, '图片已复制');
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: widget.maxHeight,
      child: Scrollbar(
        thumbVisibility: _images.length > 2,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _images.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final image = _images[index];
            final path = image.localPath;
            final file = path == null ? null : File(path);
            final thumb = ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: widget.maxHeight * 1.25,
                color: AppTheme.bgInput,
                child: file != null && file.existsSync()
                    ? Image.file(file, fit: BoxFit.cover)
                    : Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: AppTheme.textHint,
                        ),
                      ),
              ),
            );
            if (!widget.showDeleteButton && !widget.showCopyButton) {
              return InkWell(
                onTap: () => _open(image),
                borderRadius: BorderRadius.circular(8),
                child: thumb,
              );
            }
            return Stack(
              children: [
                InkWell(
                  onTap: () => _open(image),
                  borderRadius: BorderRadius.circular(8),
                  child: thumb,
                ),
                if (widget.showDeleteButton)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _delete(image),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                if (widget.showCopyButton)
                  Positioned(
                    top: 4,
                    right: widget.showDeleteButton ? 28 : 4,
                    child: GestureDetector(
                      onTap: () => _copy(image),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

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
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await _service.saveAttachment(widget.task.id, file);
      await _load();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImageFile() async {
    final file = await _service.pickImageFile();
    if (file == null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await _service.saveAttachment(widget.task.id, file);
      await _load();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteFile(TaskAttachment attachment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除附件'),
        content: Text('确定要删除"${attachment.fileName}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
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
                Icon(
                  Icons.attach_file_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
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
                  onPressed: _loading ? null : _pickImageFile,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 16,
                  ),
                  color: AppTheme.primaryColor,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  tooltip: '上传图片',
                ),
                IconButton(
                  onPressed: _loading ? null : _pickFile,
                  icon: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded, size: 16),
                  color: AppTheme.primaryColor,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
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
                children: _attachments
                    .map((a) => _buildAttachmentRow(a))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentRow(TaskAttachment attachment) {
    final isText =
        attachment.fileName.endsWith('.md') ||
        attachment.fileName.endsWith('.txt') ||
        attachment.fileName.endsWith('.json');
    final icon = isText
        ? Icons.description_outlined
        : Icons.insert_drive_file_outlined;

    final opening = _openingId == attachment.id;
    return InkWell(
      onTap: opening ? null : () => _openAttachment(attachment),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            opening
                ? const SizedBox(
                    width: 14,
                    height: 14,
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
