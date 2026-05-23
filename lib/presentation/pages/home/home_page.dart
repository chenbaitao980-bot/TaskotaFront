import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/notification_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/create_schedule_dialog.dart';
import '../calendar/calendar_page.dart';
import '../ai_chat/ai_chat_page.dart';
import '../profile/profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final LocalStorageService _storage = LocalStorageService();
  int _pendingCount = 0;
  int _inProgressCount = 0;
  int _completedCount = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _HomeContent(
        storage: _storage,
        pendingCount: _pendingCount,
        inProgressCount: _inProgressCount,
        completedCount: _completedCount,
        onNavigateToChat: () => setState(() => _currentIndex = 2),
        onCreateSchedule: _createSchedule,
        onRefresh: _loadStats,
      ),
      const CalendarPage(),
      const AiChatPage(),
      const ProfilePage(),
    ];
    _initStorage();
  }

  Future<void> _initStorage() async {
    await _storage.init();
    _loadStats();
  }

  void _loadStats() {
    final tasks = _storage.getTasks();
    setState(() {
      _pendingCount = tasks.where((t) => t.status == 'pending').length;
      _inProgressCount = tasks.where((t) => t.status == 'in_progress').length;
      _completedCount = tasks.where((t) => t.status == 'completed').length;
    });
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
      final newSchedule = await _storage.createSchedule(
        userId: _getUserId(),
        title: result['title'] as String,
        description: result['description'] as String?,
        startTime: result['startTime'] as DateTime,
        endTime: result['endTime'] as DateTime,
        priority: result['priority'] as String,
      );
      // Schedule reminder notification
      NotificationService().scheduleReminderForSchedule(
        scheduleId: newSchedule.id,
        title: newSchedule.title,
        startTime: newSchedule.startTime,
        description: newSchedule.description,
      );
      _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: '日历',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'AI助手',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSchedule,
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final LocalStorageService storage;
  final int pendingCount;
  final int inProgressCount;
  final int completedCount;
  final VoidCallback onNavigateToChat;
  final VoidCallback onCreateSchedule;
  final VoidCallback onRefresh;

  const _HomeContent({
    required this.storage,
    required this.pendingCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.onNavigateToChat,
    required this.onCreateSchedule,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '早上好！',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pendingCount > 0 ? '今天有$pendingCount个待办事项' : '今天没有待办事项',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTodayOverview(),
                  const SizedBox(height: 24),
                  _buildQuickActions(context),
                  const SizedBox(height: 24),
                  _buildRecentSchedules(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日概览',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('待办', '$pendingCount', Icons.check_circle_outline),
              _buildStatItem('进行中', '$inProgressCount', Icons.timelapse),
              _buildStatItem('已完成', '$completedCount', Icons.done_all),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('快捷操作', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                '语音录入',
                Icons.mic,
                AppTheme.primaryColor,
                onNavigateToChat,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'AI拆解目标',
                Icons.auto_fix_high,
                AppTheme.secondaryColor,
                onNavigateToChat,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSchedules(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final schedules = storage.getSchedules(startDate: todayStart, endDate: todayEnd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('今日日程', style: Theme.of(context).textTheme.headlineMedium),
            TextButton(onPressed: onRefresh, child: const Text('刷新')),
          ],
        ),
        const SizedBox(height: 8),
        if (schedules.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('暂无日程', style: TextStyle(color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: onCreateSchedule,
                      child: const Text('创建第一个日程'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              final s = schedules[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _priorityColor(s.priority),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text(s.title),
                  subtitle: Text(
                    '${s.startTime.hour}:${s.startTime.minute.toString().padLeft(2, '0')} - '
                    '${s.endTime.hour}:${s.endTime.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onCreateSchedule,
                ),
              );
            },
          ),
      ],
    );
  }

  Color _priorityColor(String p) {
    return switch (p) { 'P0' => Colors.red, 'P1' => Colors.orange, 'P2' => Colors.green, _ => Colors.blue };
  }
}
