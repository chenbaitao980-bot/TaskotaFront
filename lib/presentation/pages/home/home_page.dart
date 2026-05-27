import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/checklist_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/project_sync_service.dart';
import '../../../services/task_sync_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/schedule/schedule_bloc.dart';
import '../../blocs/task_new/task_bloc.dart';
import '../../blocs/task_new/task_event.dart';
import '../../blocs/task_new/task_state.dart';
import '../../widgets/calendar_date_picker.dart';
import '../../widgets/create_schedule_dialog.dart';
import '../calendar/calendar_page.dart';
import '../onboarding/onboarding_page.dart';
import '../profile/profile_page.dart';
import '../task/create_task_page.dart';
import '../task/task_list_page.dart';
import '../tasks/task_detail/task_detail_page.dart';
import '../tasks/tasks_page.dart';

class HomePage extends StatefulWidget {
  final ProjectRepository? projectRepository;
  final TaskRepository? taskRepository;
  final ChecklistRepository? checklistRepository;

  const HomePage({
    super.key,
    this.projectRepository,
    this.taskRepository,
    this.checklistRepository,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final LocalStorageService _storage = LocalStorageService();
  bool _storageReady = false;
  bool _onboardingPromptChecked = false;

  @override
  void initState() {
    super.initState();
    _initStorage();
  }

  void _checkOnboarding() {
    if (_onboardingPromptChecked || _storage.onboardingCompleted) return;
    _onboardingPromptChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_storage.onboardingCompleted && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
        );
      }
    });
  }

  List<Widget> _buildPages() {
    return [
      _HomeContent(
        storage: _storage,
        projectRepository: widget.projectRepository,
        taskRepository: widget.taskRepository,
        checklistRepository: widget.checklistRepository,
        onCreateSchedule: _createSchedule,
        onRefresh: _loadStats,
        onOpenTaskStatus: _openTaskStatus,
        onEditSchedule: _editSchedule,
        onDeleteSchedule: _deleteSchedule,
      ),
      const TasksPage(),
      const CalendarPage(),
      const ProfilePage(),
    ];
  }

  Future<void> _initStorage() async {
    await _storage.init();
    _storageReady = true;
    await _storage.fetchAndMergeFromCloud();
    // Supabase 云端任务同步
    TaskSyncService.instance.pullAll().then((_) {
      if (mounted) {
        context.read<TaskNewBloc>().add(LoadTasks());
      }
    });
    TaskSyncService.instance.subscribe();
    // 项目与分组的云同步
    ProjectSyncService.instance.pullAll().then((_) {
      if (mounted) context.read<TaskNewBloc>().add(LoadTasks());
    });
    ProjectSyncService.instance.subscribe();
    _loadStats();
    _checkOnboarding();
    if (mounted) setState(() {});
  }

  Future<void> _ensureStorageReady() async {
    if (_storageReady) return;
    await _storage.init();
    _storageReady = true;
  }

  void _loadStats() {
    // Stats no longer displayed directly; kept for future use
  }

  String _getUserId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is LocalAuthenticated) return authState.email;
    if (authState is Authenticated) return authState.user.id;
    return 'local_user';
  }

  // Schedule CRUD

  Future<void> _createSchedule() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateScheduleDialog(),
    );

    if (result != null) {
      try {
        await _ensureStorageReady();
        final newSchedule = await _storage.createSchedule(
          userId: _getUserId(),
          title: result['title'] as String,
          description: result['description'] as String?,
          startTime: result['startTime'] as DateTime,
          endTime: result['endTime'] as DateTime,
          priority: result['priority'] as String,
          remindBeforeMinutes: result['remindBeforeMinutes'] as int? ?? 15,
          reminderEnabled: result['reminderEnabled'] as bool? ?? true,
          isRepeating: result['isRepeating'] as bool? ?? false,
          repeatInterval: result['repeatInterval'] as int?,
        );
        if (newSchedule.reminderEnabled) {
          await NotificationService().scheduleReminderForSchedule(
            scheduleId: newSchedule.id,
            title: newSchedule.title,
            startTime: newSchedule.startTime,
            description: newSchedule.description,
            remindBeforeMinutes: newSchedule.remindBeforeMinutes,
            isRepeating: newSchedule.isRepeating,
            repeatInterval: newSchedule.repeatInterval,
          );
        }
        // 同步到 Supabase 云端
        try {
          if (context.mounted) {
            context.read<ScheduleBloc>().add(
              CreateSchedule(schedule: newSchedule.copyWith(syncStatus: 'synced')),
            );
          }
        } catch (_) {
          // 云端同步失败不影响本地使用
        }
        _loadStats();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('日程已创建')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('创建日程失败：$e')));
        }
      }
    }
  }

  Future<void> _openTaskStatus(String status, String title) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskListPage(status: status, title: title),
      ),
    );
    await _ensureStorageReady();
    _loadStats();
  }

  Future<void> _editSchedule(dynamic schedule) async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (context) => CreateScheduleDialog(
        initialTitle: schedule.title as String,
        initialDate: schedule.startTime as DateTime,
        initialStartTime: schedule.startTime as DateTime,
        initialEndTime: schedule.endTime as DateTime,
        initialPriority: schedule.priority as String,
        initialRemindBeforeMinutes: schedule.remindBeforeMinutes as int? ?? 15,
        initialReminderEnabled: schedule.reminderEnabled as bool? ?? true,
        initialIsRepeating: schedule.isRepeating as bool? ?? false,
        initialRepeatInterval: schedule.repeatInterval as int?,
        isEditing: true,
      ),
    );

    if (result == 'delete') {
      await _deleteSchedule(schedule);
      return;
    }

    if (result == 'add_subtask') {
      await _createSubtaskForSchedule(schedule);
      return;
    }

    if (result != null && result is Map<String, dynamic>) {
      final updated = schedule.copyWith(
        title: result['title'] as String,
        description: result['description'] as String?,
        startTime: result['startTime'] as DateTime,
        endTime: result['endTime'] as DateTime,
        priority: result['priority'] as String,
        remindBeforeMinutes: result['remindBeforeMinutes'] as int? ?? 15,
        reminderEnabled: result['reminderEnabled'] as bool? ?? true,
        isRepeating: result['isRepeating'] as bool? ?? false,
        repeatInterval: result['repeatInterval'] as int?,
      );
      await _storage.updateSchedule(updated);
      if (updated.reminderEnabled) {
        await NotificationService().scheduleReminderForSchedule(
          scheduleId: updated.id,
          title: updated.title,
          startTime: updated.startTime,
          description: updated.description,
          remindBeforeMinutes: updated.remindBeforeMinutes,
          isRepeating: updated.isRepeating,
          repeatInterval: updated.repeatInterval,
        );
      } else {
        await NotificationService().cancelNotification(updated.id.hashCode);
      }
      // 同步更新到 Supabase 云端
      try {
        if (context.mounted) {
          context.read<ScheduleBloc>().add(
            UpdateSchedule(schedule: updated.copyWith(syncStatus: 'synced')),
          );
        }
      } catch (_) {}
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('日程已更新')));
      }
    }
  }

  Future<void> _createSubtaskForSchedule(dynamic schedule) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTaskPage(
          parentScheduleId: schedule.id as String,
          initialStartDate: schedule.startTime as DateTime,
          initialEndDate: schedule.endTime as DateTime,
        ),
      ),
    );
    if (created == true) {
      await _ensureStorageReady();
      _loadStats();
    }
  }

  Future<void> _deleteSchedule(dynamic schedule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日程'),
        content: Text('确定要删除"${schedule.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storage.deleteSchedule(schedule.id as String);
      // 同步删除到 Supabase 云端
      try {
        if (context.mounted) {
          context.read<ScheduleBloc>().add(
            DeleteSchedule(id: schedule.id as String),
          );
        }
      } catch (_) {}
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('日程已删除')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _buildPages()),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _createSchedule,
              elevation: 2,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: const Border(
          top: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            if (index == 1 || index == 2) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && context.mounted) {
                  context.read<TaskNewBloc>().add(LoadTasks());
                }
              });
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: [
            _navItem(0, Icons.home_rounded, Icons.home_rounded, '首页'),
            _navItem(
              1,
              Icons.checklist_outlined,
              Icons.checklist_rounded,
              '任务',
            ),
            _navItem(
              2,
              Icons.calendar_month_outlined,
              Icons.calendar_month,
              '日历',
            ),
            _navItem(
              3,
              Icons.person_outline_rounded,
              Icons.person_rounded,
              '我的',
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(
    int index,
    IconData outlined,
    IconData filled,
    String label,
  ) {
    final isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(outlined, size: 24),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      activeIcon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(filled, size: 24),
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      label: label,
    );
  }
}

