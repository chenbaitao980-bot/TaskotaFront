import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/notification_service.dart';
import '../../../models/entities/task_breakdown.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/create_schedule_dialog.dart';
import '../calendar/calendar_page.dart';
import '../ai_chat/ai_chat_page.dart';
import '../profile/profile_page.dart';
import '../onboarding/onboarding_page.dart';
import '../task/create_task_page.dart';
import '../task/task_list_page.dart';
import '../tasks/tasks_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  int _calendarRefreshToken = 0;
  final LocalStorageService _storage = LocalStorageService();
  int _pendingCount = 0;
  int _completedCount = 0;
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
        pendingCount: _pendingCount,
        completedCount: _completedCount,
        onNavigateToChat: () => setState(() => _currentIndex = 3),
        onCreateSchedule: _createSchedule,
        onRefresh: _loadStats,
        onOpenTaskStatus: _openTaskStatus,
        onEditSchedule: _editSchedule,
        onDeleteSchedule: _deleteSchedule,
      ),
      const TasksPage(),
      CalendarPage(refreshToken: _calendarRefreshToken),
      const AiChatPage(),
      const ProfilePage(),
    ];
  }

  Future<void> _initStorage() async {
    await _storage.init();
    _storageReady = true;
    _loadStats();
    _checkOnboarding();
  }

  Future<void> _ensureStorageReady() async {
    if (_storageReady) return;
    await _storage.init();
    _storageReady = true;
  }

  void _loadStats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final tasks = _storage.getTasks(excludeParent: true);
    final todaySchedules = _storage.getSchedules(
      startDate: todayStart,
      endDate: todayEnd,
    );
    setState(() {
      _pendingCount =
          tasks
              .where(
                (t) =>
                    t.status == 'pending' &&
                    _timeRangeInvolvesToday(t.startDate, t.endDate),
              )
              .length +
          todaySchedules.where((s) => s.status != 'completed').length;
      _completedCount =
          tasks
              .where(
                (t) => t.status == 'completed' && _isSameDay(t.updatedAt, now),
              )
              .length +
          todaySchedules
              .where(
                (s) => s.status == 'completed' && _isSameDay(s.updatedAt, now),
              )
              .length;
    });
    _updateImplicitProfile(tasks, todaySchedules);
  }

  void _updateImplicitProfile(List tasks, List todaySchedules) {
    final totalCreated = tasks.length;
    final totalCompleted = tasks.where((t) => t.status == 'completed').length;
    final completionRate = totalCreated > 0
        ? (totalCompleted / totalCreated).clamp(0.0, 1.0)
        : 0.0;
    _storage.updateImplicitProfile({
      'avgTaskCompletionRate': completionRate,
      'totalTasks': totalCreated,
      'completedTasks': totalCompleted,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  bool _timeRangeInvolvesToday(DateTime? start, DateTime? end) {
    if (start == null || end == null) return true;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return start.isBefore(todayEnd) && end.isAfter(todayStart);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getUserId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is LocalAuthenticated) return authState.email;
    if (authState is Authenticated) return authState.user.id;
    return 'local_user';
  }

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
        );
        await NotificationService().scheduleReminderForSchedule(
          scheduleId: newSchedule.id,
          title: newSchedule.title,
          startTime: newSchedule.startTime,
          description: newSchedule.description,
        );
        _loadStats();
        if (mounted) {
          setState(() => _calendarRefreshToken++);
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('日程已创建')));
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
      );
      await _storage.updateSchedule(updated);
      _loadStats();
      if (mounted) {
        setState(() => _calendarRefreshToken++);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日程已更新')));
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
      if (mounted) {
        setState(() => _calendarRefreshToken++);
      }
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
      _loadStats();
      if (mounted) {
        setState(() => _calendarRefreshToken++);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日程已删除')));
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
              if (index == 1) {
                _calendarRefreshToken++;
              }
            });
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
              Icons.chat_bubble_outline_rounded,
              Icons.chat_bubble_rounded,
              'AI助手',
            ),
            _navItem(
              4,
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
// Home Content
// ────────────────────────────────────────────────────────────

class _HomeContent extends StatelessWidget {
  final LocalStorageService storage;
  final int pendingCount;
  final int completedCount;
  final VoidCallback onNavigateToChat;
  final VoidCallback onCreateSchedule;
  final VoidCallback onRefresh;
  final void Function(String status, String title) onOpenTaskStatus;
  final void Function(dynamic schedule) onEditSchedule;
  final void Function(dynamic schedule) onDeleteSchedule;

  const _HomeContent({
    required this.storage,
    required this.pendingCount,
    required this.completedCount,
    required this.onNavigateToChat,
    required this.onCreateSchedule,
    required this.onRefresh,
    required this.onOpenTaskStatus,
    required this.onEditSchedule,
    required this.onDeleteSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Greeting
                  _buildGreeting(),
                  const SizedBox(height: 24),
                  // Overview Card
                  _buildTodayOverview(),
                  const SizedBox(height: 24),
                  // Quick Actions
                  _buildQuickActions(context),
                  const SizedBox(height: 24),
                  // Today's Schedules
                  _buildRecentSchedules(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
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
          pendingCount > 0 ? '今天有 $pendingCount 个待办事项' : '今天没有待办事项',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildTodayOverview() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Coral accent bar
          Container(
            height: 3,
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '今日概览',
                      style: GoogleFonts.interTextTheme().titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: '待办',
                        value: '$pendingCount',
                        icon: Icons.check_circle_outline,
                        color: AppTheme.primaryColor,
                        onTap: () => onOpenTaskStatus('pending', '待办'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        label: '已完成',
                        value: '$completedCount',
                        icon: Icons.done_all_rounded,
                        color: AppTheme.success,
                        onTap: () => onOpenTaskStatus('completed', '已完成'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('快捷操作', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                label: '语音录入',
                icon: Icons.mic_rounded,
                color: AppTheme.primaryColor,
                bgColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                onTap: onNavigateToChat,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                label: 'AI拆解目标',
                icon: Icons.auto_fix_high_rounded,
                color: AppTheme.primaryColor,
                bgColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                onTap: onNavigateToChat,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentSchedules(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final schedules = storage.getSchedules(
      startDate: todayStart,
      endDate: todayEnd,
    );

    // 获取今日任务并按父任务分组
    final allTasks = storage.getTasks();
    final todayTasks = storage.getTasks(
      startDate: todayStart,
      endDate: todayEnd,
      excludeParent: true,
    );
    final groups = <String, List<TaskBreakdown>>{};
    final parentNames = <String, String>{};
    for (final t in todayTasks) {
      if (t.parentTaskId != null) {
        groups.putIfAbsent(t.parentTaskId!, () => []);
        groups[t.parentTaskId!]!.add(t);
        if (!parentNames.containsKey(t.parentTaskId!)) {
          final p = allTasks.where((x) => x.id == t.parentTaskId).firstOrNull;
          parentNames[t.parentTaskId!] = p?.title ?? '未知';
        }
      }
    }
    // 无父任务的任务归到"其他"组
    final ungroupedTasks =
        todayTasks.where((t) => t.parentTaskId == null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('今日日程', style: Theme.of(context).textTheme.titleLarge),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('刷新'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (schedules.isEmpty && todayTasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  size: 44,
                  color: AppTheme.textHint,
                ),
                const SizedBox(height: 12),
                Text(
                  '暂无日程',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 15),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onCreateSchedule,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('创建第一个日程'),
                ),
              ],
            ),
          )
        else ...[
          // 日程列表
          ...schedules.map((s) => _ScheduleCard(
                schedule: s,
                onToggle: (checked) {
                  final newStatus =
                      checked == true ? 'completed' : 'in_progress';
                  storage.updateSchedule(s.copyWith(status: newStatus));
                  onRefresh();
                },
                onEdit: () => onEditSchedule(s),
                onDelete: () => onDeleteSchedule(s),
              )),
          const SizedBox(height: 16),
          // 今日任务分组
          if (todayTasks.isNotEmpty) ...[
            Text('今日任务',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            // 分组任务
            for (final entry in groups.entries)
              _buildTaskGroup(context, entry.key, entry.value,
                  parentNames[entry.key] ?? ''),
            // 无父任务的任务
            ...ungroupedTasks.map((t) => _buildTaskItem(context, t)),
          ],
        ],
      ],
    );
  }

  Widget _buildTaskGroup(BuildContext context, String parentId,
      List<TaskBreakdown> children, String parentName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: const Border(
                left: BorderSide(color: AppTheme.primaryColor, width: 3),
              ),
            ),
            child: Text(
              '📁 $parentName',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          ...children.map((t) => InkWell(
                onTap: () => onOpenTaskStatus(t.status, t.title),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: t.status == 'completed'
                              ? AppTheme.success
                              : AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: t.status == 'completed'
                                ? AppTheme.textHint
                                : AppTheme.textPrimary,
                            decoration: t.status == 'completed'
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (t.startDate != null)
                        Text(
                          '${t.startDate!.hour.toString().padLeft(2, '0')}:${t.startDate!.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textHint,
                          ),
                        ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, TaskBreakdown task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: InkWell(
        onTap: () => onOpenTaskStatus(task.status, task.title),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _priorityColor(task.priority),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (task.startDate != null)
              Text(
                '${task.startDate!.hour.toString().padLeft(2, '0')}:${task.startDate!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
              ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'P0':
        return AppTheme.priorityP0;
      case 'P1':
        return AppTheme.priorityP1;
      case 'P2':
        return AppTheme.priorityP2;
      default:
        return AppTheme.priorityP3;
    }
  }
}

// ────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.jetBrainsMonoTextTheme().headlineMedium
                    ?.copyWith(
                      color: color,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                label,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final dynamic schedule;
  final void Function(bool? checked) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.schedule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  Color _priorityColor(String? priority) {
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
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(schedule.priority as String?);
    final isCompleted = schedule.status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Color bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: isCompleted ? AppTheme.textHint : color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Checkbox
                    GestureDetector(
                      onTap: () => onToggle(!isCompleted),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          border: Border.all(
                            color: isCompleted
                                ? AppTheme.primaryColor
                                : AppTheme.textHint,
                            width: 2,
                          ),
                        ),
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedule.title as String,
                            style: TextStyle(
                              color: isCompleted
                                  ? AppTheme.textHint
                                  : AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${schedule.startTime.hour.toString().padLeft(2, '0')}:${schedule.startTime.minute.toString().padLeft(2, '0')}  →  ${schedule.endTime.hour.toString().padLeft(2, '0')}:${schedule.endTime.minute.toString().padLeft(2, '0')}',
                            style: GoogleFonts.jetBrainsMonoTextTheme()
                                .bodySmall
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Menu
                    SizedBox(
                      width: 32,
                      child: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') onEdit();
                          if (action == 'delete') onDelete();
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
                                Text(
                                  '删除',
                                  style: TextStyle(color: AppTheme.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                        icon: const Icon(
                          Icons.more_horiz,
                          color: AppTheme.textHint,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
