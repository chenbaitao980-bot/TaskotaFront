import 'package:flutter/material.dart';
import '../../data/database/app_database.dart';

/// 分组+搜索项目选择器内容，供多处弹窗复用。
///
/// [setDialogState] 来自外层 StatefulBuilder，用于刷新 draft 勾选状态。
Widget buildProjectPickerContent({
  required List<Project> projects,
  required List<ProjectGroup> groups,
  required Set<String> draft,
  required void Function(void Function()) setDialogState,
  Widget? extraHeader,
}) {
  final searchController = TextEditingController();
  String searchText = '';
  final expandedGroups = <String>{...groups.map((g) => g.id)};

  return StatefulBuilder(
    builder: (context, setInnerState) {
      final query = searchText.trim().toLowerCase();
      final filtered = query.isEmpty
          ? null
          : projects.where((p) => p.name.toLowerCase().contains(query)).toList();

      final Map<String?, List<Project>> buckets = {};
      for (final p in projects) {
        buckets.putIfAbsent(p.groupId, () => []).add(p);
      }
      final ungrouped = buckets[null] ?? [];

      void toggle(String id, bool? checked) {
        setDialogState(() {
          setInnerState(() {
            if (checked == true) {
              draft.add(id);
            } else {
              draft.remove(id);
            }
          });
        });
      }

      void toggleGroup(List<Project> groupProjects) {
        final allIds = groupProjects.map((p) => p.id).toSet();
        final allSelected = allIds.every((id) => draft.contains(id));
        setDialogState(() {
          setInnerState(() {
            if (allSelected) {
              draft.removeAll(allIds);
            } else {
              draft.addAll(allIds);
            }
          });
        });
      }

      Widget buildCheckbox(Project p) => CheckboxListTile(
            value: draft.contains(p.id),
            title: Text(p.name),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => toggle(p.id, v),
          );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (extraHeader != null) extraHeader,
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: '搜索项目名称',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (v) => setInnerState(() => searchText = v),
          ),
          const SizedBox(height: 8),
          if (filtered != null)
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('无匹配项目', style: TextStyle(fontSize: 13)),
              )
            else
              for (final p in filtered) buildCheckbox(p)
          else ...[
            for (final g in groups) ...[
              Builder(builder: (_) {
                final groupProjects = buckets[g.id] ?? [];
                final groupIds = groupProjects.map((p) => p.id).toSet();
                final selectedCount = groupIds.where((id) => draft.contains(id)).length;
                final allSelected = groupProjects.isNotEmpty && selectedCount == groupIds.length;
                final someSelected = selectedCount > 0 && !allSelected;
                return Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey('epg_${g.id}'),
                  initiallyExpanded: expandedGroups.contains(g.id),
                  onExpansionChanged: (exp) => setInnerState(() {
                    if (exp) {
                      expandedGroups.add(g.id);
                    } else {
                      expandedGroups.remove(g.id);
                    }
                  }),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: allSelected ? true : (someSelected ? null : false),
                          tristate: true,
                          onChanged: (_) => toggleGroup(groupProjects),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.folder_rounded,
                        size: 20,
                        color: Color(int.parse(g.color.replaceFirst('#', '0xFF'))),
                      ),
                    ],
                  ),
                  title: Text(
                    g.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  children: (buckets[g.id] ?? []).isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(48, 2, 16, 6),
                            child: Text(
                              '暂无项目',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ),
                        ]
                      : (buckets[g.id] ?? []).map(buildCheckbox).toList(),
                ),
              ); }),
            ],
            if (groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '未分组',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            if (ungrouped.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                child: Text(
                  '暂无未分组项目',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              )
            else
              for (final p in ungrouped) buildCheckbox(p),
          ],
        ],
      );
    },
  );
}
