import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_writer.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/project_group_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../services/task_export_service.dart';

class TaskExportPage extends StatefulWidget {
  final TaskRepository? taskRepository;
  final ProjectRepository? projectRepository;
  final ProjectGroupRepository? projectGroupRepository;

  const TaskExportPage({
    super.key,
    this.taskRepository,
    this.projectRepository,
    this.projectGroupRepository,
  });

  @override
  State<TaskExportPage> createState() => _TaskExportPageState();
}

class _TaskExportPageState extends State<TaskExportPage> {
  static final _dateFormat = DateFormat('yyyy-MM-dd');
  final _exportService = TaskExportService();
  final _priorityOptions = const [(5, '高'), (3, '中'), (1, '低'), (0, '无')];

  List<Project> _projects = const [];
  List<ProjectGroup> _groups = const [];
  List<Task> _tasks = const [];
  Set<String> _selectedProjectIds = {};
  final Set<String> _expandedGroupIds = {};
  Set<int> _selectedPriorities = {5, 3, 1, 0};
  DateTime? _startDate;
  DateTime? _endDate;
  bool _ready = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.taskRepository == null || widget.projectRepository == null) {
      setState(() {
        _error = '导出需要任务和项目数据源';
        _ready = true;
      });
      return;
    }
    final projects = await widget.projectRepository!.getActive();
    final tasks = await widget.taskRepository!.getAll();
    final groups = await widget.projectGroupRepository?.getAll() ?? [];
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _groups = groups;
      _tasks = tasks;
      _selectedProjectIds = projects.map((project) => project.id).toSet();
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导出')),
      bottomNavigationBar: _ready && _error == null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: FilledButton.icon(
                  key: const Key('task_export_button'),
                  onPressed: _exporting ? null : _export,
                  icon: _exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  label: Text(_exporting ? '导出中' : '导出 Excel'),
                ),
              ),
            )
          : null,
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _buildDateSection(),
                const SizedBox(height: 16),
                _buildProjectSection(),
                const SizedBox(height: 16),
                _buildPrioritySection(),
              ],
            ),
    );
  }

  Widget _buildDateSection() {
    return _Section(
      title: '时间范围',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('task_export_start_date'),
                  onPressed: () => _pickDate(isStart: true),
                  icon: const Icon(Icons.today_outlined),
                  label: Text(
                    _startDate == null ? '开始' : _dateFormat.format(_startDate!),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('task_export_end_date'),
                  onPressed: () => _pickDate(isStart: false),
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(
                    _endDate == null ? '结束' : _dateFormat.format(_endDate!),
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _startDate == null && _endDate == null
                  ? null
                  : () => setState(() {
                      _startDate = null;
                      _endDate = null;
                    }),
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('全部时间'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSection() {
    final allSelected =
        _projects.isNotEmpty && _selectedProjectIds.length == _projects.length;
    final ungroupedProjects =
        _projects.where((p) => p.groupId == null).toList();

    return _Section(
      title: '项目',
      child: Column(
        children: [
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('全部项目'),
            value: allSelected,
            onChanged: (value) {
              setState(() {
                _selectedProjectIds = value == true
                    ? _projects.map((project) => project.id).toSet()
                    : <String>{};
              });
            },
          ),
          const Divider(height: 1),
          // Render each group as a collapsible section
          ..._groups.map((group) {
            final groupProjects =
                _projects.where((p) => p.groupId == group.id).toList();
            if (groupProjects.isEmpty) return const SizedBox.shrink();
            final groupProjectIds = groupProjects.map((p) => p.id).toSet();
            final selectedCount =
                groupProjectIds.intersection(_selectedProjectIds).length;
            final bool? groupValue = selectedCount == 0
                ? false
                : selectedCount == groupProjectIds.length
                ? true
                : null;
            final isExpanded = _expandedGroupIds.contains(group.id);
            return _buildGroupTile(
              id: group.id,
              name: group.name,
              color: group.color,
              projects: groupProjects,
              groupValue: groupValue,
              isExpanded: isExpanded,
              onGroupChanged: (value) {
                setState(() {
                  final next = Set<String>.from(_selectedProjectIds);
                  if (value == true || value == null) {
                    next.addAll(groupProjectIds);
                  } else {
                    next.removeAll(groupProjectIds);
                  }
                  _selectedProjectIds = next;
                });
              },
            );
          }),
          // Ungrouped section
          if (ungroupedProjects.isNotEmpty) ...[
            _buildUngroupedTile(ungroupedProjects),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupTile({
    required String id,
    required String name,
    required String color,
    required List<Project> projects,
    required bool? groupValue,
    required bool isExpanded,
    required ValueChanged<bool?> onGroupChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  if (isExpanded) {
                    _expandedGroupIds.remove(id);
                  } else {
                    _expandedGroupIds.add(id);
                  }
                });
              },
            ),
            Expanded(
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(name),
                secondary: _ProjectDot(color: color),
                tristate: true,
                value: groupValue,
                onChanged: onGroupChanged,
              ),
            ),
          ],
        ),
        if (isExpanded)
          ...projects.map((project) {
            return CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 32),
              title: Text(project.name),
              secondary: _ProjectDot(color: project.color),
              value: _selectedProjectIds.contains(project.id),
              onChanged: (value) {
                setState(() {
                  final next = Set<String>.from(_selectedProjectIds);
                  if (value == true) {
                    next.add(project.id);
                  } else {
                    next.remove(project.id);
                  }
                  _selectedProjectIds = next;
                });
              },
            );
          }),
      ],
    );
  }

  Widget _buildUngroupedTile(List<Project> projects) {
    const groupId = '__ungrouped__';
    final projectIds = projects.map((p) => p.id).toSet();
    final selectedCount = projectIds.intersection(_selectedProjectIds).length;
    final bool? groupValue = selectedCount == 0
        ? false
        : selectedCount == projectIds.length
        ? true
        : null;
    final isExpanded = _expandedGroupIds.contains(groupId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  if (isExpanded) {
                    _expandedGroupIds.remove(groupId);
                  } else {
                    _expandedGroupIds.add(groupId);
                  }
                });
              },
            ),
            Expanded(
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('未分组'),
                tristate: true,
                value: groupValue,
                onChanged: (value) {
                  setState(() {
                    final next = Set<String>.from(_selectedProjectIds);
                    if (value == true || value == null) {
                      next.addAll(projectIds);
                    } else {
                      next.removeAll(projectIds);
                    }
                    _selectedProjectIds = next;
                  });
                },
              ),
            ),
          ],
        ),
        if (isExpanded)
          ...projects.map((project) {
            return CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 32),
              title: Text(project.name),
              secondary: _ProjectDot(color: project.color),
              value: _selectedProjectIds.contains(project.id),
              onChanged: (value) {
                setState(() {
                  final next = Set<String>.from(_selectedProjectIds);
                  if (value == true) {
                    next.add(project.id);
                  } else {
                    next.remove(project.id);
                  }
                  _selectedProjectIds = next;
                });
              },
            );
          }),
      ],
    );
  }

  Widget _buildPrioritySection() {
    return _Section(
      title: '重要级别',
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: _priorityOptions.map((option) {
          final selected = _selectedPriorities.contains(option.$1);
          return FilterChip(
            label: Text(option.$2),
            selected: selected,
            onSelected: (value) {
              setState(() {
                final next = Set<int>.from(_selectedPriorities);
                if (value) {
                  next.add(option.$1);
                } else {
                  next.remove(option.$1);
                }
                _selectedPriorities = next;
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? _endDate ?? now)
          : (_endDate ?? _startDate ?? now),
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('zh', 'CN'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        _endDate ??= _endOfDay(picked);
      } else {
        _endDate = _endOfDay(picked);
        _startDate ??= DateTime(picked.year, picked.month, picked.day);
      }
      if (_startDate != null &&
          _endDate != null &&
          _startDate!.isAfter(_endDate!)) {
        final oldStart = _startDate!;
        _startDate = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
        _endDate = _endOfDay(oldStart);
      }
    });
  }

  Future<void> _export() async {
    if (_selectedProjectIds.isEmpty) {
      showAppSnackBar(context, '请选择至少一个项目');
      return;
    }
    if (_selectedPriorities.isEmpty) {
      showAppSnackBar(context, '请选择至少一个重要级别');
      return;
    }
    setState(() => _exporting = true);
    try {
      final projectIdsForExport = _selectedProjectIds.length == _projects.length
          ? const <String>{}
          : _selectedProjectIds;
      final bytes = _exportService.exportTasksToExcel(
        tasks: _tasks,
        projects: _projects,
        groups: _groups,
        startDate: _startDate,
        endDate: _endDate,
        projectIds: projectIdsForExport,
        priorities: _selectedPriorities,
      );
      final fileName =
          '智能小助手任务导出_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '保存任务导出',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: isMobile ? bytes : null,
        lockParentWindow: true,
      );
      if (path == null) return;
      final outputPath = path.toLowerCase().endsWith('.xlsx')
          ? path
          : '$path.xlsx';
      if (!isMobile) {
        await _writeAndOpenFile(outputPath, bytes);
      }
      if (mounted) showAppSnackBar(context, '导出完成');
    } catch (e) {
      if (mounted) showAppSnackBar(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  static DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  Future<void> _writeAndOpenFile(String path, List<int> bytes) async {
    await writeAndOpenFile(path, bytes);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadowLight,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ProjectDot extends StatelessWidget {
  final String color;

  const _ProjectDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _parseColor(color),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _parseColor(String value) {
    final hex = value.replaceFirst('#', '');
    final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return parsed == null ? AppTheme.primaryColor : Color(parsed);
  }
}
