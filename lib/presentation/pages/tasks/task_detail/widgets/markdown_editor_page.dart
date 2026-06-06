import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../services/task_attachment_service.dart';
import '../../../../../core/utils/snackbar_helper.dart';
import 'attachment_section.dart';

/// 全屏 Markdown 编辑器页面
/// 点击"编辑"后打开，提供大面积编辑区、工具栏、预览切换、图片粘贴
class MarkdownEditorPage extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onTextChanged;
  final VoidCallback? onEditingComplete;
  final String taskId;
  final VoidCallback? onAttachmentChanged;

  const MarkdownEditorPage({
    super.key,
    required this.controller,
    this.onTextChanged,
    this.onEditingComplete,
    required this.taskId,
    this.onAttachmentChanged,
  });

  @override
  State<MarkdownEditorPage> createState() => _MarkdownEditorPageState();
}

class _MarkdownEditorPageState extends State<MarkdownEditorPage> {
  bool _showPreview = false;
  int _attachmentRefreshToken = 0;

  void _onAttachmentChanged() {
    setState(() => _attachmentRefreshToken++);
    widget.onAttachmentChanged?.call();
  }

  // ---- 图片操作 ----

  Future<void> _pickImage() async {
    final service = TaskAttachmentService();
    final file = await service.pickImageFile();
    if (file == null) return;
    await service.saveAttachment(widget.taskId, file);
    if (!mounted) return;
    _onAttachmentChanged();
    showAppSnackBar(context, '图片已添加');
  }

  Future<void> _handlePaste() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;
    final reader = await clipboard.read();

