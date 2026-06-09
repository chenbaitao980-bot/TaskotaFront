import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/file_logger.dart';
import 'core/utils/platform_utils.dart';
import 'data/database/app_database.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/project_group_repository.dart';
import 'data/repositories/task_repository.dart';
import 'data/repositories/checklist_repository.dart';
import 'data/repositories/node_template_repository.dart';
import 'platform/tray_service.dart';
import 'platform/window_manager_bridge.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/schedule/schedule_bloc.dart';
import 'presentation/blocs/task/task_bloc.dart';
import 'presentation/blocs/task_new/task_bloc.dart' as task_new;
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/home/home_page.dart';
import 'presentation/pages/privacy/privacy_consent_page.dart';
import 'services/attachment_sync_service.dart';
import 'services/checklist_sync_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'services/aliyun_push_service.dart';
import 'services/project_sync_service.dart';
import 'services/supabase_service.dart';
import 'services/task_attachment_service.dart';
import 'services/task_sync_service.dart';
import 'services/node_template_sync_service.dart';
import 'services/subscription_service.dart';
import 'services/member_config_service.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      flog('[FlutterError] ${details.exceptionAsString()}');
    };

    await FileLogger.instance.clear();
    final logPath = await FileLogger.instance.filePath;
    print('Log path: $logPath');
    flog('[App] ===== 应用启动 =====');

    if (!kIsWeb && isDesktop) {
      await _initWindowManager();
    }

    await themeController.load();

    // 先检查隐私协议是否已同意
    final privacyAccepted = await PrivacyConsentPage.isAccepted();

    // 始终只调用一次 runApp，由 MyApp 内部决定展示隐私页还是主界面
    final deps = await _initServices();

    runApp(MyApp(
      privacyAccepted: privacyAccepted,
      database: deps.database,
      projectRepository: deps.projectRepository,
      projectGroupRepository: deps.projectGroupRepository,
      taskRepository: deps.taskRepository,
      checklistRepository: deps.checklistRepository,
      nodeTemplateRepository: deps.nodeTemplateRepository,
    ));

    if (!kIsWeb && isDesktop) {
      await initTray();
    }
  }, (error, stack) {
    flog('[UncaughtError] $error\n$stack');
  });
}

Future<void> _initWindowManager() async {
  await ensureWindowManagerInitialized();
  if (!kIsWeb && isDesktop) {
    await setupCloseToTray();
  }
}

class _AppDeps {
  final AppDatabase database;
  final ProjectRepository projectRepository;
  final ProjectGroupRepository projectGroupRepository;
  final TaskRepository taskRepository;
  final ChecklistRepository checklistRepository;
  final NodeTemplateRepository nodeTemplateRepository;

  _AppDeps({
    required this.database,
    required this.projectRepository,
    required this.projectGroupRepository,
    required this.taskRepository,
    required this.checklistRepository,
    required this.nodeTemplateRepository,
  });
}

Future<_AppDeps> _initServices() async {
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  await NotificationService().init();
  await AlarmService().init();
  await AliyunPushService().init();

  final database = AppDatabase();
  final projectRepository = ProjectRepository(
    database,
    syncService: ProjectSyncService.instance,
  );
  final projectGroupRepository = ProjectGroupRepository(
    database,
    syncService: ProjectSyncService.instance,
  );
  final taskRepository = TaskRepository(
    database,
    syncService: TaskSyncService.instance,
  );
  final checklistRepository = ChecklistRepository(
    database,
    syncService: ChecklistSyncService.instance,
  );
  final nodeTemplateRepository = NodeTemplateRepository(
    database,
    syncService: NodeTemplateSyncService.instance,
  );
  await MemberConfigService.instance.init();
  await SubscriptionService.instance.init();

  TaskSyncService.instance.bind(taskRepository);
  ChecklistSyncService.instance.bind(checklistRepository);
  NodeTemplateSyncService.instance.bind(nodeTemplateRepository);
  TaskAttachmentService().bind(database);
  AttachmentSyncService.instance.bind(database);
  ProjectSyncService.instance.bind(
    db: database,
    projectRepo: projectRepository,
    groupRepo: projectGroupRepository,
  );

  return _AppDeps(
    database: database,
    projectRepository: projectRepository,
    projectGroupRepository: projectGroupRepository,
    taskRepository: taskRepository,
    checklistRepository: checklistRepository,
    nodeTemplateRepository: nodeTemplateRepository,
  );
}

class MyApp extends StatefulWidget {
  final bool privacyAccepted;
  final AppDatabase database;
  final ProjectRepository projectRepository;
  final ProjectGroupRepository projectGroupRepository;
  final TaskRepository taskRepository;
  final ChecklistRepository checklistRepository;
  final NodeTemplateRepository nodeTemplateRepository;

  const MyApp({
    super.key,
    required this.privacyAccepted,
    required this.database,
    required this.projectRepository,
    required this.projectGroupRepository,
    required this.taskRepository,
    required this.checklistRepository,
    required this.nodeTemplateRepository,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _privacyAccepted;

  @override
  void initState() {
    super.initState();
    _privacyAccepted = widget.privacyAccepted;
  }

  void _onPrivacyAccepted() {
    setState(() => _privacyAccepted = true);
  }

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
              create: (context) =>
                  AuthBloc(supabaseService: SupabaseService())
                    ..add(AppStarted()),
            ),
            BlocProvider(
              create: (context) =>
                  ScheduleBloc(supabaseService: SupabaseService()),
            ),
            BlocProvider(
              create: (context) => TaskBloc(supabaseService: SupabaseService()),
            ),
            BlocProvider(
              create: (context) => task_new.TaskNewBloc(
                projectRepository: widget.projectRepository,
                projectGroupRepository: widget.projectGroupRepository,
                taskRepository: widget.taskRepository,
                checklistRepository: widget.checklistRepository,
                nodeTemplateRepository: widget.nodeTemplateRepository,
                supabaseService: SupabaseService(),
              ),
            ),
          ],
          child: ListenableBuilder(
            listenable: themeController,
            builder: (context, _) => MaterialApp(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.themeData,
              darkTheme: AppTheme.themeData,
              themeMode: AppTheme.current.isDark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              navigatorKey: AppRouter.navigatorKey,
              locale: const Locale('zh', 'CN'),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
              onGenerateRoute: AppRouter.onGenerateRoute,
              home: _privacyAccepted
                  ? BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        if (state is Authenticated ||
                            state is LocalAuthenticated) {
                          return HomePage(
                            database: widget.database,
                            projectRepository: widget.projectRepository,
                            projectGroupRepository: widget.projectGroupRepository,
                            taskRepository: widget.taskRepository,
                            checklistRepository: widget.checklistRepository,
                          );
                        }
                        return const LoginPage();
                      },
                    )
                  : PrivacyConsentPage(onAccepted: _onPrivacyAccepted),
            ),
          ),
        );
      },
    );
  }
}
