import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_assistant/core/constants/app_constants.dart';
import 'package:smart_assistant/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'deleteTask blocks deleting a parent that still has child tasks',
    () async {
      final storage = LocalStorageService();
      await storage.init();

      final start = DateTime(2026, 5, 25, 9);
      final parent = await storage.createTask(
        userId: 'local_user',
        title: 'Parent task',
        level: 'task',
        startDate: start,
        endDate: start.add(const Duration(hours: 1)),
      );
      await storage.createTask(
        userId: 'local_user',
        title: 'Child task',
        level: 'subtask',
        parentTaskId: parent.id,
        startDate: start,
        endDate: start.add(const Duration(hours: 1)),
      );

      expect(storage.hasChildTasks(parent.id), isTrue);
      expect(() => storage.deleteTask(parent.id), throwsStateError);
      expect(
        storage.getTasks().where((task) => task.id == parent.id),
        isNotEmpty,
      );
    },
  );
}
