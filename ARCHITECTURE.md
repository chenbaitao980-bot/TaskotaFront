> 2026-06-06: 移动端提醒通知准时性优化。三层保障策略：本地通知(flutter_local_notifications + alarm包) → 服务端推送(微信WxPusher + FCM)。过期提醒合并为一条摘要通知，不再逐条触发。首次启动电池优化引导弹窗（品牌适配：小米/华为/OPPO/vivo/三星）。`NotificationService.rescheduleTaskReminders` 新增过期检测+合并摘要（`_showOverdueDigest`）。`WechatReminderService.scheduleServerPush` 注册服务端定时推送。`FcmService` 管理 FCM token 生命周期。`BatteryOptimizationGuide` 品牌检测+设置步骤引导。服务端需部署 `schedule-push`（定时推送调度）和 `register-fcm-token`（FCM token 注册）两个 Edge Function。

> 2026-06-05: 微信提醒模块（独立模块）。WxPusher 推送集成：`supabase/functions/_shared/wxpusher.ts` 封装 API；`wxpusher-callback` Edge Function 处理用户扫码关注回调写入 `wechat_bindings` 表；`wechat-binding` Edge Function 提供绑定状态查询/开关/解绑 REST API；`scan-wechat-reminders` Edge Function 由 pg_cron 每分钟触发，扫描所有已绑定用户的即将到期任务并调用 WxPusher 推送，`wechat_reminder_log` 表防重复。Flutter 端 `WechatReminderService` 封装 Edge Function 调用，`WechatBindingPage` 提供二维码扫码绑定/解绑/开关 UI，`app_settings_page` 新增"微信提醒"入口 ListTile。与现有 NotificationService/AlarmService 零耦合。

> 2026-06-04: MVP 上架准备（小米应用商店）。(1) Android 包名从 `com.example.smart_assistant` 更换为 `com.taskora.app`（build.gradle.kts namespace/applicationId + MainActivity.kt package + 目录迁移）。(2) Release 签名配置：`key.properties` + `signingConfigs.release`，debug 签名作为 fallback。(3) 代码混淆：release 启用 `isMinifyEnabled`/`isShrinkResources` + ProGuard 规则。(4) 首次启动隐私合规弹窗：`PrivacyConsentPage` 在用户同意前阻止 Supabase 初始化和任何网络请求。(5) 登录页新增协议勾选框（与注册页对齐），协议文字可点击查看全文。(6) 全局错误捕获：`main()` 用 `runZonedGuarded` 包裹 + `FlutterError.onError` 记录日志，未捕获异常不再白屏。(7) 隐私政策和用户协议内置文本，包含第三方 SDK 披露（Supabase/DeepSeek/Google Fonts）。

> 2026-06-10: 父任务时间自动跟随子任务。TaskRepository 新增 expandAncestorDates (DB查询版) + hasChildren。calendar_page 拖拽子任务后调 expandAncestorDates 补漏。task_bloc 内联 logic 迁移至 repo。task_detail_page：父任务时间 chip 只读（灰色+ "子任务"标注），项目 chip 仅最上级可编辑，新增"父任务"badge。

> 2026-06-10: Markdown 编辑器升级为全屏编辑器（MarkdownEditorPage）。点击"编辑"不再内嵌展开，改为 Navigator.push 全屏页面，提供大编辑区（expands:true 填满屏幕）、工具栏、预览切换、图片粘贴（Ctrl+V 智能检测剪贴板：有图上传附件、有文字插入光标）、拖拽上传（DropTarget）。MarkdownDescriptionSection 新增 onEnterEdit 回调，由父级决定编辑方式。原有 _pasteDescriptionImage / _readClipboardPng / _saveDescriptionImageBytes 移至编辑器页，task_detail_page 移除 CallbackShortcuts 避免拦截原生粘贴。

> 2026-06-10: 跨端任务消失修复。三处改动：(A) syncAll push 循环墓碑防护 — 本地 `deleted=1` 且远端存活时跳过推送；(B) `_onDeleteTask` 删除后即时 `push()` 上云，不依赖 syncAll 传播；(C) 项目级联软删任务改用远端 `updated_at` 而非 local `now`。根因：项目级联用 local now → cascaded 墓碑时间戳 > 远端活任务 → syncAll 推送墓碑覆盖云端 → 传染全部设备。

> 2026-06-10: 任务详情描述区域新增 Markdown 编辑器（MarkdownDescriptionSection）。折叠态用 flutter_markdown 渲染预览，展开态提供工具栏+编辑器+可选分栏预览。工具栏支持 H1-H3/加粗/斜体/删除线/列表/引用/代码/链接/表格/分割线。数据层无变更，description 仍存纯文本。

> 2026-06-09: 修复新建任务后卡顿/消失。五处改动：(A) 新建任务 `syncImmediately: true` 立即上云；(B) syncAll 失败不 rollback；(D) 通知重调度加 2s 节流；(E) _taskChangesSub 中去掉 _rescheduleTaskReminders 断连锁反应；(I) 创建新任务时自动将其 projectId 纳入过滤，未选项目时任务不被隐藏。根因：syncAll 失败→rollback→任务本地消失 / 通知调度→LoadTasks 连锁刷新风暴 / 未选项目→projectId='inbox'→被当前项目过滤排除。

> 2026-06-04: 退出APP后提醒不生效修复。重复提醒从Timer改为预调度未来24h内最多20次独立通知（AlarmManager+alarm包双保险）；AlarmService不再依赖精确闹钟权限；APP恢复前台时自动重新调度所有提醒；新增BatteryOptimizationService通过MethodChannel引导用户关闭Android电池优化（国产ROM必要）；设置页新增电池优化状态和入口。

> 2026-06-05: 任务编辑冲突检测。新增 `TaskConflictService`（`lib/services/task_conflict_service.dart`）统一冲突检测/延后计算/自动插入逻辑，新增 `showTaskConflictDialog()`（`lib/presentation/widgets/task_conflict_dialog.dart`）统一冲突弹窗。`TaskDetailPage`、`TaskEditPage`、`MindMapView._editSingleDate()` 三个编辑入口修改时间后触发冲突检测，行为与创建任务一致。`UpdateTask` 事件新增 `shiftedTasks` 参数，Bloc 中批量更新被移位的任务。`task_create_sheet.dart` 改用公共工具。

> 2026-06-05: 首页逾期判定增加小时级精度。紧凑统计栏逾期改用 now 比较（总逾期）；详情弹窗拆分为逾期(天)/逾期(小时)/总逾期三个可点击指标；_showOverdueSheet 增加 mode 参数支持按天/小时/总计过滤。

> 2026-06-05: 首页描述框新增粘贴/拖拽图片功能。_buildDescriptionBox 包裹 CallbackShortcuts(Ctrl+V) + DropTarget，新增 _pasteHomeDescriptionImage / _readClipboardPng / _handleDroppedHomeDescriptionImages 三个方法，复用 TaskAttachmentService.saveImageBytes。

> 2026-06-05: 修复 migration from<9 重复添加 is_template 列导致启动崩溃。addColumn 包裹 try-catch，捕获 duplicate column name 后忽略，使 migration 幂等。
>
> 2026-06-04: 首页新建日程改为底部弹出对齐任务模块，任务模块新增提醒设置。CreateScheduleDialog 从 AlertDialog 重写为 BottomSheet 风格（拖拽手柄、OutlineInputBorder、showCalendarDatePicker）；TaskCreateSheet 新增提醒开关+提前时间；TaskRepository.create / CreateTask 事件 / 全部调用方同步传递 remindBeforeMinutes / reminderEnabled。

> 2026-06-03: 修复通知BUG：已删/已完成任务仍弹通知。NotificationService.rescheduleTaskReminders 防御过滤 deleted/status；TaskNewBloc._onDeleteTask/_onToggleTaskStatus 主动取消 OS 通知；旧版 task_detail_page 同步修复。
> 2026-06-03: 移动端提醒彻底修复。alarm_service 使用 assets/audio/alarm.wav 实现闹钟式响铃（loopAudio=true, volume=0.8, androidFullScreenIntent=true）；notification_service 时区配置修正为直接使用 FlutterTimezone 返回的 String；home_page 启动时主动请求通知权限后再调度提醒；app_settings_page 权限授权后全量重调度含 Task 表提醒。
> 2026-06-03: 修复完成后任务进度未显示100%问题。TaskProgressCalculator._leafTally 当 status==2 时直接返回 (1,1)，忽略检查项未完成状态，使进度与 completeEligibleAncestors 自动完成逻辑一致。同步修正 task_progress_calculator_test.dart 中 5 个预失败测试的 projectProgress 期望值。
> 2026-06-03: 修复项目不同步根因（Supabase 缺 is_template 列导致 pushProject upsert 静默失败）+ 移动端提醒 3 bug + AppLifecycleListener 前台自动对账。

# Architecture

