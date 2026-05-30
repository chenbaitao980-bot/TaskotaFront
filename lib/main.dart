import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';

import 'core/constants/app_constants.dart';
import 'core/desktop/desktop_runtime.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/database/app_database.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/project_group_repository.dart';
import 'data/repositories/task_repository.dart';
import 'data/repositories/checklist_repository.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/schedule/schedule_bloc.dart';
import 'presentation/blocs/task/task_bloc.dart';
import 'presentation/blocs/task_new/task_bloc.dart' as task_new;
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/home/home_page.dart';
import 'services/attachment_sync_service.dart';
import 'services/checklist_sync_service.dart';
import 'services/notification_service.dart';
import 'services/project_sync_service.dart';
import 'services/supabase_service.dart';
import 'services/task_attachment_service.dart';
import 'services/task_sync_service.dart';
import 'core/utils/file_logger.dart';

final SystemTray systemTray = SystemTray();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化文件日志
  await FileLogger.instance.clear();
  final logPath = await FileLogger.instance.filePath;
  print('📋 调试日志路径: $logPath');
  flog('[App] ===== 应用启动 =====');

  // 桌面端：初始化窗口管理
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
  }

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  await NotificationService().init();

  // 加载持久化主题
  await themeController.load();

  final database = AppDatabase();
  final projectRepository =
      ProjectRepository(database, syncService: ProjectSyncService.instance);
  final projectGroupRepository = ProjectGroupRepository(database,
      syncService: ProjectSyncService.instance);
  final taskRepository = TaskRepository(database, syncService: TaskSyncService.instance);
  final checklistRepository = ChecklistRepository(database,
      syncService: ChecklistSyncService.instance);
  TaskSyncService.instance.bind(taskRepository);
  ChecklistSyncService.instance.bind(checklistRepository);
  TaskAttachmentService().bind(database);
  AttachmentSyncService.instance.bind(database);
  ProjectSyncService.instance.bind(
    db: database,
    projectRepo: projectRepository,
    groupRepo: projectGroupRepository,
  );

  runApp(MyApp(
    database: database,
    projectRepository: projectRepository,
    projectGroupRepository: projectGroupRepository,
    taskRepository: taskRepository,
    checklistRepository: checklistRepository,
  ));

  // 桌面端：系统托盘 + 窗口关闭拦截（需在 runApp 后）
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await _initSystemTray();
  }
}

Future<void> _initSystemTray() async {
  try {
    await windowManager.waitUntilReadyToShow();
    await windowManager.setSkipTaskbar(false);

    final trayOk = await systemTray.initSystemTray(
      title: AppConstants.appName,
      iconPath: 'assets/icons/tray_icon.ico',
      toolTip: AppConstants.appName,
    );
    print(trayOk ? '[Tray] 初始化成功' : '[Tray] 初始化失败 - 检查图标路径');
  } catch (e) {
    print('[Tray] 异常: $e');
    return;
  }

  // 右键菜单
  final menu = [
    MenuItem(
      label: '显示',
      onClicked: () async {
        await windowManager.show();
        await windowManager.focus();
      },
    ),
    MenuSeparator(),
    MenuItem(
      label: '退出',
      onClicked: () async {
        await windowManager.destroy();
        exit(0);
      },
    ),
  ];
  await systemTray.setContextMenu(menu);

  // 左键点击托盘图标 → 显示窗口
  systemTray.registerSystemTrayEventHandler((eventName) {
    final action = trayEventActionFor(eventName);
    if (action == TrayEventAction.showWindow) {
      windowManager.show();
      windowManager.focus();
    } else if (action == TrayEventAction.popUpContextMenu) {
      systemTray.popUpContextMenu();
    }
  });
}

class MyApp extends StatelessWidget {
  final AppDatabase database;
  final ProjectRepository projectRepository;
  final ProjectGroupRepository projectGroupRepository;
  final TaskRepository taskRepository;
  final ChecklistRepository checklistRepository;

  const MyApp({
    super.key,
    required this.database,
    required this.projectRepository,
    required this.projectGroupRepository,
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
                projectGroupRepository: projectGroupRepository,
                taskRepository: taskRepository,
                checklistRepository: checklistRepository,
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
            themeMode: AppTheme.current.isDark ? ThemeMode.dark : ThemeMode.light,
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
          ),
        );
      },
    );
  }
}
