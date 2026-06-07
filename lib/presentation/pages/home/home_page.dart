import 'dart:async';
import '../../../core/utils/platform_utils.dart';
import 'dart:math';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:super_clipboard/super_clipboard.dart';
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
import '../../../services/task_attachment_service.dart';
import '../../../services/task_sync_service.dart';
import '../../../services/node_template_sync_service.dart';
import '../../../services/subscription_service.dart';
import '../../../services/aliyun_push_service.dart';
import '../../widgets/battery_optimization_guide.dart';
import '../../../services/supabase_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/schedule/schedule_bloc.dart';
import '../../blocs/task_new/task_bloc.dart';
import '../../blocs/task_new/task_event.dart';
import '../../blocs/task_new/task_state.dart';
import '../../widgets/upgrade_dialog.dart';
import '../../widgets/calendar_date_picker.dart';
import '../../widgets/project_picker_content.dart';
import '../../widgets/create_schedule_dialog.dart';
import '../calendar/calendar_page.dart';
import '../profile/profile_page.dart';
import '../task/create_task_page.dart';
import '../task/task_list_page.dart';
import '../tasks/task_detail/task_detail_page.dart';
import '../tasks/task_detail/widgets/attachment_section.dart';
import '../tasks/task_detail/widgets/checklist_section.dart';
import '../tasks/tasks_page.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

class HomePage extends StatefulWidget {
  final AppDatabase? database;
  final ProjectRepository? projectRepository;
  final TaskRepository? taskRepository;
  final ChecklistRepository? checklistRepository;

  const HomePage({
    super.key,
    this.database,
    this.projectRepository,
    this.taskRepository,
    this.checklistRepository,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ValueNotifier<int> _tabIndex = ValueNotifier<int>(0);
  /// 可见 tab 索引通知器，避免每次切换重建整个 _HomeContent
  final ValueNotifier<int> _visibleTabIndex = ValueNotifier<int>(0);
  final LocalStorageService _storage = LocalStorageService();
  bool _storageReady = false;
  StreamSubscription<sb.AuthState>? _authSub;
  StreamSubscription<void>? _projectChangesSub;
  StreamSubscription<void>? _taskChangesSub;
  StreamSubscription<void>? _nodeTemplateChangesSub;

  Timer? _projectChangesDebounce;
  bool _projectSyncStarted = false;
  DateTime? _lastRescheduleTime;
  AppLifecycleListener? _lifecycleListener;
  /// 防抖：短时间内密集的 LoadTasks 只执行最后一次
  Timer? _loadTasksDebounce;
  /// 缓存页面实例，避免每次 build 重建
  late final List<Widget> _pages = _buildPages();

  @override
  void initState() {
    super.initState();
    _initStorage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionService.showNotificationGuideIfNeeded(context);
    });
    // 每次 App 回到前台时触发全量对账（打开就刷新）
    _lifecycleListener = AppLifecycleListener(
      onResume: _onAppResume,
    );
  }

  void _onAppResume() {
    final client = sb.Supabase.instance.client;
    if (client.auth.currentUser == null) return;
    // 回到前台后纯拉取云端数据，不推送本地（推送在首次登录和修改时已做）
    Future.microtask(() async {
      await ProjectSyncService.instance.forcePullAll();
      await TaskSyncService.instance.syncAll();
      _debounceLoadTasks();
      // 重新调度所有提醒（国产ROM杀进程后AlarmManager可能被清除）
      await _rescheduleTaskReminders();
    });
  }

