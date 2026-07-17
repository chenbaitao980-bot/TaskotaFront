import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/assistant/lazy_log_mapping.dart';
import '../../../services/lazy_log_mapping_service.dart';

class KeywordMappingPage extends StatefulWidget {
  const KeywordMappingPage({super.key});

  @override
  State<KeywordMappingPage> createState() => _KeywordMappingPageState();
}

class _KeywordMappingPageState extends State<KeywordMappingPage> {
  final _service = LazyLogMappingService();
  List<LazyLogKeywordMapping> _mappings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mappings = await _service.loadMappings();
    if (!mounted) return;
    setState(() {
      _mappings = mappings;
      _loading = false;
    });
  }

  Future<void> _toggle(LazyLogKeywordMapping mapping) async {
    await _service.toggleMapping(mapping.id, !mapping.enabled);
    await _load();
  }

  Future<void> _delete(LazyLogKeywordMapping mapping) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除映射'),
        content: Text('确定删除「${mapping.triggersLabel}」的映射规则？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteMapping(mapping.id);
    await _load();
  }

  Future<void> _edit(LazyLogKeywordMapping? mapping) async {
    final result = await showDialog<LazyLogKeywordMapping>(
      context: context,
      builder: (_) => _MappingEditDialog(mapping: mapping),
    );
    if (result == null) return;
    if (mapping == null) {
      await _service.addMapping(result);
    } else {
      await _service.updateMapping(result);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgScaffold,
      appBar: AppBar(
        title: const Text('关键字映射'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '添加映射',
            onPressed: _loading ? null : () => _edit(null),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mappings.isEmpty
          ? _emptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: _mappings.length,
              itemBuilder: (context, index) {
                final mapping = _mappings[index];
                return _MappingCard(
                  mapping: mapping,
                  onToggle: () => _toggle(mapping),
                  onEdit: () => _edit(mapping),
                  onDelete: () => _delete(mapping),
                );
              },
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tune_rounded, size: 48, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text(
            '暂无关键字映射',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('添加映射'),
          ),
        ],
      ),
    );
  }
}

class _MappingCard extends StatelessWidget {
  final LazyLogKeywordMapping mapping;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MappingCard({
    required this.mapping,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[
      _chipRow(),
      const SizedBox(height: 8),
      if (mapping.afterHour != null) _timeRow(),
      if (mapping.afterHour != null && (mapping.projectId != null)) ...[
        const SizedBox(height: 4),
      ],
      if (mapping.projectId != null) _projectRow(),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: mapping.enabled
          ? AppTheme.bgCard
          : AppTheme.bgCard.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: parts,
              ),
            ),
            Column(
              children: [
                Switch(
                  value: mapping.enabled,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (_) => onToggle(),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppTheme.textHint,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppTheme.error,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: mapping.triggers.map((t) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            t,
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _timeRow() {
    final hour = mapping.afterHour!.toString().padLeft(2, '0');
    final minute = (mapping.afterMinute ?? 0).toString().padLeft(2, '0');
    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          '→ $hour:$minute',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _projectRow() {
    return Row(
      children: [
        Icon(Icons.folder_outlined, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          mapping.projectHint ?? mapping.projectId!,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

class _MappingEditDialog extends StatefulWidget {
  final LazyLogKeywordMapping? mapping;
  const _MappingEditDialog({this.mapping});

  @override
  State<_MappingEditDialog> createState() => _MappingEditDialogState();
}

class _MappingEditDialogState extends State<_MappingEditDialog> {
  late final TextEditingController _triggersController;
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  late final TextEditingController _projectHintController;
  bool _hasTime = false;
  bool _hasProject = false;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    final m = widget.mapping;
    _triggersController = TextEditingController(
      text: m?.triggers.join('、') ?? '',
    );
    _hourController = TextEditingController(
      text: m?.afterHour?.toString() ?? '',
    );
    _minuteController = TextEditingController(
      text: m?.afterMinute?.toString() ?? '',
    );
    _projectHintController = TextEditingController(text: m?.projectHint ?? '');
    _hasTime = m?.afterHour != null;
    _hasProject = m?.projectId != null;
    _projectId = m?.projectId;
  }

  @override
  void dispose() {
    _triggersController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _projectHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.mapping != null;
    return AlertDialog(
      title: Text(isEdit ? '编辑映射' : '添加映射'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _triggersController,
                decoration: const InputDecoration(
                  labelText: '触发关键字',
                  hintText: '用顿号分隔，如：下班、放工、收工',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '输入用户原文中的关键词，多个用顿号分隔',
                style: TextStyle(fontSize: 11, color: AppTheme.textHint),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _hasTime,
                    onChanged: (v) => setState(() => _hasTime = v ?? false),
                  ),
                  const Text('映射时间'),
                  if (_hasTime) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: _hourController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '时',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: _minuteController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '分',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _hasProject,
                    onChanged: (v) => setState(() => _hasProject = v ?? false),
                  ),
                  const Text('映射项目'),
                  if (_hasProject) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _projectHintController,
                        decoration: const InputDecoration(
                          labelText: '项目名称',
                          hintText: '项目ID将自动匹配',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _save() {
    final triggers = _triggersController.text
        .split(RegExp(r'[、,，\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (triggers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少输入一个触发关键字')));
      return;
    }

    int? hour;
    int? minute;
    if (_hasTime) {
      hour = int.tryParse(_hourController.text);
      minute = int.tryParse(_minuteController.text) ?? 0;
      if (hour == null || hour < 0 || hour > 23) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入有效的小时 (0-23)')));
        return;
      }
    }

    String? projectId;
    String? projectHint;
    if (_hasProject) {
      projectHint = _projectHintController.text.trim();
      if (projectHint.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入项目名称')));
        return;
      }
      // projectId 暂时用 name 代替，后续可改为真实 ID
      projectId = projectHint;
    }

    final mapping = widget.mapping != null
        ? widget.mapping!.copyWith(
            triggers: triggers,
            enabled: true,
            afterHour: hour,
            afterMinute: minute,
            projectId: projectId,
            projectHint: projectHint,
            clearProject: !_hasProject,
          )
        : LazyLogKeywordMapping.create(
            triggers: triggers,
            afterHour: hour,
            afterMinute: minute,
            projectId: projectId,
            projectHint: projectHint,
          );

    Navigator.pop(context, mapping);
  }
}
