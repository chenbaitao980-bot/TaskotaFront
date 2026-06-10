# Research: 启动链路性能审计（冷启动 → 首屏可交互）

- **Query**: 从 lib/main.dart 追踪冷启动到首批数据展示的完整链路，找出拖慢启动的弱点
- **Scope**: internal（全部基于源码静态追踪）
- **Date**: 2026-06-10

---

## 一、完整启动时序链路图（按执行顺序）

> 标注：[阻塞首帧] = 在 runApp 前串行 await，首帧渲染必须等它完成；[首帧后] = runApp 之后执行。

```
冷启动
│
├─ 1. main() → runZonedGuarded                          main.dart:44-45
├─ 2. WidgetsFlutterBinding.ensureInitialized()          main.dart:46           [阻塞首帧]
├─ 3. await FileLogger.instance.clear()                  main.dart:53           [阻塞首帧] 磁盘IO
│      └─ getApplicationDocumentsDirectory + 建目录
│         + 清理旧日志(list/stat/delete) + 写session头    file_logger_io.dart:16-73
├─ 4. await FileLogger.instance.filePath                 main.dart:54           [阻塞首帧] (有缓存，轻)
├─ 5. [桌面] await _initWindowManager()                  main.dart:58-60        [阻塞首帧]
│      └─ windowManager.ensureInitialized
│         + setPreventClose(true)                        window_manager_bridge_desktop.dart:4-11
├─ 6. await themeController.load()                       main.dart:62           [阻塞首帧]
│      └─ SharedPreferences.getInstance + 读主题          theme_controller.dart:13-23
├─ 7. await PrivacyConsentPage.isAccepted()              main.dart:65           [阻塞首帧]
│      └─ SharedPreferences.getInstance（再 await 一次）  privacy_consent_page.dart:18-21
├─ 8. await _initServices()                              main.dart:68           [阻塞首帧] ★重灾区
│      ├─ 8.1 await Supabase.initialize()                main.dart:114-117      恢复本地会话
│      ├─ 8.2 await NotificationService().init()         main.dart:119
│      │      ├─ tz.initializeTimeZones()  全量时区库     notification_service_io.dart:124  CPU重
│      │      ├─ await FlutterTimezone.getLocalTimezone() notification_service_io.dart:226-231  平台通道
│      │      ├─ [Windows] _windowsPlugin.initialize()   notification_service_io.dart:129-183
│      │      └─ [Android] plugin.initialize +
│      │          删除2个旧通道 + 创建1个新通道            notification_service_io.dart:185-258
│      ├─ 8.3 await AlarmService().init()                main.dart:120
│      │      └─ [Android原生模式] 直接return（轻）；
│      │         [iOS/回滚] Alarm.init + stopAll          alarm_service_io.dart:25-39
│      ├─ 8.4 await AliyunPushService().init()           main.dart:121          ★网络
│      │      ├─ await _plugin.initPush()  原生SDK网络注册 aliyun_push_service_io.dart:34-38
│      │      ├─ await createAndroidChannel()            aliyun_push_service_io.dart:44-51
│      │      └─ await _tryUploadDeviceId()  Supabase网络 aliyun_push_service_io.dart:80,116+
│      ├─ 8.5 AppDatabase() 构造                          main.dart:123          LazyDatabase，OK
│      ├─ 8.6 5 个 Repository 构造（同步，轻）             main.dart:124-143
│      ├─ 8.7 await MemberConfigService.instance.init()  main.dart:144          ★网络×3，无超时
│      │      └─ Future.wait(member_types /
│      │          member_discount_codes /
│      │          member_recharge_tiers)                  member_config_service.dart:183-206
│      ├─ 8.8 await SubscriptionService.instance.init()  main.dart:145          ★网络×2串行，无超时
│      │      ├─ _loadFromCache() SharedPreferences       subscription_service.dart:50-52,165
│      │      └─ await refresh(): user_subscriptions 查询
│      │          + vip_whitelist 查询（串行）             subscription_service.dart:55-92
│      └─ 8.9 各 SyncService.bind()（同步，轻）           main.dart:147-156
│
├─ 9. runApp(MyApp)                                      main.dart:70
├─ 10.[桌面] await initTray()                            main.dart:80-82        [与首帧竞争]
│      └─ waitUntilReadyToShow + setSkipTaskbar
│         + initSystemTray                                tray_service_desktop.dart:9-23
│
├─ 11. MyApp.build → ScreenUtilInit → MultiBlocProvider  main.dart:206-236
│      （BlocProvider 默认 lazy，4个bloc不立即实例化）
├─ 12. MaterialApp → home BlocBuilder<AuthBloc>          main.dart:256-272
│      └─ 首次 read 触发 AuthBloc 创建 + AppStarted
│         （仅同步读 currentUser，轻）                     auth_bloc.dart:24-37
├─ 13. HomePage 首帧构建                                  home_page.dart:494-498
│      ├─ _pages = _buildPages() 一次性构建全部 4 个 tab   home_page.dart:89,148-178
│      │   放进 IndexedStack（index切换但4个子树全部活着）  home_page.dart:498
│      ├─ initState → _initStorage() fire-and-forget     home_page.dart:92-94
│      │   ├─ _storage.init() SharedPreferences           home_page.dart:181
│      │   ├─ await fetchAndMergeFromCloud()  ★网络        home_page.dart:183 → local_storage_service.dart:580
│      │   ├─ _setupProjectSyncOnAuth → runSyncAll:
│      │   │   Project→Task→Checklist→NodeTemplate→
│      │   │   Attachment 5个同步服务串行 await  ★网络      home_page.dart:220-228,269
│      │   ├─ requestMobilePermissions()                  home_page.dart:187
│      │   └─ _rescheduleTaskReminders():
│      │       taskRepository.getAll() 全表 + 逐条重排通知  home_page.dart:195-214
│      └─ 隐藏 tab 也在启动时各自发起加载：
│          ├─ TasksPage.initState → LoadTasks             tasks_page.dart:45-49
│          ├─ CalendarPage postFrame → _reloadData(全量DB)
│          │   + _loadHolidaysForYears  ★网络              calendar_page.dart:77-93
│          └─ _HomeContent postFrame → _loadData():
│              projects.getActive + tasks.getAll 全表      home_page.dart:750,774-800
│
└─ 14. 首批数据展示：TaskNewBloc._onLoadTasks             task_bloc.dart:291
       串行 await 链（首屏数据必经）：
       getTemplateProjects → getActive → _storage.init →
       ★await supabaseService.fetchPreferences() 网络      task_bloc.dart:320-328
       → taskRepository.getAll() 全表                      task_bloc.dart:344
       → getToday/getImportant（部分filter再查一次）        task_bloc.dart:366-373
       → _calculateProgress(checklist.getByTaskIds
         + projects.getAll 再查)                           task_bloc.dart:414-417,1114-1127
       → projectGroupRepository.getAll()                   task_bloc.dart:434-436
       → emit(TaskNewLoaded)  ← 首批任务上屏
```

