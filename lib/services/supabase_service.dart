import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/entities/schedule.dart';
import '../models/entities/task_breakdown.dart';
import '../models/entities/user_profile.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  
  // Auth Methods
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }
  
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
  
  User? get currentUser => _client.auth.currentUser;
  
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  
  /// 将 camelCase 键转换为 snake_case（Supabase 列名格式）
  Map<String, dynamic> _toSnakeCase(Map<String, dynamic> json) {
    final result = <String, dynamic>{};
    for (final entry in json.entries) {
      final snakeKey = entry.key.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}',
      );
      result[snakeKey] = entry.value;
    }
    return result;
  }

  // Schedule Methods
  Future<List<Schedule>> getSchedules({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _client
        .from('schedules')
        .select()
        .eq('user_id', currentUser!.id);
    
    if (startDate != null) {
      query = query.gte('start_time', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('end_time', endDate.toIso8601String());
    }
    
    final response = await query.order('start_time', ascending: true);
    return (response as List).map((json) => Schedule.fromJson(json)).toList();
  }
  
  Future<Schedule> createSchedule(Schedule schedule) async {
    final json = _toSnakeCase(schedule.toJson());
    final response = await _client
        .from('schedules')
        .insert(json)
        .select()
        .single();
    return Schedule.fromJson(response);
  }
  
  Future<Schedule> updateSchedule(Schedule schedule) async {
    final json = _toSnakeCase(schedule.toJson());
    final response = await _client
        .from('schedules')
        .update(json)
        .eq('id', schedule.id)
        .select()
        .single();
    return Schedule.fromJson(response);
  }
  
  Future<void> deleteSchedule(String id) async {
    await _client.from('schedules').delete().eq('id', id);
  }
  
  // Task Methods
  Future<List<TaskBreakdown>> getTasks({
    String? level,
    String? status,
  }) async {
    var query = _client
        .from('task_breakdowns')
        .select()
        .eq('user_id', currentUser!.id);
    
    if (level != null) {
      query = query.eq('level', level);
    }
    if (status != null) {
      query = query.eq('status', status);
    }
    
    final response = await query.order('created_at', ascending: false);
    return (response as List).map((json) => TaskBreakdown.fromJson(json)).toList();
  }
  
  Future<TaskBreakdown> createTask(TaskBreakdown task) async {
    final response = await _client
        .from('task_breakdowns')
        .insert(task.toJson())
        .select()
        .single();
    return TaskBreakdown.fromJson(response);
  }
  
  Future<TaskBreakdown> updateTask(TaskBreakdown task) async {
    final response = await _client
        .from('task_breakdowns')
        .update(task.toJson())
        .eq('id', task.id)
        .select()
        .single();
    return TaskBreakdown.fromJson(response);
  }
  
  Future<void> deleteTask(String id) async {
    await _client.from('task_breakdowns').delete().eq('id', id);
  }
  
  // ── 本地任务云同步 ──
  
  /// 将本地任务数据同步到云端（存储为 JSON）
  Future<void> syncLocalTasks(List<Map<String, dynamic>> tasksJson) async {
    if (currentUser == null) {
      print('[Sync] 推送跳过：用户未登录');
      return;
    }
    try {
      print('[Sync] 推送 ${tasksJson.length} 条到 local_task_sync, user=${currentUser!.id}');
      await _client.from('local_task_sync').upsert({
        'user_id': currentUser!.id,
        'tasks_data': tasksJson,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      print('[Sync] 推送成功');
    } catch (e) {
      print('[Sync] 推送失败: $e');
      print('[Sync] 请确保 Supabase 数据库中存在 local_task_sync 表');
      print('[Sync] 解决方法：Supabase Dashboard → SQL Editor → 运行 database/create_sync_table.sql');
    }
  }

  /// 从云端拉取本地任务数据
  Future<List<Map<String, dynamic>>?> fetchRemoteLocalTasks() async {
    if (currentUser == null) {
      print('[Sync] 拉取跳过：用户未登录');
      return null;
    }
    try {
      print('[Sync] 开始拉取, user=${currentUser!.id}');
      final response = await _client
          .from('local_task_sync')
          .select('tasks_data')
          .eq('user_id', currentUser!.id)
          .maybeSingle();
      if (response == null) {
        print('[Sync] 云端无数据');
        return null;
      }
      final tasksData = response['tasks_data'];
      if (tasksData is List) {
        print('[Sync] 拉取到 ${tasksData.length} 条任务');
        return tasksData.cast<Map<String, dynamic>>();
      }
      print('[Sync] tasks_data 格式异常: ${tasksData.runtimeType}');
      return null;
    } catch (e) {
      print('[Sync] 拉取失败: $e');
      return null;
    }
  }
  
  // User Profile Methods
  Future<UserProfile?> getUserProfile() async {
    final response = await _client
        .from('user_profiles')
        .select()
        .eq('id', currentUser!.id)
        .maybeSingle();
    
    if (response == null) return null;
    return UserProfile.fromJson(response);
  }
  
  Future<UserProfile> createUserProfile(UserProfile profile) async {
    final response = await _client
        .from('user_profiles')
        .insert(profile.toJson())
        .select()
        .single();
    return UserProfile.fromJson(response);
  }
  
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    final response = await _client
        .from('user_profiles')
        .update(profile.toJson())
        .eq('id', profile.id)
        .select()
        .single();
    return UserProfile.fromJson(response);
  }
}