// ────────────────────────────────────────────────────────────
// New Home Content: Timeline + Detail + Quadrant Chart
// ────────────────────────────────────────────────────────────

class _HomeContent extends StatefulWidget {
  final LocalStorageService storage;
  final ProjectRepository? projectRepository;
  final TaskRepository? taskRepository;
  final ChecklistRepository? checklistRepository;
  final VoidCallback onCreateSchedule;
  final VoidCallback onRefresh;
  final void Function(String status, String title) onOpenTaskStatus;
  final void Function(dynamic schedule) onEditSchedule;
  final void Function(dynamic schedule) onDeleteSchedule;

  const _HomeContent({
    required this.storage,
    this.projectRepository,
    this.taskRepository,
    this.checklistRepository,
    required this.onCreateSchedule,
    required this.onRefresh,
    required this.onOpenTaskStatus,
    required this.onEditSchedule,
    required this.onDeleteSchedule,
  });

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  static const double _dayWidth = 72.0;
  static const double _hourWidth = 120.0;
  static const int _daysBefore = 180;
  static const int _daysAfter = 180;

  bool _loading = false;
  bool _modeSwitchGuard = false;
  late final ScrollController _timelineController;
  String _timelineMode = 'hour'; // 'day' | 'hour'
  String? _filterProjectId;

  // Combined timeline data
  List<_TimelineTask> _timelineTasks = [];
  List<_TimelineTask> _filteredTasks = [];
  Map<String, Project> _projectCache = {};
  final Map<String, List<ChecklistItem>> _checklistCache = {};
  final Map<String, List<Task>> _subtaskCache = {};
  String? _selectedTaskId;
  _TimelineTask? _selectedTask;

  @override
  void initState() {
    super.initState();
    _timelineController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _timelineController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_loading) return;
    _loading = true;

