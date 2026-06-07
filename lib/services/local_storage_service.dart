import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entities/schedule.dart';
import '../models/entities/task_breakdown.dart';
import 'package:uuid/uuid.dart';
import 'local_data_service.dart';
import 'supabase_service.dart';

class LocalStorageService {
  static const _schedulesKey = 'local_schedules';
  static const _tasksKey = 'local_tasks';
  static const _userKey = 'local_user';
  static const _uuid = Uuid();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Auth: local mock
  Future<bool> register(String email, String password) async {
    if (password.length < 6) return false;
    final existing = _prefs?.getString(_userKey);
    if (existing != null) {
      final users = json.decode(existing) as Map<String, dynamic>;
      if (users.containsKey(email)) return false;
    }
    final users = existing != null
        ? json.decode(existing) as Map<String, dynamic>
        : <String, dynamic>{};
    users[email] = {
      'password': password,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _prefs?.setString(_userKey, json.encode(users));
    await LocalDataService().persistPreferencesSnapshot();
    return true;
  }

  Future<bool> login(String email, String password) async {
    final existing = _prefs?.getString(_userKey);
    if (existing == null) {
      // Auto-register for first-time use
      return await register(email, password);
    }
    final users = json.decode(existing) as Map<String, dynamic>;
    if (!users.containsKey(email)) {
      return await register(email, password);
    }
    final user = users[email] as Map<String, dynamic>;
    return user['password'] == password;
  }

  bool get hasLocalUser {
    final existing = _prefs?.getString(_userKey);
    return existing != null;
  }

  // Schedules
  List<Schedule> getSchedules({DateTime? startDate, DateTime? endDate}) {
    final jsonStr = _prefs?.getString(_schedulesKey);
    if (jsonStr == null) return [];
    final list = json.decode(jsonStr) as List;
    var schedules = list
        .map((e) => Schedule.fromJson(e as Map<String, dynamic>))
        .toList();

    if (startDate != null || endDate != null) {
      final rangeStart = startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rangeEnd = endDate ?? DateTime(9999, 12, 31);
      schedules = schedules.where((s) {
        return s.startTime.isBefore(rangeEnd) && s.endTime.isAfter(rangeStart);
      }).toList();
    }
    schedules.sort((a, b) => a.startTime.compareTo(b.startTime));
    return schedules;
  }

  Future<Schedule> createSchedule({
    required String userId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    String priority = 'P2',
    bool focusRequired = false,
    int remindBeforeMinutes = 15,
    bool reminderEnabled = true,
    bool isRepeating = false,
    int? repeatInterval,
  }) async {
    final now = DateTime.now();
    final schedule = Schedule(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      priority: priority,
      focusRequired: focusRequired,
      remindBeforeMinutes: remindBeforeMinutes,
      reminderEnabled: reminderEnabled,
      isRepeating: isRepeating,
      repeatInterval: repeatInterval,
      reminderType: isRepeating ? 'repeat' : 'once',
      createdAt: now,
      updatedAt: now,
    );

    final schedules = getSchedules();
    schedules.add(schedule);
    await _saveSchedules(schedules);
    return schedule;
  }

  Future<Schedule> updateSchedule(Schedule updated) async {
    final schedules = getSchedules();
    final index = schedules.indexWhere((s) => s.id == updated.id);
    if (index == -1) throw Exception('Schedule not found');
    schedules[index] = updated.copyWith(updatedAt: DateTime.now());
    await _saveSchedules(schedules);
    return schedules[index];
  }

  Future<void> deleteSchedule(String id) async {
    final schedules = getSchedules();
    schedules.removeWhere((s) => s.id == id);
    await _saveSchedules(schedules);
  }

  Future<void> _saveSchedules(List<Schedule> schedules) async {
    final jsonList = schedules.map((s) => s.toJson()).toList();
    await _prefs?.setString(_schedulesKey, json.encode(jsonList));
    await LocalDataService().persistPreferencesSnapshot();
  }

  // Tasks
  List<TaskBreakdown> getTasks({
    String? level,
    String? status,
    String? parentTaskId,
    bool rootOnly = false,
    bool? excludeParent,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final jsonStr = _prefs?.getString(_tasksKey);
    if (jsonStr == null) return [];
    final list = json.decode(jsonStr) as List;
    var tasks = list
        .map((e) => TaskBreakdown.fromJson(e as Map<String, dynamic>))
        .toList();

    if (level != null) tasks = tasks.where((t) => t.level == level).toList();
    if (status != null) tasks = tasks.where((t) => t.status == status).toList();
    if (parentTaskId != null) {
      tasks = tasks.where((t) => t.parentTaskId == parentTaskId).toList();
    }
    if (rootOnly) {
      tasks = tasks
          .where((t) => t.parentTaskId == null && t.parentScheduleId == null)
          .toList();
    }
    if (excludeParent != null) {
      if (excludeParent) {
        tasks = tasks.where((t) => !t.isParent).toList();
      } else {
        tasks = tasks.where((t) => t.isParent).toList();
      }
    }
    if (startDate != null || endDate != null) {
      final rangeStart = startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rangeEnd = endDate ?? DateTime(9999, 12, 31);
      tasks = tasks.where((t) {
        final taskStart = t.startDate;
        final taskEnd = t.endDate;
        if (taskStart == null && taskEnd == null) return false;
        final effectiveStart = taskStart ?? taskEnd!;
        final effectiveEnd = (taskEnd ?? taskStart!).add(
          const Duration(days: 1),
        );
        return effectiveStart.isBefore(rangeEnd) &&
            effectiveEnd.isAfter(rangeStart);
      }).toList();
    }
    tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return tasks;
  }

  Future<TaskBreakdown> createTask({
    required String userId,
    required String title,
    String? description,
    required String level,
    DateTime? startDate,
    DateTime? endDate,
    String priority = 'P2',
    String? parentGoalId,
    String? parentTaskId,
    String? parentScheduleId,
  }) async {
    final now = DateTime.now();
    final task = TaskBreakdown(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      description: description,
      level: level,
      startDate: startDate,
      endDate: endDate,
      status: 'pending',
      progress: 0,
      priority: priority,
      parentGoalId: parentGoalId,
      parentTaskId: parentTaskId,
      parentScheduleId: parentScheduleId,
      focusRequired: false,
      dependencies: const [],
      createdAt: now,
      updatedAt: now,
    );

    final tasks = getTasks();
    tasks.add(task);
    await _saveTasks(tasks);
    // 鑷姩鍒锋柊鐖朵换鍔＄殑 isParent
    if (task.parentTaskId != null) {
      await refreshParentFlag(task.parentTaskId!);
    }
    _syncTasksToCloud(); // 鑷姩鍚屾鍒颁簯绔?
    return task;
  }

  Future<TaskBreakdown> updateTask(TaskBreakdown updated) async {
    final tasks = getTasks();
    final index = tasks.indexWhere((t) => t.id == updated.id);
    if (index == -1) throw Exception('Task not found');
    final oldParentId = tasks[index].parentTaskId;
    tasks[index] = updated.copyWith(updatedAt: DateTime.now());
    await _saveTasks(tasks);
    // parentTaskId 鍙樺寲鏃跺埛鏂颁袱绔?isParent
    if (oldParentId != updated.parentTaskId) {
      if (oldParentId != null) await refreshParentFlag(oldParentId);
      if (updated.parentTaskId != null) {
        await refreshParentFlag(updated.parentTaskId!);
      }
    }
    _syncTasksToCloud(); // 鑷姩鍚屾鍒颁簯绔?
    return tasks[index];
  }

  bool hasChildTasks(String id) {
    return getTasks().any((task) => task.parentTaskId == id);
  }

  // 鑾峰彇鏌愪换鍔＄殑鎵€鏈夊悗浠ｄ换鍔★紙閫掑綊锛?
  List<TaskBreakdown> getAllDescendantTasks(String taskId) {
    final allTasks = getTasks();
    final result = <TaskBreakdown>[];

    void collect(String parentId) {
      final children = allTasks
          .where((t) => t.parentTaskId == parentId)
          .toList();
      for (final child in children) {
        result.add(child);
        collect(child.id);
      }
    }

    collect(taskId);
    return result;
  }

  // 璁＄畻浠诲姟杩涘害锛堝熀浜庡悗浠ｄ换鍔″畬鎴愮姸鎬侊級
  int calculateTaskProgress(String taskId) {
    final descendants = getAllDescendantTasks(taskId);
    if (descendants.isEmpty) {
      // 鍙跺瓙鑺傜偣锛氳繑鍥炶嚜韬?progress
      final task = getTasks().where((t) => t.id == taskId).firstOrNull;
      return task?.progress ?? 0;
    }
    // 鏈夊悗浠ｏ細鎸夊畬鎴愬悗浠ｆ瘮渚嬭绠?
    final completedCount = descendants
        .where((t) => t.status == 'completed')
        .length;
    return ((completedCount / descendants.length) * 100).round();
  }

  /// 褰撳瓙浠诲姟瀹屾垚鏃讹紝妫€鏌ョ埗浠诲姟鏄惁搴旇嚜鍔ㄥ畬鎴愶紙閫掑綊鍚戜笂浼犳挱锛?
  Future<void> checkAndAutoCompleteParent(String taskId) async {
    final allTasks = getTasks();
    final task = allTasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null || task.parentTaskId == null) return;

    final parentId = task.parentTaskId!;
    final parent = allTasks.where((t) => t.id == parentId).firstOrNull;
    if (parent == null) return;

    // 鑾峰彇鎵€鏈夊悓绾у瓙浠诲姟
    final siblings = allTasks.where((t) => t.parentTaskId == parentId).toList();
    final allCompleted = siblings.every((t) => t.status == 'completed');

    if (allCompleted) {
      // 鐖朵换鍔℃墍鏈夊瓙浠诲姟閮藉畬鎴?鈫?鑷姩瀹屾垚鐖朵换鍔?
      final updated = parent.copyWith(status: 'completed', progress: 100);
      await updateTask(updated);
      // 閫掑綊鍚戜笂浼犳挱
      await checkAndAutoCompleteParent(parentId);
    }
  }

  /// 褰撳瓙浠诲姟浠?completed 鏀逛负鍏朵粬鐘舵€佹椂锛屽皢鐖朵换鍔″洖閫€
  Future<void> revertParentOnChildIncomplete(String taskId) async {
    final allTasks = getTasks();
    final task = allTasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null || task.parentTaskId == null) return;

    final parentId = task.parentTaskId!;
    final parent = allTasks.where((t) => t.id == parentId).firstOrNull;
    if (parent == null) return;

    // 濡傛灉鐖朵换鍔℃槸鑷姩瀹屾垚鐨勶紝鍥為€€鍒拌繘琛屼腑
    if (parent.status == 'completed') {
      final progress = calculateTaskProgress(parentId);
      final updated = parent.copyWith(
        status: progress > 0 ? 'in_progress' : 'pending',
        progress: progress,
      );
      await updateTask(updated);
      // 閫掑綊鍚戜笂浼犳挱
      await revertParentOnChildIncomplete(parentId);
    }
  }

