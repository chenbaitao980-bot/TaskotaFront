import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/desktop/desktop_floating_tab_controller.dart';
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
import 'data/sync/cloud_sync_gateway.dart';
import 'data/sync/data_backend.dart';
import 'data/sync/local_only_cloud_sync_gateway.dart';
import 'platform/single_instance.dart';
import 'platform/tray_service.dart';
import 'platform/window_manager_bridge.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/schedule/schedule_bloc.dart';
import 'presentation/blocs/task/task_bloc.dart';
import 'presentation/blocs/task_new/task_bloc.dart' as task_new;
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/home/home_page.dart';
import 'presentation/pages/privacy/privacy_consent_page.dart';
import 'presentation/pages/floating_note/note_window_app.dart';
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
import 'services/app_config_service.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        flog('[FlutterError] ${details.exceptionAsString()}');
      };

      // 日志清理为磁盘 IO，可延后，不阻塞首帧（W9）
      unawaited(FileLogger.instance.clear());
      unawaited(
        FileLogger.instance.filePath.then((p) => debugPrint('Log path: $p')),
      );
      flog('[App] ===== 应用启动 =====');

      // 便签引擎分支：独立第二 Flutter 引擎，跳过全部业务初始化。
      if (!kIsWeb && isDesktop && await _isNoteWindowRole()) {
        await runNoteWindow();
        return;
      }

      if (!kIsWeb && isDesktop) {
        await _initWindowManager();
      }

      // 单实例锁（prd P0-3）：注册表自启 + 无锁 → 双进程抢同一 drift 库（WAL 锁竞争）
      // 且第二实例无前台权（打开慢/需点任务栏）。放 _initWindowManager 之后保证 onActivate
      // 回调时 windowManager 已就绪。第二实例经回环 socket 握手唤起首实例主窗后自行退出。
      if (!kIsWeb && isDesktop) {
        final isPrimary = await SingleInstance.tryAcquire(
          onActivate: () {
            unawaited(DesktopFloatingTabController.instance.restoreFullWindow());
          },
        );
        if (!isPrimary) {
          flog('[App] 单实例锁：检测到已运行实例，唤起其主窗后本实例退出');
          exit(0);
        }
      }

      // 主题 / 隐私标记 / Supabase 会话恢复互不依赖，并行执行（W8+W15）
      // Supabase.initialize 带 2s 超时（prd P1-A）：弱网悬挂不再阻塞 runApp 前关键路径。
      var privacyAccepted = false;
      await Future.wait<void>([
        themeController.load(),
        PrivacyConsentPage.isAccepted().then((v) => privacyAccepted = v),
        _initSupabase(),
      ]);

      // 始终只调用一次 runApp，由 MyApp 内部决定展示隐私页还是主界面
      final deps = await _initServices();

      runApp(
        MyApp(
          privacyAccepted: privacyAccepted,
          database: deps.database,
          projectRepository: deps.projectRepository,
          projectGroupRepository: deps.projectGroupRepository,
          taskRepository: deps.taskRepository,
          checklistRepository: deps.checklistRepository,
          nodeTemplateRepository: deps.nodeTemplateRepository,
        ),
      );

      // 首帧后再做托盘 / 通知 / 推送 / 会员配置等非首屏必需初始化（W1/W2/W3/W7/W13/W14）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!kIsWeb && isDesktop) {
          // 冷启动置前台（prd P1-B）：注册表自启进程无前台权限，SetForegroundWindow 静默
          // 失败 → 窗口需再点一下。restoreFullWindow 的 HWND_TOPMOST 切换绕过前台锁直接弹出。
          unawaited(DesktopFloatingTabController.instance.restoreFullWindow());
          unawaited(initTray());
        }
        if (kIsWeb) {
          // Web 端预热 wasm 数据库，让下载/编译与首帧并行（W13）
          unawaited(deps.database.customSelect('select 1').get());
        }
        unawaited(_initDeferredServices());
      });
    },
    (error, stack) {
      flog('[UncaughtError] $error\n$stack');
    },
  );
}

