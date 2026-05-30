import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/database/app_database.dart';
import '../../../../../services/obsidian_service.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

class ChecklistSection extends StatefulWidget {
  final List<ChecklistItem> items;
  final String taskId;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onDelete;
  final void Function(String id, String title) onEdit;
  final ValueChanged<(String, String)> onAdd;
  final void Function(String id, String? obsidianUri) onSetObsidianUri;

  const ChecklistSection({
    super.key,
    required this.items,
    required this.taskId,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onAdd,
    required this.onSetObsidianUri,
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
                Icon(Icons.checklist_rounded,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '检查项 ${total > 0 ? '($completed/$total)' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: completed / total,
                  backgroundColor: AppTheme.borderSubtle,
                  color: AppTheme.success,
                  minHeight: 3,
                ),
              ),
            ),
          // 列表（限高+滚动）
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.items.map((item) => _buildItem(item)).toList(),
              ),
            ),
          ),
          // 添加输入框
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
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
    final hasObsidian = item.obsidianUri != null && item.obsidianUri!.isNotEmpty;

    return GestureDetector(
      onLongPress: () => _showContextMenu(item),
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
            // Obsidian 链接图标
            if (hasObsidian)
              GestureDetector(
                onTap: () => _openObsidianLink(item),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            // 删除
            GestureDetector(
              onTap: () => widget.onDelete(item.id),
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close, size: 16, color: AppTheme.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(ChecklistItem item) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑标题'),
              onTap: () {
                Navigator.pop(ctx);
                _editItem(item);
              },
            ),
            ListTile(
              leading: Icon(
                item.obsidianUri != null && item.obsidianUri!.isNotEmpty
                    ? Icons.link
                    : Icons.link_off,
                color: AppTheme.primaryColor,
              ),
              title: Text(
                item.obsidianUri != null && item.obsidianUri!.isNotEmpty
                    ? '更改 Obsidian 关联'
                    : '关联 Obsidian',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showObsidianDialog(item);
              },
            ),
            if (item.obsidianUri != null && item.obsidianUri!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.link_off, color: AppTheme.textHint),
                title: const Text('移除 Obsidian 关联'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onSetObsidianUri(item.id, null);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppTheme.error),
              title:
                  Text('删除', style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                widget.onDelete(item.id);
              },
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
                widget.onEdit(item.id, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showObsidianDialog(ChecklistItem item) {
    // 解析已有关联，用于预填
    final existingUri = item.obsidianUri;

    showDialog(
      context: context,
      builder: (ctx) => _ObsidianLinkDialog(
        existingUri: existingUri,
        onConfirm: (uri) {
          widget.onSetObsidianUri(item.id, uri);
        },
      ),
    );
  }

  void _openObsidianLink(ChecklistItem item) async {
    final uri = item.obsidianUri;
    if (uri == null || uri.isEmpty) return;

    final success = await ObsidianService.openUri(uri);
    if (!success && mounted) {
      showAppSnackBar(context, '无法打开 Obsidian，请确认已安装');
    }
  }
}

// --- Obsidian 关联对话框（文件选择器 + 自动检测 Vault） ---

class _ObsidianLinkDialog extends StatefulWidget {
  final String? existingUri;
  final void Function(String? uri) onConfirm;

  const _ObsidianLinkDialog({this.existingUri, required this.onConfirm});

  @override
  State<_ObsidianLinkDialog> createState() => _ObsidianLinkDialogState();
}

class _ObsidianLinkDialogState extends State<_ObsidianLinkDialog> {
  String? _selectedFilePath; // 绝对路径
  String? _vaultName;
  String? _relativePath;
  String _documentName = '';
  final _headingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 预填已有关联
    final uri = widget.existingUri;
    if (uri != null && uri.isNotEmpty) {
      // 解析 vault 名称与相对路径
      _vaultName = ObsidianService.parseVault(uri);
      _relativePath = ObsidianService.parseFilePath(uri);
      if (_relativePath != null) {
        // URI 中路径用正斜杠，需要兼容两种分隔符取文件名
        final name = _relativePath!.replaceAll('/', '\\').split('\\').last;
        _documentName = name.endsWith('.md')
            ? name.substring(0, name.length - 3)
            : name;
      }
      // 解析 heading
      final heading = ObsidianService.parseHeading(uri);
      if (heading != null) _headingController.text = heading;
    }
  }

  @override
  void dispose() {
    _headingController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md'],
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    // 自动检测 Vault
    final vaultInfo = ObsidianService.detectVault(filePath);

    setState(() {
      _selectedFilePath = filePath;
      _documentName = ObsidianService.documentName(filePath);
      if (vaultInfo != null) {
        _vaultName = vaultInfo.vaultName;
        _relativePath = ObsidianService.relativePath(filePath, vaultInfo.vaultRoot);
      } else {
        _vaultName = null;
        _relativePath = null;
      }
    });
  }

  void _confirm() {
    if (_relativePath == null || _vaultName == null) {
      showAppSnackBar(context, '请先选择一个 Obsidian Vault 内的 .md 文件');
      return;
    }

    final heading = _headingController.text.trim();
    final uri = ObsidianService.buildUri(
      vault: _vaultName!,
      filePath: _relativePath!,
      heading: heading.isNotEmpty ? heading : null,
    );

    widget.onConfirm(uri);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('关联 Obsidian 文档'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 文件选择
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedFilePath != null
                        ? _documentName
                        : '未选择文件',
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedFilePath != null
                          ? AppTheme.textPrimary
                          : AppTheme.textHint,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('浏览'),
                ),
              ],
            ),
            // 自动检测信息
            if (_vaultName != null) ...[
              const SizedBox(height: 12),
              _infoRow('Vault', _vaultName!),
              const SizedBox(height: 4),
              _infoRow('路径', _relativePath!),
            ] else if (_selectedFilePath != null) ...[
              const SizedBox(height: 8),
              Text(
                '未检测到 Obsidian Vault（.obsidian 目录）',
                style: TextStyle(fontSize: 12, color: AppTheme.warning),
              ),
            ],
            const SizedBox(height: 12),
            // 标题（可选）
            TextField(
              controller: _headingController,
              decoration: InputDecoration(
                labelText: '跳转到标题（可选）',
                hintText: '例如: ## 实现方案',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: Tooltip(
                  message: '需要安装 Obsidian Advanced URI 插件',
                  child: Icon(Icons.info_outline,
                      size: 16, color: AppTheme.textHint),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _confirm,
          child: const Text('确认'),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textHint,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