    // Load projects
    if (widget.projectRepository != null) {
      final projects = await widget.projectRepository!.getActive();
      _projectCache = {for (final p in projects) p.id: p};
    }

    // Load storage tasks
    final storageTasks = widget.storage.getTasks();

    // Load DB tasks
    List<Task> dbTasks = [];
    if (widget.taskRepository != null) {
      dbTasks = await widget.taskRepository!.getAll();
    }

    // Build timeline items
    final timelineItems = <_TimelineTask>[];
    final now = DateTime.now();

    // From storage (TaskBreakdown)
    for (final t in storageTasks) {
      final date = t.startDate ?? t.endDate ?? now;
      timelineItems.add(_TimelineTask(
        id: t.id,
        title: t.title,
        description: t.description,
        date: date,
        isCompleted: t.status == 'completed',
        priority: t.priority,
        source: 'storage',
        projectId: null,
        taskId: t.id,
      ));
    }

    // From DB (Task)
    for (final t in dbTasks) {
      final date = t.startDate != null
          ? DateTime.fromMillisecondsSinceEpoch(t.startDate!)
          : (t.dueDate != null
              ? DateTime.fromMillisecondsSinceEpoch(t.dueDate!)
              : now);
      timelineItems.add(_TimelineTask(
        id: t.id,
        title: t.title,
        description: t.description,
        date: date,
        isCompleted: t.status == 2,
        priority: _dbPriorityToLabel(t.priority),
        source: 'db',
        projectId: t.projectId,
        taskId: t.id,
        parentId: t.parentId,
      ));
    }

