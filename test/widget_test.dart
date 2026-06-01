import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/native.dart';

import 'package:smart_assistant/core/constants/app_constants.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/data/repositories/project_repository.dart';
import 'package:smart_assistant/data/repositories/project_group_repository.dart';
import 'package:smart_assistant/data/repositories/task_repository.dart';
import 'package:smart_assistant/data/repositories/checklist_repository.dart';
import 'package:smart_assistant/main.dart';

void main() {
  late AppDatabase database;
  late ProjectRepository projectRepository;
  late ProjectGroupRepository projectGroupRepository;
  late TaskRepository taskRepository;
  late ChecklistRepository checklistRepository;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );

    database = AppDatabase();
    projectRepository = ProjectRepository(database);
    projectGroupRepository = ProjectGroupRepository(database);
    taskRepository = TaskRepository(database);
    checklistRepository = ChecklistRepository(database);
  });

  tearDownAll(() {
    database.close();
  });

  testWidgets('shows login page when unauthenticated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        database: database,
        projectRepository: projectRepository,
        projectGroupRepository: projectGroupRepository,
        taskRepository: taskRepository,
        checklistRepository: checklistRepository,
      ),
    );
    await tester.pump();

    expect(find.text('智能小助手'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('立即注册'), findsOneWidget);
  });
}