> 2026-06-02: 浠诲姟妯″潡鏂板鈥滄ā鏉胯妭鐐光€濄€俙AppDatabase` 鏂板鏈湴 `node_templates` Drift 琛紝瀛楁鍖呭惈妯℃澘鍚嶇О銆佽妭鐐规爣棰樸€佹弿杩般€佷紭鍏堢骇銆佹鏌ラ」 JSON銆佸浘鐗?JSON銆佸瓙浠诲姟 JSON銆佽蒋鍒犻櫎鍜屽垱寤?鏇存柊鏃堕棿锛沗NodeTemplateRepository` 璐熻矗鏈湴 CRUD 涓?JSON 缂栬В鐮侊紝`NodeTemplateSyncService` 閫氳繃 Supabase `node_templates` 琛ㄥ仛鐧诲綍鐢ㄦ埛缁村害鐨勫叏閲忓璐﹀拰 Realtime 璁㈤槄銆俙main()` 鍒濆鍖栧苟缁戝畾妯℃澘浠撳簱锛宍HomePage` 鍦ㄧ櫥褰曞悗鐨勯」鐩?浠诲姟/娓呭崟/闄勪欢鍚屾閾捐矾涓悓鏃舵墽琛屾ā鏉垮悓姝ャ€俙TasksPage` AppBar 鏂板鈥滄ā鏉胯妭鐐光€濆叆鍙ｏ紝`NodeTemplatesPage` 缁存姢妯℃澘锛沗TaskCreateSheet`銆佹棩鍘嗘柊寤哄叆鍙ｃ€佷换鍔￠〉鏂板缓鍏ュ彛鍜岃鎯呴〉瀛愪换鍔″叆鍙ｅ潎鍙€夋嫨澶嶇敤妯℃澘锛屽鐢ㄥ悗鍦?`CreateTask` 鎻愪氦闃舵濉厖鎻忚堪銆佹鏌ラ」銆佹ā鏉垮浘鐗囧拰瀛愪换鍔℃爲銆傛棫 `CreateTaskPage` 浠嶈蛋 `LocalStorageService` 鏈湴浠诲姟妯″瀷锛屽彧澶嶇敤妯℃澘鏍囬銆佹弿杩般€佷紭鍏堢骇鍜屽瓙浠诲姟銆?
> 2026-06-02: 棣栭〉鏃堕棿杞存柊澧炲綋鍓嶆椂闂村畾浣嶈兘鍔涖€俙HomePage` 鐨勬椂闂磋酱澶撮儴鏂板瀹氫綅鎸夐挳锛屽皬鏃舵ā寮忔寜褰撳墠灏忔椂/鍒嗛挓婊氬姩锛屽ぉ妯″紡鎸変粖澶╂粴鍔紱椤甸潰鍔犺浇鍚庡拰灏忔椂/澶╂ā寮忓垏鎹㈠悗榛樿瀹氫綅鍒板綋鍓嶆椂闂寸偣锛屼笉鍐嶅湪澶╂ā寮忎笅浼樺厛璺虫渶杩戜换鍔°€?> 2026-06-02: 棣栭〉绛涢€夌姸鎬佹墿灞曚负鍙悓姝ュ亸濂姐€俙LocalStorageService.home_filter_project_ids` 浠庡崟涓€椤圭洰 ID 鍒楄〃鍏煎鍗囩骇涓哄寘鍚?`projectIds`銆乣nodeTypes`銆乣completion` 鐨勯椤电瓫閫夌姸鎬侊紱`SupabaseService.syncPreferences()` 鏀逛负璇诲彇鐜版湁 `app_preferences_sync.preferences_data` 鍚庡悎骞跺啓鍏ワ紝閬垮厤浠诲姟椤电瓫閫夊拰棣栭〉绛涢€変簰鐩歌鐩栥€俙HomePage` 棣栨鍔犺浇鏃朵紭鍏堟仮澶嶄簯绔?`homeFilters`锛屾湰鍦扮姸鎬佷綔涓哄吋瀹瑰洖閫€銆?> 2026-06-02: 椤圭洰杩涘害鎸夋湯浣嶄换鍔″拰妫€鏌ラ」鐪熷疄璁℃暟銆俙TaskProgressCalculator` 瀵规病鏈夊瓙浠诲姟鐨勪换鍔¤鍏ヤ竴涓换鍔″伐浣滈噺锛屽苟棰濆璁″叆璇ヤ换鍔℃鏌ラ」锛涙湁瀛愪换鍔＄殑浠诲姟涓嶈鍏ョ埗浠诲姟鑷韩锛屼粎璁″叆鑷韩妫€鏌ラ」鍜岄€掑綊瀛愭爲銆傞」鐩?鍒嗙粍杩涘害鐩存帴绱姞鏍逛换鍔￠€掑綊 tally锛屼笉鍐嶆妸姣忎釜鏍逛换鍔℃姌绠椾负鍚屾潈閲?100 鍒嗐€?> 2026-06-02: 瀛愪换鍔″畬鎴愬悗鐨勭埗浠诲姟鑷姩瀹屾垚閫昏緫涓嬫矇鍒?`TaskRepository`銆俙toggleStatus()` 鍜?`setStatusCascade()` 鍦ㄤ换鍔″彉涓哄畬鎴愬悗璋冪敤 `completeEligibleAncestors()`锛屽綋鐖朵换鍔＄殑鍏ㄩ儴鐩存帴瀛愪换鍔″潎涓哄畬鎴愮姸鎬佹椂鑷姩瀹屾垚鐖朵换鍔★紝骞剁户缁悜绁栧厛妫€鏌ャ€?> 2026-06-02: 棣栭〉浠诲姟璇︽儏鍥剧墖鍖哄鐢ㄩ檮浠舵湇鍔″寮轰氦浜掋€俙AttachmentImageStrip` 鏀寔鍙€夊垹闄や笌澶嶅埗鍥剧墖鍒扮郴缁熷壀璐存澘锛涢椤?DB 浠诲姟璇︽儏鍥剧墖鏉″紑鍚垹闄?澶嶅埗锛屽苟閫氳繃 `desktop_drop` 鎺ユ敹鎷栧叆鍥剧墖鍚庤皟鐢?`TaskAttachmentService.saveImageBytes()` 淇濆瓨涓轰换鍔￠檮浠躲€?> 2026-06-02: 涓汉椤垫柊澧炲彧璇昏繍缁村悗鍙板叆鍙ｃ€俙AdminOpsPage` 灞曠ず褰撳墠鐧诲綍鐢ㄦ埛銆佷换鍔?椤圭洰/妫€鏌ラ」/闄勪欢鏁伴噺銆佹渶鏂颁换鍔℃洿鏂版椂闂寸瓑褰撳墠璐﹀彿鍙闂殑鐪熷疄鏁版嵁锛涘叏閲忕敤鎴风鐞嗐€佽法鐢ㄦ埛鏁版嵁鏌ヨ鍜屽璁?澶囦唤/瀵嗛挜杞崲鏍囪涓哄繀椤婚€氳繃鏈嶅姟绔?Supabase Admin API 鎴?Edge Function 鎵ц锛屽鎴风涓嶄繚瀛?PAT 鎴?service_role銆?
> 2026-06-02: 瀛愪换鍔″垱寤哄悗鐖朵换鍔℃椂闂磋法搴﹁嚜鍔ㄨ鐩栧瓙浠诲姟銆俙TaskNewBloc._onCreateTask` 鍦ㄦ柊浠诲姟钀藉簱鍚庤皟鐢?`_expandAncestorDatesForTaskId()`锛屽熀浜?`TaskRepository.getAll()` 璇诲彇鏈€鏂颁换鍔￠泦鍚堝苟澶嶇敤 `_expandAncestorDates()` 鍚戜笂鎵╁睍鐖堕摼 `startDate/dueDate`锛沗CreateTask.shiftedTasks` 鑷姩鎻掑叆椤哄欢宸叉湁瀛愪换鍔″悗涔熼€愪釜瑙﹀彂鍚屼竴鎵╁睍閫昏緫銆傛湭鏂板鏁版嵁搴撳瓧娈点€佷粨搴?API 鎴?BLoC 浜嬩欢銆?
> 2026-06-02: 棣栭〉灏忔椂缁村害鏃堕棿杞村瓙浠诲姟鎷栨嫿瑙﹀彂鍖轰紭鍖栥€俙HomePage` 鐨勬椂闂磋酱浠诲姟 overlay 缁х画鍙厑璁?DB 鏉ユ簮銆乣parentId != null`銆佹湁 `endDate` 涓旈潪璺ㄥぉ鐨勫皬鏃舵ā寮忎换鍔℃嫋鎷斤紱瑙﹀彂灞傜敱鎵嬪啓 `GestureDetector.onLongPress*` 鏀逛负 `LongPressDraggable`锛屽浐瀹氶€忔槑鍛戒腑鍖轰负 56px x 36px锛岄暱鎸?delay 涓?300ms锛屾嫋鎷戒粎鎺ュ彈涓婚敭/宸﹂敭銆傛嫋鎷戒綅绉婚€氳繃 `onDragUpdate.delta.dx` 绱Н鍚庢寜 `_hourWidth` 鍚搁檮鍒版暣灏忔椂锛屾澗鎵嬩粛娲惧彂鏃㈡湁 `TaskNewBloc.UpdateTask(startDate, dueDate)`锛屾湭鏂板鏁版嵁搴撳瓧娈点€佷粨搴?API 鎴?BLoC 浜嬩欢銆?
> 2026-06-02: Taskora 鍛藉悕缁х画琛ラ綈鍒扮敤鎴峰彲瑙佸叆鍙ｃ€俉indows/Android/妯℃嫙鍣ㄦ瀯寤鸿剼鏈爣棰樹娇鐢?`Taskora`锛學indows 鎵撳寘鑴氭湰杈撳嚭鐩綍鏀逛负 `Taskora_windows_release`锛沇eb manifest 鐨?`name`銆乣short_name` 鍜屾弿杩版敼涓?Taskora锛汻EADME 鏍囬涓庣畝浠嬨€乄indows 閫氱煡娴嬭瘯鑴氭湰鏄剧ず鍚嶃€丼upabase SQL 鑴氭湰娉ㄩ噴鍚屾涓?Taskora锛涘叧浜庨〉鏍囬鍜屾湰鍦伴粯璁ゆ杩庢棩绋嬫爣棰樹篃鍚屾涓?Taskora銆傚彂甯冭崏绋裤€丱penSpec 鐘舵€佹憳瑕佸拰 PDF 鐢熸垚鑴氭湰婧愭枃浠朵腑鐨勪骇鍝佸悕涔熸敼涓?Taskora銆侱art 鍖呭悕銆佹暟鎹簱鏂囦欢鍚嶅拰 Android applicationId 鏈鏈敼鍔ㄣ€?
> 2026-06-02: 妗岄潰绔彁閱掑惎鍔ㄦ仮澶嶄慨澶嶃€俙HomePage._rescheduleTaskReminders()` 鍦ㄦ湰鍦板瓨鍌ㄥ垵濮嬪寲銆佺櫥褰曞悗鍏ㄩ噺鍚屾銆侀」鐩?浠诲姟鍙樻洿璁㈤槄鍒锋柊鍚庣粺涓€鎭㈠鎻愰啋锛涙仮澶嶈寖鍥村寘鎷?`LocalStorageService.getSchedules()` 鐨勬湰鍦版棩绋嬨€乣LocalStorageService.getTasks()` 鐨勬棫鏈湴浠诲姟锛屼互鍙?`TaskRepository.getAll()` 鐨?Drift 浠诲姟銆俙NotificationService.rescheduleTaskReminders()` 涓嶅啀璺宠繃妗岄潰绔紝妗岄潰绔户缁€氳繃杩涚▼鍐?`Timer` 瑙﹀彂 Windows/macOS/Linux 閫氱煡锛涙柊澧?`rescheduleScheduleReminders()`銆乣rescheduleBreakdownTaskReminders()` 鍜?`shouldRescheduleReminder()`锛屽叧闂彁閱掋€佹棤寮€濮嬫椂闂淬€佸凡杩囨湡鐨勪竴娆℃€ф彁閱掍笉浼氶噸鎺掞紝宸茶繃鏈熶絾浠嶅惎鐢ㄧ殑閲嶅鎻愰啋浼氶噸鎺掋€?
> 2026-06-02: 棣栭〉浠诲姟璇︽儏鎻忚堪鍖烘敼涓虹洿鎺ョ紪杈戙€俙HomePage._buildDescriptionBox` 涓嶅啀娓叉煋鍙鎴柇鏂囨湰锛岃€屾槸浣跨敤澶氳 `TextFormField` 灞曠ず瀹屾暣鎻忚堪锛涜緭鍏ュ彉鍖栭€氳繃 600ms 闃叉姈璋冪敤 `_saveDescription()` 淇濆瓨銆侱B 鏉ユ簮浠诲姟璧版棦鏈?`TaskRepository.update(description:)`锛屾棫鏈湴 `TaskBreakdown` 鏉ユ簮浠诲姟璧?`LocalStorageService.updateTask(copyWith(description: ...))`锛涙洿鏂板悗鍚屾鍒锋柊棣栭〉鍐呭瓨涓殑 `_TimelineTask.description` 鍜屽綋鍓嶉€変腑浠诲姟锛屼笉鏂板鏁版嵁搴撳瓧娈点€佷粨搴?API 鎴?BLoC 浜嬩欢銆?
> 2026-06-02: 棣栭〉鏃堕棿杞撮暱浠诲姟灞曠ず鏀逛负鎸夎捣姝㈣寖鍥存覆鏌撱€俙HomePage` 鐨勬椂闂磋酱婊氬姩鍖虹敱姣忓垪鍐呴儴浠诲姟鐐规敼涓虹粺涓€鍧愭爣 `Stack`锛氬皬鏃舵ā寮忎笅锛屽悓鏃ヤ换鍔＄粨鏉熸椂闂磋法鍑哄紑濮嬪皬鏃舵Ы鏃舵寜寮€濮嬪垎閽熷埌缁撴潫鍒嗛挓缁樺埗浼樺厛绾ч鑹茬鐘舵潯锛涘ぉ妯″紡涓嬶紝璺ㄥぉ浠诲姟鎸夊紑濮?缁撴潫鏃ユ湡缁樺埗璺ㄦ棩绠姸鏉★紱鏅€氱煭浠诲姟浠嶆樉绀哄渾鐐广€備换鍔￠€変腑銆佸彸閿垹闄ゃ€佽妭鐐圭被鍨嬬瓫閫夊拰宸叉湁灏忔椂妯″紡闀挎寜鎷栧姩浠嶅鐢ㄥ師浠诲姟浜や簰锛屼笉鏂板鏁版嵁搴撳瓧娈点€佷粨搴?API 鎴?BLoC 浜嬩欢銆傚綋鍓?`codegraph/graphify` MCP 宸ュ叿鏈湪鏈細璇濇毚闇诧紝鏈鎸夊彧璇诲畾浣嶇粨鏋滃仛鏈€灏忚寖鍥翠慨鏀广€?
> 2026-06-02: 浠诲姟妯″潡鏂板瀹屾垚鐘舵€佺瓫閫夈€俙LoadTasks.statusFilter` 鍜?`TaskNewLoaded.selectedStatusFilter` 璁板綍 `all`銆乣pending`銆乣completed` 涓夋€侊紱`TaskNewBloc._onLoadTasks` 鍦ㄩ」鐩€佷粖澶?閲嶈鍜屾棩鏈熺瓫閫変箣鍚庡啀鎸?`Task.status` 杩囨护锛岄粯璁?`all` 淇濇寔鍘熸湁鍏ㄩ儴浠诲姟鏄剧ず銆俙TasksPage` AppBar 鏂板浠诲姟鐘舵€佽彍鍗曟寜閽紝鍒囨崲鏃朵繚鐣欏綋鍓嶉」鐩€佹棩鏈熷拰浠诲姟绫诲瀷绛涢€夛紱鏁版嵁搴撶粨鏋勩€佷换鍔″畬鎴愬啓鍏ュ拰浜戠鍚屾閾捐矾鏈敼鍔ㄣ€?
> 2026-06-02: 鏃ュ巻鍛ㄨ鍥惧崟鏃ヤ换鍔″潡骞惰甯冨眬鏀逛负鎸夐噸鍙犳椂闂寸皣鍒嗛厤 lane銆俙CalendarPage._buildTaskBlocksForDay` 涓嶅啀鐢ㄦ暣澶╂渶澶у苟琛屾暟鍘嬬缉鎵€鏈夊崟鏃ヤ换鍔″潡锛岃€屾槸璋冪敤 `day_task_lane_layout.dart` 涓殑 `assignDayTaskLanes()`锛屼粎鍦ㄥ悓涓€杩炵画閲嶅彔缁勫唴鍏变韩瀹藉害锛涢灏剧浉鎺ョ殑鏃堕棿娈典粛浣跨敤鏁村垪瀹藉害銆傞《閮ㄨ法澶╀换鍔℃潯銆佷换鍔℃暟鎹ā鍨嬨€丅loc銆佷粨搴撳拰鎺掔▼閫昏緫鏈敼鍔ㄣ€?
> 2026-06-02: 浠诲姟璇︽儏缂栬緫椤垫鏌ラ」涓庡浘鐗囦笂浼犲井璋冦€俙TaskDetailPage` 鍦ㄤ换鍔¤鎯呬富浣撳竷灞€涓负 `ChecklistSection` 鎻愪緵鏇撮珮鐨勬渶澶ч珮搴﹀拰鏈€灏忓睍绀洪珮搴︼紱`ChecklistSection` 鏆撮湶 `maxListHeight` 鍙傛暟锛岄粯璁ゅ€间繚鎸?320锛屽洜姝ら椤电瓑鍏跺畠澶嶇敤澶勪笉鍙樸€俙AttachmentSection` 鏍囬鏍忔柊澧炲浘鐗囦笂浼犳寜閽紝璋冪敤鏃㈡湁 `TaskAttachmentService.pickImageFile()` 涓?`saveAttachment()` 淇濆瓨涓轰换鍔￠檮浠讹紱鍘熸湁浠绘剰鏂囦欢涓婁紶鍏ュ彛銆侀檮浠惰〃缁撴瀯鍜屽悓姝ラ摼璺湭鏀瑰姩銆?
> 2026-06-02: 浠诲姟璇︽儏瀛愪换鍔℃爲鍒锋柊淇濈暀鐢ㄦ埛灞曞紑鐘舵€併€俙TaskNewBloc._onLoadSubTree` 鍒锋柊 `subTrees[rootTaskId]` 鍚庝笉鍐嶆棤鏉′欢鎶?`expandedNodes[rootTaskId]` 閲嶇疆涓烘墍鏈変竴绾у瓙浠诲姟锛涘凡鏈夊睍寮€闆嗗悎鏃朵粎淇濈暀浠嶅瓨鍦ㄤ簬鏈€鏂?descendants 鐨勮妭鐐?ID锛岄娆″姞杞借鏍逛换鍔″瓙鏍戞椂缁х画榛樿灞曞紑涓€绾у瓙浠诲姟銆俙LoadSubTree`銆乣ToggleTreeNode`銆乣TaskNewLoaded.expandedNodes` 澶栭儴浜嬩欢鍜岀姸鎬佸瓧娈垫湭鏀瑰姩銆?
> 2026-06-02: Windows 妗岄潰绔獥鍙ｆ爣棰樺拰鍙墽琛屾枃浠跺悕缁熶竴涓?`Taskora`銆俙windows/runner/main.cpp` 浣跨敤 `Taskora` 鍒涘缓绐楀彛骞舵煡鎵惧凡鏈夊疄渚嬶紝鍗曞疄渚嬩簰鏂ュ悕鏀逛负 `Taskora_SingleInstance`锛沗windows/CMakeLists.txt` 鐨?`project` 涓?`BINARY_NAME` 鏀逛负 `Taskora`锛屾瀯寤轰骇鐗╂枃浠跺悕鍙樹负 `Taskora.exe`锛沗windows/runner/Runner.rc` 鐨?`InternalName` 涓?`OriginalFilename` 鍚屾涓?`Taskora` / `Taskora.exe`銆?
> 2026-06-01: Taskora 澶氶」浠诲姟浣撻獙淇銆備换鍔¤鎯呬笌棣栭〉璇︽儏澶嶇敤 `TaskAttachmentService` 鍜?`AttachmentImageStrip` 鏄剧ず鍥剧墖闄勪欢锛屼换鍔¤鎯呮弿杩板尯鍙€氳繃 `pickImageFile()` 涓婁紶鍥剧墖闄勪欢锛沗ChecklistSection` 澧炲ぇ琛岄珮銆佸嬀閫夊湀鍜岃緭鍏ュ尯锛屽苟鍦ㄥ妫€鏌ラ」鏃朵娇鐢ㄥ眬閮ㄦ粴鍔ㄦ潯銆俙TaskCreateSheet` 澧炲姞椤圭洰鍒嗙粍/椤圭洰涓ょ骇閫夋嫨鍜屽脊绐楀唴鍒涘缓鍒嗙粍/椤圭洰鑳藉姏锛岀埗浠诲姟鍊欓€夌敱浼犲叆浠诲姟闆嗗悎缁撳悎褰撳墠椤圭洰绛涢€夌敓鎴愶紝璺ㄥ懆鏈熶换鍔′笉鍙備笌鏂板缓浠诲姟鍐茬獊妫€娴嬨€俙TaskNewBloc.ToggleTaskStatus` 鏀寔 `cascadeChildren`锛宍TaskRepository.setStatusCascade()` 璐熻矗鐖朵换鍔″畬鎴愭椂绾ц仈瀛愪换鍔★紱绉诲姩鐖朵换鍔℃椂瀛愪换鍔￠」鐩悓姝ュ埌鏂扮埗浠诲姟椤圭洰锛屽苟娌跨敤浠撳簱宸叉湁鍚庝唬椤圭洰绾ц仈銆俙CalendarPage` 鍙嶈浆 Ctrl+榧犳爣婊氳疆缂╂斁鏂瑰悜锛岀Щ鍔ㄧ鍛ㄨ鍥鹃粯璁?3 澶╋紝骞舵仮澶嶅彸閿姩浣滆彍鍗曘€俙HomePage` 鍒囨崲椤圭洰鍚庨€夋嫨褰撳墠绛涢€夊唴鏈€杩戜换鍔¤鎯咃紝鏃犱换鍔℃椂娓呯┖璇︽儏锛涘唴閮ㄦ粴鍔ㄥ尯浠呭湪榧犳爣鎸変笅鍚庢嫤鎴粴杞€俙TaskDecompositionService` 涓庤鎯呴〉 AI 鎷嗗垎鍏ュ彛澧炲姞瑙勮寖鍖栨爣棰樻寚绾瑰拰鍒涘缓鍓嶄簩娆″幓閲嶃€俙NotificationService` 鍦ㄨ皟搴﹀墠纭繚鍒濆鍖栵紝Windows 鏅€氭彁閱掍紭鍏堜娇鐢?Taskora 鍘熺敓閫氱煡锛屼笉鍐嶈蛋 MessageBox 璺緞銆傚簲鐢ㄦ樉绀哄悕宸插湪 Flutter 甯搁噺鍜?Android/iOS/macOS/Linux/Windows 鍚姩閰嶇疆涓敼涓?`Taskora`銆?
> 2026-06-01: 棣栭〉灏忔椂缁村害鏃堕棿杞存敮鎸佸瓙浠诲姟鐐归暱鎸夋í鍚戞嫋鍔ㄣ€俙HomePage` 鐨?`_buildTaskDots` 浠呭 DB 鏉ユ簮銆乣parentId != null`銆佹湁 `endDate`銆侀潪璺ㄥぉ涓斿綋鍓嶄负灏忔椂妯″紡鐨勪换鍔＄偣缁戝畾闀挎寜鎷栧姩锛涙嫋鍔ㄦ寜 `_hourWidth` 鎹㈢畻涓烘暣灏忔椂鍋忕Щ锛屽苟閫氳繃 `_clampedHourShift` 淇濊瘉绉诲姩鍚庣殑寮€濮?缁撴潫鏃堕棿浠嶅湪鍘熸棩鏈熷唴銆傛澗鎵嬪悗娲惧彂 `TaskNewBloc.UpdateTask` 鏇存柊 `startDate` 鍜?`dueDate`锛屽鐢ㄦ棦鏈夌埗浠诲姟鏃ユ湡鎵╁睍涓庝换鍔″埛鏂伴摼璺紝涓嶆柊澧炴暟鎹簱瀛楁銆佷粨搴?API 鎴?BLoC 浜嬩欢銆?
> 2026-06-01: 瀛愪换鍔″垱寤虹殑鍐茬獊妫€娴嬨€佽嚜鍔ㄥ欢鍚庡拰鑷姩鎻掑叆缁熶竴鍙妸 `parentId != null` 鐨勬湭瀹屾垚銆佹湭鍒犻櫎銆侀潪璺ㄥぉ瀛愪换鍔′綔涓烘椂闂村崰鐢ㄣ€俙TaskCreateSheet` 閫氳繃 `isSubtaskTimingOccupantForTaskCreateSheet` 杩囨护浼犲叆 `SubtaskScheduler` 鐨勪换鍔￠泦鍚堬紝鐖朵换鍔°€佹櫘閫氭牴浠诲姟鍜岃法澶╅暱鏉′笉鍐嶉樆濉炲瓙浠诲姟鎺掔▼锛沗SubtaskScheduler` 鏈韩浠嶄繚鎸侀€氱敤鎺掔▼鑳藉姏銆?
> 2026-06-01: 鏃ュ巻鍛ㄨ鍥鹃《閮ㄥ鏃ヤ换鍔℃í鏉℃敮鎸佹姌鍙犲睍寮€銆俙CalendarPage` 閫氳繃 `_isMultiDayLaneCollapsed` 鎺у埗 `_buildMultiDayLane` 鐨勫睍绀虹姸鎬侊細灞曞紑鏃朵繚鐣欏師鏈夋渶澶?6 琛屽彲绾靛悜婊氬姩妯潯鍜屽彸涓婃姌鍙犳寜閽紱鎶樺彔鏃堕殣钘忔墍鏈夋í鏉★紝浠呬繚鐣?30px 楂樼殑灞曞紑鎸夐挳琛屽苟鏄剧ず璺ㄥぉ浠诲姟鏁伴噺銆備换鍔℃ā鍨嬨€佷粨搴撱€丅loc銆佹帓绋嬪拰 `_isMultiDayTask` 鍒ゅ畾閫昏緫鏈敼鍔ㄣ€?
> 2026-06-01: 浠诲姟椤典换鍔″彉鏇撮摼璺敼涓烘湰鍦颁箰瑙傚埛鏂般€俙TaskNewBloc` 鍦ㄥ垱寤恒€佹洿鏂般€佸垹闄ゃ€佸畬鎴愬垏鎹€佺Щ鍔ㄧ埗鑺傜偣鍜屽悓绾ф帓搴忔椂鍏堟墽琛屾湰鍦?Drift 鍐欏叆骞跺埛鏂板綋鍓?`TaskNewLoaded`锛屽啀璋冪敤 `TaskSyncService.syncAll(rethrowErrors: true)` 鍋氫簯绔璐︼紱鍚屾澶辫触鏃堕€氳繃 `TaskRepository.restoreRawTasks()` 鎭㈠浠诲姟琛ㄥ揩鐓э紝骞跺湪浠诲姟椤垫彁绀衡€滃悓姝ュけ璐ワ紝宸插洖閫€鏈鎿嶄綔鈥濄€俙TaskRepository` 鐨勪换鍔″啓鍏ユ柟娉曚繚鐣欓粯璁ゅ嵆鏃跺悓姝ヨ涓猴紝鍚屾椂鏂板 `syncImmediately` 鍙€夊弬鏁颁緵浠诲姟椤佃烦杩囧崟琛?push銆?> 2026-06-01: 鐎电厧鍤粵娑⑩偓澶夋叏濮濓絻鈧倵鈧粌鍙忛柈銊┿€嶉惄顔光偓婵嗩嚤閸戠儤妞?`TaskExportPage` 閸?`TaskExportService` 娴肩姷鈹栨い鍦窗闂嗗棗鎮庣悰銊с仛娑撳秵瀵滄い鍦窗鏉╁洦鎶ら敍灞芥礈濮濄倓绱伴崠鍛儓 `tasks.projectId` 娑撳秴婀ぐ鎾冲妞ゅ湱娲伴崚妤勩€冩稉顓犳畱閳ユ粍婀崚鍡涘帳/閺堫亜灏柊宥夈€嶉惄顔光偓婵呮崲閸斺槄绱遍張宥呭缂佈呯敾鐏忓棜绻栫猾璁虫崲閸斺€冲晸閸忋儳瀚粩瀣畱閺堫亜灏柊宥夈€嶉惄?Sheet閵?
> 2026-06-01: 閹繄娣€电厧娴橀弬鏉款杻閼哄倻鍋ｆ潻鐐靛殠閸旂喕鍏橀妴淇檁MindMapNodeCard` 閻?`+` 閹稿鎸抽梹鎸庡瘻鐟欙箑褰?`onConnectStart/Update/End/Cancel` 閸ョ偠鐨熼柧鎾呯礉`_MindMapViewState` 鐏忓棝鏆遍幐澶屝╅崝銊ユ綏閺嶅浄绱檅utton-local 閳?node-space閿涘宕茬粻妤€鎮楅崘娆忓弳 `_connectingEndPos`閿涘畭_MindMapLinesPainter` 閺傛澘顤?`connectingFrom`/`connectingTo` 閸欏倹鏆熼敍宀€鏁?`PathMetric` 閾忔氨鍤庣紒妯哄煑濮楋紕姣婄粵瀣婵夌偛鐨甸敍娑欐緱閹靛妞?`_hitTestNode` 閸涙垝鑵戦崚銈嗘焽閻╊喗鐖ｉ懞鍌滃仯楠炴儼鐨熼悽銊ュ嚒閺?`onMoveToParent(targetId, sourceId)`閵嗗倸褰搁柨顔惧仯閸戞槒绻涚痪鍨隘閸╃噦绱癭GestureDetector.onSecondaryTapUp` 鐎电绀夋繅鐐茬毜娑擃厾鍋ｉ崑?24px 鐠烘繄顬囬崨鎴掕厬濡偓濞村绱濋崨鎴掕厬閸?`showMenu` 閹绘劒绶?閺傤厼绱戞潻鐐村复"闁銆嶉妴淇檁onMoveTaskToParent` 閸?`moveTask` 閸氬氦鍤滈崝銊﹀⒖鐏炴洜鍩楅懞鍌滃仯 `startDate`/`dueDate` 娴犮儱瀵橀崥顐㈢摍閼哄倻鍋ｉ弮銉︽埂閼煎啫娲块妴鍌涙）閸?`_isMultiDayTask` 瀹稿弶顥呴弻?`_hasChildren`閿涘瞼鍩楅懞鍌滃仯鏉╃偟鍤庨崥搴ゅ殰閸斻劌婀い鍫曞劥濡亝娼崨鍫㈠箛閵?
> 2026-06-01: 閻ц缍嶆い鍨暙閻ｆ瑤璐￠惍浣规瀮濡楀牊鏁奸崶鐐拌厬閺傚浄绱遍弽纭呯熅閻㈠崬婀?`AuthLoading`閵嗕梗PhoneOtpSent`閵嗕梗AuthError` 缁涘娼拋銈堢槈閹存劕濮涢悩鑸碘偓浣风瑓缂佈呯敾濞撳弶鐓嬮崥灞肩娑?`LoginPage`閿涘矂浼╅崗宥嗗閺堟椽鐛欑拠浣虹垳閸欐垿鈧焦绁︾粙瀣╄厬妞ょ敻娼伴崡姝屾祰鐎佃壈鍤ч張顒€婀?`_otpSent` 閻樿埖鈧椒娑径渚库偓淇橝uthBloc` 闁藉牆顕幍瀣簚閸欓攱鐗稿蹇撴嫲 Supabase Phone Auth/SMS Provider 閺堫亜鎯庨悽銊﹀灗閺堫亪鍘ょ純顔炬畱闁挎瑨顕ゆ潻鏂挎礀娑擃厽鏋冮幓鎰仛閵嗗倹鍨滈惃鍕侀崸妤佹煀婢х偘鎹㈤崝鈥愁嚤閸戞椽鎽肩捄顖ょ窗`ProfilePage` 閹恒儱鍙?`TaskExportPage`閿涘矁顕伴崣鏍箛閺?`TaskRepository`/`ProjectRepository` 閺佺増宓侀敍娌桾askExportService` 娴ｈ法鏁?`excel` 閸栧懐鏁撻幋?`.xlsx`閿涘苯鍟€閻?`archive`/`xml` 閸愭瑥鍙嗛崘鑽ょ波缁愭鐗?OpenXML閿涘本瀵滄い鍦窗閹峰棗鍨?Sheet閿涘本瀵滄禒璇插閻栬泛鐡欓崗宕囬兇 DFS 鏉堟挸鍤弽鎴濊埌缂傗晞绻樼悰宀嬬礉缁涙盯鈧娼禒璺哄瘶閹奉兛鎹㈤崝鈩冩闂傜瀵栭崶瀵告祲娴溿們鈧線銆嶉惄顔碱樋闁鎷伴柌宥堫洣缁狙冨焼婢舵岸鈧绱濇稉宥勬叏閺€?Drift 鐞涖劎绮ㄩ弸鍕灗閸氬本顒為崡蹇氼唴閵?
> 2026-06-01: 閹存垹娈戝Ο鈥虫健鐠у嫭鏋＄紓鏍帆閸旂喕鍏橀拃钘夋勾閵嗕繖ProfilePage` 娴?`LocalStorageService.getExplicitProfile()` 鐠囪褰囬悽銊﹀煕娑撹濮╂繅顐㈠晸閻ㄥ嫭妯夊蹇氱カ閺傛瑱绱濇径鎾劥鐏炴洜銇氶弰鐢敌為崣濞锯偓婊嗕捍娑?闊偂鍞?璺?閹碘偓閸︺劌鐓勭敮鍌椻偓婵撶礉鐠愶箑褰块柇顔绢唸/閹靛婧€閸欒渹绮庢担婊€璐熼崣顏囶嚢鐠併倛鐦夋穱鈩冧紖娴肩姷绮?`ProfileEditPage`閵嗕繖ProfileEditPage` 閸忎浇顔忕紓鏍帆閺勭數袨閵嗕浇浜存稉姘灗闊偂鍞ら妴浣瑰閸︺劌鐓勭敮鍌樷偓浣烘窗閺嶅洤鐓勭敮鍌樷偓浣峰瘜鐟曚胶娲伴弽鍥风幢娣囨繂鐡ㄩ弮鍓佹埛缂侇厼鍟撻崗?`LocalStorageService.saveExplicitProfile()`閿涘苯鑻熼崥灞炬缂佸瓨濮?`primaryGoals` 娑撳骸宸婚崣?`goals` 闁款喕浜掗崗鐓庮啇 onboarding 瀹稿弶婀侀弫鐗堝祦缂佹挻鐎妴鍌氱秼閸撳秷绁弬娆戠椽鏉堟垳绗夐崘娆忓弳 Supabase `user_profiles`閵?
> 2026-05-31: 閺堫剚顐兼穱顔碱槻娣囨繄鏆€閻滅増婀?Drift `tasks.parentId` 閳?Supabase `user_tasks.parent_id` 闁劘顢戦崥灞绢劄閺嬭埖鐎敍娌桾askNewBloc` 閻ㄥ嫪鎹㈤崝鈥虫倱濮濄儱鍙嗛崣锝嗘暭娑撻缚鐨熼悽?`TaskSyncService.syncAll()`閿涘奔绗夐崘宥夆偓姘崇箖閺?`local_task_sync.tasks_data` JSON 鐠侯垰绶為崥灞绢劄娴犺濮熼弽鎴欌偓淇橳askSyncService` 閺嗘挳婀剁痪顖涙Ё鐏忓嫭鏌熷▔鏇犳暏娴滃酣鐛欑拠?`parent_id`/`parentId` 鏉烆剚宕查妴鍌欒厬閸ュ€熷Ν閸嬪洦妫╃仦鏇犮仛閸?`HolidayService` 娑擃厼顤冮崝?2026 楠炴潙濮甸崝銊ㄥΝ閺堫剙婀撮崗婊冪俺鐟曞棛娲婇敍宀兯夋?2026-05-01 閼?2026-05-05 娴兼垶浼呴弮銉ユ嫲 2026-04-26閵?026-05-09 鐞涖儳褰弮銉ｂ偓鍌溞╅崝銊ь伂妫ｆ牠銆夋禒璇插鐠囷附鍎忕挧鍕爱閸栬桨绻氶幐浣告倱娑撯偓閺佺増宓侀弶銉︾爱閿涘奔绲剧粣鍕潌娑撳妾禒璺烘嫲濡偓閺屻儵銆嶉弨閫涜礋缁鹃潧鎮滈崚鍡楀隘鐏炴洜銇氶敍娑欘攽闂堛垻顏禒宥勮礋濡亜鎮滅敮鍐ㄧ湰閵嗗倹鍨滈惃鍕€夐柅鈧崙铏规瑜版洜鏁?`ProfilePage` 濞叉儳褰?`AuthBloc.LoggedOut`閵?
> 2026-05-31: 閹繄娣€电厧娴樻禒璇插鐟欏棗娴橀弬鏉款杻娑撯偓濞嗏剝鈧€鈧粏鍤滈崝銊╂敚鐎规埃鈧繆顫嬬憴鎺戠暰娴ｅ秲鈧繖lib/presentation/pages/tasks/widgets/mind_map_view.dart` 婢跺秶鏁?`TransformationController`閿涘本瀵滆ぐ鎾冲閸欘垵顫嗛懞鍌滃仯閻?`startDate ?? dueDate` 娑撳骸缍嬮崜宥嗘闂傜绐涚粋濠氣偓澶嬪閺堚偓鏉╂垳鎹㈤崝鈽呯礉楠炶泛婀穱婵囧瘮瑜版挸澧犵紓鈺傛杹濮ｆ柧绶ラ惃鍕剰閸愬吀绗呴獮宕囆╅悽璇茬閸掓媽顕氶懞鍌滃仯娑擃厼绺鹃敍娑滃Ν閻愮懓娼楅弽鍥﹀▏閻?`_positionNotifiers`閿涘苯娲滃銈嗘暜閹镐焦澧滈崝銊﹀珛閸斻劌鎮楅惃鍕杽闂勫懍缍呯純顔衡偓?
> 2026-05-31: 閺傛澘顤冮悪顒傜彌闂堟瑦鈧胶鐝悙?`personal_admin_site/`閿涘瞼鏁ゆ禍搴濋嚋娴滃搫濮╅幀浣哥槕闁姐儯鈧礁濮╅幀浣规殶閹诡喖鎷?App 缁狅紕鎮婇妴鍌滅彲閻愬湱鏁?`index.html`閵嗕梗styles.css`閵嗕梗app.js`閵嗕梗config.js`閵嗕梗config.example.js`閵嗕梗supabase.sql` 閸?`README.md` 缂佸嫭鍨氶敍灞肩瑝閹恒儱鍙嗛悳鐗堟箒 Flutter 鎼存梻鏁ゆ潻鎰攽閺冭翰鈧倸澧犵粩顖炩偓姘崇箖 Supabase JS CDN 娴ｈ法鏁?Email OTP 閻ц缍嶉敍娌梥upabase.sql` 鐎规矮绠?`allowed_users`閵嗕梗dynamic_secrets`閵嗕梗dynamic_data`閵嗕梗managed_apps` 閸ユ稑绱剁悰顭掔礉閸氼垳鏁?RLS閿涘苯鑻熺憰浣圭湴閻ц缍嶉柇顔绢唸鐎涙ê婀禍?allowlist閵嗗倸鐦戦柦銉モ偓鐓庢躬濞村繗顫嶉崳銊ь伂娴ｈ法鏁?WebCrypto PBKDF2 + AES-GCM 閸旂姴鐦戦崥搴濈箽鐎涙﹫绱濋崣锝勬姢娑撳秳绗傛导鐘偓浣风瑝閽€钘夌氨閵嗗倹甯归懡鎰板劥缂冭尙绮ㄩ弸鍕礋 Cloudflare Pages 闂堟瑦鈧焦澧粻?+ Supabase 閸忓秷鍨傜仦鍌樷偓?
> 2026-05-31: `personal_admin_site/` 鐞涖儱鍘?Cloudflare Pages 閸欐垵绔烽柊宥囩枂閸滃奔绗傜痪鎸庮梾閺屻儯鈧繖_headers` 鐎规矮绠熼棃娆愨偓浣虹彲鐎瑰鍙忛崫宥呯安婢惰揪绱盽DEPLOYMENT_PLAN.md` 鐠佹澘缍?Cloudflare Pages + Supabase 閸忓秷鍨傜仦鍌滄畱 0 缂囧骸鍘撻崶鍝勭暰閹存劖婀伴弬瑙勵攳閵嗕礁鐣奸弬閫涚贩閹诡噣鎽奸幒銉ユ嫲娑撳﹦鍤庡銉╊€冮敍娌梔eploy-check.ps1` 閸︺劌褰傜敮鍐ㄥ濡偓閺屻儱绻€鐟曚焦鏋冩禒韬测偓渚€妯嗗銏犲窗娴?Supabase 闁板秶鐤嗛妴渚€妯嗗?`sbp_`/`service_role` 缁涘鏅遍幇鐔风槕闁姐儴绻橀崗銉ュ缁旑垽绱濋獮鑸靛⒔鐞?`node --check app.js`閵?
> 2026-05-31: `personal_admin_site/` 鐞涖儱鍘栨稉銈囶潚闁板秶鐤嗛悽鐔稿灇鐠侯垰绶為敍娆砽oudflare Pages 娴犳挸绨遍柈銊ц閺冭埖澧界悰?`build-cloudflare.sh`閿涘奔绮?`PUBLIC_SUPABASE_URL` 閸?`PUBLIC_SUPABASE_ANON_KEY` 閻㈢喐鍨?`config.js`閿涙稒婀伴崷?Direct Upload 閸撳秴褰查幍褑顢?`build-local.ps1` 閻㈢喐鍨氶崥灞剧壉闁板秶鐤嗛妴鍌涚壌閻╊喖缍嶉悽鐔稿灇 `personal_admin_site_template.zip` 娴ｆ粈璐熸稉濠佺炊濡剝婢橀崠鍜冪礉娴犲秹娓堕惇鐔风杽 Supabase `anon public key` 閺囨寧宕查崥搴㈠閼宠棄褰傜敮鍐ц礋閸欘垳鏁ょ粩娆戝仯閵?
> 2026-05-31: 妫ｆ牠銆夋禒璇插鐠囷附鍎忛崡锛勬畱 DB 娴犺濮熺挧鍕爱閸栬櫣鏁遍悪顒傜彌閻ㄥ嫧鈧粌鐡欐禒璇插閸︺劋绗傞妴渚€妾禒?濡偓閺屻儵銆嶉崷銊ょ瑓閳ユ繄绮ㄩ弸鍕殶閺佺繝璐熼崥灞肩濡亜鎮滅挧鍕爱鐞涘矉绱癭_buildResourceRow` 閸?`lib/presentation/pages/home/home_page.dart` 娑擃厼鑻熼崚妤佸鏉炶棄鐡欐禒璇插閺嶆垯鈧梗AttachmentSection`閵嗕梗ChecklistSection`閿涘奔绮涙禒鍛嚠 `source == 'db'` 娴犺濮熼弰鍓с仛閵?
> 2026-05-30: 婢舵矮瀵屾０妯哄瀼閹诡潿鈧繖lib/core/theme/app_theme.dart` 閹惰棄鍤?`AppPalette` 鐠嬪啳澹婇弶鎸幠侀崹瀣剁礄閸忋劑鍎存０婊嗗 token + `ThemeData build()`閿涘绱濇稉澶婎殰鐎圭偘绶?`claude`(姒涙顓婚弳鏍挤閻?/`auroraBlue`(Google Material 3 閽?/`obsidian`(濞ｈ精澹?閵嗕繖AppTheme` 妫版粏澹婇悽?`static const` 閺€閫涜礋婵梹澧?`_current` 閻?`static get`閿涘牆顕径鏍ф倳娑撳秴褰夐敍灞藉弿 App 653 婢跺嫬绱╅悽銊╂祩閺€鐟板З閿涙稐鍞禒閿嬫Ц 215 婢?const 娑撳﹣绗呴弬鍥у箵 const閿涘鈧繖lib/core/theme/theme_controller.dart` 閻?`ThemeController`(ChangeNotifier閿涘苯鍙忕仦鈧崡鏇氱伐 `themeController`)鐠愮喕鐭楅幐浣风畽閸?SharedPreferences via `LocalStorageService.themeId`)+ 闁氨鐓￠柌宥呯紦閿涙矖main.dart` 閻?`ListenableBuilder` 閸?`MaterialApp`閿涘畭themeMode` 闂呭繗鐨熼懝鍙夋緲娴?閺嗘鍨忛幑顫偓鍌炩偓澶嬪妞?`theme_settings_page.dart`閿涘苯鍙嗛崣锝呮躬 profile"娑撳顣?閼挎粌宕熼妴?> 2026-05-31: 閹存垹娈戝Ο鈥虫健鐞涖儱鍙忛妴淇檖rofile_page.dart` 缁夊娅庣粚铏规畱"閹绘劙鍟嬬拋鍓х枂"閼挎粌宕熼崗銉ュ經閿?鐠佸墽鐤?鐢喖濮稉搴″冀妫?閸忓厖绨?閺€閫涜礋妞ょ敻娼扮捄瀹犳祮閵嗕繖app_settings_page.dart` 閹佃儻娴?AI 閹烘帞鈻肩捄瀹犵箖閸涖劍婀鈧崗绛圭礄婢跺秶鏁?`LocalStorageService.skipWeekends`閿涘鈧椒瀵屾０妯哄弳閸欙絻鈧線鈧氨鐓￠崪灞炬殶閹诡喛顕╅弰搴幢`help_feedback_page.dart` 鐠佹澘缍嶆禒璇插缁狅紕鎮婇妴涓処 閹峰棜袙閵嗕焦妫╅崢鍡樺絹闁辨帇鈧椒瀵屾０妯哄瀼閹诡潿鈧礁鐖剁憴渚€妫舵０妯烘嫲閸欏秹顩拠瀛樻閿涙矖about_page.dart` 鐏炴洜銇氶弲楦垮厴鐏忓繒顓哥€硅翰鈧胶澧楅張?`1.0.0+3`閵嗕焦鐗宠箛鍐厴閸旀稏鈧焦鏆熼幑顔兼倱濮濄儱鎷伴梾鎰潌閺夊啴妾虹拠瀛樻閵?
> 2026-06-06: 閸ユ稖钖勯梽鎰侀崸妤佹暭娑撳搫鍨┃銏犲毉濡€崇础閳ユ柡鈧梹鐦￠崚妤佹付婢?5 閺夆槄绱濈搾鍛毉閼奉亜濮╅弬鏉跨磻閸掓绱濈挒锟犳閸?`SingleChildScrollView` 濡亜鎮滃姘З閿涘苯鍨梻?1px 閸掑棝娈х痪瑁も偓鍌溞╅梽銈団€栨稉濠囨閹搭亝鏌?`q.removeRange(5)`閵嗕線鈧偓婀″Ο顏勭畽閵嗕梗"N 闁偓婀?` 閹绘劗銇氶敍灞肩箽閻ｆ瑥宕熼弶鈥叉崲閸斺€冲闁偓婀?`!` 閸ョ偓鐖ｉ妴?
> 2026-07-17: 娣囶喖顦查幀婵堟樊鐎电厧娴橀悙鐟板毊缁岃櫣娅ф径鍕絿濞戝牊顢嬮柅澶夌瑝閻㈢喐鏅ラ妴鍌涚壌閸ョ媴绱伴崣鏍ㄧХ濡楀棝鈧娈?`Listener` 閸樼喐婀伴弨鎯ф躬 `InteractiveViewer` 閸愬懘鍎?Stack閿涘本顢戦棃銏㈩伂 `InteractiveViewer` 閻?`ScaleGestureRecognizer` 閹凤附鍩呴幐鍥嫛娴滃娆㈢€佃壈鍤х€涙劗楠?`onPointerUp` 娑撳秷袝閸欐垯鈧倷鎱ㄦ径宥忕窗鐏?`Listener` 缁夎鍩?`InteractiveViewer` 婢舵牕鐪?Stack閿涘潉_buildMindMapCanvas` 鏉╂柨娲栭崐纭风礆閿涘瞼绮鈧幍瀣◢缁旂偞濡ч崷鎭掆偓?
> 2026-06-06: 閹繄娣€电厧娴樻晶鐐插濡楀矂娼扮粩?Ctrl+濡楀棝鈧顦块懞鍌滃仯閸旂喕鍏橀妴淇檁MindMapViewState` 閺傛澘顤?`_ctrlPressed`/`_selectedIds`/`_isSelecting` 閻樿埖鈧緤绱濋柅姘崇箖 `HardwareKeyboard` 閻╂垵鎯?Ctrl 闁款噯绱漙Listener` 閹规洝骞忛幐鍥嫛娴滃娆㈢紒妯哄煑闁瀚ㄩ惌鈺佽埌閵嗕繖_SelectionRectPainter` 缂佹ê鍩楅崡濠団偓蹇旀闁瀚ㄥ鍡愨偓鍌炩偓澶夎厬閸氬孩瀚嬮幏鑺ユ `onDragUpdate` 鐎?`_selectedIds` 閸愬懏澧嶉張澶庡Ν閻愮懓绨查悽銊ф祲閸氬奔缍呯粔姹団偓?
> 2026-05-30: 妫ｆ牠銆夐弬鏉款杻缂佺喕顓搁崡锛勫閿涘牅绮栭弮銉ゆ崲閸斺剝鏆?鐎瑰本鍨氶悳?闁偓婀￠弫甯礆閿涘矁顕涚憴浣碘偓宀勵浕妞ょ數绮虹拋鈥冲幢閻楀洢鈧?> 2026-05-30: Realtime DELETE 閸ョ偠鐨熸晶鐐插婢ф挾顣舵穱婵囧Б閿涘矂妲诲銏犲坊閸欐彃鍨归梽銈勭皑娴犺泛娲栭弨鎯ь嚤閼锋潙鐡欐禒璇插濞戝牆銇?
## Overview

