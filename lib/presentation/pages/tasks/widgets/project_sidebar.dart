import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database/app_database.dart';

class ProjectSidebar extends StatelessWidget {
  final List<Project> projects;
  final List<ProjectGroup> groups;
  final String? selectedProjectId;
  final String? selectedFilter;
  final Map<String, int> projectProgress;
  final Map<String, int> groupProgress;
  final ValueChanged<String?> onProjectSelected;
  final ValueChanged<String> onFilterSelected;
  final VoidCallback onCreateProject;
  final void Function(Project)? onEditProject;
  final void Function(Project)? onDeleteProject;

  const ProjectSidebar({
    super.key,
    required this.projects,
    this.groups = const [],
    this.selectedProjectId,
    this.selectedFilter,
    this.projectProgress = const {},
    this.groupProgress = const {},
    required this.onProjectSelected,
    required this.onFilterSelected,
    required this.onCreateProject,
    this.onEditProject,
    this.onDeleteProject,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.checklist_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '任务管理',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '共 ${projects.length} 个项目',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 快捷筛选
            _buildFilterItem(
              context,
              icon: Icons.inbox_rounded,
              label: '所有任务',
              filter: 'all',
            ),
            _buildFilterItem(
              context,
              icon: Icons.today_rounded,
              label: '今天',
              filter: 'today',
            ),
            _buildFilterItem(
              context,
              icon: Icons.star_rounded,
              label: '重要',
              filter: 'important',
            ),
            const Divider(height: 24, indent: 16, endIndent: 16),
            // 项目标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '项目',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textHint,
                    ),
                  ),
                  IconButton(
                    onPressed: onCreateProject,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    color: AppTheme.primaryColor,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 项目列表（按分组）
            Expanded(
              child: projects.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无项目，点击 + 创建',
                        style: TextStyle(color: AppTheme.textHint),
                      ),
                    )
                  : _buildGroupedProjects(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedProjects() {
    return Builder(builder: (ctx) {
      // 把项目按 groupId 分桶
      final Map<String?, List<Project>> buckets = {};
      for (final p in projects) {
        buckets.putIfAbsent(p.groupId, () => []).add(p);
      }
      final ungrouped = buckets.remove(null) ?? <Project>[];

      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          ...groups.map((g) {
            final items = buckets[g.id] ?? const <Project>[];
            if (items.isEmpty) return const SizedBox.shrink();
            final prog = (groupProgress[g.id] ?? 0).clamp(0, 100).toInt();
            return Theme(
              data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey('group_${g.id}'),
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                childrenPadding: EdgeInsets.zero,
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(int.parse(g.color.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  g.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                trailing: Text(
                  '$prog%',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textHint,
                      fontWeight: FontWeight.w600),
                ),
                children: items.map((p) {
                  final isSelected = p.id == selectedProjectId;
                  return _buildProjectItem(ctx,
                      project: p, isSelected: isSelected);
                }).toList(),
              ),
            );
          }),
          if (ungrouped.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (groups.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  '未分组',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ...ungrouped.map((p) {
              final isSelected = p.id == selectedProjectId;
              return _buildProjectItem(ctx,
                  project: p, isSelected: isSelected);
            }),
          ],
        ],
      );
    });
  }

  Widget _buildFilterItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String filter,
  }) {
    final isSelected = selectedFilter == filter && selectedProjectId == null;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : AppTheme.textHint,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
        ),
      ),
      dense: true,
      onTap: () => onFilterSelected(filter),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildProjectItem(
    BuildContext context, {
    required Project project,
    required bool isSelected,
  }) {
    final progress = (projectProgress[project.id] ?? 0).clamp(0, 100).toInt();
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: Color(int.parse(project.color.replaceFirst('#', '0xFF'))),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        project.name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
        ),
      ),
      trailing: SizedBox(
        width: 88,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$progress%',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') {
                  onEditProject?.call(project);
                } else if (action == 'delete') {
                  onDeleteProject?.call(project);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppTheme.textPrimary,
                      ),
                      SizedBox(width: 8),
                      Text('编辑'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppTheme.error,
                      ),
                      SizedBox(width: 8),
                      Text('删除', style: TextStyle(color: AppTheme.error)),
                    ],
                  ),
                ),
              ],
              icon: const Icon(
                Icons.more_horiz,
                size: 18,
                color: AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
      dense: true,
      onTap: () => onProjectSelected(project.id),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
