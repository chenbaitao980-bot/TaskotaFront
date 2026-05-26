import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/task_repository.dart';
import 'data/repositories/checklist_repository.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/schedule/schedule_bloc.dart';
import 'presentation/blocs/task/task_bloc.dart';
import 'presentation/blocs/task_new/task_bloc.dart' as task_new;
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/home/home_page.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  await NotificationService().init();

  final database = AppDatabase();
  final projectRepository = ProjectRepository(database);
  final taskRepository = TaskRepository(database);
  final checklistRepository = ChecklistRepository(database);

  runApp(MyApp(
    database: database,
    projectRepository: projectRepository,
    taskRepository: taskRepository,
    checklistRepository: checklistRepository,
  ));
}

class MyApp extends StatelessWidget {
  final AppDatabase database;
  final ProjectRepository projectRepository;
  final TaskRepository taskRepository;
  final ChecklistRepository checklistRepository;

  const MyApp({
    super.key,
    required this.database,
    required this.projectRepository,
    required this.taskRepository,
    required this.checklistRepository,
  });

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => AuthBloc(
                supabaseService: SupabaseService(),
              )..add(AppStarted()),
            ),
            BlocProvider(
              create: (context) => ScheduleBloc(
                supabaseService: SupabaseService(),
              ),
            ),
            BlocProvider(
              create: (context) => TaskBloc(
                supabaseService: SupabaseService(),
              ),
            ),
            BlocProvider(
              create: (context) => task_new.TaskNewBloc(
                projectRepository: projectRepository,
                taskRepository: taskRepository,
                checklistRepository: checklistRepository,
              ),
            ),
          ],
          child: MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.lightTheme,
            themeMode: ThemeMode.light,
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is Authenticated || state is LocalAuthenticated) {
                  return HomePage(
                    projectRepository: projectRepository,
                    taskRepository: taskRepository,
                    checklistRepository: checklistRepository,
                  );
                }
                if (state is AuthLoading) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return const LoginPage();
              },
            ),
          ),
        );
      },
    );
  }
}