`smart_assistant` is a Flutter application with shared UI code for mobile and desktop platforms. The main entrypoint is [lib/main.dart](/E:/claude/project2/smart_assistant/lib/main.dart), which initializes Supabase, the local notification service, the Drift database, repositories, and the root `MaterialApp`.

## Core Modules

- `lib/main.dart`
  Bootstraps platform services, desktop window management, and the system tray on Windows/macOS/Linux.
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
  A heavy task-editing surface that combines title/description inputs, reminder controls, subtask tree, checklist, attachments, and AI decomposition in one scrollable page. Heavy child sections (SubtaskTreeSection, ChecklistSection, AttachmentSection, AiDecomposeSection) are wrapped in `RepaintBoundary` to isolate repaints. `BlocListener` uses `listenWhen` to avoid unnecessary setState on unrelated BLoC changes.
- `lib/services/holiday_service.dart`
  閼哄倸浜ｉ弮銉︽殶閹诡喗婀囬崝掳鈧倷鑵戦崶鎴掔喘閸忓牏鏁?`timor.tools/api/holiday/year/{year}`閿涘牆鎯堝▔鏇炵暰閸嬪洦妫?+ 鐠嬪啩绱ょ悰銉у疆閿涘绱濇径杈Е閹存牞绻戦崶鐐碘敄閺冭泛娲栭柅鈧?`date.nager.at/api/v3`閿涘湑N閿涘奔绮庡▔鏇炵暰閸嬪洦妫╅敍澶涚幢閸忔湹绮崶钘夘啀閻?`date.nager.at/api/v3`閵嗗倻绮ㄩ弸婊€浜?`Map<"yyyy-MM-dd", HolidayInfo>` 瑜般垹绱℃潻鏂挎礀閿涘苯鑻熼悽?`SharedPreferences` 缂傛挸鐡?7 婢垛晪绱濋弬顓犵秹閺冨爼妾风痪褑顕版潻鍥ㄦ埂缂傛挸鐡ㄩ妴鍌涙暜閹?`HolidayCountry`閿涘牅鑵?缂?閺?閼?闂娾晪绱氶弸姘閿涘瞼鏁ら幋鐑解偓澶嬪閹镐椒绠欓崠鏍モ偓?- `lib/services/notification_service.dart`
  Centralizes reminder scheduling. Android/iOS 缁旑垳鏁?`zonedSchedule`閿涘牏閮寸紒?AlarmManager閿涘绱濇潻娑氣柤濮濊楠搁崥搴ｉ兇缂佺喍绮涢崣顖澬曢崣鎴幢濡楀矂娼扮粩顖欑箽閻?Timer閵嗗倿娓?`timezone` 閸栧懎鍨垫慨瀣閿涘潉tz.initializeTimeZones()`閿涘鈧?- `lib/services/permission_service.dart`
  鏉╂劘顢戦弮鍫曗偓姘辩叀閺夊啴妾洪悽瀹狀嚞鐏忎浇顥婇敍鍦搉droid/iOS閿涘绱漙showNotificationGuideIfNeeded` 閸︺劑顩诲▎鈥虫儙閸斻劍妞傚鐟板毉瀵洖顕?dialog閿涘畭SharedPreferences` 闂冩煡鍣告径宥冣偓?- `lib/core/desktop/desktop_runtime.dart`
  Holds desktop-only runtime decisions used by the app, including tray event mapping and desktop notification channel selection.
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`
  閹繄娣€电厧娴樻禒璇插鐟欏棗娴橀妴鍌滄暏 InteractiveViewer + Stack + Positioned 鐎圭偟骞囧鏉戦挬閺嶆垵鑸扮敮鍐ㄧ湰閿涘瓔ustomPaint 缂佹ê鍩楃拹婵嗩敚鐏忔梹娲哥痪鑳箾閹恒儳鍤庨妴鍌涚槨娑擃亣濡悙瑙勬Ц鐎瑰本鏆ｉ惃鍕唉娴滄帒宕遍悧鍥风礄Draggable + DragTarget + Slidable閿涘鈧倿鈧俺绻?BLoC state 閻?`viewMode` 鐎涙顔岄崚鍥ㄥ床閸掓銆?鐎电厧娴樼憴鍡楁禈閵?  **閼奉亞鏁遍幏鏍ㄥ濡€崇础**閿涙瓪_freeDragMode` 閻樿埖鈧焦甯堕崚璁圭礉閼哄倻鍋ｉ悽?`GestureDetector.onPanDown/onPanUpdate/onPanEnd/onPanCancel` 閼奉亞鏁遍幏鏍уЗ閿涘潉onPanDown` 濮?`onPanStart` 閺囧瓨妫憴锕€褰傛禒銉ユ晼閺冣晝顩﹂悽銊ф暰鐢啫閽╃粔浼欑礉`onPanCancel` 濞撳懐鎮婇悩鑸碘偓渚€妲诲銏＄暙閻ｆ瑱绱氶敍娑樻綏閺嶅洭鎸搁崚?`dx>=0/dy>=6` 闂冨弶顒涚搾濠傚毉閻㈣绔烽弮鐘崇《閸涙垝鑵戦妴淇橧nteractiveViewer.panEnabled = !_nodeDragging`閿涙碍瀚嬮懞鍌滃仯閺堢喖妫跨粋浣烘暏閻㈣绔烽獮宕囆╅敍宀勪缉閸忓秶鏁剧敮鍐╂殻娴ｆ捁浠堥崝顭掔幢缁屾椽妫介弮鏈电矝閸欘垰閽╃粔?缂傗晜鏂侀妴? 閹稿鎸抽悽?`HitTestBehavior.opaque` + 28鑴?8 閻戭厼灏柆鍨帳閹靛濞嶇粩鐐村Η閸﹀搫鎮舵禍瀣╂閵?  **閹嗗厴娴兼ê瀵?(2026-06-04)**閿涙艾绔风仦鈧紒鎾寸亯缂傛挸鐡ㄩ崷?`_cachedPendingNodes/Lines/CanvasSize` 娑擃叏绱漙initState`/`didUpdateWidget` 娑擃厺绔村▎鈩冣偓褑顓哥粻妤嬬礉`build()` 閻╁瓨甯寸拠鑽ょ处鐎涙ǜ鈧倹瀚嬮幏鐣屾暏 `ValueNotifier<Offset>` 濮ｅ繗濡悙鍦缁?+ `ValueListenableBuilder`閿涘苯褰ч柌宥呯紦鐞氼偅瀚嬮懞鍌滃仯閵嗗倽绻涚痪鍨湴閻?`AnimatedBuilder` + `Listenable.merge` 閻╂垵鎯夐幍鈧張?notifier閿涘苯褰ч柌宥囩帛 `CustomPaint`閵嗗倹鐦℃稉顏囧Ν閻愮懓顦婚崠?`RepaintBoundary`閵嗗倸鍑＄粔濠氭珟 `_lineAnimController` 閸斻劎鏁鹃妴?- `lib/presentation/pages/home/home_page.dart`
  妫ｆ牠銆夐妴淇檁HomeContent` 閼奉亙绗傞懓灞肩瑓閿涙岸妫堕崐娆掝嚔 閳?**缂佺喕顓搁崡?`_buildStatsCard`** 閳?妞ゅ湱娲扮粵娑⑩偓?閳?閺冨爼妫挎潪?閳?娴犺濮熺拠锔藉剰閸?閳?閸ユ稖钖勯梽鎰┾偓鍌滅埠鐠佲€冲幢閿?026-05-30閿涘绗佹い鐧哥窗娴犲﹥妫╂禒璇插閺?/ 鐎瑰本鍨氶悳?`鐎瑰本鍨?閹堡閿涘苯鎳嗛張?`_statsPeriod` 閸欘垰鍨忛弮銉ユ噯閺堝牆鍕鹃敍宀€鏁?`_periodRange` 閸?`[start,end)`) / 闁偓婀￠弫鑸偓鍌氬弿闁劌鐔€娴滃骸鍞寸€?`_filteredTasks` 閹?`_TimelineTask.date` 鐠侊紕鐣婚妴浣哥毀闁插秹銆嶉惄顔剧摣闁鈧線娈?`_loadData` 閸掗攱鏌婇敍灞炬￥閺傛澘顤冮弫鐗堝祦鐏炲倶鈧倿鈧偓婀￠弫鏉垮讲閻?閳?`_showOverdueSheet` 鎼存洟鍎村鍦崶 閳?閻愰€涙崲閸斺€愁槻閻?`_selectTask`閿涘牊妞傞梻纾嬮叡閸掑洦宕?+ 鐠囷附鍎忛崡鈥崇潔瀵偓閿涘鈧倷鎹㈤崝陇顕涢幆鍛幢閺堫偄鐔弬鏉款杻閵嗗矁绁┃鎰隘閵嗗稄绱?026-05-30閿涘绱板锕€鍨?`AttachmentSection`閵嗕礁褰搁崚?`ChecklistSection`閿涘矂鈧俺绻?`_dbTaskCache`閿涘牊鍣块崝鐘烘祰 Task 鐎电钖勯敍澶婃嫲閸忣厺閲?`_home*` 閺傝纭剁€佃甯?`ChecklistRepository`閿涘奔绮?`source=='db'` 娴犺濮熼弰鍓с仛閵?- `lib/services/subscription_service.dart`
  VIP 订阅状态管理单例。从 Supabase `user_subscriptions` 表拉取订阅状态，缓存到 SharedPreferences。提供 `isVip`、`canCreateProject()`、`canCreateTask()`、`canUseAiDecompose()`、`canExportData()` 权限检查方法。支持 Realtime 订阅实时感知 VIP 状态变更。
