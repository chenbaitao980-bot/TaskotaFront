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
    final response = await _client
        .from('schedules')
        .insert(schedule.toJson())
        .select()
        .single();
    return Schedule.fromJson(response);
  }
  
  Future<Schedule> updateSchedule(Schedule schedule) async {
    final response = await _client
        .from('schedules')
        .update(schedule.toJson())
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
