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
    users[email] = {'password': password, 'createdAt': DateTime.now().toIso8601String()};
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
    var schedules = list.map((e) => Schedule.fromJson(e as Map<String, dynamic>)).toList();

    if (startDate != null) {
      schedules = schedules.where((s) => s.startTime.isAfter(startDate) || s.startTime.isAtSameMomentAs(startDate)).toList();
    }
    if (endDate != null) {
      schedules = schedules.where((s) => s.endTime.isBefore(endDate) || s.endTime.isAtSameMomentAs(endDate)).toList();
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
  List<TaskBreakdown> getTasks({String? level, String? status}) {
    final jsonStr = _prefs?.getString(_tasksKey);
    if (jsonStr == null) return [];
    final list = json.decode(jsonStr) as List;
    var tasks = list.map((e) => TaskBreakdown.fromJson(e as Map<String, dynamic>)).toList();

    if (level != null) tasks = tasks.where((t) => t.level == level).toList();
    if (status != null) tasks = tasks.where((t) => t.status == status).toList();
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
      parentScheduleId: null,
      focusRequired: false,
      dependencies: const [],
      createdAt: now,
      updatedAt: now,
    );

    final tasks = getTasks();
    tasks.add(task);
    await _saveTasks(tasks);
    return task;
  }

  Future<TaskBreakdown> updateTask(TaskBreakdown updated) async {
    final tasks = getTasks();
    final index = tasks.indexWhere((t) => t.id == updated.id);
    if (index == -1) throw Exception('Task not found');
    tasks[index] = updated.copyWith(updatedAt: DateTime.now());
    await _saveTasks(tasks);
    return tasks[index];
  }

  Future<void> deleteTask(String id) async {
    final tasks = getTasks();
    tasks.removeWhere((t) => t.id == id);
    await _saveTasks(tasks);
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
    return schedules.any((s) =>
        s.startTime.isBefore(end) && s.endTime.isAfter(start));
  }
}