- `lib/models/entities/user_subscription.dart`
  订阅模型：`SubscriptionPlan`（free/vipMonthly/vipYearly）、`SubscriptionStatus`（active/expired/cancelled）、`UserSubscription` 数据类。
- `lib/core/exceptions/quota_exceeded_exception.dart`
  配额超限异常，携带 `QuotaType`（project/task/aiDecompose/dataExport）用于 UI 层区分处理。
- `lib/presentation/pages/profile/vip_page.dart`
  VIP 开通/管理页面，展示当前状态、权益说明、套餐选择（月¥9.9/年¥68）。
- `lib/presentation/widgets/upgrade_dialog.dart`
  升级提示弹窗，配额超限或功能受限时引导跳转 VipPage。
- `lib/services/payment_service.dart`
  支付宝扫码支付客户端。调用 Edge Function 创建订单、轮询支付状态（3秒间隔，5分钟超时），返回 Stream<PaymentStatus> 供 UI 监听。
- `supabase/functions/` — 3 个 Edge Function（Deno）
  `create-order`：生成支付宝当面付二维码；`alipay-notify`：异步回调验签+激活VIP；`order-status`：查询订单状态。共享 `_shared/alipay.ts`（RSA2签名/验签）。
- `lib/presentation/widgets/create_schedule_dialog.dart`
  Schedule creation/edit dialog, including reminder settings UI.
