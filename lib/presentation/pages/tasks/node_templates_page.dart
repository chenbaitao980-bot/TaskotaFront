import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_reader.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/node_template_repository.dart';
import '../../../models/node_template_payload.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

class NodeTemplatesPage extends StatefulWidget {
  final NodeTemplateRepository repository;

  const NodeTemplatesPage({super.key, required this.repository});

  @override
  State<NodeTemplatesPage> createState() => _NodeTemplatesPageState();
}

class _NodeTemplatesPageState extends State<NodeTemplatesPage> {
  late Future<List<NodeTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _templatesFuture = widget.repository.getAll();
  }

  Future<void> _editTemplate(NodeTemplate? template) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _NodeTemplateEditDialog(
        repository: widget.repository,
        template: template,
      ),
    );
    if (saved == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _deleteTemplate(NodeTemplate template) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除模板节点'),
        content: Text('确定删除“${template.name}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repository.delete(template.id);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模板节点'),
        actions: [
          IconButton(
            tooltip: '新增模板',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _editTemplate(null),
          ),
        ],
      ),
      body: FutureBuilder<List<NodeTemplate>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          final templates = snapshot.data ?? const <NodeTemplate>[];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (templates.isEmpty) {
            return const Center(child: Text('暂无模板节点'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final template = templates[index];
              final payload = widget.repository.payloadOf(template);
              return Material(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  title: Text(template.name),
                  subtitle: Text(
                    '${template.title} · 检查项 ${payload.checklistTitles.length} · 图片 ${payload.images.length} · 子任务 ${payload.subtasks.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '编辑',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editTemplate(template),
                      ),
                      IconButton(
                        tooltip: '删除',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteTemplate(template),
                      ),
                    ],
                  ),
                  onTap: () => _editTemplate(template),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NodeTemplateEditDialog extends StatefulWidget {
  final NodeTemplateRepository repository;
  final NodeTemplate? template;

  const _NodeTemplateEditDialog({
    required this.repository,
    required this.template,
  });

  @override
  State<_NodeTemplateEditDialog> createState() =>
      _NodeTemplateEditDialogState();
}

class _NodeTemplateEditDialogState extends State<_NodeTemplateEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _checklistController;
  late final TextEditingController _subtasksController;
  late int _priority;
  late List<NodeTemplateImage> _images;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    final payload = template == null
        ? NodeTemplatePayload.empty
        : widget.repository.payloadOf(template);
    _nameController = TextEditingController(text: template?.name ?? '');
    _titleController = TextEditingController(text: template?.title ?? '');
    _descriptionController = TextEditingController(
      text: template?.description ?? '',
    );
    _checklistController = TextEditingController(
      text: payload.checklistTitles.join('\n'),
    );
    _subtasksController = TextEditingController(
      text: _formatSubtasks(payload.subtasks),
    );
    _priority = template?.priority ?? 1;
    _images = [...payload.images];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _checklistController.dispose();
    _subtasksController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) {
      if (mounted) showAppSnackBar(context, '图片文件不可用');
      return;
    }
    final bytes = file.bytes ?? await readFileBytes(file.path!);
    if (!mounted) return;
    setState(() {
      _images.add(
        NodeTemplateImage(
          fileName: file.name,
          mimeType: _guessMime(file.name),
          base64Data: base64Encode(bytes),
        ),
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = NodeTemplatePayload(
      checklistTitles: _checklistController.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(),
      images: _images,
      subtasks: _parseSubtasks(_subtasksController.text),
    );
    final template = widget.template;
    if (template == null) {
      await widget.repository.create(
        name: _nameController.text.trim(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        payload: payload,
      );
    } else {
      await widget.repository.update(
        template.id,
        name: _nameController.text.trim(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        payload: payload,
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.template == null ? '新增模板节点' : '编辑模板节点',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '模板名称',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '请输入模板名称'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: '节点标题',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '请输入节点标题'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _priority,
                        decoration: const InputDecoration(
                          labelText: '优先级',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('无')),
                          DropdownMenuItem(value: 1, child: Text('低')),
                          DropdownMenuItem(value: 3, child: Text('中')),
                          DropdownMenuItem(value: 5, child: Text('高')),
                        ],
                        onChanged: (value) =>
                            setState(() => _priority = value ?? 1),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: '描述',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _checklistController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: '检查项（一行一个）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _subtasksController,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: '子任务（用两个空格缩进表示层级）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: Text('图片 ${_images.length}')),
                          TextButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('添加图片'),
                          ),
                        ],
                      ),
                      if (_images.isNotEmpty)
                        SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _images.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final image = _images[index];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      image.bytes,
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: IconButton.filled(
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.black54,
                                      ),
                                      iconSize: 14,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
                                      ),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => setState(
                                        () => _images.removeAt(index),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _save, child: const Text('保存')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MutableSubtask {
  final String title;
  final List<_MutableSubtask> children = [];

  _MutableSubtask(this.title);

  NodeTemplateSubtask toPayload() => NodeTemplateSubtask(
    title: title,
    children: children.map((child) => child.toPayload()).toList(),
  );
}

List<NodeTemplateSubtask> _parseSubtasks(String raw) {
  final roots = <_MutableSubtask>[];
  final stack = <_MutableSubtask>[];
  for (final rawLine in raw.split('\n')) {
    if (rawLine.trim().isEmpty) continue;
    final spaces = rawLine.length - rawLine.trimLeft().length;
    final depth = spaces ~/ 2;
    final node = _MutableSubtask(rawLine.trim());
    while (stack.length > depth) {
      stack.removeLast();
    }
    if (stack.isEmpty) {
      roots.add(node);
    } else {
      stack.last.children.add(node);
    }
    stack.add(node);
  }
  return roots.map((root) => root.toPayload()).toList();
}

String _formatSubtasks(List<NodeTemplateSubtask> subtasks) {
  final lines = <String>[];
  void walk(NodeTemplateSubtask subtask, int depth) {
    lines.add('${'  ' * depth}${subtask.title}');
    for (final child in subtask.children) {
      walk(child, depth + 1);
    }
  }

  for (final subtask in subtasks) {
    walk(subtask, 0);
  }
  return lines.join('\n');
}

String? _guessMime(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  return null;
}