/// 首帧后初始化的服务：均不影响首屏渲染与首批数据。
/// NotificationService → AlarmService 保持原有先后顺序串行；其余并行。
Future<void> _initDeferredServices() async {
  try {
    await NotificationService().init();
  } catch (e) {
    flog('[App] NotificationService init failed: $e');
  }
  try {
    await AlarmService().init();
  } catch (e) {
    flog('[App] AlarmService init failed: $e');
  }
  unawaited(AliyunPushService().init());
  unawaited(MemberConfigService.instance.init());
  unawaited(AppConfigService.instance.init());
  unawaited(SubscriptionService.instance.refresh());
}

Future<void> _initWindowManager() async {
  await ensureWindowManagerInitialized();
  if (!kIsWeb && isDesktop) {
    await setupCloseToTray();
  }
}

/// 检测当前引擎是否为便签引擎（第二引擎启动时由 desktop_multi_window 注入 arguments）。
Future<bool> _isNoteWindowRole() async {
  try {
    final controller = await WindowController.fromCurrentEngine();
    if (controller.arguments.isEmpty) return false;
    final decoded = jsonDecode(controller.arguments);
    return decoded is Map && decoded['role'] == 'note';
  } catch (_) {
    return false;
  }
}

/// Supabase 初始化（prd P1-A）：带 2s 超时，弱网悬挂不再阻塞 runApp 前关键路径。
/// 超时/失败仅记录；本地模式（DataBackend.local）不依赖云端会话，currentUser 降级 null。
Future<void> _initSupabase() async {
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    ).timeout(const Duration(seconds: 2));
  } catch (e) {
    flog('[App] Supabase.initialize 超时/失败：$e（本地模式继续，currentUser 降级 null）');
  }
}

class _AppDeps {
  final AppDatabase database;
  final ProjectRepository projectRepository;
  final ProjectGroupRepository projectGroupRepository;
  final TaskRepository taskRepository;
  final ChecklistRepository checklistRepository;
  final NodeTemplateRepository nodeTemplateRepository;
  final CloudSyncGateway cloudSyncGateway;

  _AppDeps({
    required this.database,
    required this.projectRepository,
    required this.projectGroupRepository,
    required this.taskRepository,
    required this.checklistRepository,
    required this.nodeTemplateRepository,
    required this.cloudSyncGateway,
  });
}

Future<_AppDeps> _initServices() async {
  final database = AppDatabase();
  // 断连（prd Decision 2/4）：默认本地后端；同步网关为 LocalOnly（同步 no-op + 快照导出/导入桥）
  DataBackendConfig.current = DataBackend.local;
  final cloudSyncGateway = LocalOnlyCloudSyncGateway(database);
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
  // 订阅服务仅加载本地缓存（首屏 isVip 够用），网络 refresh 在首帧后执行（W2）
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
    cloudSyncGateway: cloudSyncGateway,
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
  final _desktopFloatingTabController = DesktopFloatingTabController.instance;
  late bool _privacyAccepted;

  @override
  void initState() {
    super.initState();
    _privacyAccepted = widget.privacyAccepted;
    _desktopFloatingTabController.bindTaskRepository(widget.taskRepository);
    if (!kIsWeb && isDesktop) {
      unawaited(_desktopFloatingTabController.ensureInitialized());
    }
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
            listenable: Listenable.merge([
              themeController,
              _desktopFloatingTabController,
            ]),
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
                        final canShowFloatingTab =
                            state is Authenticated ||
                            state is LocalAuthenticated;
                        _desktopFloatingTabController.setCanShowFloatingTab(
                          canShowFloatingTab,
                        );
                        if (state is Authenticated ||
                            state is LocalAuthenticated) {
                          return HomePage(
                            database: widget.database,
                            projectRepository: widget.projectRepository,
                            projectGroupRepository:
                                widget.projectGroupRepository,
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