- `lib/presentation/pages/task/task_detail_page.dart`
  Legacy task detail page with reminder settings UI.
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
  Task detail page in the newer tasks area, also with reminder settings UI.

## Data Flow

1. `main()` initializes Supabase, `NotificationService`, the Drift database, and repositories.
2. UI actions in pages such as `HomePage` create or update schedules/tasks.
3. Reminder settings are passed into `NotificationService.scheduleReminderForSchedule(...)`.
4. `NotificationService` creates timers for future reminders.
5. When a timer fires on desktop:
   - Windows now prefers the native Windows notification plugin path.
   - If the Windows native path is unavailable, the service falls back to the existing PowerShell toast script.
   - macOS and Linux continue to use shell-based native notification commands.
6. On desktop, tray icon events are routed through `desktop_runtime.dart`, then handled in `main.dart` to show the window or open the tray context menu.
7. Windows 閸楁洖鐤勬笟瀣╃箽閹躲倝鈧俺绻?`main.cpp` 娑擃厾娈?Named Mutex 鐎圭偟骞囬敍宀€顑囨禍灞奸嚋鐎圭偘绶ュ┑鈧ú璇插嚒閺堝鐛ラ崣锝呮倵闁偓閸戞亽鈧?
## Mobile Performance Notes

- The newer task detail page keeps many editing and data sections in a single `ListView`.
- Text edits in that page eventually flow through `TaskDetailPage._saveTask()` into `TaskNewBloc._onUpdateTask()`, which performs repository writes and then reloads task data.
- During this task, text-input dirty tracking on that page was adjusted so typing no longer schedules the debounced save pipeline on every pause. Text changes are now saved when editing completes, focus leaves the field, or the page closes.

## Local Android Debugging Status

- Flutter and the Android SDK are installed on this machine and `flutter doctor -v` reports the Android toolchain as healthy.
- `E:\android-sdk\platform-tools\adb.exe` exists locally.
- At inspection time there were no connected Android devices, `flutter emulators` found no AVD images, and `adb` was not on the shell `PATH`.
- Result: this computer can support Android debugging after either connecting a device or creating an emulator and, ideally, adding platform-tools to `PATH`.

## Dependencies Relevant To This Change

- `flutter_local_notifications`
  Cross-platform notification API already used by the project. Updated to `^19.5.0`.
- `flutter_local_notifications_windows`
  Added to provide a native Windows desktop notification implementation.
- `system_tray`
  Used for the desktop tray icon and context menu.
- `window_manager`
  Used to show, focus, and destroy the desktop window.

## UI 瀹搞儱鍙跨仦?
- `lib/core/utils/snackbar_helper.dart`閿涙艾鍙忕仦鈧?`showAppSnackBar(context, message)` 閳?閹碘偓閺堝褰佺粈鐑樼Х閹垳绮烘稉鈧担璺ㄦ暏濮濄倕鍤遍弫甯礉閸愬懐鐤嗛悙鐟板毊濞戝牆銇戦崝鐔诲厴閿涘湙estureDetector + hideCurrentSnackBar閿涘鈧?
## Important Implementation Decisions

- Windows desktop reminders are no longer limited to the PowerShell toast fallback. The app now prefers the native Windows notification plugin path when available.
- Tray menu visibility is controlled explicitly from tray events. Right-click popup behavior is mapped in `desktop_runtime.dart` and executed in `main.dart`.
- Reminder UI sections use taller `SwitchListTile` layouts (`isThreeLine: true`) in the affected desktop surfaces to reduce bottom overflow risk on shorter windows.

## 2026-05-27 閹靛綊鍣烘导妯哄 閳?閺傛澘顤冨Ο鈥虫健

### 閺佺増宓佸Ο鈥崇€烽敍鍦杛ift v5閿?
- `Projects.groupId`閿涙艾褰茬粚鐚寸礉閹稿洤鎮?`ProjectGroups.id`
- 閺傛媽銆?`ProjectGroups(id, name, color, sortOrder, createdAt, updatedAt)`
- `Tasks.estimatedMinutes`閿涙艾褰茬粚鐚寸礉AI 娴肩増妞傞崚鍡涙寭閺?- onUpgrade(4閳?)閿涙瓫ddColumn + createTable

