import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../../core/theme/app_theme.dart';

class MarkdownDescriptionSection extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onTextChanged;
  final VoidCallback? onEditingComplete;
  final Widget? imageStrip;
  final List<Widget> trailingActions;
  final VoidCallback? onEnterEdit;

  const MarkdownDescriptionSection({
    super.key,
    required this.controller,
    this.onTextChanged,
    this.onEditingComplete,
    this.imageStrip,
    this.trailingActions = const [],
    this.onEnterEdit,
  });

  @override
  State<MarkdownDescriptionSection> createState() =>
      _MarkdownDescriptionSectionState();
}

class _MarkdownDescriptionSectionState
    extends State<MarkdownDescriptionSection> {
  bool _editing = false;
  bool _showPreview = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!_editing && mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant MarkdownDescriptionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _enterEdit() {
    if (widget.onEnterEdit != null) {
      widget.onEnterEdit!();
      return;
    }
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _exitEdit() {
    setState(() {
      _editing = false;
      _showPreview = false;
    });
    widget.onEditingComplete?.call();
  }

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
        insert = '| 列1 | 列2 | 列3 |\n| --- | --- | --- |\n| 内容 | 内容 | 内容 |';
        cursorOffset = insert.length;
    }

    final newText = text.replaceRange(start, end, insert);
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + cursorOffset),
    );
    widget.onTextChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          if (widget.imageStrip != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: widget.imageStrip!,
            ),
          ],
          if (_editing) ...[
            _buildToolbar(),
            if (_showPreview) _buildSplitView() else _buildEditor(),
          ] else
            _buildPreview(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 4),
      child: Row(
        children: [
          Icon(Icons.notes_rounded, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            '描述',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          if (_editing) ...[
            const SizedBox(width: 8),
            _headerPill(
              icon: _showPreview ? Icons.edit_note : Icons.visibility,
              label: _showPreview ? '纯编辑' : '预览',
              onTap: () => setState(() => _showPreview = !_showPreview),
            ),
          ],
          const Spacer(),
          if (_editing)
            _headerPill(
              icon: Icons.check_rounded,
              label: '完成',
              color: AppTheme.success,
              onTap: _exitEdit,
            )
          else
            _headerPill(
              icon: Icons.edit_outlined,
              label: '编辑',
              onTap: _enterEdit,
            ),
          ...widget.trailingActions,
        ],
      ),
    );
  }

  Widget _headerPill({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final c = color ?? AppTheme.primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600),
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
          top: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
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
          _toolBtn(Icons.strikethrough_s, '删除线', _MarkdownAction.strikethrough),
          _toolDivider(),
          _toolBtn(Icons.format_list_bulleted, '无序列表', _MarkdownAction.unorderedList),
          _toolBtn(Icons.format_list_numbered, '有序列表', _MarkdownAction.orderedList),
          _toolBtn(Icons.check_box_outlined, '任务列表', _MarkdownAction.taskList),
          _toolDivider(),
          _toolBtn(Icons.format_quote, '引用', _MarkdownAction.quote),
          _toolBtn(Icons.code, '行内代码', _MarkdownAction.inlineCode),
          _toolBtn(Icons.data_object, '代码块', _MarkdownAction.codeBlock),
          _toolDivider(),
          _toolBtn(Icons.link, '链接', _MarkdownAction.link),
          _toolBtn(Icons.horizontal_rule, '分割线', _MarkdownAction.divider),
          _toolBtn(Icons.table_chart_outlined, '表格', _MarkdownAction.table),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        minLines: 14,
        maxLines: 40,
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimary,
          height: 1.6,
          fontFamily: 'monospace',
        ),
        decoration: const InputDecoration(
          hintText: '输入 Markdown 内容...',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onChanged: (_) => widget.onTextChanged?.call(),
        onTapOutside: (_) => widget.onEditingComplete?.call(),
        onEditingComplete: widget.onEditingComplete,
      ),
    );
  }

  Widget _buildSplitView() {
    return SizedBox(
      height: 400,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 12),
              child: TextFormField(
                controller: widget.controller,
                focusNode: _focusNode,
                minLines: 20,
                maxLines: 100,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  height: 1.5,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  hintText: '输入 Markdown 内容...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onChanged: (_) {
                  widget.onTextChanged?.call();
                  setState(() {});
                },
              ),
            ),
          ),
          VerticalDivider(width: 1, color: AppTheme.borderSubtle),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 8, 14, 12),
              child: _renderMarkdown(widget.controller.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final text = widget.controller.text;
    if (text.trim().isEmpty) {
      return InkWell(
        onTap: _enterEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
          child: Text(
            '点击编辑描述...',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textHint,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: _enterEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        child: _renderMarkdown(text),
      ),
    );
  }

  Widget _renderMarkdown(String data) {
    return MarkdownBody(
      data: data,
      selectable: !_editing,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.6),
        h1: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        h2: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        h3: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
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
        tableBorder: TableBorder.all(color: AppTheme.borderSubtle, width: 0.5),
        tableHead: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        tableBody: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
        ),
        listBullet: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
        a: TextStyle(color: AppTheme.primaryColor, decoration: TextDecoration.underline),
      ),
    );
  }
}

enum _MarkdownAction {
  h1, h2, h3,
  bold, italic, strikethrough,
  unorderedList, orderedList, taskList,
  quote, inlineCode, codeBlock,
  link, divider, table,
}