**关键结论**：首帧前有 **5 处网络请求**（AliyunPush SDK注册、deviceId上传、会员配置×3、订阅+白名单×2），全部无超时降级；首批任务上屏前还要再等 1 次 `fetchPreferences` 网络请求。弱网/离线场景下白屏时间 = 各请求超时之和。

---

## 二、弱点清单

### W1. runApp 前 await 会员配置网络请求（无超时）

- **文件**: `lib/main.dart:144` → `lib/services/member_config_service.dart:178-206`
- **类别**: 反模式4（启动路径网络阻塞）+ 反模式2（首帧前初始化重型服务）
- **代码**:
  ```dart
  await MemberConfigService.instance.init();   // main.dart:144
  // member_config_service.dart:
  Future<void> init() async { await refresh(); }
  Future<void> refresh() async {
    final results = await Future.wait([typesFuture, codesFuture, tiersFuture]); // 3张表REST查询
  ```
- **影响**: 高。会员配置仅在购买页才需要，却让所有用户首帧等 3 个 REST 请求；离线时等到 socket 超时（可能 10-30s）才进 catch。注释自称"支持本地缓存"，实际无任何缓存。
- **建议**: 从 `_initServices` 移除，首帧后 `unawaited(refresh())`，或进入会员页时懒加载；补 SharedPreferences 缓存 + `Future.timeout(3s)`。

### W2. runApp 前 await 订阅刷新（2 次串行网络查询，无超时）

- **文件**: `lib/main.dart:145` → `lib/services/subscription_service.dart:50-92`
- **类别**: 反模式4 + 反模式2
- **代码**:
  ```dart
  Future<void> init() async {
    await _loadFromCache();   // 本地缓存，OK
    await refresh();          // user_subscriptions 查询 → 再串行 vip_whitelist 查询
  }
  ```