  /// 鍒锋柊浠诲姟鐨?isParent锛氭湁瀛愪换鍔?鈫?true锛屽惁鍒?false
  Future<void> refreshParentFlag(String taskId) async {
    final allTasks = getTasks();
    final task = allTasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;
    final hasChildren = allTasks.any((t) => t.parentTaskId == taskId);
    if (task.isParent != hasChildren) {
      final updated = task.copyWith(isParent: hasChildren);
      await updateTask(updated);
    }
  }

  /// 妫€娴嬩换鍔℃椂闂村啿绐侊細涓庡凡鏈?Schedule 鎴栧叾浠栭潪鐖朵换鍔?TaskBreakdown 閲嶅彔
  bool detectTaskTimeConflict(
    DateTime start,
    DateTime end, {
    String? excludeId,
  }) {
    // 1. 妫€娴?Schedule 鍐茬獊
    if (detectTimeConflict(start, end, excludeId: excludeId)) return true;
    // 2. 妫€娴?TaskBreakdown 鍐茬獊锛堟帓闄ょ埗浠诲姟锛?
    final tasks = getTasks(excludeParent: true);
    for (final task in tasks) {
      if (excludeId != null && task.id == excludeId) continue;
      final tStart = task.startDate;
      final tEnd = task.endDate;
      if (tStart == null || tEnd == null) continue;
      if (tStart.isBefore(end) && tEnd.isAfter(start)) return true;
    }
    return false;
  }