### 娴滄垵鎮撳銉礄Supabase閿?
- 閺傛媽銆?`projects`閵嗕梗project_groups`閿涘牆鎯?user_id + RLS閿涘鈧總QL 鐟?`database/migration_002_groups_and_estimate.sql`
- 瀹稿弶婀?`user_tasks` 閸?`estimated_minutes` 閸?- 閺?`ProjectSyncService` (`lib/services/project_sync_service.dart`)閿涙矮璞?`TaskSyncService` 缂佹挻鐎敍瀹瞮ll/push/subscribe閿涘瞼绮︾€?`ProjectRepository` 娑?`ProjectGroupRepository` 閻ㄥ嫬鍟撻幙宥勭稊
- `home_page` 閸掓繂顫愰崠鏍ㄦ `pullAll()` + `subscribe()`閿涘瞼娅ヨぐ鏇犳暏閹村嘲鍙℃禍?projects/groups

### 閸忋劋绗熼崝鈩冩殶閹诡喖寮荤粩顖氭倱濮濄儻绱欐潪顖氬灩闂勩倕顣搁惌?+ 閸欏苯鎮?LWW閿?026-05-29閿?
- **婢ф挾鐓舵潪顖氬灩闂?*閿涙瓪Tasks/Projects/ProjectGroups/ChecklistItems` 閸欏﹤顕惔鏂剧隘鐞涱煉绱檂user_tasks/projects/project_groups/checklist_items`閿涘娼庨崥?`deleted`閿?/1閿涘鈧倸鍨归梽銈勭瀵?`deleted=1, updatedAt=now` 楠炶埖甯归柅渚婄礉娑撳秶澧块悶鍡楀灩闂勩倧绱遍幍鈧張澶庮嚢閺屻儴顕楁潻鍥ㄦ姢 `deleted=0`閵嗗倸鍨归梽銈夋浆婢ф挾鐓剁捄銊ь伂娴肩姵鎸遍妴渚€鍣搁崥顖欑瑝婢跺秵妞块妴淇縞hemaVersion=7閵?- **閸欏苯鎮?LWW 鐎电澶?*閿涙瓪{Task,Project,Checklist,Attachment}SyncService.syncAll()` = 閹峰绨粩顖ょ礄閸氼偄顣搁惌绛圭礆閸氬牆鑻熼張顒€婀撮敍鍫滅矌瑜?remote `updatedAt` 閺囧瓨鏌婇幍宥堫洬閻╂牭绱? 閺堫剙婀撮敍鍫濇儓婢ф挾鐓堕敍瀹峠etAllRaw()`閿涘鍤掓禍鎴狀伂缂傚搫銇戦幋鏍ㄦ拱閸︾増娲块弬鏉垮灟 upsert 娑撳﹣绨妴鍌欑瑝娓氭繆绂?Realtime 閸楀啿褰茬悰銉╃秷鐎涙劒鎹㈤崝鈩冪埐娑撳簼绱堕幘顓炲灩闂勩倧绱盧ealtime 娴犲懍缍旈崝鐘烩偓鐔粹偓?- **checklist 娑撳﹣绨?*閿涙碍鏌?`ChecklistSyncService` + 娴滄垼銆?`checklist_items`閿涘湩LS `auth.uid()=user_id` + REPLICA IDENTITY FULL + 閸?supabase_realtime publication閿涘鈧繖ChecklistRepository` 濞夈劌鍙?syncService閿涘苯顤冮崚鐘虫暭 push + `syncFromJson`閵?- **缁狙嗕粓**閿涙roject 鏉烆垰鍨?閳?缁狙嗕粓鏉烆垰鍨归崗鏈电瑓 tasks/checklist閿涙稖绻欑粩顖炪€嶉惄顔碱暩閻啿鍩屾潏?`_upsertProjectFromRow` 閺冭埖婀伴崷鏉挎倱閺嶉楠囬懕鏂烩偓?- **閸氼垰濮╅梻銊﹀付**閿涙瓪home_page` 閹碘偓閺?`syncAll()+subscribe()` 娴犲懎婀?Supabase 閻ц缍嶉崥搴℃儙閸旑煉绱漙signedIn/initialSession` 濮ｅ繑顐奸柌宥堢獓閸忋劑鍣虹€电澶勯敍鍫⑿╅梽銈勭啊閺堫亞娅ヨぐ鏇炲祮鐟欙箑褰傞惃?task pull閿涘鈧?- **濞撳懐鈹?*閿涙瓪AppDatabase.wipeAllData()` 娴滃濮熷〒鍛敄閸氬嫯銆冮獮鍫曞櫢瀵?inbox閿涙稐绨粩顖滅病 Management API 瀹稿弶绔荤粚鎭掆偓淇俀L 閻ｆ瑧妫?`database/migration_004_soft_delete_checklist_realtime.sql`閵?- 閳?閺堫剙婀撮懟銉︽弓濞撳懐鈹栭敍灞肩瑓濞嗏€虫儙閸?`syncAll` 娴兼碍濡搁弮褎鏆熼幑顔煎冀閹恒劌娲栨禍鎴狀伂 閳ユ柡鈧?濞撳懐鈹栨禍鎴狀伂閸氬酣銆忛崥灞绢劄濞撳懐鈹栨稉銈囶伂閺堫剙婀撮敍鍫濆彠 App 閸氬氦绐?`clear_data.bat` / 缁夎濮╃粩顖氬祻鏉炰粙鍣哥憗鍜冪礆閵?- **syncFromJson 娣囨繄鏆€鏉╂粎顏弮鍫曟？閹?*閿涙艾鎮庨獮鑸垫閸愭瑥鍙嗘潻婊咁伂 `updatedAt` 閼板矂娼?`now`閿涘矂浼╅崗宥勭瑓濞嗏€愁嚠鐠愶箑寮介幒銊︽＋閺佺増宓佺憰鍡欐磰娴滄垹顏妴鍌氼暩閻厖绻氶幎銈忕窗閺堫剙婀?`deleted=1` 娑?`updatedAt>=鏉╂粎顏琡 閺冩湹绗夌悮顐ｆ弓閸掔娀娅庨悩鑸碘偓浣筋洬閻╂牓鈧?- **Realtime 娑撹尪顢戦崠?*閿涙瓪TaskSyncService._enqueue()` 娑撹尪顢戦幍褑顢?Realtime 閸ョ偠鐨熼惃鍕殶閹诡喖绨遍幙宥勭稊閿涘矂妲诲銏犺嫙閸欐垵鍟撻崗銉ヮ嚤閼?SQLite `database is locked`閵?
### AI 閹峰棗鍨庨幒鎺斺柤

- 鏉堟挸鍙嗛敍姘卞煑娴犺濮熼敍鍫濇儓閹诲繗鍫?/ 闂勫嫪娆㈤敍澶涚幢AI 缁旑垰褰ф禍?WBS + 閸欒泛鐡?minutes
- 閹烘帞鈻奸敍姝歋ubtaskScheduler`閿涘潉lib/services/subtask_scheduler.dart`閿?  - 9:00閳?1:00 瀹搞儰缍旈弮鑸殿唽閵? 閸掑棝鎸撻崥鎼佹閵?5 閸掑棝鎸撶紓鎾冲暱閵嗕線浼╃拋鈺佸嚒閺?task 閻?`[start, due]`
  - `skipWeekends` 閺夈儴鍤?`LocalStorage`
  - 娑撳秴鍘戠拋绋垮礋濞堜絻娉曢弮銉礉瑜版挻妫╅崜鈺€缍戞稉宥咁檮閸掓瑦鏆ｅ▓鍨腹濞嗏剝妫?- 閻栨湹鎹㈤崝陇娉曟径鈺佹礀閸愭瑱绱癭computeParentSpans` 閳?`startOfDay(minLeafStart)` 閸?`endOfDay(maxLeafEnd)`閿涘矁顫?`_isMultiDayTask` 鐠囧棗鍩嗘稉娲€婇柈銊╂毐閺?
### 閺冦儱宸婚幏鏍уЗ闁插秴鍟?
- 閹舵稑绱?`Draggable` / `DragTarget`閿涘本鏁?`Listener` + 閻樿埖鈧焦婧€閿?  - `onPointerDown` 鐠佹澘缍嶇挧椋庡仯
  - `onPointerMove` 缁鳖垳袧 delta 閳?`Transform.translate` 娣囨繃瀵旈崢鐔锋槀鐎垫瓕绐￠幍?  - `onPointerUp` 閹?delta 閹广垻鐣绘稉?5 閸掑棝鎸撻崥鎼佹閺冨爼妫?+ dayWidth 閸掓浜哥粔浼欑礉鐠?`_moveTask` / `_resizeTaskStart` / `_resizeTaskEnd`
- 婢舵碍妫?bar 閸氬本鐗遍弨鐟板晸閿涘本瀵?`dayWidth` 鐠侊紕鐣婚弫鏉戙亯閸嬪繒些
- 缁夎濮╃粩?resize hot zone (`_ResizeHotZone`) 娴?36px 妤傛ê瀹虫担鍡楀箵 `Draggable` 閸氬氦骞忓妤佸閸斿じ绱崗鍫熸綀
- 閻栨湹鎹㈤崝锟犳毐閺?lane 閼奉亪鈧倸绨查敍姘瘻鐏炲倻楠囧ǎ鍗炲閹烘帒绨敍鍫熺壌娑撳绱氶敍瀹璦ne 閺佹澘濮╅幀渚婄礉>6 閺冭泛顔愰崳銊ユ祼鐎规岸鐝惔锕€鍞撮柈銊ф棻閸氭垶绮撮崝?
### TaskNewBloc 閻樿埖鈧椒绻氶悾娆掝潐閸掓瑱绱?026-05-31閿?
`_onLoadTasks` 閸?emit `TaskNewLoading` 閸撳秳绮犺ぐ鎾冲 `TaskNewLoaded` 娣囨繄鏆€娴犮儰绗呯€涙顔岄敍灞借嫙閸︺劍娓剁紒?`emit TaskNewLoaded` 閺冭泛鍟撻崶鐑囩窗
- `subTrees` / `expandedNodes`閿涘牆鍑￠張澶涚礆
- `viewMode`閿涘牊鏌婃晶鐑囩礉闁灝鍘ゅВ蹇旑偧 LoadTasks 閸氬骸娲栭柅鈧稉?'mindmap'閿?- `dateFrom` / `dateTo`閿涘牊鏌婃晶鐑囩礉闁灝鍘ら弮銉︽埂缁涙盯鈧娑径鎲嬬礆