- **影响**: 高。本地缓存已经够首帧用（`isVip` 读 `_cached`），refresh 完全可后台做；且两个查询串行而非并行。HomePage `startIfReady` 里登录后还会再 `SubscriptionService.instance.refresh()`（home_page.dart:242），启动这次纯属重复。
- **建议**: `init()` 只 `_loadFromCache()`；`refresh()` 移到首帧后/登录后（已有该调用点），两查询 `Future.wait` + timeout。

### W3. runApp 前 await 阿里云推送 SDK 初始化 + deviceId 网络上传

- **文件**: `lib/main.dart:121` → `lib/services/aliyun_push_service_io.dart:29-83,116+`
- **类别**: 反模式2 + 反模式4 + 反模式6（Android 通道创建）
- **代码**:
  ```dart
  final result = await _plugin.initPush(appKey: ..., appSecret: ...); // 原生SDK向阿里云注册（网络）
  await _plugin.createAndroidChannel(...);
  ...
  await _tryUploadDeviceId();   // Supabase upsert（网络）
  ```
- **影响**: 高（Android）。推送注册完全不影响首屏功能，却在 runApp 前串行 await 原生网络注册 + Supabase 上传。
- **建议**: 整体延迟到首帧后（`addPostFrameCallback` / `Future.delayed`），`onUserLoggedIn()` 已有登录后补传逻辑（home_page.dart:236），启动时这次上传可直接砍掉。

### W4. 首批任务上屏被 fetchPreferences 网络请求卡住

- **文件**: `lib/presentation/blocs/task_new/task_bloc.dart:326-329`
- **类别**: 反模式4（应本地优先 + 后台合并）
- **代码**:
  ```dart
  if (state is! TaskNewLoaded) {            // 首次加载必走
    final localPrefs = _storage.getTaskFilterState();
    final cloudPrefs = await supabaseService?.fetchPreferences();  // 网络，等完才继续
    final prefs = cloudPrefs ?? localPrefs;
  ```
- **影响**: 高。这是首批数据展示的必经路径：本地 DB 明明毫秒级可出数据，却先等一次云端偏好查询。弱网下首屏任务列表延迟 = 该请求耗时。
- **建议**: 先用 `localPrefs` 立即出首屏；`fetchPreferences` 后台拉取，与本地不一致时再补发一次 LoadTasks（或仅更新筛选状态）。

### W5. 启动窗口内多次全表 getAll + 多源重复触发 LoadTasks

- **文件**:
  - `task_bloc.dart:344`（LoadTasks 全表）+ `task_bloc.dart:1118-1121`（_calculateProgress 内 checklist 全量 + projects 再查）
  - `home_page.dart:795`（_HomeContent._loadData 又一次全表）
  - `home_page.dart:212`（_rescheduleTaskReminders 又一次全表）
  - 触发源：`tasks_page.dart:49`（initState 即 LoadTasks）、`home_page.dart:1274,1288`（BlocListener 链式 _loadData）、`home_page.dart:226`（syncAll 后 debounce LoadTasks）
- **类别**: 反模式3（全量加载）+ 反模式7（重复初始化/重复查询）
- **代码**:
  ```dart
  // task_bloc.dart:344
  final allTasks = (await taskRepository.getAll()) ...
  // home_page.dart:795 (_HomeContent._loadData)
  dbTasks = await widget.taskRepository!.getAll();
  // home_page.dart:212 (_rescheduleTaskReminders)
  final tasks = await taskRepository.getAll();
  ```
- **影响**: 高（任务量大时）。一次冷启动至少 3-4 次任务全表查询 + 全量 checklist 查询，全部跑在 UI isolate（见 W7），数据量上千时直接掉帧。无分页/无"首屏可见优先"。
- **建议**: 启动期共享一次查询结果（仓库层加短 TTL 内存缓存，或 LoadTasks 结果传给 reschedule/_loadData）；归档任务已分离（LoadArchivedTasks），保持；长期可按 filter 下推 SQL 条件而非内存过滤。

### W6. Drift 用 NativeDatabase 跑在 UI isolate

- **文件**: `lib/data/database/connection/connection_native.dart:7-14`
- **类别**: 反模式6（多端差异）/ 主线程阻塞
- **代码**:
  ```dart
  return LazyDatabase(() async {
    final file = await LocalDataService().databaseFile();
    ...
    return NativeDatabase(file);   // 非 createInBackground
  });
  ```
