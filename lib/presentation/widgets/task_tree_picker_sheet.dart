import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../pages/home/lazy_log_creation_dialog.dart';

/// 父任务树状选择器弹层：可展开/折叠树 + 搜索 + 单点回填。
/// 适用于 bottom sheet 内空间局促的场景（复用 subtask_tree_section 的
/// childrenByParent 索引 + 递归构建 + expandedNodes 骨架）。
class TaskTreePickerSheet extends StatefulWidget {
  final List<LazyLogParentOption> parents;
  final String? selectedId;

  /// 取消选择哨兵：选中节点再点一次时随 pop 返回，供调用方清空父任务。
  /// 用哨兵而非 null，是为了与"关闭弹层 / 点外面返回 null"语义区分，避免误清。
  static const LazyLogParentOption clearSelection = LazyLogParentOption(
    id: '__clear__',
    title: '',
  );

  const TaskTreePickerSheet({
    super.key,
    required this.parents,
    this.selectedId,
  });

  @override
  State<TaskTreePickerSheet> createState() => _TaskTreePickerSheetState();
}

class _TaskTreePickerSheetState extends State<TaskTreePickerSheet> {
  final _searchController = TextEditingController();
  final Set<String> _expanded = {};
  String _query = '';

  /// 当前勾选态（可变）：初值 = widget.selectedId；点节点切换，确认时随 pop 返回。
  late String? _selectedId;

  /// 所有有子节点的 id（"一键展开"的目标集合）。
  late final Set<String> _allParentIds;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
    final ids = widget.parents.map((p) => p.id).toSet();
    final byId = {for (final p in widget.parents) p.id: p};
    _allParentIds = widget.parents
        .map((p) => p.parentId)
        .whereType<String>()
        .where(ids.contains)
        .toSet();
    // 默认收缩：不再预展开根节点。仅展开选中项的祖先路径，
    // 保证打开后能直接看到当前勾选位置（其余分支保持折叠）。
    var node = _selectedId == null ? null : byId[_selectedId];
    while (node != null) {
      _expanded.add(node.id);
      node = node.parentId == null ? null : byId[node.parentId];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final matching = query.isEmpty ? widget.parents : _matchingParents(query);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: '搜索任务标题',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                filled: true,
                fillColor: AppTheme.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.borderSubtle),
                ),
              ),
            ),
          ),
          if (matching.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  widget.parents.isEmpty ? '该项目暂无任务' : '未找到匹配的任务',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: query.isEmpty
                    ? _buildTree()
                    : [
                        for (final p in matching)
                          _nodeRow(p, depth: 0, hasChildren: false, isExpanded: false),
                      ],
              ),
            ),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Row(
        children: [
          Icon(Icons.account_tree_outlined, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '选择父任务',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '点任务切换勾选，点"完成"确认',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleAllExpanded,
            icon: Icon(
              _allCollapsed
                  ? Icons.unfold_more_rounded
                  : Icons.unfold_less_rounded,
            ),
            color: AppTheme.textSecondary,
            tooltip: _allCollapsed ? '全部展开' : '全部收起',
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            color: AppTheme.textSecondary,
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  bool get _allCollapsed => _expanded.isEmpty;

  /// 一键展开/收起：全折叠时展开所有有子节点项，否则全部收起。
  void _toggleAllExpanded() {
    setState(() {
      if (_allCollapsed) {
        _expanded.addAll(_allParentIds);
      } else {
        _expanded.clear();
      }
    });
  }

  /// 底部确认按钮：有勾选返回该节点，无勾选（含刚取消）返回清空哨兵，
  /// 由审核页据此清空父任务。
  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton(
          onPressed: _confirm,
          child: const Text('完成'),
        ),
      ),
    );
  }

  void _confirm() {
    final node = _selectedId == null
        ? null
        : widget.parents.where((p) => p.id == _selectedId).firstOrNull;
    Navigator.pop(context, node ?? TaskTreePickerSheet.clearSelection);
  }

  List<LazyLogParentOption> _matchingParents(String query) {
    final q = query.toLowerCase();
    return widget.parents
        .where((p) => p.title.toLowerCase().contains(q))
        .toList();
  }

  /// 一次性构建 parentId → children 索引（孤儿节点归到根层），O(n)。
  Map<String?, List<LazyLogParentOption>> _childrenByParent() {
    final ids = widget.parents.map((p) => p.id).toSet();
    final map = <String?, List<LazyLogParentOption>>{};
    for (final p in widget.parents) {
      final key = p.parentId != null && ids.contains(p.parentId)
          ? p.parentId
          : null;
      map.putIfAbsent(key, () => []).add(p);
    }
    return map;
  }

  List<Widget> _buildTree() {
    return _buildTreeRows(_childrenByParent(), null, 0);
  }

  List<Widget> _buildTreeRows(
    Map<String?, List<LazyLogParentOption>> childrenByParent,
    String? parentId,
    int depth,
  ) {
    final children = childrenByParent[parentId] ?? const <LazyLogParentOption>[];
    final widgets = <Widget>[];
    for (final node in children) {
      final hasChildren = (childrenByParent[node.id] ?? const []).isNotEmpty;
      final isExpanded = _expanded.contains(node.id);
      widgets.add(_nodeRow(node, depth: depth, hasChildren: hasChildren, isExpanded: isExpanded));
      if (isExpanded && hasChildren) {
        widgets.addAll(
          _buildTreeRows(childrenByParent, node.id, depth + 1),
        );
      }
    }
    return widgets;
  }

  Widget _nodeRow(
    LazyLogParentOption node, {
    required int depth,
    required bool hasChildren,
    required bool isExpanded,
  }) {
    final selected = node.id == _selectedId;
    return InkWell(
      // 点节点=切换勾选：已选→取消（清空），未选→选中；窗口保持打开，
      // 由底部"完成"按钮统一提交（pop 该节点或清空哨兵）。
      onTap: () {
        setState(() {
          _selectedId = selected ? null : node.id;
        });
      },
      child: Container(
        height: 44,
        padding: EdgeInsets.only(left: 8.0 + depth * 18, right: 12),
        child: Row(
          children: [
            if (hasChildren)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expanded.remove(node.id);
                    } else {
                      _expanded.add(node.id);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isExpanded
                        ? Icons.expand_more_rounded
                        : Icons.chevron_right_rounded,
                    size: 18,
                    color: AppTheme.textHint,
                  ),
                ),
              )
            else
              const SizedBox(width: 26),
            const SizedBox(width: 2),
            Icon(
              hasChildren ? Icons.folder_outlined : Icons.task_alt_outlined,
              size: 16,
              color: hasChildren ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? AppTheme.primaryColor : AppTheme.textPrimary,
                  fontWeight:
                      hasChildren || selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}