鐠嬪啰鏁ら弬閫涚炊閸忋儳娈?`event.dateFrom`/`event.dateTo` 娴兼ê鍘涙禍搴濈箽閻ｆ瑥鈧》绱檂event.dateFrom ?? preservedDateFrom`閿涘鈧繖LoadTasks(clearDateRange: true)` 閺冭泛宸遍崚鑸靛Ω `dateFrom/dateTo` 缂?null閿涘牏鏁ゆ禍?濞撳懘娅庨弮銉︽埂缁涙盯鈧?閿涘苯鎯侀崚?`?? preserved` 娴兼矮绻氶悾娆愭＋缁涙盯鈧顕遍懛瀛樼娑撳秵甯€閿涘鈧?
### 娴犺濮熼崚娑樼紦閺冨爼妫块崘鑼崐婢跺嫮鎮婇敍?026-05-31閿?
- `TaskCreateSheet` 閸︺劋绱堕崗?`TaskRepository` 閺冭泛顕幍鈧張澶嬫煀瀵よ桨鎹㈤崝鈥充粵閺冨爼妫块崘鑼崐濡偓濞村绱濆鍦崶閺€顖涘瘮閸欐牗绉烽妴浣歌嫙鐞涘被鈧浇鍤滈崝銊ユ閸氬簺鈧浇鍤滈崝銊﹀絻閸忋儯鈧?- 閼奉亜濮╅幓鎺戝弳閻?`SubtaskScheduler.autoInsert` 鐠侊紕鐣婚敍姘簰閺傞鎹㈤崝鈥冲斧婵妞傞梻瀛橆唽娴ｆ粈璐熼崡鐘垫暏閸栨椽妫块敍灞藉涧缁夎濮╅張顏勭暚閹存劑鈧焦婀崚鐘绘珟娑撴梹婀佸鈧慨?閹搭亝顒涢弮鍫曟？閻ㄥ嫭妫﹂張澶夋崲閸斺槄绱辩悮顐ば╅崝銊ゆ崲閸斺€茬箽閹镐礁甯幐浣虹敾閺冨爼鏆遍敍灞惧瘻 09:00-21:00 瀹搞儰缍旈弮鑸殿唽閸?15 閸掑棝鎸撶紓鎾冲暱缁狙嗕粓閸氬海些閵?- `CreateTask.shiftedTasks` 閹煎搫鐢懛顏勫З閹绘帒鍙嗘禍褏鏁撻惃鍕倵缁夎崵绮ㄩ弸婊愮幢`TaskNewBloc._onCreateTask` 閸忓牆鍨卞鐑樻煀娴犺濮熼敍灞藉晙闁劖娼弴瀛樻煀鐞氼偄鎮楃粔璁虫崲閸旓紕娈?`startDate`/`dueDate`閿涘奔绠ｉ崥搴㈠⒔鐞涘苯甯張澶夌隘閸氬本顒為崪灞藉灙鐞涖劌鍩涢弬鑸偓?- 娴犺濮熸い鍨煀瀵ゆ亽鈧椒鎹㈤崝陇顕涢幆鍛摍娴犺濮熼弬鏉跨紦閵嗕焦妫╅崢鍡樻闂傜閰遍弬鏉跨紦閸у洣绱堕柅?`shiftedTasks` 閸?`CreateTask`閿涙稒妫╅崢鍡楀灡瀵ゅ搫鍙嗛崣锝呮倱濮濄儰绱堕崗?`TaskRepository` 娴犮儱鎯庨悽銊ユ倱閺嶉娈戦崘鑼崐婢跺嫮鎮婇妴?
### 閺冦儱宸婚懞鍌氫海閺冦儰绗屾导鎴炰紖閺冦儱鐫嶇粈鐚寸礄2026-05-31閿?
- `CalendarPage` 閹恒儱鍙?`HolidayService`閿涘本瀵滆ぐ鎾冲閼哄倸浜ｉ弮銉ユ禇鐎规湹绗岄獮缈犲敜閸旂姾娴囬獮鍓佺处鐎涙濡崑鍥ㄦ）閺佺増宓侀妴?- AppBar 閹绘劒绶甸懞鍌氫海閺冦儱娴楃€硅泛鍨忛幑顫幢閸掑洦宕查崥搴㈢缁屾椽銆夐棃銏犲敶閼哄倸浜ｉ弮銉х处鐎涙ê鑻熼柌宥嗘煀閸旂姾娴囪ぐ鎾冲楠炵繝鍞ら妴?- 閸涖劏顫嬮崶鐐）閺堢喎銇旈崪灞炬箑鐟欏棗娴橀弮銉︽埂閺嶇厧鐫嶇粈楦跨殶娴兼垼藟閻濐厹鈧焦纭剁€规俺濡崑鍥ㄦ）閵嗕焦娅橀柅姘噯閺堫偂绱ら幁顖涙）閿涙稐鑵戦崶鍊熕夐悵顓熸）娴兼ê鍘涙禍搴℃噯閺堫偂绱ら幁顖涚垼鐠佽埇鈧?- `HolidayService` 鐎甸€涜厬閸ュ€熷Ν閺冦儱顤冮崝鐘虫拱閸︽媽藟閸忓拑绱版俊鍥с偝閼哄倶鈧焦顦查弽鎴ｅΝ閵嗕線娼氶獮纾嬪Ν閵嗕礁鍔圭粩銉ㄥΝ閵嗕礁缂撻崗姘冲Ν閵嗕礁缂撻崘娑滃Ν閵嗕焦鏆€鐢牐濡敍娑滅箹娴滄稐濞囬悽?`HolidayType.observance`閿涘苯褰х仦鏇犮仛閼哄倹妫╅崥宥忕礉娑撳秵瀵滄导鎴炰紖閺冦儱顦╅悶鍡愨偓?# 2026-05-31 娑撳﹦鍤庢稉搴″綁閻滄澘鍣径鍥ㄦ瀮濡?
- 閺傛澘顤?`docs/launch/` 娴ｆ粈璐熸稉濠勫殠閸戝棗顦挧鍕灐閻╊喖缍嶉敍灞肩瑝閸欏倷绗屾潻鎰攽閺冭埖鐎鐚寸礉娑撳秵鏁奸崣?Flutter 娑撴艾濮熸禒锝囩垳閵?- `PLATFORM_RESEARCH_CN.md` 鐠佹澘缍嶆稉顓炴禇婢堆囨娑擃亙姹夊鈧崣鎴ｂ偓鍛畱娑撳﹦鍤庨獮鍐插酱闁瀚ㄩ敍姘额浕閸欐垵缂撶拋?Windows 鐎规缍?缁変礁鐓欓崚鍡楀絺 + 閸ヨ棄鍞寸€瑰宕滃〒鐘讳壕瀵洘绁﹂敍灞炬畯缂?Google Play 閸滃苯閽╅崣鏉垮敶鐠愵厹鈧?- `LAUNCH_CHECKLIST.md`閵嗕梗RISK_REGISTER.md`閵嗕梗RELEASE_EVIDENCE.md` 鐠佹澘缍嶆稉濠勫殠閺夋劖鏋￠妴渚€顥撻梽鈺佹嫲瑜版挸澧犻崣鎴濈鐠囦焦宓侀妴?- `PRIVACY_POLICY_DRAFT.md`閵嗕梗TERMS_OF_SERVICE_DRAFT.md`閵嗕梗STORE_LISTING_COPY.md`閵嗕梗PRICING_AND_GO_TO_MARKET.md` 鐠佹澘缍嶉梾鎰潌閺€璺ㄧ摜閼藉顢嶉妴浣烘暏閹村嘲宕楃拋顔垮磸濡楀牄鈧礁鏅㈡惔妤佹瀮濡楀牆鎷扮€规矮鐜?閼惧嘲顓归弬瑙勵攳閵?- 閺堫剚顐奸張顏呮纯閹?DeepSeek Key閿涘本婀穱顔芥暭 Android 缁涙儳鎮曢妴浣稿瘶閸氬秲鈧椒绗熼崝鈥插敩閻焦鍨ㄩ弸鍕紦閼存碍婀伴妴?
### 妫ｆ牠銆夐崥顖氬З瀵洖顕遍敍?026-05-31閿?
- `HomePage` 閸氼垰濮╅崥搴濈矝娴兼俺鐨熼悽?`PermissionService.showNotificationGuideIfNeeded` 閸嬫岸鈧氨鐓￠弶鍐瀵洖顕遍妴?- `HomePage` 娑撳秴鍟€閼奉亜濮╃捄瀹犳祮 `OnboardingPage`閿涘畭LocalStorageService.onboardingCompleted` 娑撳秴鍟€閸欏倷绗屾＃鏍€夐崥顖氬З鐎佃壈鍩呴崚銈嗘焽閵?
### 鐎涙劒鎹㈤崝鈥冲灡瀵ゆ椽绮拋銈夈€嶉惄顕嗙礄2026-05-31閿?
- `TasksPage` 娴犲簼鎹㈤崝鈩冪埐/閹繄娣€电厧娴橀悥鎯板Ν閻愯鏌婃晶鐐茬摍娴犺濮熼弮璁圭礉閸掓稑缂撳鍦崶閻ㄥ嫰绮拋銈夈€嶉惄顔荤喘閸忓牅濞囬悽銊у煑娴犺濮?`projectId`閿涘苯鍟€閸ョ偤鈧偓瑜版挸澧犳い鍦窗缁涙盯鈧鈧?- `TaskCreateSheet` 閸︺劌鍨垫慨瀣閸滃瞼鍩楁禒璇插娑撳濯洪崚鍥ㄥ床閺冭绱濇导姘瘻閹碘偓闁鍩楁禒璇插閸氬本顒?`_selectedProjectId`閿涘瞼鈥樻穱婵嗙摍娴犺濮熸妯款吇瑜版帒鐫橀悥鏈垫崲閸旓繝銆嶉惄顔衡偓?
### 妫ｆ牠銆夋禒璇插鐠囷附鍎忕粔璇插З缁旑垵绁┃鎰隘閿?026-05-31閿?
- `HomePage._buildResourceRow` 閹稿褰查悽銊ヮ啍鎼达箑鍨忛幑銏犵鐏炩偓閿涙碍顢戦棃顫箽閹镐礁鐡欐禒璇插/闂勫嫪娆?濡偓閺屻儵銆嶅Ο顏呭笓閿涙稓鐛庣仦蹇庣瑓鐎涙劒鎹㈤崝鈥冲礋閻欘兛绔寸悰宀嬬礉闂勫嫪娆㈤崪灞绢梾閺屻儵銆嶇紒鍕灇閻欘剛鐝涚挧鍕爱鐞涘被鈧?
### 娴犺濮熼崚鐘绘珟鐠恒劎顏崥灞绢劄閿?026-05-31閿?
- `TaskRepository.syncFromJson` 鐎电绻欑粩?`deleted=1` 婢ф挾鐓舵担璺ㄦ暏 `updatedAt` 閸?LWW閿涙俺绻欑粩顖涙纯閺傜増妞傜憰鍡欐磰閺堫剙婀村ú璁虫崲閸斺槄绱濋張顒€婀撮弴瀛樻煀閺冩儼鐑︽潻鍥箖閺堢喎顣搁惌鐐解偓?- `TaskSyncService.syncAll` 娑撳秴鍟€閻劍婀伴崷鐗堟た娴犺濮熼弮鐘虫蒋娴犳儼顩惄鏍︾隘缁旑垰顣搁惌绛圭礉闁灝鍘ら柌宥呮儙閸忋劑鍣虹€电澶勯弮鑸靛Ω閸欙缚绔寸粩顖氬嚒閸掔娀娅庨惃鍕偓婵堟樊鐎电厧娴橀懞鍌滃仯婢跺秵妞块妴?- `TaskSyncService` 婢х偛濮?`changes` 楠炴寧鎸遍敍娌桯omePage` 閻╂垵鎯夋禒璇插閸氬本顒為崣妯绘纯楠?debounce 鐟欙箑褰?`LoadTasks`閿涘矁顔€娴犺濮熸い?閹繄娣€电厧娴橀崷銊ㄧ箼缁旑垱鏌婃晶鐐偓浣规纯閺傝埇鈧礁鍨归梽銈呮倵閸掗攱鏌婇妴?
### 閹靛婧€妤犲矁鐦夐惍浣烘瑜版洩绱?026-05-31閿?
- `SupabaseService` 鐏忎浇顥?`signInWithOtp(phone: ...)` 閸欐垿鈧胶鐓穱锟犵崣鐠囦胶鐖滈敍灞界殱鐟?`verifyOTP(type: OtpType.sms)` 閺嶏繝鐛欐宀冪槈閻礁鑻熸潻鏂挎礀 Supabase 閻劍鍩涙导姘崇樈閵?- `AuthBloc` 閺傛澘顤?`PhoneOtpRequested`閵嗕梗PhoneOtpVerified`閵嗕梗PhoneOtpSent`閿涘本澧滈張鍝勫娇妤犲矁鐦夐惍浣烘瑜版洘鍨氶崝鐔锋倵鏉╂稑鍙嗛悳鐗堟箒 `Authenticated` 閻樿埖鈧降鈧?- `LoginPage` 婢х偛濮為柇顔绢唸/閹靛婧€妤犲矁鐦夐惍浣烘瑜版洘膩瀵繐鍨忛幑顫幢閹靛婧€閸欒渹绗夌敮?`+` 娑撴柧璐熸稉顓炴禇婢堆囨 11 娴ｅ秵澧滈張鍝勫娇閺冩儼鍤滈崝銊ㄋ?`+86`閵?
### 閸忋劌鐪幒鎺楁珟妞ゅ湱娲伴敍?026-05-31閿?
- `LocalStorageService.excludedProjectIds` 娴ｈ法鏁?SharedPreferences 閹镐椒绠欓崠鏍ㄥ笓闂勩倝銆嶉惄?ID 閸掓銆冮妴?- `TaskNewBloc._onLoadTasks` 閸︺劌濮炴潪鎴掓崲閸斺€冲灙鐞涖劌鎷扮拋锛勭暬鏉╂稑瀹抽崜宥嗗笓闂勩倛绻栨禍娑€嶉惄顕嗙幢鐞氼偅甯撻梽銈夈€嶉惄顔荤瑝鏉╂稑鍙嗘禒璇插妞ら潧鍨悰銊ｂ偓浣光偓婵堟樊鐎电厧娴橀崪宀冪箻鎼达箒顓哥粻妞尖偓?- `HomePage` 閺嬪嫬缂撴＃鏍€夐弮鍫曟？鏉炲瓨鏆熼幑顔煎閹烘帡娅庢潻娆庣昂妞ゅ湱娲伴敍灞芥礈濮濄倖妞傞梻纾嬮叡閵嗕胶绮虹拋鈥虫嫲閸ユ稖钖勯梽鎰綆娴ｈ法鏁ら幒鎺楁珟閸氬海娈戞禒璇插闂嗗棗鎮庨敍娑㈩浕妞ょ敻銆嶉惄顔剧摣闁濮搁幀浣峰▏閻劑銆嶉惄?ID 闂嗗棗鎮庨敍宀冾吀缁犳瀵滈梿鍡楁値鏉╁洦鎶ら敍瀛禝 娣囨繄鏆€韫囶偊鈧喎宕熼柅澶夌瑓閹峰鑻熼幓鎰返婢舵岸鈧鑴婄粣妤€鍙嗛崣锝冣偓?- `CalendarPage` 閸旂姾娴囬弮銉ュ坊娴犺濮熼弮鑸靛笓闂勩倛绻栨禍娑€嶉惄顕嗙幢閺冦儱宸绘い鍦窗缁涙盯鈧濮搁幀浣峰▏閻劑銆嶉惄?ID 闂嗗棗鎮庨敍宀冨綅閸楁洟銆嶉崣顖氼樋闁?閸欐牗绉烽妴?- `TaskNewBloc` 閻?`LoadTasks.projectIds` 娑?`TaskNewLoaded.selectedProjectIds` 閹佃儻娴囨禒璇插濡€虫健婢舵岸銆嶉惄顔剧摣闁绱辨禒璇插妞?AppBar 閹绘劒绶垫い鍦窗婢舵岸鈧鐡柅澶婂弳閸欙絽鎷伴垾婊勫笓闂勩倝銆嶉惄顔光偓婵嗩樋闁顔曠純顔煎弳閸欙絻鈧?
### 閹绘劙鍟嬮柅姘辩叀閿?026-05-31閿?
- `NotificationService` 鐠愮喕鐭楅張顒€婀撮幓鎰板晪鐠嬪啫瀹抽妴鍌溞╅崝銊ь伂娴ｈ法鏁?`flutter_local_notifications` 閻?`zonedSchedule`閿涘矁鐨熸惔锕€澧犻崗婊冪俺鐠囬攱鐪伴柅姘辩叀閺夊啴妾洪敍姹歯droid 閸氬本顒炵拠閿嬬湴缁墽鈥橀梻褰掓寭閺夊啴妾洪敍瀹∣S 閸撳秴褰寸仦鏇犮仛閺勬儳绱￠崥顖滄暏 alert/badge/sound閵?- 濡楀矂娼扮粩顖欑矝閻劏绻樼粙瀣敶 `Timer` 鐟欙箑褰傞幓鎰板晪閿涙矅indows 鐟欙箑褰傞崥搴㈡暭娑?PowerShell `MessageBox` 鐢悂鈹楀鍦崶閿涘瞼鏁ら幋椋庡仯閸?OK 閸撳秳绗夋导姘冲殰閸斻劍绉锋径渚库偓?- `PermissionService.showNotificationGuideIfNeeded` 娴犲秴褰ч崷銊╅崝銊ь伂妫ｆ牗顐肩仦鏇犮仛闁氨鐓￠弶鍐瀵洖顕遍敍姹歯droid 绾喛顓婚崥搴℃倱閺冨墎鏁电拠鐑解偓姘辩叀閺夊啴妾洪崪宀€绨跨涵顕€妞嗛柦鐔告綀闂勬劑鈧?
### 妞ゅ湱娲伴崚鍡欑矋娓氀嗙珶閺嶅繐鐫嶇粈鐚寸礄2026-06-01閿?
- `ProjectSidebar` 閹恒儲鏁?`projects` 娑?`groups`閿涘苯婀笟褑绔熼弽蹇斿瘻閸掑棛绮嶅〒鍙夌厠妞ゅ湱娲伴妴?- 缁屽搫鍨庣紒鍕暠 `_buildGroupedProjects()` 娑擃厾娈?`ExpansionTile` 鐏炴洜銇氶敍灞藉祮娴ｅ灝鍨庣紒鍕瑓濞屸剝婀佹い鍦窗娑旂喐妯夌粈琛♀偓婊勬畯閺冪娀銆嶉惄顔光偓婵嗗窗娴ｅ秲鈧?- 娴犲懎缍?`projects` 娑?`groups` 閸氬本妞傛稉铏光敄閺冭绱濇笟褑绔熼弽蹇斿鐏炴洜銇氶弫缈犵秼缁岃櫣濮搁幀浣碘偓?
### 妞ゅ湱娲版笟褎鐖崚鍡欑矋鐏炴洖绱戞稉搴㈡闂傚瓨甯撴惔蹇ョ礄2026-06-01閿?
- `TasksPage` 缂佸瓨濮㈡い鍦窗娓氀勭埉閸掑棛绮嶇仦鏇炵磻闂嗗棗鎮庨敍娑㈩浕濞嗏€冲鏉炶姤鍨ㄩ弬鏉款杻閸掑棛绮嶆妯款吇鐏炴洖绱戦敍灞炬煀瀵ゆ椽銆嶉惄顕€鈧瀚ㄩ崚鍡欑矋閸氬簼绱伴崷銊︽烦閸?`CreateProject` 閸撳秵濡哥拠銉ュ瀻缂佸嫬濮為崗銉ョ潔瀵偓闂嗗棗鎮庨妴?- `ProjectSidebar` 閻ㄥ嫬鍨庣紒鍕潔瀵偓閻樿埖鈧胶鏁?`expandedGroupIds` 閹貉冨煑閿涘奔绗夐崘宥勭贩鐠?`ExpansionTile` 閻?PageStorage 鐠佹澘绻傞敍娑欑垼妫版顢戦幓鎰返閸忋劑鍎寸仦鏇炵磻閵嗕礁鍙忛柈銊︽暪缂傗晛鎷伴弮鍫曟？閹烘帒绨弬鐟版倻閸掑洦宕查妴?- 妞ゅ湱娲版笟褎鐖仦鏇犮仛鐏炲倹瀵?`createdAt` 鐎电懓鍨庣紒鍕嫲缂佸嫬鍞存い鍦窗閹烘帒绨敍灞肩瑝娣囶喗鏁奸弫鐗堝祦鎼存挻甯撴惔蹇撶摟濞堢绱遍幒鎺戠碍閺傜懓鎮滈柅姘崇箖 `LocalStorageService.projectSidebarTimeSortDesc` 閸愭瑥鍙?SharedPreferences閿涘矂绮拋銈呪偓鎺戠碍閵?### 妫ｆ牠銆夊畵灞筋殰濠婃俺鐤嗘潏鍦櫕閿?026-06-01閿?- `HomePage` 娑撴椽顩绘い鍨闂傜閰辨禒璇插閼哄倻鍋ｉ妴浣锋崲閸斅ゎ嚊閹懘妾禒璺哄隘閸滃本顥呴弻銉┿€嶉崠鍝勵杻閸旂姴鐪柈銊╃炊閺嶅洦绮存潪顔跨珶閻ｅ矉绱辨潏鍦櫕闁俺绻?`Listener.onPointerSignal` 濞夈劌鍞?`PointerScrollEvent`閿涘矂浼╅崗宥堢箹娴滄稑鐪柈銊ュ隘閸╃喓娈戝姘崇枂娴滃娆㈢紒褏鐢荤憴锕€褰傛径鏍х湴妫ｆ牠銆?`CustomScrollView` 娑撳﹣绗呭姘З閵?- 妫ｆ牠銆夐梽鍕閸栧搫顦查悽?`AttachmentSection`閿涘苯顦荤仦鍌氼杻閸?`ConstrainedBox(maxHeight: 240)` 閸滃苯鐪柈?`SingleChildScrollView`閿涘矂妾禒鎯扮窛婢舵碍妞傞崷銊╂娴犺泛灏崘鍛村劥濠婃艾濮╅敍灞肩瑝閺€鐟板綁闂勫嫪娆㈡稉濠佺炊閵嗕焦澧﹀鈧妴浣稿灩闂勩倝鈧槒绶妴?

### 鏃ュ巻鍙抽敭璺宠浆鎬濈淮瀵煎浘鑺傜偣锛?026-06-01锛?- `CalendarPage` 鏀寔鎺ユ敹 `onJumpToMindMap` 鍥炶皟锛屾棩鍘嗕换鍔″垪琛ㄩ」銆佸崟鏃ユ椂闂村潡鍜屽鏃ヤ换鍔℃潯鍙抽敭璋冪敤璇ュ洖璋冿紝涓嶅啀鎶婂崟鏃ユ椂闂村潡鍙抽敭鐩存帴缁戝畾鍒板垹闄ゃ€?- `HomePage` 灏嗘棩鍘嗚烦杞洖璋冭浆鎹负搴曢儴瀵艰埅鍒囧埌浠诲姟椤碉紝骞跺悜 `TaskNewBloc` 娲惧彂甯?`focusTaskId/focusRequestToken` 鐨?`LoadTasks`銆?- `TaskNewBloc` 鍦ㄥ甫鑱氱劍浠诲姟鐨勫姞杞借姹備腑鍒囨崲鍒?`mindmap` 瑙嗗浘銆佹竻闄ゆ棩鏈熻繃婊ゃ€佷繚鐣欓」鐩繃婊わ紝骞跺睍寮€鐩爣浠诲姟绁栧厛鑺傜偣锛沗TaskNewLoaded` 淇濆瓨鑱氱劍浠诲姟 ID 涓庤姹?token銆?- `TasksPage` 灏嗚仛鐒﹁姹傞€忎紶缁?`MindMapView`锛沗MindMapView` 娑堣垂涓€娆?token 鍚庡眳涓苟閫変腑瀵瑰簲鑺傜偣锛屾壘涓嶅埌鍙鑺傜偣鏃舵樉绀鸿交鎻愮ず銆?
### 妗岄潰鏈湴鏁版嵁鍖栨ā寮忥紙2026-06-01锛?- `LoginPage` 鍦?Windows/macOS/Linux 鏄剧ず鈥滀笉鐧诲綍锛屾湰鍦颁娇鐢ㄢ€濆叆鍙ｏ紝鐩存帴杩涘叆 `LocalAuthenticated(email: local_desktop)`锛涗簯绔偖绠?鎵嬫満鍙风櫥褰曟祦绋嬩笉浣跨敤璇ュ叆鍙ｃ€?- `LocalDataService` 缁熶竴瑙ｆ瀽鏈湴鏁版嵁鐩綍銆傛湭閰嶇疆鐩綍鏃剁户缁娇鐢ㄧ郴缁熷簲鐢ㄦ枃妗ｇ洰褰曪紱閰嶇疆鍚?Drift 鏁版嵁搴撴枃浠朵娇鐢?`{鐩綍}/smart_assistant.db`锛岄檮浠剁紦瀛樹娇鐢?`{鐩綍}/task_attachments`銆?- `AppDatabase` 鎵撳紑鏁版嵁搴撳墠閫氳繃 `LocalDataService.databaseFile()` 鑾峰彇鏂囦欢璺緞锛屽苟鎻愪緵 `checkpointForBackup()` 鍦ㄧ洰褰曞垏鎹㈡垨瀵煎嚭鍓嶆墽琛?SQLite WAL checkpoint銆?- `TaskAttachmentService` 鐨勬湰鍦伴檮浠舵牴鐩綍鏀逛负 `LocalDataService.attachmentsDirectory()`锛屼娇鏈湴妯″紡涓嬮檮浠朵笌鏁版嵁搴撹繘鍏ュ悓涓€鏁版嵁鐩綍銆?- `LocalStorageService` 鍐欏叆鏈湴鐢ㄦ埛銆佹棩绋嬨€佹棫鏈湴浠诲姟銆佽祫鏂欏拰鍋忓ソ鍚庯紝浼氬埛鏂?`{鐩綍}/preferences.json` 蹇収銆?- `ProfilePage` 浠呭湪妗岄潰绔?`LocalAuthenticated` 鐘舵€佷笅鍚?`AppSettingsPage` 浼犲叆鏈湴鏁版嵁宸ュ叿寮€鍏筹紱浜戠 `Authenticated` 鐘舵€佷笉鏄剧ず鏈湴鏁版嵁鐩綍銆佸鍏ャ€佸鍑哄叆鍙ｃ€?- `AppSettingsPage` 鏈湴鏁版嵁宸ュ叿鏀寔閫夋嫨淇濆瓨浣嶇疆銆佸鍏?zip 澶囦唤銆佸鍑?zip 澶囦唤銆備繚瀛樹綅缃細澶嶅埗褰撳墠鏁版嵁搴撱€侀檮浠跺拰 SharedPreferences 蹇収锛屽苟鍦ㄩ噸鍚悗鐢熸晥锛涘鍏ヤ細瑙ｅ帇鍒版柊鐨勬湰鍦版暟鎹洰褰曞苟鏇存柊閰嶇疆锛岄噸鍚悗鐢熸晥銆?> 2026-06-01: 鏃ュ巻鍛ㄨ鍥鹃《閮ㄨ法澶╀换鍔℃潯璋冩暣澧炲己銆俙CalendarPage` 鐨?`_EditableMultiDayBar` 妗岄潰绔乏鍙宠皟鏁寸儹鍖轰粠 18px 鎵╁ぇ鍒?32px锛涜法澶╂潯淇濆瓨鍓嶉€氳繃 `descendantTaskTimeRange` 鍩轰簬 `_allTasks` 閫掑綊璁＄畻鐖朵换鍔″叏閮ㄦ湭鍒犻櫎鍚庝唬鐨勬渶鏃╁紑濮嬪拰鏈€鏅氱粨鏉燂紝鐖朵换鍔℃柊鏃堕棿鑼冨洿鏈鐩栨墍鏈夊瓙浠诲姟鏃堕棿娈垫椂鎷掔粷鏇存柊骞舵彁绀恒€傛湭鏀?Drift 琛ㄣ€佷粨搴?API銆丅loc 浜嬩欢鎴栬法澶╀换鍔″睍绀鸿鍒欍€?> 2026-06-02: 鎬濈淮瀵煎浘浠诲姟鍒锋柊淇濈暀褰撳墠椤圭洰绛涢€夈€俙LoadTasks` 鏂板 `hasProjectSelectionOverride` 鍙鏍囪锛岃８ `LoadTasks()` 琛ㄧず鎸夊綋鍓?`TaskNewLoaded` 鐨勯」鐩€佷换鍔＄被鍨嬨€佹棩鏈熷拰瑙嗗浘鐘舵€佸埛鏂帮紱鏄惧紡浼犲叆 `projectId/projectIds` 鏃舵墠瑕嗙洊椤圭洰绛涢€夈€俙TaskNewBloc` 鍒涘缓浠诲姟鍚庡湪鏈湴涔愯鍒锋柊蹇収涓睍寮€鏂颁换鍔＄殑鐖堕摼骞跺啓鍏?`focusTaskId/focusRequestToken`锛屼娇鎬濈淮瀵煎浘鍒囧埌鐩爣鑺傜偣锛沗TasksPage` 涓嶅啀鍦ㄥ脊绐楄繑鍥炲悗鍩轰簬鏃?state 棰濆鍒囨崲灞曞紑銆俙AppDatabase` 榛樿鏋勯€犱粛浣跨敤鏈湴鏂囦欢锛屾祴璇曞彲浼犲叆 `QueryExecutor` 浣跨敤鍐呭瓨鏁版嵁搴撱€?
## 2026-06-02 浠诲姟璇︽儏鍥剧墖銆侀」鐩瓫閫変笌 Android 鎻愰啋