- **影响**: 中-高。所有 SQL（含 W5 的多次全表查询、v11 schema 迁移）都在主 isolate 同步执行，启动期数据库打开 + 迁移 + 全表查询直接吃首帧。老用户升级触发 onUpgrade（app_database.dart:153-203，v10 一次建 10 个索引）时首启更明显。
- **建议**: 改 `NativeDatabase.createInBackground(file)`，一行改动收益大。

### W7. NotificationService.init 在 runApp 前做时区全量初始化 + 通道删建

- **文件**: `lib/main.dart:119` → `lib/services/notification_service_io.dart:120-258`
- **类别**: 反模式2 + 反模式6（Android 通道、Windows 插件差异）
- **代码**:
  ```dart
  tz.initializeTimeZones();                  // 加载全量时区数据库，CPU 数十ms级
  await _configureLocalTimezone();           // FlutterTimezone 平台通道往返
  // Android: plugin.initialize + delete旧通道×2 + create通道
  // Windows: FlutterLocalNotificationsWindows().initialize(...)
  ```
- **影响**: 中。纯本地但 CPU+平台通道开销叠加在首帧前；通知只在"有提醒到点"时才真正需要。`initializeTimeZones` 可换 `latest_10y` 子集。
- **建议**: 移到首帧后初始化（HomePage._initStorage 里 `requestMobilePermissions` 之前本来就会再碰它）；用 `timezone/data/latest_10y.dart` 减少数据量。

### W8. main() 串行 await 链（可并行/可延后项混在关键路径）

- **文件**: `lib/main.dart:53-68`
- **类别**: 反模式1
- **代码**:
  ```dart
  await FileLogger.instance.clear();
  final logPath = await FileLogger.instance.filePath;
  if (!kIsWeb && isDesktop) await _initWindowManager();
  await themeController.load();
  final privacyAccepted = await PrivacyConsentPage.isAccepted();
  final deps = await _initServices();   // 内部 8 个 await 也全串行
  ```
- **影响**: 中。即使砍掉网络项，剩余本地 init 也全串行：FileLogger（磁盘）、SharedPreferences（theme/privacy/subscription 各自独立 await 同一实例）、Supabase.initialize、通知服务互不依赖。
- **建议**: 首帧真正需要的只有 theme + privacy 标记 +（桌面）窗口管理；`Future.wait([themeController.load(), PrivacyConsentPage.isAccepted(), Supabase.initialize(...)])`，FileLogger.clear/通知/闹钟/推送/会员/订阅全部首帧后。

### W9. FileLogger 启动期磁盘清理阻塞首帧

- **文件**: `lib/main.dart:53-54` → `lib/core/utils/file_logger_io.dart:16-73`
- **类别**: 反模式1（可延后）
- **代码**:
  ```dart
  await FileLogger.instance.clear();
  // 内部: getApplicationDocumentsDirectory → create dir →
  // _cleanOldLogs(): 遍历目录 list + 逐文件 stat + delete → 写 session 头
  ```
- **影响**: 中。日志多/磁盘慢时逐文件 stat+delete 在 runApp 前同步等待。flog 本身已有 500ms buffer，clear 没必要抢在最前。
- **建议**: `unawaited(FileLogger.instance.clear())` 或移到首帧后；清理旧日志放后台。

### W10. IndexedStack 一次性构建 4 个 tab，隐藏 tab 启动即发起各自加载

- **文件**: `home_page.dart:89,148-178,498`；`tasks_page.dart:45-49`；`calendar_page.dart:77-93`
- **类别**: 反模式8 + 反模式5
- **代码**:
  ```dart
  late final List<Widget> _pages = _buildPages();   // 4个tab全建
  ... IndexedStack(index: index, children: _pages)
  // tasks_page.dart:45  initState → context.read<TaskNewBloc>().add(LoadTasks());
  // calendar_page.dart:80  postFrame → _initRepos() → _reloadData() + _loadHolidaysForYears(网络)
  ```
- **影响**: 中。首帧要 build 4 棵子树；TasksPage（tab1，不可见）启动即派发 LoadTasks，CalendarPage（tab2，不可见）启动即全量 DB 加载 + 节假日 HTTP 请求。_HomeContent 自己有 `_visible` 守卫，其他 tab 没有。
- **建议**: 改懒加载 IndexedStack（未访问的 tab 用占位，首次切换时再 build），或给 TasksPage/CalendarPage 加与 _HomeContent 相同的 visibleTabIndex 守卫，首次可见时才加载。

