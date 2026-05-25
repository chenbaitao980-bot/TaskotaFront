import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entities/schedule.dart';
import '../models/entities/task_breakdown.dart';
import 'package:uuid/uuid.dart';

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
    // 自动刷新父任务的 isParent
    if (task.parentTaskId != null) {
      await refreshParentFlag(task.parentTaskId!);
    }
    return task;
  }

  Future<TaskBreakdown> updateTask(TaskBreakdown updated) async {
    final tasks = getTasks();
    final index = tasks.indexWhere((t) => t.id == updated.id);
    if (index == -1) throw Exception('Task not found');
    final oldParentId = tasks[index].parentTaskId;
    tasks[index] = updated.copyWith(updatedAt: DateTime.now());
    await _saveTasks(tasks);
    // parentTaskId 变化时刷新两端 isParent
    if (oldParentId != updated.parentTaskId) {
      if (oldParentId != null) await refreshParentFlag(oldParentId);
      if (updated.parentTaskId != null) {
        await refreshParentFlag(updated.parentTaskId!);
      }
    }
    return tasks[index];
  }

  bool hasChildTasks(String id) {
    return getTasks().any((task) => task.parentTaskId == id);
  }

  // 获取某任务的所有后代任务（递归）
  List<TaskBreakdown> getAllDescendantTasks(String taskId) {
    final allTasks = getTasks();
    final result = <TaskBreakdown>[];

    void collect(String parentId) {
      final children = allTasks.where((t) => t.parentTaskId == parentId).toList();
      for (final child in children) {
        result.add(child);
        collect(child.id);
      }
    }

    collect(taskId);
    return result;
  }

  // 计算任务进度（基于后代任务完成状态）
  int calculateTaskProgress(String taskId) {
    final descendants = getAllDescendantTasks(taskId);
    if (descendants.isEmpty) {
      // 叶子节点：返回自身 progress
      final task = getTasks().where((t) => t.id == taskId).firstOrNull;
      return task?.progress ?? 0;
    }
    // 有后代：按完成后代比例计算
    final completedCount = descendants.where((t) => t.status == 'completed').length;
    return ((completedCount / descendants.length) * 100).round();
  }

  /// 当子任务完成时，检查父任务是否应自动完成（递归向上传播）
  Future<void> checkAndAutoCompleteParent(String taskId) async {
    final allTasks = getTasks();
    final task = allTasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null || task.parentTaskId == null) return;

    final parentId = task.parentTaskId!;
    final parent = allTasks.where((t) => t.id == parentId).firstOrNull;
    if (parent == null) return;

    // 获取所有同级子任务
    final siblings = allTasks.where((t) => t.parentTaskId == parentId).toList();
    final allCompleted = siblings.every((t) => t.status == 'completed');

    if (allCompleted) {
      // 父任务所有子任务都完成 → 自动完成父任务
      final updated = parent.copyWith(
        status: 'completed',
        progress: 100,
      );
      await updateTask(updated);
      // 递归向上传播
      await checkAndAutoCompleteParent(parentId);
    }
  }

  /// 当子任务从 completed 改为其他状态时，将父任务回退
  Future<void> revertParentOnChildIncomplete(String taskId) async {
    final allTasks = getTasks();
    final task = allTasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null || task.parentTaskId == null) return;

    final parentId = task.parentTaskId!;
    final parent = allTasks.where((t) => t.id == parentId).firstOrNull;
    if (parent == null) return;

    // 如果父任务是自动完成的，回退到进行中
    if (parent.status == 'completed') {
      final progress = calculateTaskProgress(parentId);
      final updated = parent.copyWith(
        status: progress > 0 ? 'in_progress' : 'pending',
        progress: progress,
      );
      await updateTask(updated);
      // 递归向上传播
      await revertParentOnChildIncomplete(parentId);
    }
  }

  /// 刷新任务的 isParent：有子任务 → true，否则 false
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

  /// 检测任务时间冲突：与已有 Schedule 或其他非父任务 TaskBreakdown 重叠
  bool detectTaskTimeConflict(DateTime start, DateTime end,
      {String? excludeId}) {
    // 1. 检测 Schedule 冲突
    if (detectTimeConflict(start, end, excludeId: excludeId)) return true;
    // 2. 检测 TaskBreakdown 冲突（排除父任务）
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
    // 删除子任务后刷新父任务的 isParent
    if (parentId != null) {
      await refreshParentFlag(parentId);
    }
  }

  Future<void> _saveTasks(List<TaskBreakdown> tasks) async {
    final jsonList = tasks.map((t) => t.toJson()).toList();
    await _prefs?.setString(_tasksKey, json.encode(jsonList));
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
        title: '欢迎使用智能小管家',
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
  }

  Future<void> saveExplicitProfile(Map<String, dynamic> data) async {
    await _prefs?.setString(_profileKey, json.encode(data));
  }

  Map<String, dynamic>? getExplicitProfile() {
    final jsonStr = _prefs?.getString(_profileKey);
    if (jsonStr == null) return null;
    return json.decode(jsonStr) as Map<String, dynamic>;
  }

  Future<void> updateImplicitProfile(Map<String, dynamic> data) async {
    await _prefs?.setString('implicit_profile', json.encode(data));
  }

  Map<String, dynamic>? getImplicitProfile() {
    final jsonStr = _prefs?.getString('implicit_profile');
    if (jsonStr == null) return null;
    return json.decode(jsonStr) as Map<String, dynamic>;
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
