import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/checklist_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/permission_service.dart';
import '../../../services/attachment_sync_service.dart';
import '../../../services/checklist_sync_service.dart';
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
import '../tasks/task_detail/widgets/attachment_section.dart';
import '../tasks/task_detail/widgets/checklist_section.dart';
import '../tasks/tasks_page.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

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
  StreamSubscription<sb.AuthState>? _authSub;
  StreamSubscription<void>? _projectChangesSub;
  Timer? _projectChangesDebounce;
  bool _projectSyncStarted = false;

  @override
  void initState() {
    super.initState();
    _initStorage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionService.showNotificationGuideIfNeeded(context);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _projectChangesSub?.cancel();
    _projectChangesDebounce?.cancel();
    super.dispose();
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
      ProfilePage(taskRepository: widget.taskRepository),
    ];
  }

  Future<void> _initStorage() async {
    await _storage.init();
    _storageReady = true;
    await _storage.fetchAndMergeFromCloud();
    // 所有业务数据同步统一在登录后启动（见 _setupProjectSyncOnAuth）
    _setupProjectSyncOnAuth();
    _loadStats();
    _checkOnboarding();
    if (mounted) setState(() {});
  }

  /// 监听 Supabase 登录状态：登录后才启动项目/分组同步
  void _setupProjectSyncOnAuth() {
    final client = sb.Supabase.instance.client;
    // 全量对账（projects/tasks/checklist/attachments），完成后刷新 UI
    Future<void> runSyncAll() async {
      await ProjectSyncService.instance.syncAll();
      await TaskSyncService.instance.syncAll();
      await ChecklistSyncService.instance.syncAll();
      await AttachmentSyncService.instance.pullAll();
      if (mounted) context.read<TaskNewBloc>().add(LoadTasks());
    }

    void startIfReady() {
      if (client.auth.currentUser == null) return;
      if (!_projectSyncStarted) {
        _projectSyncStarted = true;
        print('[Sync] 检测到登录用户 ${client.auth.currentUser?.id}，启动同步');
        ProjectSyncService.instance.subscribe();
        TaskSyncService.instance.subscribe();
        ChecklistSyncService.instance.subscribe();
        AttachmentSyncService.instance.subscribe();
        // 远端变更（Realtime/拉取）后 debounce 触发 LoadTasks，让 sidebar 实时刷新
        _projectChangesSub ??= ProjectSyncService.instance.changes.listen((_) {
          _projectChangesDebounce?.cancel();
          _projectChangesDebounce =
              Timer(const Duration(milliseconds: 500), () {
            if (mounted) context.read<TaskNewBloc>().add(LoadTasks());
          });
        });
      }
      // 每次登录/会话恢复都跑一次全量对账
      runSyncAll();
    }
    startIfReady();
    _authSub = client.auth.onAuthStateChange.listen((data) {
      if (data.event == sb.AuthChangeEvent.signedIn ||
          data.event == sb.AuthChangeEvent.initialSession) {
        startIfReady();
      }
    });
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
          showAppSnackBar(context, '日程已创建');
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, '创建日程失败：$e');
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
        showAppSnackBar(context, '日程已更新');
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
        showAppSnackBar(context, '日程已删除');
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
        border: Border(
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
              decoration: BoxDecoration(
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
            decoration: BoxDecoration(
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
  String _statsPeriod = 'day'; // 完成率统计周期: 'day'|'week'|'month'|'year'
  String? _filterProjectId;
  Timer? _timelineScrollDebounce;
  double _viewportWidth = 0;

  // Combined timeline data
  List<_TimelineTask> _timelineTasks = [];
  List<_TimelineTask> _filteredTasks = [];
  Map<String, Project> _projectCache = {};
  final Map<String, List<ChecklistItem>> _checklistCache = {};
  final Map<String, List<Task>> _subtaskCache = {};
  final Map<String, Task?> _dbTaskCache = {};
  String? _selectedTaskId;
  _TimelineTask? _selectedTask;

  @override
  void initState() {
    super.initState();
    _timelineController = ScrollController()
      ..addListener(() {
        // 滚动时 debounce 触发高度重算
        _timelineScrollDebounce?.cancel();
        _timelineScrollDebounce =
            Timer(const Duration(milliseconds: 120), () {
          if (mounted) setState(() {});
        });
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _timelineScrollDebounce?.cancel();
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
      final end = t.dueDate != null
          ? DateTime.fromMillisecondsSinceEpoch(t.dueDate!)
          : null;
      timelineItems.add(_TimelineTask(
        id: t.id,
        title: t.title,
        description: t.description,
        date: date,
        endDate: end,
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
          border: Border(
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _buildGreeting()),
                          const SizedBox(width: 12),
                          _buildStatsCompact(),
                        ],
                      ),
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
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Stats Card (今日任务数 / 完成率 / 逾期数)
  // ──────────────────────────────────────────────

  /// 返回指定周期的 [start, end) 区间（含 start，不含 end）
  (DateTime, DateTime) _periodRange(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case 'week':
        final start = today.subtract(Duration(days: today.weekday - 1));
        return (start, start.add(const Duration(days: 7)));
      case 'month':
        final start = DateTime(now.year, now.month, 1);
        final end = now.month < 12
            ? DateTime(now.year, now.month + 1, 1)
            : DateTime(now.year + 1, 1, 1);
        return (start, end);
      case 'year':
        return (DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1));
      case 'day':
      default:
        return (today, today.add(const Duration(days: 1)));
    }
  }

  Widget _buildStatsCompact() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayCount =
        _filteredTasks.where((t) => _isSameDayDate(t.date, today)).length;

    final (start, end) = _periodRange(_statsPeriod);
    final inPeriod = _filteredTasks
        .where((t) => !t.date.isBefore(start) && t.date.isBefore(end))
        .toList();
    final completedCount = inPeriod.where((t) => t.isCompleted).length;

    final overdueCount = _filteredTasks
        .where((t) => t.date.isBefore(today) && !t.isCompleted)
        .length;

    return GestureDetector(
      onTap: _showStatsDetail,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCompactStat('今日', '$todayCount', AppTheme.textPrimary),
            _compactDivider(),
            _buildCompactStat(
              '完成率',
              '$completedCount/${inPeriod.length}',
              AppTheme.primaryColor,
            ),
            _compactDivider(),
            _buildCompactStat(
              '逾期',
              '$overdueCount',
              overdueCount > 0 ? AppTheme.error : AppTheme.textPrimary,
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 14, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.jetBrainsMonoTextTheme().titleMedium?.copyWith(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: AppTheme.textHint, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _compactDivider() => Container(
        width: 0.5,
        height: 28,
        color: AppTheme.borderSubtle,
      );

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color valueColor,
    bool showChevron = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: GoogleFonts.jetBrainsMonoTextTheme().titleLarge?.copyWith(
                    color: valueColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right, size: 16, color: AppTheme.error),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  void _showStatsDetail() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayCount =
        _filteredTasks.where((t) => _isSameDayDate(t.date, today)).length;
    final overdueCount = _filteredTasks
        .where((t) => t.date.isBefore(today) && !t.isCompleted)
        .length;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        String sheetPeriod = _statsPeriod;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final (start, end) = _periodRange(sheetPeriod);
            final inPeriod = _filteredTasks
                .where((t) => !t.date.isBefore(start) && t.date.isBefore(end))
                .toList();
            final completedCount = inPeriod.where((t) => t.isCompleted).length;

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textHint.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        label: '今日任务', value: '$todayCount',
                        valueColor: AppTheme.textPrimary,
                      ),
                      _buildStatItem(
                        label: '完成率', value: '$completedCount/${inPeriod.length}',
                        valueColor: AppTheme.primaryColor,
                      ),
                      GestureDetector(
                        onTap: overdueCount > 0
                            ? () {
                                Navigator.pop(ctx);
                                _showOverdueSheet();
                              }
                            : null,
                        child: _buildStatItem(
                          label: '逾期', value: '$overdueCount',
                          valueColor: overdueCount > 0
                              ? AppTheme.error
                              : AppTheme.textPrimary,
                          showChevron: overdueCount > 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ['日', '周', '月', '年'].map((label) {
                      final p = label == '日' ? 'day'
                          : label == '周' ? 'week'
                          : label == '月' ? 'month'
                          : 'year';
                      final selected = sheetPeriod == p;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () {
                            if (sheetPeriod == p) return;
                            setSheetState(() => sheetPeriod = p);
                            setState(() => _statsPeriod = p);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppTheme.primaryColor
                                    : AppTheme.borderSubtle,
                                width: selected ? 1.5 : 0.5,
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showOverdueSheet() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = _filteredTasks
        .where((t) => t.date.isBefore(today) && !t.isCompleted)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (overdue.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppTheme.error),
                  const SizedBox(width: 6),
                  Text(
                    '逾期任务 (${overdue.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: overdue.length,
                itemBuilder: (_, i) {
                  final task = overdue[i];
                  return ListTile(
                    leading: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _priorityColor(task.priority),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatTaskDate(task.date),
                      style: TextStyle(color: AppTheme.error, fontSize: 12),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        size: 18, color: AppTheme.textHint),
                    onTap: () {
                      Navigator.pop(ctx);
                      // 选中时间轴节点并展开详情卡（时间轴随之切换天/小时）
                      _selectTask(task);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
          Icon(Icons.folder_outlined, size: 16, color: AppTheme.textSecondary),
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
              child: Icon(Icons.close, size: 16, color: AppTheme.textHint),
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

  /// 仅看当前视野内列的最大任务数。1 个任务保持 base 高度
  double _timelineHeight() {
    final offset =
        _timelineController.hasClients ? _timelineController.offset : 0.0;
    final viewport = _viewportWidth > 0
        ? _viewportWidth
        : MediaQuery.of(context).size.width;
    int maxInCol = 0;
    if (_timelineMode == 'hour') {
      final firstHour = (offset / _hourWidth).floor().clamp(0, 23);
      final lastHour =
          ((offset + viewport) / _hourWidth).ceil().clamp(0, 24);
      for (int h = firstHour; h < lastHour; h++) {
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
      final firstCol =
          (offset / _dayWidth).floor().clamp(0, _daysBefore + _daysAfter - 1);
      final lastCol = ((offset + viewport) / _dayWidth)
          .ceil()
          .clamp(0, _daysBefore + _daysAfter);
      for (int d = firstCol; d < lastCol; d++) {
        final day = base.add(Duration(days: d));
        final n =
            _filteredTasks.where((t) => _isSameDayDate(t.date, day)).length;
        if (n > maxInCol) maxInCol = n;
      }
    }
    // 0 或 1 任务保持基础 80px；从 2 个开始按 26px/任务递增；封顶 6 行
    if (maxInCol <= 1) return 80.0;
    final h = 80.0 + (maxInCol.clamp(2, 6) - 1) * 26.0;
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
                  child: LayoutBuilder(builder: (ctx, box) {
                    if (_viewportWidth != box.maxWidth) {
                      _viewportWidth = box.maxWidth;
                    }
                    return SizedBox(
                      height: _timelineHeight(),
                      child: ListView.builder(
                        controller: _timelineController,
                        scrollDirection: Axis.horizontal,
                        itemCount: itemCount,
                        itemExtent: itemExtent,
                        itemBuilder: itemBuilder,
                      ),
                    );
                  }),
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            )
          else
            Text(
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
                decoration: BoxDecoration(
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
                decoration: BoxDecoration(
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
                    style: TextStyle(
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
                        child: Text(
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
                    Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _quickEditDate(task, isStart: true),
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
                    if (task.endDate != null) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward_rounded, size: 10, color: AppTheme.textHint),
                      ),
                      GestureDetector(
                        onTap: () => _quickEditDate(task, isStart: false),
                        child: Text(
                          _formatTaskDate(task.endDate!),
                          style: GoogleFonts.jetBrainsMonoTextTheme().bodySmall?.copyWith(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                            decorationColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
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
                  _buildProjectBadge(task.projectId!, task),
                ],
                // Description（固定高度可滚动；超过 1000 字截断+"展开全文"）
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDescriptionBox(task),
                ],
                // Subtask tree (DB only)
                if (task.source == 'db')
                  _buildSubtaskTree(task.taskId),
                // Resource section: attachment + checklist (DB only, fully interactive)
                _buildResourceSection(task),
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
                style: TextStyle(
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

  Widget _buildProjectBadge(String projectId, _TimelineTask task) {
    final project = _projectCache[projectId]!;
    return GestureDetector(
      onTap: () => _quickChangeProject(task),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined,
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
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
              decorationColor: Color(0x4DDE6B48),
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 14, color: AppTheme.textHint),
        ],
      ),
    );
  }

  Future<void> _quickChangeProject(_TimelineTask task) async {
    if (task.source != 'db' || widget.taskRepository == null) return;
    final projects = _projectCache.values.toList();
    if (projects.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择项目', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ...projects.map((p) {
              final color = Color(int.parse(p.color.replaceFirst('#', '0xFF')));
              return ListTile(
                leading: CircleAvatar(
                  radius: 10,
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                ),
                title: Text(p.name),
                selected: p.id == task.projectId,
                onTap: () => Navigator.pop(ctx, p.id),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && selected != task.projectId && mounted) {
      await widget.taskRepository!.update(task.taskId, projectId: selected);
      _loadData();
    }
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

  Future<void> _loadDbTask(String taskId) async {
    if (widget.taskRepository == null) return;
    final task = await widget.taskRepository!.get(taskId);
    if (mounted) setState(() => _dbTaskCache[taskId] = task);
  }

  Future<void> _homeToggleChecklist(String itemId, String taskId) async {
    await widget.checklistRepository?.toggleStatus(itemId);
    await _loadChecklists(taskId);
  }

  Future<void> _homeDeleteChecklist(String itemId, String taskId) async {
    await widget.checklistRepository?.delete(itemId);
    await _loadChecklists(taskId);
  }

  Future<void> _homeEditChecklist(String itemId, String title, String taskId) async {
    await widget.checklistRepository?.update(itemId, title: title);
    await _loadChecklists(taskId);
  }

  Future<void> _homeAddChecklist((String, String) args) async {
    final (taskId, title) = args;
    await widget.checklistRepository?.create(taskId: taskId, title: title);
    await _loadChecklists(taskId);
  }

  Future<void> _homeSetObsidianUri(String itemId, String? uri, String taskId) async {
    await widget.checklistRepository?.setObsidianUri(itemId, uri);
    await _loadChecklists(taskId);
  }

  Widget _buildResourceSection(_TimelineTask task) {
    if (task.source != 'db') return const SizedBox.shrink();
    final taskId = task.taskId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Divider(color: AppTheme.borderSubtle, height: 1),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.taskRepository != null) ...[
              Expanded(child: _buildAttachmentWidget(taskId)),
              const SizedBox(width: 8),
            ],
            if (widget.checklistRepository != null)
              Expanded(child: _buildChecklistWidget(task)),
          ],
        ),
      ],
    );
  }

  Widget _buildAttachmentWidget(String taskId) {
    final dbTask = _dbTaskCache[taskId];
    if (dbTask == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDbTask(taskId));
      return const SizedBox.shrink();
    }
    return AttachmentSection(task: dbTask);
  }

  Widget _buildChecklistWidget(_TimelineTask task) {
    final taskId = task.taskId;
    final items = _checklistCache[taskId] ?? [];
    if (_checklistCache[taskId] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadChecklists(taskId));
    }
    return ChecklistSection(
      items: items,
      taskId: taskId,
      onToggle: (id) => _homeToggleChecklist(id, taskId),
      onDelete: (id) => _homeDeleteChecklist(id, taskId),
      onEdit: (id, title) => _homeEditChecklist(id, title, taskId),
      onAdd: _homeAddChecklist,
      onSetObsidianUri: (id, uri) => _homeSetObsidianUri(id, uri, taskId),
    );
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
            Icon(Icons.account_tree_outlined,
                size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              '子任务 (${subtasks.length})',
              style: TextStyle(
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
                          deleted: st.deleted,
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
                        endDate: st.dueDate != null
                            ? DateTime.fromMillisecondsSinceEpoch(st.dueDate!)
                            : null,
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
      showAppSnackBar(context, '暂不支持编辑此类型任务');
    }
  }

  Future<void> _quickEditDate(_TimelineTask task, {bool isStart = true}) async {
    if (task.source != 'db' || widget.taskRepository == null) return;
    final now = DateTime.now();
    final initialDate = isStart ? task.date : (task.endDate ?? task.date);
    final picked = await showCalendarDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    if (isStart) {
      final updated = DateTime(picked.year, picked.month, picked.day, task.date.hour, task.date.minute);
      final duration = (task.endDate ?? task.date.add(const Duration(hours: 1))).difference(task.date);
      await widget.taskRepository!.update(task.taskId,
        startDate: updated.millisecondsSinceEpoch,
        dueDate: updated.add(duration).millisecondsSinceEpoch,
      );
    } else {
      final updated = DateTime(picked.year, picked.month, picked.day, initialDate.hour, initialDate.minute);
      if (updated.isAfter(task.date)) {
        await widget.taskRepository!.update(task.taskId,
          dueDate: updated.millisecondsSinceEpoch,
        );
      } else {
        showAppSnackBar(context, '结束时间必须晚于开始时间');
        return;
      }
    }
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
        date: task.date, endDate: task.endDate, isCompleted: task.isCompleted,
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
        endDate: task.endDate,
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
              leading: Icon(Icons.delete_outline, color: AppTheme.error),
              title: Text('删除任务', style: TextStyle(color: AppTheme.error)),
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
    // No hard cap — tasks overflow into columns within each quadrant

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.grid_view_rounded,
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
    int maxPerColumn = 5,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Chunk tasks into columns of maxPerColumn
    final columns = <List<_TimelineTask>>[];
    for (var i = 0; i < tasks.length; i += maxPerColumn) {
      columns.add(tasks.skip(i).take(maxPerColumn).toList());
    }

    Widget taskItem(_TimelineTask task) {
      final isOverdueItem = task.date.isBefore(today);
      return GestureDetector(
        onTap: () => _selectTask(task),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              if (isOverdueItem)
                Padding(
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
                    fontWeight:
                        isOverdueItem ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
        mainAxisSize: MainAxisSize.min,
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
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '暂无',
                style: TextStyle(color: AppTheme.textHint, fontSize: 11),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < columns.length; i++) ...[
                    if (i > 0)
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: color.withValues(alpha: 0.15),
                      ),
                    SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: columns[i].map(taskItem).toList(),
                      ),
                    ),
                  ],
                  if (columns.length > 1) const SizedBox(width: 8),
                ],
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
  final DateTime? endDate;
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
    this.endDate,
    required this.isCompleted,
    required this.priority,
    required this.source,
    this.projectId,
    required this.taskId,
    this.parentId,
  });
}