### W11. HomePage 启动同步链：5 个 SyncService 串行 + 多入口重复 syncAll

- **文件**: `home_page.dart:104-115,180-193,217-279`
- **类别**: 反模式1 + 反模式4
- **代码**:
  ```dart
  Future<void> runSyncAll({bool forcePush = false}) async {
    await ProjectSyncService.instance.syncAll(forcePush: forcePush);
    await TaskSyncService.instance.syncAll();
    await ChecklistSyncService.instance.syncAll();
    await NodeTemplateSyncService.instance.syncAll();
    await AttachmentSyncService.instance.pullAll();
  ```
- **影响**: 中。虽不阻塞首帧（fire-and-forget），但启动后立即占满网络与 DB（UI isolate，见 W6），与首屏 LoadTasks 抢资源；`startIfReady` 在 `initialSession` auth 事件 + 直接调用两个入口都会跑，叠加 `_onAppResume` 的 forcePullAll，冷启动可能跑 2 遍全量对账。无整体超时。
- **建议**: 首帧 + 首屏数据上屏后再启动同步（延迟 1-2s）；独立服务间用 Future.wait；入口加 in-flight 去重。

### W12. _rescheduleTaskReminders 启动期全量重排通知

- **文件**: `home_page.dart:186-214`
- **类别**: 反模式3 + 反模式2
- **代码**:
  ```dart
  await notificationService.rescheduleScheduleReminders(_storage.getSchedules());
  await notificationService.rescheduleBreakdownTaskReminders(_storage.getTasks());
  final tasks = await taskRepository.getAll();   // 又一次全表
  await notificationService.rescheduleTaskReminders(tasks);
  ```
- **影响**: 中。_initStorage 启动链上执行；任务多时逐条 cancel/schedule 平台通道调用成本线性增长，且 `_setupProjectSyncOnAuth` 的 runSyncAll 完成后还会再排一遍（home_page.dart:227）。
- **建议**: 延后到首屏空闲（`SchedulerBinding.scheduleTask` idle 优先级）；与 syncAll 后的那次合并（已有 2s 节流 `_lastRescheduleTime`，但跨度不够）。

### W13. Web 端 WasmDatabase 首次打开开销 + 降级仅 print

- **文件**: `lib/data/database/connection/connection_web.dart:4-17`
- **类别**: 反模式6（多端差异）
- **代码**:
  ```dart
  final result = await WasmDatabase.open(
    databaseName: 'smart_assistant',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.dart.js'));
  if (result.missingFeatures.isNotEmpty) print('Drift web: degraded mode...');
  ```
- **影响**: 低-中（仅 Web）。LazyDatabase 把开销推迟到首次查询（即首屏 LoadTasks），wasm 下载+编译+worker 启动叠加在首批数据前。降级（如无 OPFS 退 IndexedDB/内存）只 print，用户无感知数据可能不持久。
- **建议**: Web 端在 runApp 后预热（`unawaited(database.customSelect('select 1').get())`）让 wasm 加载与首帧并行；missingFeatures 上报 flog 并必要时提示。

### W14. initTray 在 runApp 后立即 await，与首帧竞争

- **文件**: `main.dart:80-82` → `tray_service_desktop.dart:9-23`
- **类别**: 反模式1（可延后）
- **代码**:
  ```dart
  runApp(MyApp(...));
  if (!kIsWeb && isDesktop) {
    await initTray();   // waitUntilReadyToShow + setSkipTaskbar + initSystemTray
  ```
- **影响**: 低（仅桌面）。runApp 返回后同一事件循环继续执行托盘初始化的平台通道调用，可能挤占首帧调度。
- **建议**: `WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(initTray()))`。

### W15. SharedPreferences 多处独立串行 await（同一实例）

- **文件**: `main.dart:62`（theme）、`main.dart:65`（privacy）、`subscription_service.dart:167`、`local_storage_service.dart:18`
- **类别**: 反模式1 + 反模式7
- **影响**: 低。首次 getInstance 读盘后即缓存，但 theme 与 privacy 串行 await 两次（无依赖），可 Future.wait；纯整洁性优化。
- **建议**: 合并为一次 `Future.wait`。