  Future<void> deleteTask(String id) async {
    final tasks = getTasks();
    if (tasks.any((t) => t.parentTaskId == id)) {
      throw StateError('Task has child tasks');
    }
    final deleted = tasks.where((t) => t.id == id).firstOrNull;
    final parentId = deleted?.parentTaskId;
    tasks.removeWhere((t) => t.id == id);
    await _saveTasks(tasks);
    // 鍒犻櫎瀛愪换鍔″悗鍒锋柊鐖朵换鍔＄殑 isParent
    if (parentId != null) {
      await refreshParentFlag(parentId);
    }
    _syncTasksToCloud(); // 鑷姩鍚屾鍒颁簯绔?
  }

  Future<void> _saveTasks(List<TaskBreakdown> tasks) async {
    final jsonList = tasks.map((t) => t.toJson()).toList();
    await _prefs?.setString(_tasksKey, json.encode(jsonList));
    await LocalDataService().persistPreferencesSnapshot();
  }

  // Demo data for first-time users
  Future<void> ensureDemoData(String userId) async {
    if (_prefs == null) return;
    final schedulesExist = _prefs!.containsKey(_schedulesKey);
    if (!schedulesExist) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await createSchedule(
        userId: userId,
        title: '欢迎使用 Taskora',
        description: '点击日历查看和管理你的日程',
        startTime: today.add(const Duration(hours: 9)),
        endTime: today.add(const Duration(hours: 10)),
        priority: 'P1',
      );
      await createSchedule(
        userId: userId,
        title: '尝试语音或文字录入',
        description: '点击首页的"语音录入"或"AI拆解目标"开始使用',
        startTime: today.add(const Duration(hours: 14)),
        endTime: today.add(const Duration(hours: 15)),
        priority: 'P2',
      );
    }
  }

  // Profile
  static const _profileKey = 'user_profile';
  static const _onboardingKey = 'onboarding_completed';

  bool get onboardingCompleted => _prefs?.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingCompleted() async {
    await _prefs?.setBool(_onboardingKey, true);
    await LocalDataService().persistPreferencesSnapshot();
  }

  // AI 鎺掔▼锛氭槸鍚﹁烦杩囧懆鏈?
  static const _skipWeekendsKey = 'ai_schedule_skip_weekends';

  bool get skipWeekends => _prefs?.getBool(_skipWeekendsKey) ?? false;

  Future<void> setSkipWeekends(bool value) async {
    await _prefs?.setBool(_skipWeekendsKey, value);
    await LocalDataService().persistPreferencesSnapshot();
  }

  static const _excludedProjectIdsKey = 'excluded_project_ids';
  static const _projectSidebarTimeSortDescKey =
      'project_sidebar_time_sort_desc';

  Set<String> get excludedProjectIds {
    final raw = _prefs?.getStringList(_excludedProjectIdsKey) ?? const [];
    return raw.toSet();
  }

  Future<void> setExcludedProjectIds(Set<String> ids) async {
    await _prefs?.setStringList(_excludedProjectIdsKey, ids.toList()..sort());
    await LocalDataService().persistPreferencesSnapshot();
  }

  bool get projectSidebarTimeSortDesc =>
      _prefs?.getBool(_projectSidebarTimeSortDescKey) ?? true;

  Future<void> setProjectSidebarTimeSortDesc(bool value) async {
    await _prefs?.setBool(_projectSidebarTimeSortDescKey, value);
    await LocalDataService().persistPreferencesSnapshot();
  }

  // 涓婚閫夋嫨
  static const _themeKey = 'app_theme_id';

  // 任务筛选状态
  static const _taskFilterStateKey = 'task_filter_state';

  // 首页项目筛选
  static const _homeFilterProjectIdsKey = 'home_filter_project_ids';

  List<String> getHomeFilterProjectIds() {
    final jsonStr = _prefs?.getString(_homeFilterProjectIdsKey);
    if (jsonStr == null) return [];
    final decoded = json.decode(jsonStr);
    if (decoded is List) return decoded.cast<String>();
    if (decoded is Map<String, dynamic>) {
      return (decoded['projectIds'] as List<dynamic>? ?? []).cast<String>();
    }
    return [];
  }

  Future<void> saveHomeFilterProjectIds(Set<String> ids) async {
    await _prefs?.setString(
      _homeFilterProjectIdsKey,
      json.encode(ids.toList()),
    );
  }

  Map<String, dynamic>? getHomeFilterState() {
    final jsonStr = _prefs?.getString(_homeFilterProjectIdsKey);
    if (jsonStr == null) return null;
    final decoded = json.decode(jsonStr);
    if (decoded is List) {
      return {'projectIds': decoded.cast<String>()};
    }
    return decoded as Map<String, dynamic>;
  }

  Future<void> saveHomeFilterState(Map<String, dynamic> state) async {
    await _prefs?.setString(_homeFilterProjectIdsKey, json.encode(state));
    await LocalDataService().persistPreferencesSnapshot();
  }

  Map<String, dynamic>? getTaskFilterState() {
    final jsonStr = _prefs?.getString(_taskFilterStateKey);
    if (jsonStr == null) return null;
    return json.decode(jsonStr) as Map<String, dynamic>;
  }

  Future<void> saveTaskFilterState(Map<String, dynamic> state) async {
    await _prefs?.setString(_taskFilterStateKey, json.encode(state));
  }

  String? get themeId => _prefs?.getString(_themeKey);

  Future<void> setThemeId(String value) async {
    await _prefs?.setString(_themeKey, value);
    await LocalDataService().persistPreferencesSnapshot();
  }

  // 逾期提醒间隔（小时，默认 4）
  static const _overdueNotifIntervalHoursKey = 'overdue_notif_interval_hours';

  int get overdueNotifIntervalHours =>
      _prefs?.getInt(_overdueNotifIntervalHoursKey) ?? 4;

  Future<void> setOverdueNotifIntervalHours(int value) async {
    await _prefs?.setInt(_overdueNotifIntervalHoursKey, value);
    await LocalDataService().persistPreferencesSnapshot();
  }

  // 上次逾期通知时间（毫秒时间戳，默认 0）
  static const _overdueLastNotifMsKey = 'overdue_last_notif_ms';

  int get overdueLastNotifMs =>
      _prefs?.getInt(_overdueLastNotifMsKey) ?? 0;

  Future<void> setOverdueLastNotifMs(int value) async {
    await _prefs?.setInt(_overdueLastNotifMsKey, value);
    await LocalDataService().persistPreferencesSnapshot();
  }

  Future<void> saveExplicitProfile(Map<String, dynamic> data) async {
    await _prefs?.setString(_profileKey, json.encode(data));
    await LocalDataService().persistPreferencesSnapshot();
  }

  Map<String, dynamic>? getExplicitProfile() {
    final jsonStr = _prefs?.getString(_profileKey);
    if (jsonStr == null) return null;
    return json.decode(jsonStr) as Map<String, dynamic>;
  }

  Future<void> updateImplicitProfile(Map<String, dynamic> data) async {
    await _prefs?.setString('implicit_profile', json.encode(data));
    await LocalDataService().persistPreferencesSnapshot();
  }

  Map<String, dynamic>? getImplicitProfile() {
    final jsonStr = _prefs?.getString('implicit_profile');
    if (jsonStr == null) return null;
    return json.decode(jsonStr) as Map<String, dynamic>;
  }

  // 鈹€鈹€ 浜戝悓姝?鈹€鈹€

  /// 灏嗘湰鍦版墍鏈変换鍔℃帹閫佸埌 Supabase 浜戠
  Future<void> _syncTasksToCloud() async {
    final svc = SupabaseService();
    try {
      // 鍏堟媺鍙栬繙绔悎骞讹紝鍐嶆帹閫侊紙瑙ｅ喅澶氱瑕嗙洊闂锛?
      await fetchAndMergeFromCloud();
      final tasks = getTasks();
      final jsonList = tasks.map((t) => t.toJson()).toList();
      if (jsonList.isEmpty) return;
      await svc.syncLocalTasks(jsonList);
    } catch (_) {}
  }

  /// 浠庝簯绔媺鍙栦换鍔″苟鍚堝苟鍒版湰鍦帮紙鏍规嵁 updatedAt 淇濈暀鏈€鏂扮増鏈級
  Future<void> fetchAndMergeFromCloud() async {
    final svc = SupabaseService();
    try {
      final remoteJson = await svc.fetchRemoteLocalTasks();
      if (remoteJson == null || remoteJson.isEmpty) return;
      final localTasks = getTasks();
      final localMap = {for (final t in localTasks) t.id: t};
      bool changed = false;

      for (final json in remoteJson) {
        final remote = TaskBreakdown.fromJson(json);
        final local = localMap[remote.id];
        if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
          if (local != null) {
            final idx = localTasks.indexOf(local);
            localTasks[idx] = remote;
          } else {
            localTasks.add(remote);
          }
          changed = true;
        }
      }

      if (changed) {
        final jsonList = localTasks.map((t) => t.toJson()).toList();
        await _prefs?.setString(_tasksKey, json.encode(jsonList));
        await LocalDataService().persistPreferencesSnapshot();
      }
    } catch (_) {}
  }

  // Conflict detection
  bool detectTimeConflict(DateTime start, DateTime end, {String? excludeId}) {
    final schedules = getSchedules(startDate: start, endDate: end);
    if (excludeId != null) {
      schedules.removeWhere((s) => s.id == excludeId);
    }
    return schedules.any(
      (s) => s.startTime.isBefore(end) && s.endTime.isAfter(start),
    );
  }
}