- 鏂扮増浠诲姟璇︽儏鎻忚堪鍖烘敮鎸佹闈㈢ Ctrl+V 绮樿创鍥剧墖鍜屾嫋鍏ュ浘鐗囷紝鍏ュ彛浣嶄簬 `TaskDetailPage._buildDescriptionBox`锛涘浘鐗囬€氳繃 `TaskAttachmentService.saveImageBytes` 浠ュ瓧鑺傚舰寮忚惤鐩橈紝骞跺啓鍏?`task_attachments` 鍏冩暟鎹€?- 闄勪欢瀛楄妭淇濆瓨澶嶇敤鏈湴闄勪欢鐩綍锛涘瓨鍦?Supabase 鐧诲綍鐢ㄦ埛鏃剁户缁笂浼?Storage 鍜屽悓姝ラ檮浠跺厓鏁版嵁锛屾湰鍦版ā寮忎笅鍙繚瀛樻湰鍦版枃浠朵笌鏁版嵁搴撹褰曘€?- 棣栭〉鍜屾棩鍘嗛」鐩瓫閫夊鐢?`project_picker_content.dart`锛屼互鈥滈」鐩垎绫?-> 椤圭洰鈥濈殑澶氶€夌粨鏋勯€夋嫨椤圭洰锛屽苟鏀寔娓呯┖绛涢€夈€?- 鏃х増浠诲姟璇︽儏鎻愰啋璁剧疆鏇存柊鍚庝細閫氳繃 `SupabaseService.syncLocalTasks` 鍚屾鏃ф湰鍦颁换鍔℃暟鎹紱鏂扮増璇︽儏椤电户缁娇鐢ㄧ幇鏈?`UpdateTask` 閾捐矾銆?- Android 鏈湴鎻愰啋鍒濆鍖栨椂璁剧疆鏈湴鏃跺尯锛岄€氱煡 ID 浣跨敤绋冲畾绠楁硶锛涘惎鍔ㄥ悓姝ユ垨浜戠鍙樻洿钀藉簱鍚庯紝绉诲姩绔細瀵规湭鏉ヤ笖鍚敤鎻愰啋鐨勪换鍔￠噸鏂版帓绋嬶紝鍏抽棴鎻愰啋鏃跺彇娑堝搴旈€氱煡銆?- Android Manifest 娉ㄥ唽 `ScheduledNotificationReceiver`锛涙彁閱掓潈闄愬紩瀵艰鐩栭€氱煡銆佺簿纭椆閽熷拰鍚庡彴杩愯/鐢垫睜浼樺寲璁剧疆銆?

---

## 2026-06-04: Reasonix 全局记忆钩子系统

### 新架构组件

| 组件 | 路径 | 职责 |
|------|------|------|
| 插件清单 | .codex-plugin/.codex-plugin/plugin.json | 注册 pre-execution-hook 技能和校验脚本 |
| 钩子技能 | .codex-plugin/skills/pre-execution-hook/SKILL.md | 22 条记忆规则的 6 阶段预执行流程 |
| 钩子配置 | .codex-plugin/hooks/pre-execution.json | 声明钩子触发时机和优先级 |
| 安装脚本 | .codex-plugin/scripts/install_hook.ps1 | 安装/验证钩子状态 |
| 数据源 | C:\\Users\\Administrator\\.reasonix\\memory\\global\\ | 原始 22 条记忆规则文件 |
| marketplace | ~/.agents/plugins/marketplace.json | 插件发现入口 |

### 钩子 6 阶段流程

用户请求 -> [阶段1 回复格式] -> [阶段2 门禁检查] -> [阶段3 修改执行] -> [阶段4 改后维护] -> [阶段5 回复前自检] -> 输出回复

阶段1(回复格式): 强制输出 [记忆执行情况] 头 + [老板] 前缀
阶段2(改前门禁): codegraph 工具可用性检查 -> graphify query -> codegraph impact/context/callers -> 选择题征询
阶段3(修改执行): 追溯数据流 -> 反补丁检查 -> 一次只改一件事
阶段4(改后维护): graphify update -> ARCHITECTURE.md -> CHANGELOG.md
阶段5(回复前自检): 格式头 + Summary/Files/Tests/Risks/Next

### 外部触发词

| 用户说 | 行为 |
|--------|------|
| 跑技能 | 触发 force-load-global-memories subagent |
| 粘贴 force-load-global-memories | 完整逐条 recall_memory |
| 格式 | 强制自检回复格式 |