---

## 三、汇总表（按影响排序）

| # | 弱点 | 位置 | 类别 | 影响 | 修复成本 |
|---|------|------|------|------|----------|
| W1 | runApp 前 await 会员配置 3 个网络请求，无超时无缓存 | main.dart:144 / member_config_service.dart:183 | 网络阻塞首帧 | 高 | 低（移到首帧后） |
| W2 | runApp 前 await 订阅刷新 2 个串行网络请求，且与登录后 refresh 重复 | main.dart:145 / subscription_service.dart:50 | 网络阻塞首帧 | 高 | 低 |
| W3 | runApp 前 await 阿里云推送 SDK 网络注册 + deviceId 上传 | main.dart:121 / aliyun_push_service_io.dart:29 | 网络阻塞首帧 | 高（Android） | 低 |
| W4 | 首批任务上屏前 await fetchPreferences 网络请求 | task_bloc.dart:328 | 首屏数据阻塞 | 高 | 中（本地优先+后台合并） |
| W5 | 启动窗口内 3-4 次任务全表 getAll + 多源重复 LoadTasks | task_bloc.dart:344 / home_page.dart:795,212 | 全量加载/重复查询 | 高（数据量大时） | 中 |
| W6 | NativeDatabase 跑在 UI isolate（含迁移与全表查询） | connection_native.dart:13 | 主线程阻塞 | 中-高 | 极低（createInBackground） |
| W7 | 首帧前全量时区初始化 + 通知通道删建 | notification_service_io.dart:124-258 | 重型服务过早初始化 | 中 | 低 |
| W8 | main() 全串行 await 链，本地 init 未并行 | main.dart:53-68 | 串行链 | 中 | 低（Future.wait） |
| W9 | FileLogger 启动期磁盘遍历清理阻塞 | main.dart:53 / file_logger_io.dart:32 | 可延后 IO | 中 | 低 |
| W10 | IndexedStack 全量建 4 tab，隐藏 tab 启动即加载（含节假日网络请求） | home_page.dart:148-178,498 / tasks_page.dart:49 / calendar_page.dart:80 | 首页全量构建 | 中 | 中（懒加载/可见性守卫） |
| W11 | 5 个 SyncService 启动串行全量对账，多入口可能跑 2 遍 | home_page.dart:220-279 | 启动期资源竞争 | 中 | 中 |
| W12 | 启动期全量重排通知（再一次全表 + 逐条平台通道） | home_page.dart:195-214 | 全量加载 | 中 | 低（延后到 idle） |
| W13 | Web wasm 数据库开销叠加在首批数据前；降级无提示 | connection_web.dart:4-17 | 多端差异 | 低-中（Web） | 低（预热） |
| W14 | initTray 在 runApp 后立即 await | main.dart:80-82 | 与首帧竞争 | 低（桌面） | 极低 |
| W15 | SharedPreferences 多处串行 await | main.dart:62-65 等 | 串行链 | 低 | 极低 |

### 推荐修复顺序（收益/成本比）

1. **W1+W2+W3**：把三个网络型 init 全部移出 `_initServices`，首帧后执行 —— 弱网白屏问题直接消失。
2. **W6**：`NativeDatabase.createInBackground` 一行改动。
3. **W4**：LoadTasks 本地优先，云偏好后台合并。
4. **W7+W8+W9+W15**：main() 关键路径瘦身为 theme+privacy+窗口+Supabase.initialize（可并行）。
5. **W5+W10+W12**：消重全表查询、tab 懒加载、通知重排延后。
6. **W11/W13/W14**：同步链节流、Web 预热、托盘延后。

## Caveats / Not Found

- 以上为静态代码追踪结论，未做实测计时（建议落地前用 `flutter run --profile` + Timeline 验证各段耗时，特别是 tz.initializeTimeZones 与 Supabase.initialize 的实际占比）。
- `Supabase.initialize` 内部行为（会话恢复是否含网络 token refresh）未深入 SDK 源码，默认本地恢复 + 后台刷新，列为低风险未单列。
- 旧 `TaskBloc` / `ScheduleBloc`（main.dart:219-225）因 BlocProvider 默认 lazy，未发现启动期实例化路径，不构成启动弱点。
- `LocalDataService().databaseFile()` 与 Windows 自定义数据目录逻辑未展开，若含目录扫描可能加重 W6 首查询，待实测。