    // Sort by date, then by title
    timelineItems.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      return a.title.compareTo(b.title);
    });

    // Deduplicate: keep only the last occurrence per taskId (DB version overrides storage)
    final seen = <String>{};
    final deduped = <_TimelineTask>[];
    for (final item in timelineItems.reversed) {
      if (seen.add(item.taskId)) {
        deduped.add(item);
      }
    }
    deduped.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      return a.title.compareTo(b.title);
    });

    _timelineTasks = deduped;
    _applyProjectFilter();
    _loading = false;

    // Preserve previous selection if task still exists
    if (_selectedTaskId != null) {
      final sameTask =
          _timelineTasks.where((t) => t.id == _selectedTaskId).firstOrNull;
      if (sameTask != null) {
        _selectedTask = sameTask;
      } else {
        _selectedTask = null;
        _selectedTaskId = null;
      }
    }

    // 清除过期缓存，下次选中时重新加载
    final staleTaskId = _selectedTask?.taskId;
    if (staleTaskId != null) {
      _checklistCache.remove(staleTaskId);
      _subtaskCache.remove(staleTaskId);
    }

    if (mounted) setState(() {});

    // Auto-scroll to nearest task after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToNearestTask();
    });
  }

  void _applyProjectFilter() {
    if (_filterProjectId == null) {
      _filteredTasks = List.from(_timelineTasks);
    } else {
      _filteredTasks = _timelineTasks
          .where((t) => t.projectId == _filterProjectId)
          .toList();
    }
  }

  void _scrollToTask(_TimelineTask task) {
    if (!_timelineController.hasClients) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    double target;

    if (_timelineMode == 'hour') {
      if (!_isSameDayDate(task.date, today)) {
        // Task not today — jump to midday default
        target = 12 * _hourWidth;
      } else {
        target = task.date.hour * _hourWidth;
      }
      final midScreen = MediaQuery.of(context).size.width / 2;
      target = target - midScreen + _hourWidth / 2;
    } else {
      final baseDate = today.subtract(Duration(days: _daysBefore));
      final dayOffset = task.date.difference(baseDate).inDays * _dayWidth;
      final midScreen = MediaQuery.of(context).size.width / 2;
      target = dayOffset - midScreen + _dayWidth / 2;
    }

    _timelineController.animateTo(
      max(0.0, target),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToNearestTask() {
    if (!_timelineController.hasClients || _filteredTasks.isEmpty) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_timelineMode == 'hour') {
      // Scroll to current hour
      final target = now.hour * _hourWidth;
      final midScreen = MediaQuery.of(context).size.width / 2;
      _timelineController.jumpTo(max(0.0, target - midScreen + _hourWidth / 2));

      // Select nearest task for today if any
      final todayTasks = _filteredTasks.where((t) =>
          _isSameDayDate(t.date, today) && !t.isCompleted).toList();
      if (todayTasks.isNotEmpty) {
        _selectTask(todayTasks.first);
      }
      return;
    }

    final baseDate = today.subtract(Duration(days: _daysBefore));

    // Find nearest task (closest to now, preferring future tasks)
    _TimelineTask? nearest;
    Duration minDiff = const Duration(days: 365 * 10);
    for (final task in _filteredTasks) {
      if (task.isCompleted) continue;
      final diff = task.date.difference(now).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = task;
      }
    }
    if (nearest == null && _filteredTasks.isNotEmpty) {
      nearest = _filteredTasks.first;
    }
    if (nearest == null) {
      // No tasks — scroll to today
      final todayOffset = now.difference(baseDate).inDays * _dayWidth;
      final midScreen = MediaQuery.of(context).size.width / 2;
      final target = todayOffset - midScreen + _dayWidth / 2;
      _timelineController.jumpTo(max(0, target));
      return;
    }

    final dayOffset = nearest.date.difference(baseDate).inDays * _dayWidth;
    final midScreen = MediaQuery.of(context).size.width / 2;
    final target = dayOffset - midScreen + _dayWidth / 2;
    _timelineController.jumpTo(max(0, target));

    // Auto-select the nearest task
    _selectTask(nearest);
  }

  void _selectTask(_TimelineTask task) {
    setState(() {
      _selectedTaskId = task.id;
      _selectedTask = task;
    });

    // 模式切换守卫：用户手动点击天/小时模式切换时不触发自动切换
    if (_modeSwitchGuard) {
      _scrollToTask(task);
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(task.date.year, task.date.month, task.date.day);
    final isToday = taskDay == today;

    // 自动切换时间轴模式
    if (!isToday && _timelineMode == 'hour') {
      setState(() => _timelineMode = 'day');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTask(task);
      });
    } else if (isToday && _timelineMode == 'day') {
      setState(() => _timelineMode = 'hour');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTask(task);
      });
    } else {
      _scrollToTask(task);
    }
  }

  /// Normalize DB priority int to label format.
  String _dbPriorityToLabel(int p) {
    switch (p) {
      case 5: return 'P0';
      case 3: return 'P1';
      case 1: return 'P2';
      default: return 'P3';
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'P0':
        return AppTheme.priorityP0;
      case 'P1':
        return AppTheme.priorityP1;
      case 'P2':
        return AppTheme.priorityP2;
      case 'P3':
        return AppTheme.priorityP3;
      default:
        // Handle numeric format from DB
        if (priority == '5') return AppTheme.priorityP0;
        if (priority == '3') return AppTheme.priorityP1;
        if (priority == '1') return AppTheme.priorityP2;
        return AppTheme.priorityP3;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'P0': return '紧急';
      case 'P1': return '重要';
      case 'P2': return '普通';
      case 'P3': return '低';
      default:
        if (priority == '5') return '紧急';
        if (priority == '3') return '重要';
        if (priority == '1') return '普通';
        return '低';
    }
  }

  Widget _buildParentBanner(String parentId) {
    final parentTask = _timelineTasks.where((t) => t.taskId == parentId).firstOrNull;

    // Also try to load from subtask cache — parent might not be in timeline
    final parentTitle = parentTask?.title ?? '';
    final hasParent = parentTask != null;

    if (!hasParent && parentTitle.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: hasParent ? () => _selectTask(parentTask) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.bgInput.withValues(alpha: 0.5),
          border: const Border(
            bottom: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.subdirectory_arrow_left_rounded,
              size: 16,
              color: hasParent
                  ? AppTheme.primaryColor
                  : AppTheme.textHint,
            ),
            const SizedBox(width: 6),
            Text(
              hasParent ? parentTitle : '父任务未在时间轴中',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: hasParent
                    ? AppTheme.primaryColor
                    : AppTheme.textHint,
              ),
            ),
            if (hasParent) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TaskNewBloc, TaskNewState>(
      listener: (context, state) {
        if (state is TaskNewLoaded && !_loading && mounted) {
          _loadData();
        }
      },
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadData();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildGreeting(),
                      const SizedBox(height: 12),
                      _buildProjectFilter(),
                      const SizedBox(height: 12),
                      _buildTimeline(),
                      const SizedBox(height: 16),
                      if (_selectedTask != null) _buildTaskDetail(),
                      const SizedBox(height: 24),
                      _buildQuadrantChart(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? '早上好'
        : hour < 18
        ? '下午好'
        : '晚上好';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting！',
          style: GoogleFonts.instrumentSerifTextTheme().displaySmall?.copyWith(
            color: AppTheme.textPrimary,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _filteredTasks.isNotEmpty
              ? (_filterProjectId != null
                  ? '筛选出 ${_filteredTasks.length} 个任务'
                  : '时间轴上有 ${_filteredTasks.length} 个任务节点')
              : '没有匹配的任务',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildProjectFilter() {
    final projects = _projectCache.values.toList();
    if (projects.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _filterProjectId,
                isDense: true,
                hint: const Text('全部项目', style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('全部项目', style: TextStyle(fontSize: 13)),
                  ),
                  ...projects.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: Color(int.parse(p.color.replaceFirst('#', '0xFF'))),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(p.name, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )),
                ],
                onChanged: (id) {
                  setState(() {
                    _filterProjectId = id;
                    _applyProjectFilter();
                  });
                },
              ),
            ),
          ),
          if (_filterProjectId != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _filterProjectId = null;
                  _applyProjectFilter();
                });
              },
              child: const Icon(Icons.close, size: 16, color: AppTheme.textHint),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Timeline
  // ──────────────────────────────────────────────

  Widget _buildScrollButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.bgInput.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Icon(icon, size: 18, color: AppTheme.textSecondary),
      ),
    );
  }

  /// 根据当前可见列里 dayTasks 的最大数量动态算时间轴高度
  double _timelineHeight() {
    int maxInCol = 1;
    if (_timelineMode == 'hour') {
      for (int h = 0; h < 24; h++) {
        final n = _filteredTasks
            .where((t) =>
                _isSameDayDate(t.date, DateTime.now()) && t.date.hour == h)
            .length;
        if (n > maxInCol) maxInCol = n;
      }
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final base = today.subtract(Duration(days: _daysBefore));
      for (int d = 0; d < _daysBefore + _daysAfter; d++) {
        final day = base.add(Duration(days: d));
        final n = _filteredTasks
            .where((t) => _isSameDayDate(t.date, day))
            .length;
        if (n > maxInCol) maxInCol = n;
      }
    }
    // 基础 80，每多一个任务多 26，最多 6 个高度（之上靠节点内滚动）
    final h = 80.0 + (maxInCol.clamp(1, 6) - 1) * 26.0;
    return h.clamp(80.0, 80.0 + 5 * 26.0);
  }

  Widget _buildTimeline() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final baseDate = today.subtract(Duration(days: _daysBefore));
    final totalDays = _daysBefore + _daysAfter;

    final int itemCount;
    final double itemExtent;
    final Widget Function(BuildContext, int) itemBuilder;

    if (_timelineMode == 'hour') {
      itemCount = 24;
      itemExtent = _hourWidth;
      itemBuilder = (context, index) => _buildHourColumn(index);
    } else {
      itemCount = totalDays;
      itemExtent = _dayWidth;
      itemBuilder = (context, index) {
        final dayDate = baseDate.add(Duration(days: index));
        final isToday = _isSameDayDate(dayDate, today);
        return _buildDayColumn(dayDate, isToday, index);
      };
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coral accent bar
          Container(
            height: 3,
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
          ),
          // Mode toggle + date label
          _buildTimelineHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(
              children: [
                // Left scroll button
                _buildScrollButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () {
                    final offset = _timelineController.offset;
                    final screenWidth = MediaQuery.of(context).size.width;
                    _timelineController.animateTo(
                      max(0.0, offset - screenWidth * 0.7),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SizedBox(
                    height: _timelineHeight(),
                    child: ListView.builder(
                      controller: _timelineController,
                      scrollDirection: Axis.horizontal,
                      itemCount: itemCount,
                      itemExtent: itemExtent,
                      itemBuilder: itemBuilder,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Right scroll button
                _buildScrollButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () {
                    final offset = _timelineController.offset;
                    final maxScroll =
                        _timelineController.position.maxScrollExtent;
                    final screenWidth = MediaQuery.of(context).size.width;
                    _timelineController.animateTo(
                      min(maxScroll, offset + screenWidth * 0.7),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineHeader() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          // Date label
          if (_timelineMode == 'hour')
            Text(
              '${today.month}月${today.day}日',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            )
          else
            const Text(
              '时间轴',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          const Spacer(),
          // Toggle
          _buildModeChip('小时', 'hour'),
          const SizedBox(width: 4),
          _buildModeChip('天', 'day'),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, String mode) {
    final isSelected = _timelineMode == mode;
    return GestureDetector(
      onTap: () {
        if (_timelineMode == mode) return;
        _modeSwitchGuard = true;
        setState(() => _timelineMode = mode);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToNearestTask();
          _modeSwitchGuard = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderSubtle,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  bool _isSameDayDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDayColumn(DateTime dayDate, bool isToday, int dayIndex) {
    // Find tasks for this day
    final dayTasks = _filteredTasks.where((t) {
      return t.date.year == dayDate.year &&
          t.date.month == dayDate.month &&
          t.date.day == dayDate.day;
    }).toList();

    final now = DateTime.now();
    final isPastDay = dayDate.isBefore(DateTime(now.year, now.month, now.day));

    return GestureDetector(
      onTap: () {
        if (dayTasks.isNotEmpty) {
          _selectTask(dayTasks.first);
        }
      },
      child: SizedBox(
        width: _dayWidth,
        child: Column(
          children: [
            // Day label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: isToday
                  ? BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Text(
                '${dayDate.month}/${dayDate.day}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday
                      ? AppTheme.primaryColor
                      : isPastDay
                      ? AppTheme.textHint
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Day separator line
            Container(
              height: 1,
              color: isToday
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : AppTheme.borderSubtle.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 6),
            // Task dots
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: dayTasks.isEmpty
                    ? const SizedBox.shrink()
                    : _buildTaskDots(dayTasks),
              ),
            ),
            // Today indicator
            if (isToday)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourColumn(int hour) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hourDateTime = DateTime(today.year, today.month, today.day, hour);

    // Find tasks for this hour
    final hourTasks = _filteredTasks.where((t) {
      return _isSameDayDate(t.date, today) && t.date.hour == hour;
    }).toList();

    final isCurrentHour =
        now.hour == hour && _isSameDayDate(now, today);
    final isPastHour = hourDateTime.isBefore(now) && !isCurrentHour;

    return GestureDetector(
      onTap: () {
        if (hourTasks.isNotEmpty) {
          _selectTask(hourTasks.first);
        }
      },
      child: SizedBox(
        width: _hourWidth,
        child: Column(
          children: [
            // Hour label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: isCurrentHour
                  ? BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isCurrentHour ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrentHour
                      ? AppTheme.primaryColor
                      : isPastHour
                          ? AppTheme.textHint
                          : AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Hour separator line
            Container(
              height: 1,
              color: isCurrentHour
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : AppTheme.borderSubtle.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 6),
            // Task dots
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: hourTasks.isEmpty
                    ? const SizedBox.shrink()
                    : _buildTaskDots(hourTasks),
              ),
            ),
            // Current hour indicator
            if (isCurrentHour)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskDots(List<_TimelineTask> tasks) {
    // 单列内允许上下滚动（任务多时）
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: tasks.map((task) {
          final isSelected = task.id == _selectedTaskId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _selectTask(task),
                  onSecondaryTap: () => _showDeleteContextMenu(context, task),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 14 : 10,
                    height: isSelected ? 14 : 10,
                    decoration: BoxDecoration(
                      color: task.isCompleted
                          ? AppTheme.textHint.withValues(alpha: 0.4)
                          : _priorityColor(task.priority),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: AppTheme.primaryColor, width: 2)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.4),
                              blurRadius: 4,
                            )]
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 40,
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Task Detail
  // ──────────────────────────────────────────────

  Widget _buildTaskDetail() {
    final task = _selectedTask!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with priority bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: task.isCompleted
                    ? [AppTheme.textHint, AppTheme.textHint]
                    : [
                        _priorityColor(task.priority),
                        _priorityColor(task.priority).withValues(alpha: 0.6),
                      ],
              ),
            ),
          ),
          // Parent task banner
          if (task.parentId != null)
            _buildParentBanner(task.parentId!),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    // 完成复选框
                    GestureDetector(
                      onTap: () => _toggleTaskCompletion(task),
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: task.isCompleted
                              ? AppTheme.success
                              : Colors.transparent,
                          border: Border.all(
                            color: task.isCompleted
                                ? AppTheme.success
                                : AppTheme.textHint,
                            width: 2,
                          ),
                        ),
                        child: task.isCompleted
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: task.isCompleted
                              ? AppTheme.textHint
                              : AppTheme.textPrimary,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (task.isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '已完成',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    // 编辑按钮
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: AppTheme.textHint,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _navigateToEdit(task),
                    ),
                    const SizedBox(width: 4),
                    // 删除按钮
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppTheme.error,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _confirmDeleteTask(task),
                    ),
                  ],
                ),
                // Date + Priority (可点击)
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _quickEditDate(task),
                      child: Text(
                        _formatTaskDate(task.date),
                        style: GoogleFonts.jetBrainsMonoTextTheme().bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _quickCyclePriority(task),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _priorityColor(task.priority).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _priorityColor(task.priority).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: _priorityColor(task.priority),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _priorityLabel(task.priority),
                              style: TextStyle(
                                color: _priorityColor(task.priority),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                //              ),\n                  ],\n                ),\n                // Project",}
                if (task.projectId != null &&
                    _projectCache.containsKey(task.projectId!)) ...[
                  const SizedBox(height: 10),
                  _buildProjectBadge(task.projectId!),
                ],
                // Description（固定高度可滚动；超过 1000 字截断+"展开全文"）
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDescriptionBox(task),
                ],
                // Checklist items (DB only)
                const SizedBox(height: 12),
                _buildChecklistPreview(task),
                // Subtask tree (DB only)
                if (task.source == 'db')
                  _buildSubtaskTree(task.taskId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionBox(_TimelineTask task) {
    final full = task.description ?? '';
    const maxChars = 1000;
    final isTruncated = full.length > maxChars;
    final shown = isTruncated ? full.substring(0, maxChars) : full;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 240),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgInput,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shown,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (isTruncated) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _navigateToEdit(task),
                  child: Text(
                    '展开全文（共 ${full.length} 字）',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor:
                          AppTheme.primaryColor.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectBadge(String projectId) {
    final project = _projectCache[projectId]!;
    return Row(
      children: [
        const Icon(Icons.folder_outlined,
            size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Color(int.parse(project.color.replaceFirst('#', '0xFF'))),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          project.name,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _loadChecklists(String taskId) async {
    if (widget.checklistRepository == null) return;
    final items = await widget.checklistRepository!.getByTask(taskId);
    if (mounted) {
      setState(() {
        _checklistCache[taskId] = items;
      });
    }
  }

  Future<void> _loadSubTasks(String taskId) async {
    if (widget.taskRepository == null) return;
    final subtasks = await widget.taskRepository!.getSubTasks(taskId);
    if (mounted) {
      setState(() {
        _subtaskCache[taskId] = subtasks;
      });
    }
  }

  Widget _buildSubtaskTree(String taskId) {
    final subtasks = _subtaskCache[taskId];

    if (subtasks == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSubTasks(taskId);
      });
      return const SizedBox.shrink();
    }

    if (subtasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.account_tree_outlined,
                size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              '子任务 (${subtasks.length})',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...subtasks.map((st) {
          final tlTask = _timelineTasks.where((t) => t.taskId == st.id).firstOrNull;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const SizedBox(width: 16),
                // 完成切换（只更新数据库，不触发任何setState/导航）
                GestureDetector(
                  onTap: () {
                    widget.taskRepository?.toggleStatus(st.id);
                    // 直接更新本地缓存来更新图标，避免触发setState级联刷新
                    final cached = _subtaskCache[taskId];
                    if (cached != null) {
                      final idx = cached.indexOf(st);
                      if (idx >= 0) {
                        final updated = List<Task>.from(cached);
                        final newStatus = st.status == 2 ? 0 : 2;
                        updated[idx] = Task(
                          id: st.id,
                          projectId: st.projectId,
                          parentId: st.parentId,
                          title: st.title,
                          description: st.description,
                          priority: st.priority,
                          status: newStatus,
                          startDate: st.startDate,
                          dueDate: st.dueDate,
                          isAllDay: st.isAllDay,
                          completedTime: newStatus == 2 ? DateTime.now().millisecondsSinceEpoch : st.completedTime,
                          sortOrder: st.sortOrder,
                          createdAt: st.createdAt,
                          updatedAt: DateTime.now().millisecondsSinceEpoch,
                          remindBeforeMinutes: st.remindBeforeMinutes,
                          reminderEnabled: st.reminderEnabled,
                        );
                        _subtaskCache[taskId] = updated;
                        setState(() {});
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      st.status == 2
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: st.status == 2
                          ? AppTheme.success
                          : AppTheme.textHint,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // 标题 — 点击导航到该子任务
                GestureDetector(
                  onTap: () {
                    if (tlTask != null) {
                      _selectTask(tlTask);
                    } else {
                      final now = DateTime.now();
                      final date = st.startDate != null
                          ? DateTime.fromMillisecondsSinceEpoch(st.startDate!)
                          : (st.dueDate != null
                              ? DateTime.fromMillisecondsSinceEpoch(st.dueDate!)
                              : now);
                      _selectTask(_TimelineTask(
                        id: st.id,
                        title: st.title,
                        description: '',
                        date: date,
                        isCompleted: st.status == 2,
                        priority: st.priority.toString(),
                        source: 'db',
                        projectId: st.projectId,
                        taskId: st.id,
                        parentId: st.parentId,
                      ));
                    }
                  },
                  child: Text(
                    st.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: st.status == 2
                          ? AppTheme.textHint
                          : AppTheme.textPrimary,
                      decoration: st.status == 2
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildChecklistPreview(_TimelineTask task) {
    if (task.source != 'db' || widget.checklistRepository == null) {
      return const SizedBox.shrink();
    }

    final cachedItems = _checklistCache[task.taskId];
    if (cachedItems == null) {
      // Trigger async load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadChecklists(task.taskId);
      });
      return const SizedBox(
        height: 24,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (cachedItems.isEmpty) return const SizedBox.shrink();

    final completed = cachedItems.where((c) => c.status == 1).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.checklist_rounded,
                size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              '检查项 ($completed/${cachedItems.length})',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...cachedItems.take(5).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    item.status == 1
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: item.status == 1
                        ? AppTheme.success
                        : AppTheme.textHint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: item.status == 1
                            ? AppTheme.textHint
                            : AppTheme.textPrimary,
                        decoration: item.status == 1
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            )),
        if (cachedItems.length > 5)
          Text(
            '+${cachedItems.length - 5} 更多',
            style: const TextStyle(
              color: AppTheme.textHint,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  String _formatTaskDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(date.year, date.month, date.day);
    final diff = taskDay.difference(today).inDays;

    if (diff == 0) return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff == 1) return '明天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff == -1) return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToEdit(_TimelineTask task) {
    if (task.source == 'db') {
      final repo = widget.taskRepository;
      if (repo == null) return;
      repo.get(task.taskId).then((dbTask) {
        if (dbTask != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<TaskNewBloc>(),
                child: TaskDetailPage(task: dbTask),
              ),
            ),
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('暂不支持编辑此类型任务')),
      );
    }
  }

  Future<void> _quickEditDate(_TimelineTask task) async {
    if (task.source != 'db' || widget.taskRepository == null) return;
    final now = DateTime.now();
    final picked = await showCalendarDatePicker(
      context: context,
      initialDate: task.date,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final updated = DateTime(picked.year, picked.month, picked.day, task.date.hour, task.date.minute);
    await widget.taskRepository!.update(task.taskId,
      startDate: updated.millisecondsSinceEpoch,
      dueDate: updated.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    _loadData();
  }

  void _quickCyclePriority(_TimelineTask task) {
    if (task.source != 'db' || widget.taskRepository == null) return;
    // Map label back to DB value
    const labelToDb = {'P3': 0, 'P2': 1, 'P1': 3, 'P0': 5};
    final dbValues = [0, 1, 3, 5];
    final labels = ['P3', 'P2', 'P1', 'P0'];
    int currentLabelIdx = labels.indexOf(task.priority);
    if (currentLabelIdx < 0) currentLabelIdx = 0;
    final nextLabel = labels[(currentLabelIdx + 1) % labels.length];
    final nextDbValue = labelToDb[nextLabel]!;
    widget.taskRepository!.update(task.taskId, priority: nextDbValue);
    final listIdx = _timelineTasks.indexOf(task);
    if (listIdx >= 0) {
      _timelineTasks[listIdx] = _TimelineTask(
        id: task.id, title: task.title, description: task.description,
        date: task.date, isCompleted: task.isCompleted,
        priority: nextLabel, source: task.source,
        projectId: task.projectId, taskId: task.taskId, parentId: task.parentId,
      );
      _applyProjectFilter();
      if (_selectedTaskId == task.id) _selectedTask = _timelineTasks[listIdx];
    }
    if (mounted) setState(() {});
  }

  void _toggleTaskCompletion(_TimelineTask task) async {
    if (task.source != 'db' || widget.taskRepository == null) return;
    // 直接操作数据库，不触发 BLoC 避免级联 reload
    await widget.taskRepository!.toggleStatus(task.taskId);
    // 更新本地缓存
    final idx = _timelineTasks.indexOf(task);
    if (idx >= 0) {
      _timelineTasks[idx] = _TimelineTask(
        id: task.id,
        title: task.title,
        description: task.description,
        date: task.date,
        isCompleted: !task.isCompleted,
        priority: task.priority,
        source: task.source,
        projectId: task.projectId,
        taskId: task.taskId,
        parentId: task.parentId,
      );
      _applyProjectFilter();
      if (_selectedTaskId == task.id) _selectedTask = _timelineTasks[idx];
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirmDeleteTask(_TimelineTask task) async {
    // Return early only if both sources are unavailable
    if (task.source == 'db' && widget.taskRepository == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除"${task.title}"吗？\n其所有子任务也会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      if (task.source == 'db' && widget.taskRepository != null) {
        await widget.taskRepository!.delete(task.taskId);
      } else if (task.source == 'storage') {
        widget.storage.deleteTask(task.taskId);
      }
      if (_selectedTaskId == task.id) {
        _selectedTaskId = null;
        _selectedTask = null;
      }
      _loadData();
    }
  }

  /// 显示删除上下文菜单（时间轴右键用）
  void _showDeleteContextMenu(BuildContext context, _TimelineTask task) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.error),
              title: const Text('删除任务', style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteTask(task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑任务'),
              onTap: () {
                Navigator.pop(ctx);
                _navigateToEdit(task);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Four-Quadrant Chart
  // ──────────────────────────────────────────────

  Widget _buildQuadrantChart() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final overdueCount = _filteredTasks.where((t) => !t.isCompleted && t.date.isBefore(today)).length;
    final scored = <_TimelineTask, int>{};
    for (final t in _filteredTasks) {
      if (t.isCompleted) continue;
      final pmap = <String, int>{'P0': 5, 'P1': 3, 'P2': 1, 'P3': 0};
      final p = pmap[t.priority] ?? 0;
      final d = t.date.difference(now).inDays;
      final u = d < 0 ? 10 : d <= 3 ? 5 : d <= 7 ? 2 : d <= 30 ? 0 : -2;
      scored[t] = p * 2 + u;
    }
    final sorted = scored.keys.toList()..sort((a, b) => scored[b]!.compareTo(scored[a]!));
    final q1 = <_TimelineTask>[], q2 = <_TimelineTask>[];
    final q3 = <_TimelineTask>[], q4 = <_TimelineTask>[];
    for (final t in sorted) {
      final urgent = t.date.difference(now).inDays <= 3;
      final important = t.priority == 'P0' || t.priority == 'P1';
      (urgent ? (important ? q1 : q3) : (important ? q2 : q4)).add(t);
    }
    for (final q in [q1, q2, q3, q4]) {
      if (q.length > 5) q.removeRange(5, q.length);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.grid_view_rounded,
                size: 18, color: AppTheme.textPrimary),
            const SizedBox(width: 6),
            Text(
              '四象限',
              style: GoogleFonts.interTextTheme().titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Overdue banner
        if (overdueCount > 0)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.error.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppTheme.error),
                const SizedBox(width: 6),
                Text(
                  '$overdueCount 个任务已逾期',
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        // Quadrant grid
        SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildQuadrant(
                      title: '重要不紧急',
                      color: const Color(0xFF4A90D9),
                      tasks: q2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuadrant(
                      title: '紧急重要',
                      color: const Color(0xFFE74C3C),
                      tasks: q1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildQuadrant(
                      title: '不重要不紧急',
                      color: const Color(0xFF95A5A6),
                      tasks: q4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuadrant(
                      title: '紧急不重要',
                      color: const Color(0xFFF39C12),
                      tasks: q3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuadrant({
    required String title,
    required Color color,
    required List<_TimelineTask> tasks,
  }) {
    // Find overdue tasks in this quadrant
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdueTasks = tasks.where((t) => t.date.isBefore(today)).toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '暂无',
                style: TextStyle(
                  color: AppTheme.textHint,
                  fontSize: 11,
                ),
              ),
            )
          else
            ...tasks.take(4).map((task) {
              final isOverdueItem = task.date.isBefore(today);
              return GestureDetector(
                onTap: () => _selectTask(task),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      if (isOverdueItem)
                        const Padding(
                          padding: EdgeInsets.only(right: 3),
                          child: Icon(Icons.error_rounded,
                              size: 12, color: AppTheme.error),
                        )
                      else
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: _priorityColor(task.priority),
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isOverdueItem
                                ? AppTheme.error
                              : AppTheme.textPrimary,
                          fontWeight: isOverdueItem
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            }),
          if (tasks.length > 4)
            Text(
              '+${tasks.length - 4} 更多',
              style: const TextStyle(
                color: AppTheme.textHint,
                fontSize: 10,
              ),
            ),
          if (overdueTasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${overdueTasks.length} 逾期',
                style: const TextStyle(
                  color: AppTheme.error,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Data model for timeline
// ──────────────────────────────────────────────

class _TimelineTask {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final bool isCompleted;
  final String priority;
  final String source; // 'storage' or 'db'
  final String? projectId;
  final String taskId;
  final String? parentId;

  const _TimelineTask({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    required this.isCompleted,
    required this.priority,
    required this.source,
    this.projectId,
    required this.taskId,
    this.parentId,
  });
}