  /// 防抖触发 LoadTasks，500ms 内多次调用只执行最后一次
  void _debounceLoadTasks() {
    _loadTasksDebounce?.cancel();
    _loadTasksDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.read<TaskNewBloc>().add(LoadTasks());
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _projectChangesSub?.cancel();
    _taskChangesSub?.cancel();
    _nodeTemplateChangesSub?.cancel();
    _projectChangesDebounce?.cancel();
    _loadTasksDebounce?.cancel();
    _tabIndex.dispose();
    _visibleTabIndex.dispose();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  /// 仅首次调用时创建页面列表，之后复用相同实例以消除每次 tab 切换的 rebuild
  List<Widget> _buildPages() {
    return [
      RepaintBoundary(
        child: _HomeContent(
          storage: _storage,
          projectRepository: widget.projectRepository,
          taskRepository: widget.taskRepository,
          checklistRepository: widget.checklistRepository,
          visibleTabIndex: _visibleTabIndex,
          onCreateSchedule: _createSchedule,
          onRefresh: _loadStats,
          onOpenTaskStatus: _openTaskStatus,
          onEditSchedule: _editSchedule,
          onDeleteSchedule: _deleteSchedule,
          key: const ValueKey('home_content'),
        ),
      ),
      const RepaintBoundary(child: TasksPage()),
      RepaintBoundary(
        child: CalendarPage(onJumpToMindMap: _jumpToMindMap),
      ),
      RepaintBoundary(
        child: ProfilePage(
          database: widget.database,
          taskRepository: widget.taskRepository,
          projectRepository: widget.projectRepository,
        ),
      ),
    ];
  }

  Future<void> _initStorage() async {
    await _storage.init();
    _storageReady = true;
    await _storage.fetchAndMergeFromCloud();
    // 所有业务数据同步统一在登录后启动（见 _setupProjectSyncOnAuth）
    _setupProjectSyncOnAuth();
    _loadStats();
    await NotificationService().requestMobilePermissions();
    await _rescheduleTaskReminders();
    if (mounted) {
      setState(() {});
      BatteryOptimizationGuide.showGuideIfNeeded(context);
    }
  }

  Future<void> _rescheduleTaskReminders() async {
    final now = DateTime.now();
    if (_lastRescheduleTime != null &&
        now.difference(_lastRescheduleTime!) < const Duration(seconds: 2)) {
      return;
    }
    _lastRescheduleTime = now;
    final notificationService = NotificationService();
    await notificationService.rescheduleScheduleReminders(
      _storage.getSchedules(),
    );
    await notificationService.rescheduleBreakdownTaskReminders(
      _storage.getTasks(),
    );

    final taskRepository = widget.taskRepository;
    if (taskRepository == null) return;
    final tasks = await taskRepository.getAll();
    await notificationService.rescheduleTaskReminders(tasks);
  }

  /// 监听 Supabase 登录状态：登录后才启动项目/分组同步
  void _setupProjectSyncOnAuth() {
    final client = sb.Supabase.instance.client;
    // 全量对账（projects/tasks/checklist/attachments），完成后刷新 UI
    Future<void> runSyncAll({bool forcePush = false}) async {
      await ProjectSyncService.instance.syncAll(forcePush: forcePush);
      await TaskSyncService.instance.syncAll();
      await ChecklistSyncService.instance.syncAll();
      await NodeTemplateSyncService.instance.syncAll();
      await AttachmentSyncService.instance.pullAll();
      _debounceLoadTasks();
      await _rescheduleTaskReminders();
    }

    void startIfReady() {
      if (client.auth.currentUser == null) return;
      final isFirstSync = !_projectSyncStarted;
      if (!_projectSyncStarted) {
        _projectSyncStarted = true;
        print('[Sync] 检测到登录用户 ${client.auth.currentUser?.id}，启动同步');
        AliyunPushService().onUserLoggedIn(); // 登录后上传推送 registrationId
        ProjectSyncService.instance.subscribe();
        TaskSyncService.instance.subscribe();
        ChecklistSyncService.instance.subscribe();
        NodeTemplateSyncService.instance.subscribe();
        AttachmentSyncService.instance.subscribe();
        SubscriptionService.instance.refresh();
        SubscriptionService.instance.startRealtime();
        // 远端变更（Realtime/拉取）后 debounce 触发 LoadTasks，让 sidebar 实时刷新
        _projectChangesSub ??= ProjectSyncService.instance.changes.listen((_) {
          _projectChangesDebounce?.cancel();
          _projectChangesDebounce = Timer(
            const Duration(milliseconds: 500),
            () {
              _debounceLoadTasks();
            },
          );
        });
        _taskChangesSub ??= TaskSyncService.instance.changes.listen((_) {
          _projectChangesDebounce?.cancel();
          _projectChangesDebounce = Timer(
            const Duration(milliseconds: 500),
            () {
              _debounceLoadTasks();
            },
          );
        });
        _nodeTemplateChangesSub ??= NodeTemplateSyncService.instance.changes
            .listen((_) {
              _debounceLoadTasks();
            });
      }
      // 桌面端每次登录都 forcePush（本地数据权威），移动端首次登录 forcePush
      runSyncAll(forcePush: isFirstSync || isDesktop);
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
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
              CreateSchedule(
                schedule: newSchedule.copyWith(syncStatus: 'synced'),
              ),
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
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
        await NotificationService().cancelReminderForSchedule(updated.id);
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
      body: ValueListenableBuilder<int>(
        valueListenable: _tabIndex,
        builder: (ctx, index, _) => IndexedStack(index: index, children: _pages),
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _tabIndex,
        builder: (ctx, index, _) => _BottomNavWidget(
          currentIndex: index,
          onTap: _onNavTap,
        ),
      ),
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: _tabIndex,
        builder: (ctx, index, _) => index == 0
            ? FloatingActionButton(
                onPressed: _createSchedule,
                elevation: 2,
                child: const Icon(Icons.add),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  void _jumpToMindMap(Task task) {
    _tabIndex.value = 1;
    _visibleTabIndex.value = 1;
    context.read<TaskNewBloc>().add(
      LoadTasks(
        projectIds: {task.projectId},
        filter: 'all',
        clearDateRange: true,
        focusTaskId: task.id,
        focusRequestToken: DateTime.now().microsecondsSinceEpoch,
      ),
    );
  }

  void _onNavTap(int index) {
    if (_tabIndex.value == index) return;
    _tabIndex.value = index;
    _visibleTabIndex.value = index;
  }
}

// ────────────────────────────────────────────────────────────
// Bottom navigation bar extracted as reusable widget
// ────────────────────────────────────────────────────────────

class _BottomNavWidget extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavWidget({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
          currentIndex: currentIndex,
          onTap: (index) {
            if (currentIndex == index) return;
            onTap(index);
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
    final isSelected = currentIndex == index;
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
  /// 监听父级可见 tab 索引，避免 widget 实例随 isVisible 变化重建
  final ValueNotifier<int> visibleTabIndex;
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
    required this.visibleTabIndex,
    required this.onCreateSchedule,
    required this.onRefresh,
    required this.onOpenTaskStatus,
    required this.onEditSchedule,
    required this.onDeleteSchedule,
    super.key,
  });

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  static const double _dayWidth = 72.0;
  double _hourWidth = 120.0;
  static const double _hourWidthMin = 60.0;
  static const double _hourWidthMax = 300.0;
  static const int _daysBefore = 180;
  static const int _daysAfter = 180;

  bool _visible = true;
  bool _loading = false;
  bool _modeSwitchGuard = false;
  // 节点类型多选过滤：'parent' | 'child' | 'multiday'，空集合 = 全部显示
  Set<String> _nodeTypeFilters = {};
  String _completionFilter = 'all';
  bool _homeFilterStateRestored = false;
  int _attachmentRefreshToken = 0;
  late final ScrollController _timelineController;
  String _timelineMode = 'hour'; // 'day' | 'hour'
  String _statsPeriod = 'day'; // 完成率统计周期: 'day'|'week'|'month'|'year'
  final Set<String> _filterProjectIds = {};
  String? get _filterProjectId =>
      _filterProjectIds.length == 1 ? _filterProjectIds.first : null;
  set _filterProjectId(String? value) {
    _filterProjectIds
      ..clear()
      ..addAll(value == null ? const [] : [value]);
  }

  Timer? _timelineScrollDebounce;
  Timer? _hourWidthSyncDebounce;
  double? _scaleStartHourWidth;
  // Combined timeline data
  List<_TimelineTask> _timelineTasks = [];
  List<_TimelineTask> _filteredTasks = [];
  Map<String, Project> _projectCache = {};
  final Map<String, List<ChecklistItem>> _checklistCache = {};
  final Map<String, List<Task>> _subtaskCache = {};
  final Map<String, Task?> _dbTaskCache = {};
  DateTime? _lastLoadTime; // BlocListener 节流
  bool _needsRefresh = false; // 后台发生数据变化时标记，切回首页时触发刷新
  String? _selectedTaskId;
  _TimelineTask? _selectedTask;
  String? _draggingTimelineTaskId;
  double _timelineDragRawDx = 0;
  double _timelineDragDx = 0;
  int _timelineDragHourShift = 0;
  Timer? _descriptionSaveDebounce;

  static const double _timelineDragHitWidth = 56;
  static const double _timelineDragHitHeight = 36;
  static const Duration _timelineDragDelay = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _timelineController = ScrollController()
      ..addListener(() {
        // 滚动时 debounce 触发高度重算
        _timelineScrollDebounce?.cancel();
        _timelineScrollDebounce = Timer(const Duration(milliseconds: 120), () {
          if (mounted) setState(() {});
        });
      });
    _visible = widget.visibleTabIndex.value == 0;
    widget.visibleTabIndex.addListener(_onVisibleTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _onVisibleTabChanged() {
    if (!mounted) return;
    final nowVisible = widget.visibleTabIndex.value == 0;
    if (_visible == nowVisible) return;
    setState(() => _visible = nowVisible);
    if (nowVisible && _needsRefresh) {
      _needsRefresh = false;
      _loadData();
    }
  }

  @override
  void dispose() {
    _timelineScrollDebounce?.cancel();
    _hourWidthSyncDebounce?.cancel();
    _descriptionSaveDebounce?.cancel();
    widget.visibleTabIndex.removeListener(_onVisibleTabChanged);
    _timelineController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_loading) return;
    // 首页不可见时跳过全量加载，避免后台 tab 触发卡顿
    if (!_visible) {
      _loading = false;
      return;
    }
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
    final excludedProjectIds = widget.storage.excludedProjectIds;
    dbTasks = dbTasks
        .where((task) => !excludedProjectIds.contains(task.projectId))
        .toList();

    // Build timeline items
    final timelineItems = <_TimelineTask>[];
    final now = DateTime.now();

    // From storage (TaskBreakdown)
    for (final t in storageTasks) {
      final date = t.startDate ?? t.endDate ?? now;
      timelineItems.add(
        _TimelineTask(
          id: t.id,
          title: t.title,
          description: t.description,
          date: date,
          isCompleted: t.status == 'completed',
          priority: t.priority,
          source: 'storage',
          projectId: null,
          taskId: t.id,
        ),
      );
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
      timelineItems.add(
        _TimelineTask(
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
        ),
      );
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

    // 恢复持久化的首页项目筛选
    if (_filterProjectIds.isEmpty) {
      final saved = widget.storage.getHomeFilterState();
      if (saved != null) {
        _filterProjectIds.addAll(
          (saved['projectIds'] as List<dynamic>? ?? []).cast<String>(),
        );
        _nodeTypeFilters.addAll(
          (saved['nodeTypes'] as List<dynamic>? ?? []).cast<String>(),
        );
        _completionFilter = saved['completion'] as String? ?? 'all';
      }
    }
    if (!_homeFilterStateRestored) {
      _homeFilterStateRestored = true;
      final cloudPrefs = await SupabaseService().fetchPreferences();
      final cloudHome = cloudPrefs?['homeFilters'];
      final cloudState = cloudHome is Map<String, dynamic>
          ? cloudHome
          : (cloudHome is Map ? Map<String, dynamic>.from(cloudHome) : null);
      if (cloudState != null) {
        _filterProjectIds
          ..clear()
          ..addAll(
            (cloudState['projectIds'] as List<dynamic>? ?? []).cast<String>(),
          );
        _nodeTypeFilters
          ..clear()
          ..addAll(
            (cloudState['nodeTypes'] as List<dynamic>? ?? []).cast<String>(),
          );
        _completionFilter = cloudState['completion'] as String? ?? 'all';
      }
      final cloudHourWidth = cloudPrefs?['timelineHourWidth'];
      if (cloudHourWidth is num) {
        _hourWidth = cloudHourWidth.toDouble().clamp(_hourWidthMin, _hourWidthMax);
      }
    }

    _applyProjectFilter();
    _loading = false;

    // Preserve previous selection if task still exists
    if (_selectedTaskId != null) {
      final sameTask = _timelineTasks
          .where((t) => t.id == _selectedTaskId)
          .firstOrNull;
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
      _processPendingNotificationTask();
      _scrollToNow(animated: false);
    });
  }

  /// 消费通知点击留下的待定位任务 ID，定位到时间轴并选中。
  void _processPendingNotificationTask() {
    final taskId = NotificationService.pendingTaskId;
    if (taskId == null) return;
    NotificationService.pendingTaskId = null;

    if (taskId == 'overdue_navigate') {
      _navigateToFirstOverdueTask();
      return;
    }

    _TimelineTask? task;
    for (final t in _timelineTasks) {
      if (t.id == taskId || t.taskId == taskId) {
        task = t;
        break;
      }
    }
    if (task != null) {
      _selectTask(task);
      _scrollToTask(task);
    }
  }

  void _navigateToFirstOverdueTask() {
    final now = DateTime.now();
    final overdueTasks = _timelineTasks
        .where(
          (t) =>
              !t.isCompleted &&
              t.endDate != null &&
              t.endDate!.isBefore(now),
        )
        .toList();
    if (overdueTasks.isEmpty) return;
    overdueTasks.sort((a, b) => a.date.compareTo(b.date));
    final earliest = overdueTasks.first;
    _selectTask(earliest);
    _scrollToTask(earliest);
  }

  Set<String> get _parentIds =>
      _timelineTasks.map((t) => t.parentId).whereType<String>().toSet();

  bool _isParentNode(_TimelineTask t) => _parentIds.contains(t.id);
  bool _isChildNode(_TimelineTask t) => t.parentId != null;
  bool _isMultiDayNode(_TimelineTask t) {
    if (t.endDate == null) return false;
    final s = t.date;
    final e = t.endDate!;
    return !(s.year == e.year && s.month == e.month && s.day == e.day);
  }

  List<_TimelineTask> get _displayTasks {
    if (_nodeTypeFilters.isEmpty) return _filteredTasks;
    return _filteredTasks.where((t) {
      if (_nodeTypeFilters.contains('parent') && _isParentNode(t)) return true;
      if (_nodeTypeFilters.contains('child') && _isChildNode(t)) return true;
      if (_nodeTypeFilters.contains('multiday') && _isMultiDayNode(t))
        return true;
      if (_nodeTypeFilters.contains('singleday') && !_isMultiDayNode(t))
        return true;
      return false;
    }).toList();
  }

  void _applyProjectFilter() {
    if (_filterProjectIds.isEmpty) {
      _filteredTasks = List.from(_timelineTasks);
    } else {
      _filteredTasks = _timelineTasks
          .where(
            (t) =>
                t.projectId != null && _filterProjectIds.contains(t.projectId),
          )
          .toList();
    }
    if (_completionFilter == 'pending') {
      _filteredTasks = _filteredTasks.where((t) => !t.isCompleted).toList();
    } else if (_completionFilter == 'completed') {
      _filteredTasks = _filteredTasks.where((t) => t.isCompleted).toList();
    }
    if (_selectedTaskId != null &&
        !_filteredTasks.any((task) => task.id == _selectedTaskId)) {
      _selectedTask = _nearestTask(_filteredTasks);
      _selectedTaskId = _selectedTask?.id;
    }
    if (_selectedTaskId == null && _selectedTask == null) {
      _selectedTask = _nearestTask(_filteredTasks);
      _selectedTaskId = _selectedTask?.id;
    }
  }

  Future<void> _persistHomeFilterState() async {
    final data = {
      'projectIds': _filterProjectIds.toList()..sort(),
      'nodeTypes': _nodeTypeFilters.toList()..sort(),
      'completion': _completionFilter,
    };
    await widget.storage.saveHomeFilterState(data);
    await SupabaseService().syncPreferences({'homeFilters': data});
  }

  void _syncHourWidth() {
    _hourWidthSyncDebounce?.cancel();
    _hourWidthSyncDebounce = Timer(const Duration(milliseconds: 800), () {
      SupabaseService().syncPreferences({'timelineHourWidth': _hourWidth});
    });
  }

  _TimelineTask? _nearestTask(List<_TimelineTask> tasks) {
    if (tasks.isEmpty) return null;
    final now = DateTime.now();
    final sorted = List<_TimelineTask>.from(tasks)
      ..sort(
        (a, b) => a.date
            .difference(now)
            .abs()
            .compareTo(b.date.difference(now).abs()),
      );
    return sorted.first;
  }

  void _scrollToTask(_TimelineTask task) {
    if (!_timelineController.hasClients) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    double target;

    if (_timelineMode == 'hour') {
      if (!_isSameDayDate(task.date, today)) {
        // Task not today - jump to midday default
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

  void _scrollToNow({bool animated = true}) {
    if (!_timelineController.hasClients) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final midScreen = MediaQuery.of(context).size.width / 2;
    double target;
    if (_timelineMode == 'hour') {
      target = _hourTimelineOffset(now) - midScreen + _hourWidth / 2;
    } else {
      final baseDate = today.subtract(Duration(days: _daysBefore));
      final todayOffset = now.difference(baseDate).inDays * _dayWidth;
      target = todayOffset - midScreen + _dayWidth / 2;
    }
    final maxScroll = _timelineController.position.maxScrollExtent;
    final offset = target.clamp(0.0, maxScroll).toDouble();
    if (animated) {
      _timelineController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _timelineController.jumpTo(offset);
    }
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
      case 5:
        return 'P0';
      case 3:
        return 'P1';
      case 1:
        return 'P2';
      default:
        return 'P3';
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
      case 'P0':
        return '紧急';
      case 'P1':
        return '重要';
      case 'P2':
        return '普通';
      case 'P3':
        return '低';
      default:
        if (priority == '5') return '紧急';
        if (priority == '3') return '重要';
        if (priority == '1') return '普通';
        return '低';
    }
  }

  Widget _buildParentBanner(String parentId) {
    final parentTask = _timelineTasks
        .where((t) => t.taskId == parentId)
        .firstOrNull;

    // Also try to load from subtask cache - parent might not be in timeline
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
              color: hasParent ? AppTheme.primaryColor : AppTheme.textHint,
            ),
            const SizedBox(width: 6),
            Text(
              hasParent ? parentTitle : '父任务未在时间轴中',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: hasParent ? AppTheme.primaryColor : AppTheme.textHint,
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
        if (state is TaskNewError && state.isQuotaExceeded && mounted) {
          UpgradeDialog.show(context, message: state.message);
          context.read<TaskNewBloc>().add(LoadTasks());
          return;
        }
        if (state is TaskNewLoaded && !_loading && mounted) {
          if (!_visible) {
            _needsRefresh = true;
            return;
          }
          final now = DateTime.now();
          if (_lastLoadTime != null &&
              now.difference(_lastLoadTime!) < const Duration(seconds: 2)) {
            return;
          }
          _lastLoadTime = now;
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
          _displayTasks.isNotEmpty
              ? (_filterProjectIds.isNotEmpty
                    ? '筛选出 ${_displayTasks.length} 个任务'
                    : '时间轴上有 ${_displayTasks.length} 个任务节点')
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

    final todayCount = _filteredTasks
        .where((t) => _isSameDayDate(t.date, today))
        .length;

    final (start, end) = _periodRange(_statsPeriod);
    final inPeriod = _filteredTasks
        .where((t) => !t.date.isBefore(start) && t.date.isBefore(end))
        .toList();
    final completedCount = inPeriod.where((t) => t.isCompleted).length;

    final totalOverdue = _filteredTasks
        .where((t) => !t.isCompleted && t.endDate != null && t.endDate!.isBefore(now))
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
              '$totalOverdue',
              totalOverdue > 0 ? AppTheme.error : AppTheme.textPrimary,
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
          Text(label, style: TextStyle(color: AppTheme.textHint, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _compactDivider() =>
      Container(width: 0.5, height: 28, color: AppTheme.borderSubtle);

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
    final todayCount = _filteredTasks
        .where((t) => _isSameDayDate(t.date, today))
        .length;
    final overdueByDay = _filteredTasks
        .where((t) => !t.isCompleted && t.endDate != null && t.endDate!.isBefore(today))
        .length;
    final overdueByHour = _filteredTasks
        .where((t) => !t.isCompleted && t.endDate != null && _isSameDayDate(t.endDate!, today) && t.endDate!.isBefore(now))
        .length;
    final totalOverdue = overdueByDay + overdueByHour;

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
                    width: 40,
                    height: 4,
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
                        label: '今日任务',
                        value: '$todayCount',
                        valueColor: AppTheme.textPrimary,
                      ),
                      _buildStatItem(
                        label: '完成率',
                        value: '$completedCount/${inPeriod.length}',
                        valueColor: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: overdueByDay > 0
                            ? () {
                                Navigator.pop(ctx);
                                _showOverdueSheet(mode: 'day');
                              }
                            : null,
                        child: _buildStatItem(
                          label: '逾期(天)',
                          value: '$overdueByDay',
                          valueColor: overdueByDay > 0
                              ? AppTheme.error
                              : AppTheme.textPrimary,
                          showChevron: overdueByDay > 0,
                        ),
                      ),
                      GestureDetector(
                        onTap: overdueByHour > 0
                            ? () {
                                Navigator.pop(ctx);
                                _showOverdueSheet(mode: 'hour');
                              }
                            : null,
                        child: _buildStatItem(
                          label: '逾期(小时)',
                          value: '$overdueByHour',
                          valueColor: overdueByHour > 0
                              ? AppTheme.warning
                              : AppTheme.textPrimary,
                          showChevron: overdueByHour > 0,
                        ),
                      ),
                      GestureDetector(
                        onTap: totalOverdue > 0
                            ? () {
                                Navigator.pop(ctx);
                                _showOverdueSheet();
                              }
                            : null,
                        child: _buildStatItem(
                          label: '总逾期',
                          value: '$totalOverdue',
                          valueColor: totalOverdue > 0
                              ? AppTheme.error
                              : AppTheme.textPrimary,
                          showChevron: totalOverdue > 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ['日', '周', '月', '年'].map((label) {
                      final p = label == '日'
                          ? 'day'
                          : label == '周'
                          ? 'week'
                          : label == '月'
                          ? 'month'
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
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.primaryColor.withValues(
                                      alpha: 0.15,
                                    )
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

  void _showOverdueSheet({String mode = 'total'}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<_TimelineTask> overdue;
    String title;
    switch (mode) {
      case 'day':
        overdue = _filteredTasks
            .where((t) => !t.isCompleted && t.endDate != null && t.endDate!.isBefore(today))
            .toList();
        title = '逾期任务-天';
        break;
      case 'hour':
        overdue = _filteredTasks
            .where((t) => !t.isCompleted && t.endDate != null && _isSameDayDate(t.endDate!, today) && t.endDate!.isBefore(now))
            .toList();
        title = '逾期任务-小时';
        break;
      case 'total':
      default:
        overdue = _filteredTasks
            .where((t) => !t.isCompleted && t.endDate != null && t.endDate!.isBefore(now))
            .toList();
        title = '逾期任务';
        break;
    }
    overdue.sort((a, b) => a.date.compareTo(b.date));
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
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$title (${overdue.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppTheme.textHint,
                    ),
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
    final selectedLabel = _filterProjectIds.isEmpty
        ? '全部项目'
        : _filterProjectIds.length == 1
        ? projects.where((p) => p.id == _filterProjectId).firstOrNull?.name ??
              '1 个项目'
        : '${_filterProjectIds.length} 个项目';

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
            child: TextButton(
              onPressed: () => _showProjectFilterDialog(projects),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                selectedLabel,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showProjectFilterDialog(projects),
            child: Icon(
              Icons.checklist_rtl,
              size: 16,
              color: _filterProjectIds.length > 1
                  ? AppTheme.primaryColor
                  : AppTheme.textHint,
            ),
          ),
          if (_filterProjectIds.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  _filterProjectId = null;
                  _applyProjectFilter();
                });
                _persistHomeFilterState();
              },
              child: Icon(Icons.close, size: 16, color: AppTheme.textHint),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  Future<void> _showProjectFilterDialog(List<Project> projects) async {
    final taskState = context.read<TaskNewBloc>().state;
    final groups = taskState is TaskNewLoaded
        ? taskState.groups
        : <ProjectGroup>[];
    final draft = Set<String>.from(_filterProjectIds);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('筛选项目'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: buildProjectPickerContent(
                projects: projects,
                groups: groups,
                draft: draft,
                setDialogState: setDialogState,
                extraHeader: CheckboxListTile(
                  value: draft.isEmpty,
                  title: const Text('全部项目'),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (_) => setDialogState(draft.clear),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, draft),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _filterProjectIds
        ..clear()
        ..addAll(result);
      _applyProjectFilter();
    });
    _persistHomeFilterState();
  }

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

  /// 任务按同一时间轴坐标分配 lane，长任务画为跨列条。
  double _timelineHeight() {
    final laneCount = _timelineRenderItems().fold<int>(
      0,
      (maxLane, item) => max(maxLane, item.lane + 1),
    );
    if (laneCount <= 1) return 80.0;
    final h = 80.0 + (laneCount.clamp(2, 8) - 1) * 26.0;
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
      itemBuilder = (context, index) =>
          _buildHourColumn(index, showTasks: false);
    } else {
      itemCount = totalDays;
      itemExtent = _dayWidth;
      itemBuilder = (context, index) {
        final dayDate = baseDate.add(Duration(days: index));
        final isToday = _isSameDayDate(dayDate, today);
        return _buildDayColumn(dayDate, isToday, index, showTasks: false);
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
                  child: GestureDetector(
                    onScaleStart: _timelineMode == 'hour'
                        ? (_) => _scaleStartHourWidth = _hourWidth
                        : null,
                    onScaleUpdate: _timelineMode == 'hour'
                        ? (details) {
                            if (details.pointerCount < 2) return;
                            setState(() {
                              _hourWidth =
                                  ((_scaleStartHourWidth ?? _hourWidth) *
                                          details.scale)
                                      .clamp(_hourWidthMin, _hourWidthMax);
                            });
                            _syncHourWidth();
                          }
                        : null,
                    child: LayoutBuilder(
                      builder: (ctx, _) {
                        final timelineHeight = _timelineHeight();
                        final timelineWidth = itemCount * itemExtent;
                        return SizedBox(
                          height: timelineHeight,
                          child: SingleChildScrollView(
                            controller: _timelineController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: timelineWidth,
                              height: timelineHeight,
                              child: Stack(
                                children: [
                                  for (var i = 0; i < itemCount; i++)
                                    Positioned(
                                      left: i * itemExtent,
                                      top: 0,
                                      width: itemExtent,
                                      height: timelineHeight,
                                      child: itemBuilder(ctx, i),
                                    ),
                                  ..._buildTimelineTaskOverlays(),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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
          _buildNodeTypeFilterChip(),
          const SizedBox(width: 4),
          _buildCompletionFilterChip(),
          const SizedBox(width: 4),
          _buildZoomButton(Icons.my_location_rounded, () => _scrollToNow()),
          const SizedBox(width: 4),
          _buildModeChip('小时', 'hour'),
          const SizedBox(width: 4),
          _buildModeChip('天', 'day'),
          if (_timelineMode == 'hour') ...[
            const SizedBox(width: 6),
            _buildZoomButton(Icons.remove, () {
              setState(() {
                _hourWidth = (_hourWidth - 20).clamp(
                  _hourWidthMin,
                  _hourWidthMax,
                );
              });
              _syncHourWidth();
            }),
            _buildZoomButton(Icons.add, () {
              setState(() {
                _hourWidth = (_hourWidth + 20).clamp(
                  _hourWidthMin,
                  _hourWidthMax,
                );
              });
              _syncHourWidth();
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppTheme.bgInput,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildNodeTypeFilterChip() {
    final hasFilter = _nodeTypeFilters.isNotEmpty;
    final labelMap = {
      'parent': '父节点',
      'child': '子节点',
      'multiday': '跨天',
      'singleday': '非跨天',
    };
    final label = hasFilter
        ? _nodeTypeFilters.map((k) => labelMap[k] ?? k).join('·')
        : '全部';

    return PopupMenuButton<String>(
      tooltip: '节点类型筛选',
      offset: const Offset(0, 28),
      onSelected: (value) {
        setState(() {
          if (value == 'all') {
            _nodeTypeFilters.clear();
          } else {
            if (_nodeTypeFilters.contains(value)) {
              _nodeTypeFilters.remove(value);
            } else {
              _nodeTypeFilters.add(value);
            }
          }
        });
        _persistHomeFilterState();
      },
      itemBuilder: (_) {
        Widget itemRow(String key, String text) {
          final checked = key == 'all'
              ? _nodeTypeFilters.isEmpty
              : _nodeTypeFilters.contains(key);
          return Row(
            children: [
              Icon(
                checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 16,
                color: checked ? AppTheme.primaryColor : AppTheme.textHint,
              ),
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(fontSize: 13)),
            ],
          );
        }

        return [
          PopupMenuItem(value: 'all', height: 36, child: itemRow('all', '全部')),
          PopupMenuItem(
            value: 'parent',
            height: 36,
            child: itemRow('parent', '父节点'),
          ),
          PopupMenuItem(
            value: 'child',
            height: 36,
            child: itemRow('child', '子节点'),
          ),
          PopupMenuItem(
            value: 'multiday',
            height: 36,
            child: itemRow('multiday', '跨天任务'),
          ),
          PopupMenuItem(
            value: 'singleday',
            height: 36,
            child: itemRow('singleday', '非跨天任务'),
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: hasFilter
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasFilter ? AppTheme.primaryColor : AppTheme.borderSubtle,
            width: hasFilter ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasFilter ? FontWeight.w600 : FontWeight.w400,
                color: hasFilter
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: hasFilter ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionFilterChip() {
    final labels = {'all': '全部', 'pending': '未完成', 'completed': '已完成'};
    final hasFilter = _completionFilter != 'all';
    return PopupMenuButton<String>(
      tooltip: '完成状态筛选',
      offset: const Offset(0, 28),
      onSelected: (value) {
        setState(() {
          _completionFilter = value;
          _applyProjectFilter();
        });
        _persistHomeFilterState();
      },
      itemBuilder: (_) => [
        for (final entry in labels.entries)
          PopupMenuItem(
            value: entry.key,
            height: 36,
            child: Row(
              children: [
                Icon(
                  _completionFilter == entry.key
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: _completionFilter == entry.key
                      ? AppTheme.primaryColor
                      : AppTheme.textHint,
                ),
                const SizedBox(width: 8),
                Text(entry.value, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: hasFilter
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasFilter ? AppTheme.primaryColor : AppTheme.borderSubtle,
            width: hasFilter ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              labels[_completionFilter] ?? '全部',
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasFilter ? FontWeight.w600 : FontWeight.w400,
                color: hasFilter
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: hasFilter ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
          ],
        ),
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
          _scrollToNow();
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

  List<_TimelineRenderItem> _timelineRenderItems() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final baseDate = today.subtract(Duration(days: _daysBefore));
    final totalDays = _daysBefore + _daysAfter;
    final rawItems = <_TimelineRenderItem>[];

    for (final task in _displayTasks) {
      final item = _timelinePositionForTask(task, today, baseDate, totalDays);
      if (item != null) rawItems.add(item);
    }

    rawItems.sort((a, b) {
      final leftCmp = a.left.compareTo(b.left);
      if (leftCmp != 0) return leftCmp;
      return a.task.title.compareTo(b.task.title);
    });

    final laneEnds = <double>[];
    final result = <_TimelineRenderItem>[];
    for (final item in rawItems) {
      var lane = 0;
      while (lane < laneEnds.length && laneEnds[lane] > item.left) {
        lane++;
      }
      if (lane == laneEnds.length) {
        laneEnds.add(item.left + item.width + 6);
      } else {
        laneEnds[lane] = item.left + item.width + 6;
      }
      result.add(item.withLane(lane));
    }
    return result;
  }

  _TimelineRenderItem? _timelinePositionForTask(
    _TimelineTask task,
    DateTime today,
    DateTime baseDate,
    int totalDays,
  ) {
    if (_timelineMode == 'hour') {
      if (!_isSameDayDate(task.date, today)) return null;
      final totalWidth = 24 * _hourWidth;
      final startOffset = _hourTimelineOffset(task.date).clamp(0.0, totalWidth);
      final end = task.endDate;
      if (end != null && _isSameDayDate(end, today) && end.isAfter(task.date)) {
        final endOffset = _hourTimelineOffset(
          end,
        ).clamp(startOffset, totalWidth);
        final startSlotEnd = (task.date.hour + 1) * _hourWidth;
        if (endOffset > startSlotEnd + 1) {
          final left = startOffset.clamp(4.0, totalWidth - 36.0);
          return _TimelineRenderItem(
            task: task,
            left: left,
            width: max(36.0, endOffset - left - 4),
            isBar: true,
          );
        }
      }

      final dotLeft = (task.date.hour * _hourWidth + _hourWidth / 2 - 20).clamp(
        0.0,
        totalWidth - 40.0,
      );
      return _TimelineRenderItem(
        task: task,
        left: dotLeft,
        width: 40,
        isBar: false,
      );
    }

    final rangeEnd = baseDate.add(Duration(days: totalDays));
    final startDay = DateTime(task.date.year, task.date.month, task.date.day);
    final end = task.endDate;
    if (end != null && _isMultiDayNode(task)) {
      final endDay = DateTime(end.year, end.month, end.day);
      if (endDay.isBefore(baseDate) || !startDay.isBefore(rangeEnd)) {
        return null;
      }
      final startIndex = max(0, startDay.difference(baseDate).inDays);
      final endIndex = min(totalDays - 1, endDay.difference(baseDate).inDays);
      if (endIndex < startIndex) return null;
      return _TimelineRenderItem(
        task: task,
        left: startIndex * _dayWidth + 6,
        width: max(36.0, (endIndex - startIndex + 1) * _dayWidth - 12),
        isBar: true,
      );
    }

    final dayIndex = startDay.difference(baseDate).inDays;
    if (dayIndex < 0 || dayIndex >= totalDays) return null;
    return _TimelineRenderItem(
      task: task,
      left: dayIndex * _dayWidth + (_dayWidth - 40) / 2,
      width: 40,
      isBar: false,
    );
  }

  double _hourTimelineOffset(DateTime date) {
    return (date.hour + date.minute / 60 + date.second / 3600) * _hourWidth;
  }

  List<Widget> _buildTimelineTaskOverlays() {
    return _timelineRenderItems().map(_buildTimelineTaskOverlay).toList();
  }

  Widget _buildTimelineTaskOverlay(_TimelineRenderItem item) {
    final task = item.task;
    final isSelected = task.id == _selectedTaskId;
    final canDrag = _canDragHourTimelineTask(task);
    final isDragging = task.id == _draggingTimelineTaskId;
    final top = 32.0 + item.lane * 26.0;
    final visualWidth = item.isBar ? item.width : 40.0;
    final visualHeight = item.isBar ? 24.0 : 30.0;
    final hitWidth = item.isBar
        ? max(item.width, _timelineDragHitWidth)
        : _timelineDragHitWidth;
    final hitHeight = max(visualHeight, _timelineDragHitHeight);
    final left = item.left - (hitWidth - visualWidth) / 2;
    final hitTop = max(0.0, top - (hitHeight - visualHeight) / 2);
    final visual = item.isBar
        ? SizedBox(
            width: item.width,
            height: visualHeight,
            child: _buildTimelineArrowBar(task, isSelected, isDragging),
          )
        : SizedBox(
            width: visualWidth,
            height: visualHeight,
            child: _buildTimelinePoint(task, isSelected, isDragging),
          );

    return Positioned(
      left: left,
      top: hitTop,
      width: hitWidth,
      height: hitHeight,
      child: Transform.translate(
        offset: Offset(isDragging ? _timelineDragDx : 0, 0),
        child: _buildTimelineDragSurface(
          task: task,
          canDrag: canDrag,
          child: Center(child: visual),
        ),
      ),
    );
  }

  Widget _buildTimelinePoint(
    _TimelineTask task,
    bool isSelected,
    bool isDragging,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: isDragging
              ? Duration.zero
              : const Duration(milliseconds: 200),
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
            boxShadow: isSelected || isDragging
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(
                        alpha: isDragging ? 0.55 : 0.4,
                      ),
                      blurRadius: isDragging ? 8 : 4,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 40,
          child: Text(
            isDragging && _timelineDragHourShift != 0
                ? '${_timelineDragHourShift > 0 ? '+' : ''}$_timelineDragHourShift h'
                : task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8, color: AppTheme.textHint),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineArrowBar(
    _TimelineTask task,
    bool isSelected,
    bool isDragging,
  ) {
    final baseColor = task.isCompleted
        ? AppTheme.textHint.withValues(alpha: 0.55)
        : _priorityColor(task.priority);
    return CustomPaint(
      painter: _TimelineArrowPainter(
        color: baseColor,
        borderColor: isSelected ? AppTheme.primaryColor : baseColor,
        selected: isSelected || isDragging,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 18),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            isDragging && _timelineDragHourShift != 0
                ? '${_timelineDragHourShift > 0 ? '+' : ''}$_timelineDragHourShift h'
                : task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: baseColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineDragSurface({
    required _TimelineTask task,
    required bool canDrag,
    required Widget child,
  }) {
    final tapSurface = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectTask(task),
      onSecondaryTap: () => _showDeleteContextMenu(context, task),
      child: child,
    );

    if (!canDrag) return tapSurface;

    return LongPressDraggable<String>(
      data: task.id,
      axis: Axis.horizontal,
      delay: _timelineDragDelay,
      hapticFeedbackOnStart: false,
      hitTestBehavior: HitTestBehavior.opaque,
      allowedButtonsFilter: (buttons) => buttons == kPrimaryButton,
      maxSimultaneousDrags: 1,
      feedback: const SizedBox.shrink(),
      childWhenDragging: tapSurface,
      onDragStarted: () => _startTimelineHourDrag(task),
      onDragUpdate: (details) =>
          _updateTimelineHourDrag(task, details.delta.dx),
      onDragEnd: (_) => _endTimelineHourDrag(task),
      onDraggableCanceled: (_, _) => _endTimelineHourDrag(task),
      child: tapSurface,
    );
  }

  bool _canDragHourTimelineTask(_TimelineTask task) {
    return _timelineMode == 'hour' &&
        task.source == 'db' &&
        task.parentId != null &&
        task.endDate != null &&
        !_isMultiDayNode(task);
  }

  int _clampedHourShift(_TimelineTask task, double rawDx) {
    var shift = (rawDx / _hourWidth).round();
    bool staysInOriginalDay(int hourShift) {
      final newStart = task.date.add(Duration(hours: hourShift));
      final newEnd = task.endDate!.add(Duration(hours: hourShift));
      return _isSameDayDate(newStart, task.date) &&
          _isSameDayDate(newEnd, task.date);
    }

    while (shift > 0 && !staysInOriginalDay(shift)) {
      shift--;
    }
    while (shift < 0 && !staysInOriginalDay(shift)) {
      shift++;
    }
    return shift;
  }

  void _startTimelineHourDrag(_TimelineTask task) {
    if (!_canDragHourTimelineTask(task)) return;
    setState(() {
      _draggingTimelineTaskId = task.id;
      _timelineDragRawDx = 0;
      _timelineDragDx = 0;
      _timelineDragHourShift = 0;
    });
  }

  void _updateTimelineHourDrag(_TimelineTask task, double deltaDx) {
    if (_draggingTimelineTaskId != task.id || !_canDragHourTimelineTask(task)) {
      return;
    }
    _timelineDragRawDx += deltaDx;
    final shift = _clampedHourShift(task, _timelineDragRawDx);
    setState(() {
      _timelineDragDx = shift * _hourWidth;
      _timelineDragHourShift = shift;
    });
  }

  void _endTimelineHourDrag(_TimelineTask task) {
    if (_draggingTimelineTaskId != task.id) return;
    final shift = _timelineDragHourShift;
    setState(() {
      _draggingTimelineTaskId = null;
      _timelineDragRawDx = 0;
      _timelineDragDx = 0;
      _timelineDragHourShift = 0;
    });
    if (shift == 0 || !_canDragHourTimelineTask(task)) return;

    final newStart = task.date.add(Duration(hours: shift));
    final newEnd = task.endDate!.add(Duration(hours: shift));
    context.read<TaskNewBloc>().add(
      UpdateTask(
        id: task.taskId,
        startDate: newStart.millisecondsSinceEpoch,
        dueDate: newEnd.millisecondsSinceEpoch,
      ),
    );
  }

  Widget _buildDayColumn(
    DateTime dayDate,
    bool isToday,
    int dayIndex, {
    bool showTasks = true,
  }) {
    // Find tasks for this day
    final dayTasks = showTasks
        ? _displayTasks.where((t) {
            return t.date.year == dayDate.year &&
                t.date.month == dayDate.month &&
                t.date.day == dayDate.day;
          }).toList()
        : const <_TimelineTask>[];

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
                child: !showTasks || dayTasks.isEmpty
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

  Widget _buildHourColumn(int hour, {bool showTasks = true}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hourDateTime = DateTime(today.year, today.month, today.day, hour);

    // Find tasks for this hour
    final hourTasks = showTasks
        ? _displayTasks.where((t) {
            return _isSameDayDate(t.date, today) && t.date.hour == hour;
          }).toList()
        : const <_TimelineTask>[];

    final isCurrentHour = now.hour == hour && _isSameDayDate(now, today);
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
                  fontWeight: isCurrentHour ? FontWeight.w700 : FontWeight.w500,
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
                child: !showTasks || hourTasks.isEmpty
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
    return _containWheelScroll(
      SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: tasks.map((task) {
            final isSelected = task.id == _selectedTaskId;
            final canDrag = _canDragHourTimelineTask(task);
            final isDragging = task.id == _draggingTimelineTaskId;
            final point = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: isDragging
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
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
                    boxShadow: isSelected || isDragging
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: isDragging ? 0.55 : 0.4,
                              ),
                              blurRadius: isDragging ? 8 : 4,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 40,
                  child: Text(
                    isDragging && _timelineDragHourShift != 0
                        ? '${_timelineDragHourShift > 0 ? '+' : ''}$_timelineDragHourShift h'
                        : task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 8, color: AppTheme.textHint),
                  ),
                ),
              ],
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Transform.translate(
                offset: Offset(isDragging ? _timelineDragDx : 0, 0),
                child: SizedBox(
                  width: _timelineDragHitWidth,
                  height: _timelineDragHitHeight,
                  child: _buildTimelineDragSurface(
                    task: task,
                    canDrag: canDrag,
                    child: Center(child: point),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _containWheelScroll(Widget child) {
    var active = false;
    return StatefulBuilder(
      builder: (context, setLocalState) => MouseRegion(
        onExit: (_) => setLocalState(() => active = false),
        child: Listener(
          onPointerDown: (_) => setLocalState(() => active = true),
          onPointerSignal: (event) {
            if (active && event is PointerScrollEvent) {
              GestureBinding.instance.pointerSignalResolver.register(
                event,
                (_) {},
              );
            }
          },
          child: child,
        ),
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
          if (task.parentId != null) _buildParentBanner(task.parentId!),
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
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
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
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _quickEditDate(task, isStart: true),
                      child: Text(
                        _formatTaskDate(task.date),
                        style: GoogleFonts.jetBrainsMonoTextTheme().bodySmall
                            ?.copyWith(
                              color: AppTheme.primaryColor,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                              decorationColor: AppTheme.primaryColor.withValues(
                                alpha: 0.3,
                              ),
                            ),
                      ),
                    ),
                    if (task.endDate != null) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 10,
                          color: AppTheme.textHint,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _quickEditDate(task, isStart: false),
                        child: Text(
                          _formatTaskDate(task.endDate!),
                          style: GoogleFonts.jetBrainsMonoTextTheme().bodySmall
                              ?.copyWith(
                                color: AppTheme.primaryColor,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                                decorationColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.3),
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _quickCyclePriority(task),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _priorityColor(
                            task.priority,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _priorityColor(
                              task.priority,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
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
                // Description（固定高度可滚动；超过 1000 字截断，显示"展开全文"）
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDescriptionBox(task),
                ],
                if (task.source == 'db') ...[
                  const SizedBox(height: 12),
                  DropTarget(
                    onDragDone: (detail) =>
                        _handleDroppedHomeImages(detail, task.taskId),
                    child: AttachmentImageStrip(
                      key: ValueKey(
                        'home-images-${task.taskId}-$_attachmentRefreshToken',
                      ),
                      taskId: task.taskId,
                      maxHeight: 160,
                      showDeleteButton: true,
                      showCopyButton: true,
                    ),
                  ),
                ],
                // Resource row: subtask tree + attachment + checklist (DB only)
                _buildResourceRow(task),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionBox(_TimelineTask task) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            () => _pasteHomeDescriptionImage(task),
      },
      child: DropTarget(
        onDragDone: (detail) =>
            _handleDroppedHomeDescriptionImages(detail, task.taskId),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            color: AppTheme.bgInput,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: TextFormField(
              key: ValueKey('home_description_${task.id}'),
              initialValue: task.description ?? '',
              minLines: 4,
              maxLines: 8,
              onChanged: (value) => _queueDescriptionSave(task, value),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _queueDescriptionSave(_TimelineTask task, String value) {
    _descriptionSaveDebounce?.cancel();
    _descriptionSaveDebounce = Timer(
      const Duration(milliseconds: 600),
      () => _saveDescription(task, value),
    );
  }

  Future<void> _pasteHomeDescriptionImage(_TimelineTask task) async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;
    final reader = await clipboard.read();
    if (!reader.canProvide(Formats.png)) {
      if (mounted) showAppSnackBar(context, '剪贴板中没有可粘贴的图片');
      return;
    }

    final imageBytes = await _readClipboardPng(reader);
    if (imageBytes == null || imageBytes.isEmpty) {
      if (mounted) showAppSnackBar(context, '读取剪贴板图片失败');
      return;
    }

    await TaskAttachmentService().saveImageBytes(
      task.taskId,
      fileName: 'pasted_${DateTime.now().millisecondsSinceEpoch}.png',
      bytes: imageBytes,
    );
    if (!mounted) return;
    setState(() => _attachmentRefreshToken++);
    showAppSnackBar(context, '图片已添加');
  }

  Future<Uint8List?> _readClipboardPng(ClipboardReader reader) {
    final completer = Completer<Uint8List?>();
    reader.getFile(
      Formats.png,
      (file) async {
        try {
          completer.complete(await file.readAll());
        } catch (_) {
          completer.complete(null);
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    return completer.future;
  }

  Future<void> _handleDroppedHomeDescriptionImages(
    DropDoneDetails detail,
    String taskId,
  ) async {
    var saved = 0;
    for (final file in detail.files) {
      final name = file.name.isNotEmpty ? file.name : file.path.split('/').last;
      if (!TaskAttachmentService.isImageFile(name, null)) continue;
      final bytes = await file.readAsBytes();
      await TaskAttachmentService().saveImageBytes(
        taskId,
        fileName: name,
        bytes: bytes,
      );
      saved++;
    }
    if (!mounted) return;
    if (saved == 0) {
      showAppSnackBar(context, '只支持拖入图片文件');
      return;
    }
    setState(() => _attachmentRefreshToken++);
    showAppSnackBar(context, '已添加 $saved 张图片');
  }

  Future<void> _saveDescription(_TimelineTask task, String value) async {
    final normalized = value.trimRight();
    if ((task.description ?? '') == normalized) return;

    if (task.source == 'db') {
      final repo = widget.taskRepository;
      if (repo == null) return;
      await repo.update(task.taskId, description: normalized);
    } else {
      final storageTask = widget.storage
          .getTasks()
          .where((t) => t.id == task.taskId)
          .firstOrNull;
      if (storageTask == null) return;
      await widget.storage.updateTask(
        storageTask.copyWith(description: normalized),
      );
    }

    final updated = _TimelineTask(
      id: task.id,
      title: task.title,
      description: normalized,
      date: task.date,
      endDate: task.endDate,
      isCompleted: task.isCompleted,
      priority: task.priority,
      source: task.source,
      projectId: task.projectId,
      taskId: task.taskId,
      parentId: task.parentId,
    );
    final idx = _timelineTasks.indexWhere((t) => t.id == task.id);
    if (idx >= 0) _timelineTasks[idx] = updated;
    _applyProjectFilter();
    if (_selectedTaskId == task.id) _selectedTask = updated;
  }

  Future<void> _handleDroppedHomeImages(
    DropDoneDetails detail,
    String taskId,
  ) async {
    var saved = 0;
    for (final file in detail.files) {
      final name = file.name.isNotEmpty ? file.name : file.path.split('/').last;
      if (!TaskAttachmentService.isImageFile(name, null)) continue;
      final bytes = await file.readAsBytes();
      await TaskAttachmentService().saveImageBytes(
        taskId,
        fileName: name,
        bytes: bytes,
      );
      saved++;
    }
    if (!mounted) return;
    if (saved == 0) {
      showAppSnackBar(context, '只支持图片文件');
      return;
    }
    setState(() => _attachmentRefreshToken++);
  }

  Widget _buildProjectBadge(String projectId, _TimelineTask task) {
    final project = _projectCache[projectId]!;
    return GestureDetector(
      onTap: () => _quickChangeProject(task),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, size: 14, color: AppTheme.textSecondary),
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
              child: Text(
                '选择项目',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ...projects.map((p) {
              final color = Color(int.parse(p.color.replaceFirst('#', '0xFF')));
              return ListTile(
                leading: CircleAvatar(
                  radius: 10,
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
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

  Future<void> _homeEditChecklist(
    String itemId,
    String title,
    String taskId,
  ) async {
    await widget.checklistRepository?.update(itemId, title: title);
    await _loadChecklists(taskId);
  }

  Future<void> _homeAddChecklist((String, String) args) async {
    final (taskId, title) = args;
    await widget.checklistRepository?.create(taskId: taskId, title: title);
    await _loadChecklists(taskId);
  }

  Future<void> _homeSetObsidianUri(
    String itemId,
    String? uri,
    String taskId,
  ) async {
    await widget.checklistRepository?.setObsidianUri(itemId, uri);
    await _loadChecklists(taskId);
  }

  Widget _buildResourceRow(_TimelineTask task) {
    if (task.source != 'db') return const SizedBox.shrink();
    final taskId = task.taskId;
    final subtasks = _subtaskCache[taskId];
    if (subtasks == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadSubTasks(taskId),
      );
    }
    final hasSubtasks = subtasks?.isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Divider(color: AppTheme.borderSubtle, height: 1),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobileLayout = constraints.maxWidth < 640;
            final resourcePanels = <Widget>[
              if (widget.taskRepository != null) _buildAttachmentWidget(taskId),
              if (widget.checklistRepository != null)
                _buildChecklistWidget(task),
            ];

            if (isMobileLayout) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasSubtasks) ...[
                    _buildSubtaskTree(taskId),
                    const SizedBox(height: 10),
                  ],
                  for (var i = 0; i < resourcePanels.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    resourcePanels[i],
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasSubtasks) ...[
                  Expanded(child: _buildSubtaskTree(taskId)),
                  const SizedBox(width: 8),
                ],
                for (var i = 0; i < resourcePanels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: resourcePanels[i]),
                ],
              ],
            );
          },
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
    return _containWheelScroll(
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: SingleChildScrollView(child: AttachmentSection(task: dbTask)),
      ),
    );
  }

  Widget _buildChecklistWidget(_TimelineTask task) {
    final taskId = task.taskId;
    final items = _checklistCache[taskId] ?? [];
    if (_checklistCache[taskId] == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadChecklists(taskId),
      );
    }
    return _containWheelScroll(
      ChecklistSection(
        items: items,
        taskId: taskId,
        onToggle: (id) => _homeToggleChecklist(id, taskId),
        onDelete: (id) => _homeDeleteChecklist(id, taskId),
        onEdit: (id, title) => _homeEditChecklist(id, title, taskId),
        onAdd: _homeAddChecklist,
        onSetObsidianUri: (id, uri) => _homeSetObsidianUri(id, uri, taskId),
        onReorder: (orderedIds) => _homeReorderChecklist(orderedIds, taskId),
      ),
    );
  }

  Future<void> _homeReorderChecklist(
    List<String> orderedIds,
    String taskId,
  ) async {
    await widget.checklistRepository?.reorderItems(taskId, orderedIds);
    await _loadChecklists(taskId);
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
        Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 14,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              '子任务(${subtasks.length})',
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
          final tlTask = _timelineTasks
              .where((t) => t.taskId == st.id)
              .firstOrNull;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const SizedBox(width: 16),
                // 完成切换（只更新数据库，不触发任何 setState/导航）
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
                          completedTime: newStatus == 2
                              ? DateTime.now().millisecondsSinceEpoch
                              : st.completedTime,
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
                // 标题 - 点击导航到该子任务
                GestureDetector(
                  onTap: () {
                    if (tlTask != null) {
                      _selectTask(tlTask);
                    } else {
                      final now = DateTime.now();
                      final date = st.startDate != null
                          ? DateTime.fromMillisecondsSinceEpoch(st.startDate!)
                          : (st.dueDate != null
                                ? DateTime.fromMillisecondsSinceEpoch(
                                    st.dueDate!,
                                  )
                                : now);
                      _selectTask(
                        _TimelineTask(
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
                        ),
                      );
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

    if (diff == 0)
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff == 1)
      return '明天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff == -1)
      return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

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
      final updated = DateTime(
        picked.year,
        picked.month,
        picked.day,
        task.date.hour,
        task.date.minute,
      );
      final duration = (task.endDate ?? task.date.add(const Duration(hours: 1)))
          .difference(task.date);
      await widget.taskRepository!.update(
        task.taskId,
        startDate: updated.millisecondsSinceEpoch,
        dueDate: updated.add(duration).millisecondsSinceEpoch,
      );
    } else {
      final updated = DateTime(
        picked.year,
        picked.month,
        picked.day,
        initialDate.hour,
        initialDate.minute,
      );
      if (updated.isAfter(task.date)) {
        await widget.taskRepository!.update(
          task.taskId,
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
        id: task.id,
        title: task.title,
        description: task.description,
        date: task.date,
        endDate: task.endDate,
        isCompleted: task.isCompleted,
        priority: nextLabel,
        source: task.source,
        projectId: task.projectId,
        taskId: task.taskId,
        parentId: task.parentId,
      );
      _applyProjectFilter();
      if (_selectedTaskId == task.id) _selectedTask = _timelineTasks[listIdx];
    }
    if (mounted) setState(() {});
  }

  Future<bool?> _confirmCascadeComplete(_TimelineTask task) async {
    if (task.isCompleted || widget.taskRepository == null) return false;
    final children = await widget.taskRepository!.getSubTasks(task.taskId);
    if (children.isEmpty || !mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完成子任务'),
        content: const Text('这个任务包含子任务，是否同时全部完成？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('仅完成父任务'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('全部完成'),
          ),
        ],
      ),
    );
  }

  void _toggleTaskCompletion(_TimelineTask task) async {
    if (task.source != 'db' || widget.taskRepository == null) return;
    final cascade = await _confirmCascadeComplete(task);
    if (cascade == null) return;
    // 直接操作数据库，不触发 BLoC 避免级联 reload
    if (cascade) {
      await widget.taskRepository!.setStatusCascade(
        task.taskId,
        2,
        includeDescendants: true,
      );
    } else {
      await widget.taskRepository!.toggleStatus(task.taskId);
    }
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
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
              child: Text(
                task.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
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
    for (final t in _displayTasks) {
      if (t.isCompleted) continue;
      final pmap = <String, int>{'P0': 5, 'P1': 3, 'P2': 1, 'P3': 0};
      final p = pmap[t.priority] ?? 0;
      final d = t.date.difference(now).inDays;
      final u = d < 0
          ? 10
          : d <= 3
          ? 5
          : d <= 7
          ? 2
          : d <= 30
          ? 0
          : -2;
      scored[t] = p * 2 + u;
    }
    final sorted = scored.keys.toList()
      ..sort((a, b) => scored[b]!.compareTo(scored[a]!));
    final q1 = <_TimelineTask>[], q2 = <_TimelineTask>[];
    final q3 = <_TimelineTask>[], q4 = <_TimelineTask>[];
    for (final t in sorted) {
      final urgent = t.date.difference(now).inDays <= 3;
      final important = t.priority == 'P0' || t.priority == 'P1';
      (urgent ? (important ? q1 : q3) : (important ? q2 : q4)).add(t);
    }
    // No hard cap - tasks overflow into columns within each quadrant

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 18,
              color: AppTheme.textPrimary,
            ),
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
                  child: Icon(
                    Icons.error_rounded,
                    size: 12,
                    color: AppTheme.error,
                  ),
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
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
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

class _TimelineRenderItem {
  final _TimelineTask task;
  final double left;
  final double width;
  final bool isBar;
  final int lane;

  const _TimelineRenderItem({
    required this.task,
    required this.left,
    required this.width,
    required this.isBar,
    this.lane = 0,
  });

  _TimelineRenderItem withLane(int value) {
    return _TimelineRenderItem(
      task: task,
      left: left,
      width: width,
      isBar: isBar,
      lane: value,
    );
  }
}

class _TimelineArrowPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final bool selected;

  const _TimelineArrowPainter({
    required this.color,
    required this.borderColor,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final arrowWidth = min(18.0, size.width / 3);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - arrowWidth, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - arrowWidth, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelineArrowPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.selected != selected;
  }
}
