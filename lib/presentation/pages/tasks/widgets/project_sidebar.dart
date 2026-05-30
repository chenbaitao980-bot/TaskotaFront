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
  final VoidCallback? onCreateGroup;
  final void Function(Project)? onEditProject;
  final void Function(Project)? onDeleteProject;
  final void Function(ProjectGroup)? onEditGroup;
  final void Function(ProjectGroup)? onDeleteGroup;

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
    this.onCreateGroup,
    this.onEditProject,
    this.onDeleteProject,
    this.onEditGroup,
    this.onDeleteGroup,
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
                children: [
                  Text(
                    '项目',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textHint,
                    ),
                  ),
                  const Spacer(),
                  if (onCreateGroup != null)
                    TextButton.icon(
                      onPressed: onCreateGroup,
                      icon: const Icon(Icons.folder_outlined, size: 16),
                      label: const Text('分组', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 28),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  IconButton(
                    onPressed: onCreateProject,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    color: AppTheme.primaryColor,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: '新建项目',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 项目列表（按分组）
            Expanded(
              child: projects.isEmpty
                  ? Center(
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
            // S1: 空分组也展示
            final prog = (groupProgress[g.id] ?? 0).clamp(0, 100).toInt();
            final groupColor = Color(int.parse(g.color.replaceFirst('#', '0xFF')));
            return Theme(
              data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey('group_${g.id}'),
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                childrenPadding: EdgeInsets.zero,
                leading: Icon(Icons.folder_rounded, size: 22, color: groupColor),
                title: Text(
                  g.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$prog%',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textHint,
                          fontWeight: FontWeight.w600),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, size: 16, color: AppTheme.textHint),
                      padding: EdgeInsets.zero,
                      onSelected: (action) {
                        if (action == 'edit') onEditGroup?.call(g);
                        if (action == 'delete') onDeleteGroup?.call(g);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('重命名分组')),
                        PopupMenuItem(value: 'delete', child: Text('删除分组（项目保留）')),
                      ],
                    ),
                  ],
                ),
                children: items.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(48, 4, 16, 8),
                          child: Text(
                            '暂无项目',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textHint.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ]
                    : items.map((p) {
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
              Padding(
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
    final projectColor =
        Color(int.parse(project.color.replaceFirst('#', '0xFF')));
    final firstChar = project.name.isNotEmpty
        ? project.name.characters.first.toUpperCase()
        : '·';
    return ListTile(
      leading: CircleAvatar(
        radius: 12,
        backgroundColor: projectColor.withValues(alpha: 0.18),
        child: Text(
          firstChar,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: projectColor,
          ),
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
              style: TextStyle(
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
                PopupMenuItem(
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
                PopupMenuItem(
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
              icon: Icon(
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