    // 1) 剪贴板有图片 → 上传
    if (reader.canProvide(Formats.png)) {
      final completer = Completer<Uint8List?>();
      reader.getFile(
        Formats.png,
        (file) async {
          try {
            completer.complete(await file.readAll());
          } catch (_) {
            completer.complete(null);
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(null);
        },
      );
      final bytes = await completer.future;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) showAppSnackBar(context, '读取剪贴板图片失败');
        return;
      }
      await TaskAttachmentService().saveImageBytes(
        widget.taskId,
        fileName: 'pasted_${DateTime.now().millisecondsSinceEpoch}.png',
        bytes: bytes,
      );
      if (!mounted) return;
      _onAttachmentChanged();
      showAppSnackBar(context, '图片已添加');
      return;
    }

    // 2) 剪贴板有文字 → 手动插入（确保原生文字粘贴不被拦截）
    if (reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);
      if (text != null && text.isNotEmpty) {
        _insertText(text);
      }
    }
  }

  void _insertText(String text) {
    final ctrl = widget.controller;
    final sel = ctrl.selection;
    final start = sel.start;
    final end = sel.end;
    if (start < 0) return;
    final newText = ctrl.text.replaceRange(start, end, text);
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    widget.onTextChanged?.call();
  }

  Future<void> _handleDroppedImages(DropDoneDetails detail) async {
    var saved = 0;
    for (final file in detail.files) {
      final name =
          file.name.isNotEmpty ? file.name : file.path.split('/').last;
      if (!TaskAttachmentService.isImageFile(name, null)) continue;
      final bytes = await file.readAsBytes();
      await TaskAttachmentService().saveImageBytes(
        widget.taskId,
        fileName: name,
        bytes: bytes,
      );
      saved++;
    }
    if (!mounted) return;
    if (saved == 0) {
      showAppSnackBar(context, '只支持拖入图片文件');
      return;
    }
    _onAttachmentChanged();
    showAppSnackBar(context, '已添加 $saved 张图片');
  }

  // ---- Markdown 工具栏 ----

  void _insertMarkdown(_MarkdownAction action) {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;
    final start = sel.start;
    final end = sel.end;
    if (start < 0) return;

    final selected = start == end ? '' : text.substring(start, end);
    String insert;
    int cursorOffset;

    switch (action) {
      case _MarkdownAction.h1:
        insert = '# ${selected.isEmpty ? "标题" : selected}';
        cursorOffset = selected.isEmpty ? 2 : insert.length;
      case _MarkdownAction.h2:
        insert = '## ${selected.isEmpty ? "标题" : selected}';
        cursorOffset = selected.isEmpty ? 3 : insert.length;
      case _MarkdownAction.h3:
        insert = '### ${selected.isEmpty ? "标题" : selected}';
        cursorOffset = selected.isEmpty ? 4 : insert.length;
      case _MarkdownAction.bold:
        insert = '**${selected.isEmpty ? "粗体" : selected}**';
        cursorOffset = selected.isEmpty ? 2 : insert.length - 2;
      case _MarkdownAction.italic:
        insert = '*${selected.isEmpty ? "斜体" : selected}*';
        cursorOffset = selected.isEmpty ? 1 : insert.length - 1;
      case _MarkdownAction.strikethrough:
        insert = '~~${selected.isEmpty ? "删除线" : selected}~~';
        cursorOffset = selected.isEmpty ? 2 : insert.length - 2;
      case _MarkdownAction.unorderedList:
        insert = '- ${selected.isEmpty ? "列表项" : selected}';
        cursorOffset = insert.length;
      case _MarkdownAction.orderedList:
        insert = '1. ${selected.isEmpty ? "列表项" : selected}';
        cursorOffset = insert.length;
      case _MarkdownAction.taskList:
        insert = '- [ ] ${selected.isEmpty ? "待办项" : selected}';
        cursorOffset = insert.length;
      case _MarkdownAction.quote:
        insert = '> ${selected.isEmpty ? "引用" : selected}';
        cursorOffset = insert.length;
      case _MarkdownAction.inlineCode:
        insert = '`${selected.isEmpty ? "代码" : selected}`';
        cursorOffset = selected.isEmpty ? 1 : insert.length - 1;
      case _MarkdownAction.codeBlock:
        insert = '```\n${selected.isEmpty ? "" : selected}\n```';
        cursorOffset = selected.isEmpty ? 4 : insert.length - 4;
      case _MarkdownAction.link:
        insert = '[${selected.isEmpty ? "链接文本" : selected}](url)';
        cursorOffset = insert.length - 1;
      case _MarkdownAction.divider:
        insert = '\n---\n';
        cursorOffset = insert.length;
      case _MarkdownAction.table:
        insert =
            '| 列1 | 列2 | 列3 |\n| --- | --- | --- |\n| 内容 | 内容 | 内容 |';
        cursorOffset = insert.length;
    }

    final newText = text.replaceRange(start, end, insert);
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + cursorOffset),
    );
    widget.onTextChanged?.call();
  }

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑描述'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '上传图片',
            onPressed: _pickImage,
            icon: Icon(
              Icons.add_photo_alternate_outlined,
              size: 20,
              color: AppTheme.primaryColor,
            ),
          ),
          IconButton(
            tooltip: _showPreview ? '编辑' : '预览',
            onPressed: () => setState(() => _showPreview = !_showPreview),
            icon: Icon(
              _showPreview ? Icons.edit_outlined : Icons.visibility_outlined,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
      body: DropTarget(
        onDragDone: _handleDroppedImages,
        child: Column(
          children: [
            // 图片附件条
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: AttachmentImageStrip(
                key: ValueKey(
                  'editor-images-${widget.taskId}-$_attachmentRefreshToken',
                ),
                taskId: widget.taskId,
                maxHeight: 100,
                showDeleteButton: true,
              ),
            ),
            // 工具栏
            _buildToolbar(),
            // 编辑区 / 预览
            Expanded(
              child: _showPreview ? _buildPreview() : _buildEditor(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
        ),
        color: AppTheme.bgInput.withValues(alpha: 0.5),
      ),
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        children: [
          _toolBtn(Icons.looks_one_outlined, 'H1', _MarkdownAction.h1),
          _toolBtn(Icons.looks_two_outlined, 'H2', _MarkdownAction.h2),
          _toolBtn(Icons.looks_3_outlined, 'H3', _MarkdownAction.h3),
          _toolDivider(),
          _toolBtn(Icons.format_bold, '粗体', _MarkdownAction.bold),
          _toolBtn(Icons.format_italic, '斜体', _MarkdownAction.italic),
          _toolBtn(
              Icons.strikethrough_s, '删除线', _MarkdownAction.strikethrough),
          _toolDivider(),
          _toolBtn(Icons.format_list_bulleted,
              '无序列表', _MarkdownAction.unorderedList),
          _toolBtn(Icons.format_list_numbered,
              '有序列表', _MarkdownAction.orderedList),
          _toolBtn(
              Icons.check_box_outlined, '任务列表', _MarkdownAction.taskList),
          _toolDivider(),
          _toolBtn(Icons.format_quote, '引用', _MarkdownAction.quote),
          _toolBtn(Icons.code, '行内代码', _MarkdownAction.inlineCode),
          _toolBtn(Icons.data_object, '代码块', _MarkdownAction.codeBlock),
          _toolDivider(),
          _toolBtn(Icons.link, '链接', _MarkdownAction.link),
          _toolBtn(Icons.horizontal_rule, '分割线', _MarkdownAction.divider),
          _toolBtn(
              Icons.table_chart_outlined, '表格', _MarkdownAction.table),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String tooltip, _MarkdownAction action) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      color: AppTheme.textSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () => _insertMarkdown(action),
    );
  }

  Widget _toolDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: VerticalDivider(width: 1, color: AppTheme.borderSubtle),
    );
  }

  Widget _buildEditor() {
    // CallbackShortcuts 拦截 Ctrl+V → 检查剪贴板是图片还是文字
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _handlePaste,
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextFormField(
            controller: widget.controller,
            minLines: null,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textPrimary,
              height: 1.6,
              fontFamily: 'monospace',
            ),
            decoration: const InputDecoration(
              hintText: '输入 Markdown 内容...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              filled: false,
            ),
            onChanged: (_) => widget.onTextChanged?.call(),
            onEditingComplete: widget.onEditingComplete,
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final text = widget.controller.text;
    if (text.trim().isEmpty) {
      return Center(
        child: Text(
          '暂无内容',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textHint,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: _renderMarkdown(text),
    );
  }

  Widget _renderMarkdown(String data) {
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.6),
        h1: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        h2: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        h3: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        code: TextStyle(
          fontSize: 13,
          color: AppTheme.primaryColor,
          backgroundColor: AppTheme.bgInput,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.bgInput,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppTheme.primaryColor, width: 3),
          ),
          color: AppTheme.primaryColor.withValues(alpha: 0.05),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        tableBorder:
            TableBorder.all(color: AppTheme.borderSubtle, width: 0.5),
        tableHead: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary),
        tableBody: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        tableCellsPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        horizontalRuleDecoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
        ),
        listBullet: TextStyle(fontSize: 15, color: AppTheme.textPrimary),
        a: TextStyle(
            color: AppTheme.primaryColor,
            decoration: TextDecoration.underline),
      ),
    );
  }
}

enum _MarkdownAction {
  h1,
  h2,
  h3,
  bold,
  italic,
  strikethrough,
  unorderedList,
  orderedList,
  taskList,
  quote,
  inlineCode,
  codeBlock,
  link,
  divider,
  table,
}
