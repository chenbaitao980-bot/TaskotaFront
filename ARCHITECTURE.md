# Architecture

> 2026-06-01: 子任务创建的冲突检测、自动延后和自动插入统一只把 `parentId != null` 的未完成、未删除、非跨天子任务作为时间占用。`TaskCreateSheet` 通过 `isSubtaskTimingOccupantForTaskCreateSheet` 过滤传入 `SubtaskScheduler` 的任务集合，父任务、普通根任务和跨天长条不再阻塞子任务排程；`SubtaskScheduler` 本身仍保持通用排程能力。

> 2026-06-01: 日历周视图顶部多日任务横条支持折叠展开。`CalendarPage` 通过 `_isMultiDayLaneCollapsed` 控制 `_buildMultiDayLane` 的展示状态：展开时保留原有最多 6 行可纵向滚动横条和右上折叠按钮；折叠时隐藏所有横条，仅保留 30px 高的展开按钮行并显示跨天任务数量。任务模型、仓库、Bloc、排程和 `_isMultiDayTask` 判定逻辑未改动。

> 2026-06-01: 任务页任务变更链路改为本地乐观刷新。`TaskNewBloc` 在创建、更新、删除、完成切换、移动父节点和同级排序时先执行本地 Drift 写入并刷新当前 `TaskNewLoaded`，再调用 `TaskSyncService.syncAll(rethrowErrors: true)` 做云端对账；同步失败时通过 `TaskRepository.restoreRawTasks()` 恢复任务表快照，并在任务页提示“同步失败，已回退本次操作”。`TaskRepository` 的任务写入方法保留默认即时同步行为，同时新增 `syncImmediately` 可选参数供任务页跳过单行 push。
> 2026-06-01: 瀵煎嚭绛涢€変慨姝ｃ€傗€滃叏閮ㄩ」鐩€濆鍑烘椂 `TaskExportPage` 鍚?`TaskExportService` 浼犵┖椤圭洰闆嗗悎琛ㄧず涓嶆寜椤圭洰杩囨护锛屽洜姝や細鍖呭惈 `tasks.projectId` 涓嶅湪褰撳墠椤圭洰鍒楄〃涓殑鈥滄湭鍒嗛厤/鏈尮閰嶉」鐩€濅换鍔★紱鏈嶅姟缁х画灏嗚繖绫讳换鍔″啓鍏ョ嫭绔嬬殑鏈尮閰嶉」鐩?Sheet銆?
> 2026-06-01: 鎬濈淮瀵煎浘鏂板鑺傜偣杩炵嚎鍔熻兘銆俙_MindMapNodeCard` 鐨?`+` 鎸夐挳闀挎寜瑙﹀彂 `onConnectStart/Update/End/Cancel` 鍥炶皟閾撅紝`_MindMapViewState` 灏嗛暱鎸夌Щ鍔ㄥ潗鏍囷紙button-local 鈫?node-space锛夋崲绠楀悗鍐欏叆 `_connectingEndPos`锛宍_MindMapLinesPainter` 鏂板 `connectingFrom`/`connectingTo` 鍙傛暟锛岀敤 `PathMetric` 铏氱嚎缁樺埗姗＄毊绛嬭礉濉炲皵锛涙澗鎵嬫椂 `_hitTestNode` 鍛戒腑鍒ゆ柇鐩爣鑺傜偣骞惰皟鐢ㄥ凡鏈?`onMoveToParent(targetId, sourceId)`銆傚彸閿偣鍑昏繛绾垮尯鍩燂細`GestureDetector.onSecondaryTapUp` 瀵硅礉濉炲皵涓偣鍋?24px 璺濈鍛戒腑妫€娴嬶紝鍛戒腑鍚?`showMenu` 鎻愪緵"鏂紑杩炴帴"閫夐」銆俙_onMoveTaskToParent` 鍦?`moveTask` 鍚庤嚜鍔ㄦ墿灞曠埗鑺傜偣 `startDate`/`dueDate` 浠ュ寘鍚瓙鑺傜偣鏃ユ湡鑼冨洿銆傛棩鍘?`_isMultiDayTask` 宸叉鏌?`_hasChildren`锛岀埗鑺傜偣杩炵嚎鍚庤嚜鍔ㄥ湪椤堕儴妯潯鍛堢幇銆?
> 2026-06-01: 鐧诲綍椤垫畫鐣欎贡鐮佹枃妗堟敼鍥炰腑鏂囷紱鏍硅矾鐢卞湪 `AuthLoading`銆乣PhoneOtpSent`銆乣AuthError` 绛夐潪璁よ瘉鎴愬姛鐘舵€佷笅缁х画娓叉煋鍚屼竴涓?`LoginPage`锛岄伩鍏嶆墜鏈洪獙璇佺爜鍙戦€佹祦绋嬩腑椤甸潰鍗歌浇瀵艰嚧鏈湴 `_otpSent` 鐘舵€佷涪澶便€俙AuthBloc` 閽堝鎵嬫満鍙锋牸寮忓拰 Supabase Phone Auth/SMS Provider 鏈惎鐢ㄦ垨鏈厤缃殑閿欒杩斿洖涓枃鎻愮ず銆傛垜鐨勬ā鍧楁柊澧炰换鍔″鍑洪摼璺細`ProfilePage` 鎺ュ叆 `TaskExportPage`锛岃鍙栫幇鏈?`TaskRepository`/`ProjectRepository` 鏁版嵁锛沗TaskExportService` 浣跨敤 `excel` 鍖呯敓鎴?`.xlsx`锛屽啀鐢?`archive`/`xml` 鍐欏叆鍐荤粨绐楁牸 OpenXML锛屾寜椤圭洰鎷嗗垎 Sheet锛屾寜浠诲姟鐖跺瓙鍏崇郴 DFS 杈撳嚭鏍戝舰缂╄繘琛岋紝绛涢€夋潯浠跺寘鎷换鍔℃椂闂磋寖鍥寸浉浜ゃ€侀」鐩閫夊拰閲嶈绾у埆澶氶€夛紝涓嶄慨鏀?Drift 琛ㄧ粨鏋勬垨鍚屾鍗忚銆?
> 2026-06-01: 鎴戠殑妯″潡璧勬枡缂栬緫鍔熻兘钀藉湴銆俙ProfilePage` 浠?`LocalStorageService.getExplicitProfile()` 璇诲彇鐢ㄦ埛涓诲姩濉啓鐨勬樉寮忚祫鏂欙紝澶撮儴灞曠ず鏄电О鍙娾€滆亴涓?韬唤 路 鎵€鍦ㄥ煄甯傗€濓紝璐﹀彿閭/鎵嬫満鍙蜂粎浣滀负鍙璁よ瘉淇℃伅浼犵粰 `ProfileEditPage`銆俙ProfileEditPage` 鍏佽缂栬緫鏄电О銆佽亴涓氭垨韬唤銆佹墍鍦ㄥ煄甯傘€佺洰鏍囧煄甯傘€佷富瑕佺洰鏍囷紱淇濆瓨鏃剁户缁啓鍏?`LocalStorageService.saveExplicitProfile()`锛屽苟鍚屾椂缁存姢 `primaryGoals` 涓庡巻鍙?`goals` 閿互鍏煎 onboarding 宸叉湁鏁版嵁缁撴瀯銆傚綋鍓嶈祫鏂欑紪杈戜笉鍐欏叆 Supabase `user_profiles`銆?
> 2026-05-31: 鏈淇淇濈暀鐜版湁 Drift `tasks.parentId` 鈫?Supabase `user_tasks.parent_id` 閫愯鍚屾鏋舵瀯锛沗TaskNewBloc` 鐨勪换鍔″悓姝ュ叆鍙ｆ敼涓鸿皟鐢?`TaskSyncService.syncAll()`锛屼笉鍐嶉€氳繃鏃?`local_task_sync.tasks_data` JSON 璺緞鍚屾浠诲姟鏍戙€俙TaskSyncService` 鏆撮湶绾槧灏勬柟娉曠敤浜庨獙璇?`parent_id`/`parentId` 杞崲銆備腑鍥借妭鍋囨棩灞曠ず鍦?`HolidayService` 涓鍔?2026 骞村姵鍔ㄨ妭鏈湴鍏滃簳瑕嗙洊锛岃ˉ榻?2026-05-01 鑷?2026-05-05 浼戞伅鏃ュ拰 2026-04-26銆?026-05-09 琛ョ彮鏃ャ€傜Щ鍔ㄧ棣栭〉浠诲姟璇︽儏璧勬簮鍖轰繚鎸佸悓涓€鏁版嵁鏉ユ簮锛屼絾绐勫睆涓嬮檮浠跺拰妫€鏌ラ」鏀逛负绾靛悜鍒嗗尯灞曠ず锛涙闈㈢浠嶄负妯悜甯冨眬銆傛垜鐨勯〉閫€鍑虹櫥褰曠敱 `ProfilePage` 娲惧彂 `AuthBloc.LoggedOut`銆?
> 2026-05-31: 鎬濈淮瀵煎浘浠诲姟瑙嗗浘鏂板涓€娆℃€р€滆嚜鍔ㄩ攣瀹氣€濊瑙掑畾浣嶃€俙lib/presentation/pages/tasks/widgets/mind_map_view.dart` 澶嶇敤 `TransformationController`锛屾寜褰撳墠鍙鑺傜偣鐨?`startDate ?? dueDate` 涓庡綋鍓嶆椂闂磋窛绂婚€夋嫨鏈€杩戜换鍔★紝骞跺湪淇濇寔褰撳墠缂╂斁姣斾緥鐨勬儏鍐典笅骞崇Щ鐢诲竷鍒拌鑺傜偣涓績锛涜妭鐐瑰潗鏍囦娇鐢?`_positionNotifiers`锛屽洜姝ゆ敮鎸佹墜鍔ㄦ嫋鍔ㄥ悗鐨勫疄闄呬綅缃€?
> 2026-05-31: 鏂板鐙珛闈欐€佺珯鐐?`personal_admin_site/`锛岀敤浜庝釜浜哄姩鎬佸瘑閽ャ€佸姩鎬佹暟鎹拰 App 绠＄悊銆傜珯鐐圭敱 `index.html`銆乣styles.css`銆乣app.js`銆乣config.js`銆乣config.example.js`銆乣supabase.sql` 鍜?`README.md` 缁勬垚锛屼笉鎺ュ叆鐜版湁 Flutter 搴旂敤杩愯鏃躲€傚墠绔€氳繃 Supabase JS CDN 浣跨敤 Email OTP 鐧诲綍锛沗supabase.sql` 瀹氫箟 `allowed_users`銆乣dynamic_secrets`銆乣dynamic_data`銆乣managed_apps` 鍥涘紶琛紝鍚敤 RLS锛屽苟瑕佹眰鐧诲綍閭瀛樺湪浜?allowlist銆傚瘑閽ュ€煎湪娴忚鍣ㄧ浣跨敤 WebCrypto PBKDF2 + AES-GCM 鍔犲瘑鍚庝繚瀛橈紝鍙ｄ护涓嶄笂浼犮€佷笉钀藉簱銆傛帹鑽愰儴缃茬粨鏋勪负 Cloudflare Pages 闈欐€佹墭绠?+ Supabase 鍏嶈垂灞傘€?
> 2026-05-31: `personal_admin_site/` 琛ュ厖 Cloudflare Pages 鍙戝竷閰嶇疆鍜屼笂绾挎鏌ャ€俙_headers` 瀹氫箟闈欐€佺珯瀹夊叏鍝嶅簲澶达紱`DEPLOYMENT_PLAN.md` 璁板綍 Cloudflare Pages + Supabase 鍏嶈垂灞傜殑 0 缇庡厓鍥哄畾鎴愭湰鏂规銆佸畼鏂逛緷鎹摼鎺ュ拰涓婄嚎姝ラ锛沗deploy-check.ps1` 鍦ㄥ彂甯冨墠妫€鏌ュ繀瑕佹枃浠躲€侀樆姝㈠崰浣?Supabase 閰嶇疆銆侀樆姝?`sbp_`/`service_role` 绛夋晱鎰熷瘑閽ヨ繘鍏ュ墠绔紝骞舵墽琛?`node --check app.js`銆?
> 2026-05-31: `personal_admin_site/` 琛ュ厖涓ょ閰嶇疆鐢熸垚璺緞锛欳loudflare Pages 浠撳簱閮ㄧ讲鏃舵墽琛?`build-cloudflare.sh`锛屼粠 `PUBLIC_SUPABASE_URL` 鍜?`PUBLIC_SUPABASE_ANON_KEY` 鐢熸垚 `config.js`锛涙湰鍦?Direct Upload 鍓嶅彲鎵ц `build-local.ps1` 鐢熸垚鍚屾牱閰嶇疆銆傛牴鐩綍鐢熸垚 `personal_admin_site_template.zip` 浣滀负涓婁紶妯℃澘鍖咃紝浠嶉渶鐪熷疄 Supabase `anon public key` 鏇挎崲鍚庢墠鑳藉彂甯冧负鍙敤绔欑偣銆?
> 2026-05-31: 棣栭〉浠诲姟璇︽儏鍗＄殑 DB 浠诲姟璧勬簮鍖虹敱鐙珛鐨勨€滃瓙浠诲姟鍦ㄤ笂銆侀檮浠?妫€鏌ラ」鍦ㄤ笅鈥濈粨鏋勮皟鏁翠负鍚屼竴妯悜璧勬簮琛岋細`_buildResourceRow` 鍦?`lib/presentation/pages/home/home_page.dart` 涓苟鍒楁壙杞藉瓙浠诲姟鏍戙€乣AttachmentSection`銆乣ChecklistSection`锛屼粛浠呭 `source == 'db'` 浠诲姟鏄剧ず銆?
> 2026-05-30: 澶氫富棰樺垏鎹€俙lib/core/theme/app_theme.dart` 鎶藉嚭 `AppPalette` 璋冭壊鏉挎ā鍨嬶紙鍏ㄩ儴棰滆壊 token + `ThemeData build()`锛夛紝涓夊瀹炰緥 `claude`(榛樿鏆栫強鐟?/`auroraBlue`(Google Material 3 钃?/`obsidian`(娣辫壊)銆俙AppTheme` 棰滆壊鐢?`static const` 鏀逛负濮旀墭 `_current` 鐨?`static get`锛堝澶栧悕涓嶅彉锛屽叏 App 653 澶勫紩鐢ㄩ浂鏀瑰姩锛涗唬浠锋槸 215 澶?const 涓婁笅鏂囧幓 const锛夈€俙lib/core/theme/theme_controller.dart` 鐨?`ThemeController`(ChangeNotifier锛屽叏灞€鍗曚緥 `themeController`)璐熻矗鎸佷箙鍖?SharedPreferences via `LocalStorageService.themeId`)+ 閫氱煡閲嶅缓锛沗main.dart` 鐢?`ListenableBuilder` 鍖?`MaterialApp`锛宍themeMode` 闅忚皟鑹叉澘浜?鏆楀垏鎹€傞€夋嫨椤?`theme_settings_page.dart`锛屽叆鍙ｅ湪 profile"涓婚"鑿滃崟銆?> 2026-05-31: 鎴戠殑妯″潡琛ュ叏銆俙profile_page.dart` 绉婚櫎绌虹殑"鎻愰啋璁剧疆"鑿滃崟鍏ュ彛锛?璁剧疆/甯姪涓庡弽棣?鍏充簬"鏀逛负椤甸潰璺宠浆銆俙app_settings_page.dart` 鎵胯浇 AI 鎺掔▼璺宠繃鍛ㄦ湯寮€鍏筹紙澶嶇敤 `LocalStorageService.skipWeekends`锛夈€佷富棰樺叆鍙ｃ€侀€氱煡鍜屾暟鎹鏄庯紱`help_feedback_page.dart` 璁板綍浠诲姟绠＄悊銆丄I 鎷嗚В銆佹棩鍘嗘彁閱掋€佷富棰樺垏鎹€佸父瑙侀棶棰樺拰鍙嶉璇存槑锛沗about_page.dart` 灞曠ず鏅鸿兘灏忕瀹躲€佺増鏈?`1.0.0+3`銆佹牳蹇冭兘鍔涖€佹暟鎹悓姝ュ拰闅愮鏉冮檺璇存槑銆?
> 2026-06-06: 鍥涜薄闄愭ā鍧楁敼涓哄垪婧㈠嚭妯″紡鈥斺€旀瘡鍒楁渶澶?5 鏉★紝瓒呭嚭鑷姩鏂板紑鍒楋紝璞￠檺鍐?`SingleChildScrollView` 妯悜婊氬姩锛屽垪闂?1px 鍒嗛殧绾裤€傜Щ闄ょ‖涓婇檺鎴柇 `q.removeRange(5)`銆侀€炬湡妯箙銆乣"N 閫炬湡"` 鎻愮ず锛屼繚鐣欏崟鏉′换鍔″墠閫炬湡 `!` 鍥炬爣銆?
> 2026-07-17: 淇鎬濈淮瀵煎浘鐐瑰嚮绌虹櫧澶勫彇娑堟閫変笉鐢熸晥銆傛牴鍥狅細鍙栨秷妗嗛€夌殑 `Listener` 鍘熸湰鏀惧湪 `InteractiveViewer` 鍐呴儴 Stack锛屾闈㈢ `InteractiveViewer` 鐨?`ScaleGestureRecognizer` 鎷︽埅鎸囬拡浜嬩欢瀵艰嚧瀛愮骇 `onPointerUp` 涓嶈Е鍙戙€備慨澶嶏細灏?`Listener` 绉诲埌 `InteractiveViewer` 澶栧眰 Stack锛坄_buildMindMapCanvas` 杩斿洖鍊硷級锛岀粫寮€鎵嬪娍绔炴妧鍦恒€?
> 2026-06-06: 鎬濈淮瀵煎浘澧炲姞妗岄潰绔?Ctrl+妗嗛€夊鑺傜偣鍔熻兘銆俙_MindMapViewState` 鏂板 `_ctrlPressed`/`_selectedIds`/`_isSelecting` 鐘舵€侊紝閫氳繃 `HardwareKeyboard` 鐩戝惉 Ctrl 閿紝`Listener` 鎹曡幏鎸囬拡浜嬩欢缁樺埗閫夋嫨鐭╁舰銆俙_SelectionRectPainter` 缁樺埗鍗婇€忔槑閫夋嫨妗嗐€傞€変腑鍚庢嫋鎷芥椂 `onDragUpdate` 瀵?`_selectedIds` 鍐呮墍鏈夎妭鐐瑰簲鐢ㄧ浉鍚屼綅绉汇€?
> 2026-05-30: 棣栭〉鏂板缁熻鍗＄墖锛堜粖鏃ヤ换鍔℃暟/瀹屾垚鐜?閫炬湡鏁帮級锛岃瑙併€岄椤电粺璁″崱鐗囥€?> 2026-05-30: Realtime DELETE 鍥炶皟澧炲姞澧撶淇濇姢锛岄槻姝㈠巻鍙插垹闄や簨浠跺洖鏀惧鑷村瓙浠诲姟娑堝け

## Overview

`smart_assistant` is a Flutter application with shared UI code for mobile and desktop platforms. The main entrypoint is [lib/main.dart](/E:/claude/project2/smart_assistant/lib/main.dart), which initializes Supabase, the local notification service, the Drift database, repositories, and the root `MaterialApp`.

## Core Modules

- `lib/main.dart`
  Bootstraps platform services, desktop window management, and the system tray on Windows/macOS/Linux.
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
  A heavy task-editing surface that combines title/description inputs, reminder controls, subtask tree, checklist, attachments, and AI decomposition in one scrollable page. Heavy child sections (SubtaskTreeSection, ChecklistSection, AttachmentSection, AiDecomposeSection) are wrapped in `RepaintBoundary` to isolate repaints. `BlocListener` uses `listenWhen` to avoid unnecessary setState on unrelated BLoC changes.
- `lib/services/holiday_service.dart`
  鑺傚亣鏃ユ暟鎹湇鍔°€備腑鍥戒紭鍏堢敤 `timor.tools/api/holiday/year/{year}`锛堝惈娉曞畾鍋囨棩 + 璋冧紤琛ョ彮锛夛紝澶辫触鎴栬繑鍥炵┖鏃跺洖閫€ `date.nager.at/api/v3`锛圕N锛屼粎娉曞畾鍋囨棩锛夛紱鍏朵粬鍥藉鐢?`date.nager.at/api/v3`銆傜粨鏋滀互 `Map<"yyyy-MM-dd", HolidayInfo>` 褰㈠紡杩斿洖锛屽苟鐢?`SharedPreferences` 缂撳瓨 7 澶╋紝鏂綉鏃堕檷绾ц杩囨湡缂撳瓨銆傛敮鎸?`HolidayCountry`锛堜腑/缇?鏃?鑻?闊╋級鏋氫妇锛岀敤鎴烽€夋嫨鎸佷箙鍖栥€?- `lib/services/notification_service.dart`
  Centralizes reminder scheduling. Android/iOS 绔敤 `zonedSchedule`锛堢郴缁?AlarmManager锛夛紝杩涚▼姝讳骸鍚庣郴缁熶粛鍙Е鍙戯紱妗岄潰绔繚鐣?Timer銆傞渶 `timezone` 鍖呭垵濮嬪寲锛坄tz.initializeTimeZones()`锛夈€?- `lib/services/permission_service.dart`
  杩愯鏃堕€氱煡鏉冮檺鐢宠灏佽锛圓ndroid/iOS锛夛紝`showNotificationGuideIfNeeded` 鍦ㄩ娆″惎鍔ㄦ椂寮瑰嚭寮曞 dialog锛宍SharedPreferences` 闃查噸澶嶃€?- `lib/core/desktop/desktop_runtime.dart`
  Holds desktop-only runtime decisions used by the app, including tray event mapping and desktop notification channel selection.
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`
  鎬濈淮瀵煎浘浠诲姟瑙嗗浘銆傜敤 InteractiveViewer + Stack + Positioned 瀹炵幇姘村钩鏍戝舰甯冨眬锛孋ustomPaint 缁樺埗璐濆灏旀洸绾胯繛鎺ョ嚎銆傛瘡涓妭鐐规槸瀹屾暣鐨勪氦浜掑崱鐗囷紙Draggable + DragTarget + Slidable锛夈€傞€氳繃 BLoC state 鐨?`viewMode` 瀛楁鍒囨崲鍒楄〃/瀵煎浘瑙嗗浘銆?  **鑷敱鎷栨嫿妯″紡**锛歚_freeDragMode` 鐘舵€佹帶鍒讹紝鑺傜偣鐢?`GestureDetector.onPanDown/onPanUpdate/onPanEnd/onPanCancel` 鑷敱鎷栧姩锛坄onPanDown` 姣?`onPanStart` 鏇存棭瑙﹀彂浠ュ敖鏃╃鐢ㄧ敾甯冨钩绉伙紝`onPanCancel` 娓呯悊鐘舵€侀槻姝㈡畫鐣欙級锛涘潗鏍囬挸鍒?`dx>=0/dy>=6` 闃叉瓒婂嚭鐢诲竷鏃犳硶鍛戒腑銆俙InteractiveViewer.panEnabled = !_nodeDragging`锛氭嫋鑺傜偣鏈熼棿绂佺敤鐢诲竷骞崇Щ锛岄伩鍏嶇敾甯冩暣浣撹仈鍔紱绌洪棽鏃朵粛鍙钩绉?缂╂斁銆? 鎸夐挳鐢?`HitTestBehavior.opaque` + 28脳28 鐑尯閬垮厤鎵嬪娍绔炴妧鍦哄悶浜嬩欢銆?  **鎬ц兘浼樺寲 (2026-06-04)**锛氬竷灞€缁撴灉缂撳瓨鍦?`_cachedPendingNodes/Lines/CanvasSize` 涓紝`initState`/`didUpdateWidget` 涓竴娆℃€ц绠楋紝`build()` 鐩存帴璇荤紦瀛樸€傛嫋鎷界敤 `ValueNotifier<Offset>` 姣忚妭鐐圭嫭绔?+ `ValueListenableBuilder`锛屽彧閲嶅缓琚嫋鑺傜偣銆傝繛绾垮眰鐢?`AnimatedBuilder` + `Listenable.merge` 鐩戝惉鎵€鏈?notifier锛屽彧閲嶇粯 `CustomPaint`銆傛瘡涓妭鐐瑰鍖?`RepaintBoundary`銆傚凡绉婚櫎 `_lineAnimController` 鍔ㄧ敾銆?- `lib/presentation/pages/home/home_page.dart`
  棣栭〉銆俙_HomeContent` 鑷笂鑰屼笅锛氶棶鍊欒 鈫?**缁熻鍗?`_buildStatsCard`** 鈫?椤圭洰绛涢€?鈫?鏃堕棿杞?鈫?浠诲姟璇︽儏鍗?鈫?鍥涜薄闄愩€傜粺璁″崱锛?026-05-30锛変笁椤癸細浠婃棩浠诲姟鏁?/ 瀹屾垚鐜?`瀹屾垚/鎬籤锛屽懆鏈?`_statsPeriod` 鍙垏鏃ュ懆鏈堝勾锛岀敱 `_periodRange` 鍙?`[start,end)`) / 閫炬湡鏁般€傚叏閮ㄥ熀浜庡唴瀛?`_filteredTasks` 鎸?`_TimelineTask.date` 璁＄畻銆佸皧閲嶉」鐩瓫閫夈€侀殢 `_loadData` 鍒锋柊锛屾棤鏂板鏁版嵁灞傘€傞€炬湡鏁板彲鐐?鈫?`_showOverdueSheet` 搴曢儴寮圭獥 鈫?鐐逛换鍔″鐢?`_selectTask`锛堟椂闂磋酱鍒囨崲 + 璇︽儏鍗″睍寮€锛夈€備换鍔¤鎯呭崱鏈熬鏂板銆岃祫婧愬尯銆嶏紙2026-05-30锛夛細宸﹀垪 `AttachmentSection`銆佸彸鍒?`ChecklistSection`锛岄€氳繃 `_dbTaskCache`锛堟噿鍔犺浇 Task 瀵硅薄锛夊拰鍏釜 `_home*` 鏂规硶瀵规帴 `ChecklistRepository`锛屼粎 `source=='db'` 浠诲姟鏄剧ず銆?- `lib/presentation/widgets/create_schedule_dialog.dart`
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
7. Windows 鍗曞疄渚嬩繚鎶ら€氳繃 `main.cpp` 涓殑 Named Mutex 瀹炵幇锛岀浜屼釜瀹炰緥婵€娲诲凡鏈夌獥鍙ｅ悗閫€鍑恒€?
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

## UI 宸ュ叿灞?
- `lib/core/utils/snackbar_helper.dart`锛氬叏灞€ `showAppSnackBar(context, message)` 鈥?鎵€鏈夋彁绀烘秷鎭粺涓€浣跨敤姝ゅ嚱鏁帮紝鍐呯疆鐐瑰嚮娑堝け鍔熻兘锛圙estureDetector + hideCurrentSnackBar锛夈€?
## Important Implementation Decisions

- Windows desktop reminders are no longer limited to the PowerShell toast fallback. The app now prefers the native Windows notification plugin path when available.
- Tray menu visibility is controlled explicitly from tray events. Right-click popup behavior is mapped in `desktop_runtime.dart` and executed in `main.dart`.
- Reminder UI sections use taller `SwitchListTile` layouts (`isThreeLine: true`) in the affected desktop surfaces to reduce bottom overflow risk on shorter windows.

## 2026-05-27 鎵归噺浼樺寲 鈥?鏂板妯″潡

### 鏁版嵁妯″瀷锛圖rift v5锛?
- `Projects.groupId`锛氬彲绌猴紝鎸囧悜 `ProjectGroups.id`
- 鏂拌〃 `ProjectGroups(id, name, color, sortOrder, createdAt, updatedAt)`
- `Tasks.estimatedMinutes`锛氬彲绌猴紝AI 浼版椂鍒嗛挓鏁?- onUpgrade(4鈫?)锛歛ddColumn + createTable

### 浜戝悓姝ワ紙Supabase锛?
- 鏂拌〃 `projects`銆乣project_groups`锛堝惈 user_id + RLS锛夈€係QL 瑙?`database/migration_002_groups_and_estimate.sql`
- 宸叉湁 `user_tasks` 鍔?`estimated_minutes` 鍒?- 鏂?`ProjectSyncService` (`lib/services/project_sync_service.dart`)锛氫豢 `TaskSyncService` 缁撴瀯锛宲ull/push/subscribe锛岀粦瀹?`ProjectRepository` 涓?`ProjectGroupRepository` 鐨勫啓鎿嶄綔
- `home_page` 鍒濆鍖栨椂 `pullAll()` + `subscribe()`锛岀櫥褰曠敤鎴峰叡浜?projects/groups

### 鍏ㄤ笟鍔℃暟鎹弻绔悓姝ワ紙杞垹闄ゅ鐭?+ 鍙屽悜 LWW锛?026-05-29锛?
- **澧撶煶杞垹闄?*锛歚Tasks/Projects/ProjectGroups/ChecklistItems` 鍙婂搴斾簯琛紙`user_tasks/projects/project_groups/checklist_items`锛夊潎鍚?`deleted`锛?/1锛夈€傚垹闄や竴寰?`deleted=1, updatedAt=now` 骞舵帹閫侊紝涓嶇墿鐞嗗垹闄わ紱鎵€鏈夎鏌ヨ杩囨护 `deleted=0`銆傚垹闄ら潬澧撶煶璺ㄧ浼犳挱銆侀噸鍚笉澶嶆椿銆俿chemaVersion=7銆?- **鍙屽悜 LWW 瀵硅处**锛歚{Task,Project,Checklist,Attachment}SyncService.syncAll()` = 鎷変簯绔紙鍚鐭筹級鍚堝苟鏈湴锛堜粎褰?remote `updatedAt` 鏇存柊鎵嶈鐩栵級+ 鏈湴锛堝惈澧撶煶锛宍getAllRaw()`锛夊嚒浜戠缂哄け鎴栨湰鍦版洿鏂板垯 upsert 涓婁簯銆備笉渚濊禆 Realtime 鍗冲彲琛ラ綈瀛愪换鍔℃爲涓庝紶鎾垹闄わ紱Realtime 浠呬綔鍔犻€熴€?- **checklist 涓婁簯**锛氭柊 `ChecklistSyncService` + 浜戣〃 `checklist_items`锛圧LS `auth.uid()=user_id` + REPLICA IDENTITY FULL + 鍦?supabase_realtime publication锛夈€俙ChecklistRepository` 娉ㄥ叆 syncService锛屽鍒犳敼 push + `syncFromJson`銆?- **绾ц仈**锛歱roject 杞垹 鈫?绾ц仈杞垹鍏朵笅 tasks/checklist锛涜繙绔」鐩鐭冲埌杈?`_upsertProjectFromRow` 鏃舵湰鍦板悓鏍风骇鑱斻€?- **鍚姩闂ㄦ帶**锛歚home_page` 鎵€鏈?`syncAll()+subscribe()` 浠呭湪 Supabase 鐧诲綍鍚庡惎鍔紝`signedIn/initialSession` 姣忔閲嶈窇鍏ㄩ噺瀵硅处锛堢Щ闄や簡鏈櫥褰曞嵆瑙﹀彂鐨?task pull锛夈€?- **娓呯┖**锛歚AppDatabase.wipeAllData()` 浜嬪姟娓呯┖鍚勮〃骞堕噸寤?inbox锛涗簯绔粡 Management API 宸叉竻绌恒€係QL 鐣欑棔 `database/migration_004_soft_delete_checklist_realtime.sql`銆?- 鈿?鏈湴鑻ユ湭娓呯┖锛屼笅娆″惎鍔?`syncAll` 浼氭妸鏃ф暟鎹弽鎺ㄥ洖浜戠 鈥斺€?娓呯┖浜戠鍚庨』鍚屾娓呯┖涓ょ鏈湴锛堝叧 App 鍚庤窇 `clear_data.bat` / 绉诲姩绔嵏杞介噸瑁咃級銆?- **syncFromJson 淇濈暀杩滅鏃堕棿鎴?*锛氬悎骞舵椂鍐欏叆杩滅 `updatedAt` 鑰岄潪 `now`锛岄伩鍏嶄笅娆″璐﹀弽鎺ㄦ棫鏁版嵁瑕嗙洊浜戠銆傚鐭充繚鎶わ細鏈湴 `deleted=1` 涓?`updatedAt>=杩滅` 鏃朵笉琚湭鍒犻櫎鐘舵€佽鐩栥€?- **Realtime 涓茶鍖?*锛歚TaskSyncService._enqueue()` 涓茶鎵ц Realtime 鍥炶皟鐨勬暟鎹簱鎿嶄綔锛岄槻姝㈠苟鍙戝啓鍏ュ鑷?SQLite `database is locked`銆?
### AI 鎷嗗垎鎺掔▼

- 杈撳叆锛氱埗浠诲姟锛堝惈鎻忚堪 / 闄勪欢锛夛紱AI 绔彧浜?WBS + 鍙跺瓙 minutes
- 鎺掔▼锛歚SubtaskScheduler`锛坄lib/services/subtask_scheduler.dart`锛?  - 9:00鈥?1:00 宸ヤ綔鏃舵銆? 鍒嗛挓鍚搁檮銆?5 鍒嗛挓缂撳啿銆侀伩璁╁凡鏈?task 鐨?`[start, due]`
  - `skipWeekends` 鏉ヨ嚜 `LocalStorage`
  - 涓嶅厑璁稿崟娈佃法鏃ワ紝褰撴棩鍓╀綑涓嶅鍒欐暣娈垫帹娆℃棩
- 鐖朵换鍔¤法澶╁洖鍐欙細`computeParentSpans` 鈫?`startOfDay(minLeafStart)` 鍒?`endOfDay(maxLeafEnd)`锛岃 `_isMultiDayTask` 璇嗗埆涓洪《閮ㄩ暱鏉?
### 鏃ュ巻鎷栧姩閲嶅啓

- 鎶涘純 `Draggable` / `DragTarget`锛屾敼 `Listener` + 鐘舵€佹満锛?  - `onPointerDown` 璁板綍璧风偣
  - `onPointerMove` 绱Н delta 鈫?`Transform.translate` 淇濇寔鍘熷昂瀵歌窡鎵?  - `onPointerUp` 鎶?delta 鎹㈢畻涓?5 鍒嗛挓鍚搁檮鏃堕棿 + dayWidth 鍒楀亸绉伙紝璋?`_moveTask` / `_resizeTaskStart` / `_resizeTaskEnd`
- 澶氭棩 bar 鍚屾牱鏀瑰啓锛屾寜 `dayWidth` 璁＄畻鏁村ぉ鍋忕Щ
- 绉诲姩绔?resize hot zone (`_ResizeHotZone`) 浠?36px 楂樺害浣嗗幓 `Draggable` 鍚庤幏寰楁墜鍔夸紭鍏堟潈
- 鐖朵换鍔￠暱鏉?lane 鑷€傚簲锛氭寜灞傜骇娣卞害鎺掑簭锛堟牴涓婏級锛宭ane 鏁板姩鎬侊紝>6 鏃跺鍣ㄥ浐瀹氶珮搴﹀唴閮ㄧ旱鍚戞粴鍔?
### TaskNewBloc 鐘舵€佷繚鐣欒鍒欙紙2026-05-31锛?
`_onLoadTasks` 鍦?emit `TaskNewLoading` 鍓嶄粠褰撳墠 `TaskNewLoaded` 淇濈暀浠ヤ笅瀛楁锛屽苟鍦ㄦ渶缁?`emit TaskNewLoaded` 鏃跺啓鍥烇細
- `subTrees` / `expandedNodes`锛堝凡鏈夛級
- `viewMode`锛堟柊澧烇紝閬垮厤姣忔 LoadTasks 鍚庡洖閫€涓?'mindmap'锛?- `dateFrom` / `dateTo`锛堟柊澧烇紝閬垮厤鏃ユ湡绛涢€変涪澶憋級

璋冪敤鏂逛紶鍏ョ殑 `event.dateFrom`/`event.dateTo` 浼樺厛浜庝繚鐣欏€硷紙`event.dateFrom ?? preservedDateFrom`锛夈€俙LoadTasks(clearDateRange: true)` 鏃跺己鍒舵妸 `dateFrom/dateTo` 缃?null锛堢敤浜?娓呴櫎鏃ユ湡绛涢€?锛屽惁鍒?`?? preserved` 浼氫繚鐣欐棫绛涢€夊鑷存竻涓嶆帀锛夈€?
### 浠诲姟鍒涘缓鏃堕棿鍐茬獊澶勭悊锛?026-05-31锛?
- `TaskCreateSheet` 鍦ㄤ紶鍏?`TaskRepository` 鏃跺鎵€鏈夋柊寤轰换鍔″仛鏃堕棿鍐茬獊妫€娴嬶紝寮圭獥鏀寔鍙栨秷銆佸苟琛屻€佽嚜鍔ㄥ欢鍚庛€佽嚜鍔ㄦ彃鍏ャ€?- 鑷姩鎻掑叆鐢?`SubtaskScheduler.autoInsert` 璁＄畻锛氫互鏂颁换鍔″師濮嬫椂闂存浣滀负鍗犵敤鍖洪棿锛屽彧绉诲姩鏈畬鎴愩€佹湭鍒犻櫎涓旀湁寮€濮?鎴鏃堕棿鐨勬棦鏈変换鍔★紱琚Щ鍔ㄤ换鍔′繚鎸佸師鎸佺画鏃堕暱锛屾寜 09:00-21:00 宸ヤ綔鏃舵鍜?15 鍒嗛挓缂撳啿绾ц仈鍚庣Щ銆?- `CreateTask.shiftedTasks` 鎼哄甫鑷姩鎻掑叆浜х敓鐨勫悗绉荤粨鏋滐紱`TaskNewBloc._onCreateTask` 鍏堝垱寤烘柊浠诲姟锛屽啀閫愭潯鏇存柊琚悗绉讳换鍔＄殑 `startDate`/`dueDate`锛屼箣鍚庢墽琛屽師鏈変簯鍚屾鍜屽垪琛ㄥ埛鏂般€?- 浠诲姟椤垫柊寤恒€佷换鍔¤鎯呭瓙浠诲姟鏂板缓銆佹棩鍘嗘椂闂磋酱鏂板缓鍧囦紶閫?`shiftedTasks` 鍒?`CreateTask`锛涙棩鍘嗗垱寤哄叆鍙ｅ悓姝ヤ紶鍏?`TaskRepository` 浠ュ惎鐢ㄥ悓鏍风殑鍐茬獊澶勭悊銆?
### 鏃ュ巻鑺傚亣鏃ヤ笌浼戞伅鏃ュ睍绀猴紙2026-05-31锛?
- `CalendarPage` 鎺ュ叆 `HolidayService`锛屾寜褰撳墠鑺傚亣鏃ュ浗瀹朵笌骞翠唤鍔犺浇骞剁紦瀛樿妭鍋囨棩鏁版嵁銆?- AppBar 鎻愪緵鑺傚亣鏃ュ浗瀹跺垏鎹紱鍒囨崲鍚庢竻绌洪〉闈㈠唴鑺傚亣鏃ョ紦瀛樺苟閲嶆柊鍔犺浇褰撳墠骞翠唤銆?- 鍛ㄨ鍥炬棩鏈熷ご鍜屾湀瑙嗗浘鏃ユ湡鏍煎睍绀鸿皟浼戣ˉ鐝€佹硶瀹氳妭鍋囨棩銆佹櫘閫氬懆鏈紤鎭棩锛涗腑鍥借ˉ鐝棩浼樺厛浜庡懆鏈紤鎭爣璁般€?- `HolidayService` 瀵逛腑鍥借妭鏃ュ鍔犳湰鍦拌ˉ鍏咃細濡囧コ鑺傘€佹鏍戣妭銆侀潚骞磋妭銆佸効绔ヨ妭銆佸缓鍏氳妭銆佸缓鍐涜妭銆佹暀甯堣妭锛涜繖浜涗娇鐢?`HolidayType.observance`锛屽彧灞曠ず鑺傛棩鍚嶏紝涓嶆寜浼戞伅鏃ュ鐞嗐€?# 2026-05-31 涓婄嚎涓庡彉鐜板噯澶囨枃妗?
- 鏂板 `docs/launch/` 浣滀负涓婄嚎鍑嗗璧勬枡鐩綍锛屼笉鍙備笌杩愯鏃舵瀯寤猴紝涓嶆敼鍙?Flutter 涓氬姟浠ｇ爜銆?- `PLATFORM_RESEARCH_CN.md` 璁板綍涓浗澶ч檰涓汉寮€鍙戣€呯殑涓婄嚎骞冲彴閫夋嫨锛氶鍙戝缓璁?Windows 瀹樼綉/绉佸煙鍒嗗彂 + 鍥藉唴瀹夊崜娓犻亾寮曟祦锛屾殏缂?Google Play 鍜屽钩鍙板唴璐€?- `LAUNCH_CHECKLIST.md`銆乣RISK_REGISTER.md`銆乣RELEASE_EVIDENCE.md` 璁板綍涓婄嚎鏉愭枡銆侀闄╁拰褰撳墠鍙戝竷璇佹嵁銆?- `PRIVACY_POLICY_DRAFT.md`銆乣TERMS_OF_SERVICE_DRAFT.md`銆乣STORE_LISTING_COPY.md`銆乣PRICING_AND_GO_TO_MARKET.md` 璁板綍闅愮鏀跨瓥鑽夋銆佺敤鎴峰崗璁崏妗堛€佸晢搴楁枃妗堝拰瀹氫环/鑾峰鏂规銆?- 鏈鏈洿鎹?DeepSeek Key锛屾湭淇敼 Android 绛惧悕銆佸寘鍚嶃€佷笟鍔′唬鐮佹垨鏋勫缓鑴氭湰銆?
### 棣栭〉鍚姩寮曞锛?026-05-31锛?
- `HomePage` 鍚姩鍚庝粛浼氳皟鐢?`PermissionService.showNotificationGuideIfNeeded` 鍋氶€氱煡鏉冮檺寮曞銆?- `HomePage` 涓嶅啀鑷姩璺宠浆 `OnboardingPage`锛宍LocalStorageService.onboardingCompleted` 涓嶅啀鍙備笌棣栭〉鍚姩瀵艰埅鍒ゆ柇銆?
### 瀛愪换鍔″垱寤洪粯璁ら」鐩紙2026-05-31锛?
- `TasksPage` 浠庝换鍔℃爲/鎬濈淮瀵煎浘鐖惰妭鐐规柊澧炲瓙浠诲姟鏃讹紝鍒涘缓寮圭獥鐨勯粯璁ら」鐩紭鍏堜娇鐢ㄧ埗浠诲姟 `projectId`锛屽啀鍥為€€褰撳墠椤圭洰绛涢€夈€?- `TaskCreateSheet` 鍦ㄥ垵濮嬪寲鍜岀埗浠诲姟涓嬫媺鍒囨崲鏃讹紝浼氭寜鎵€閫夌埗浠诲姟鍚屾 `_selectedProjectId`锛岀‘淇濆瓙浠诲姟榛樿褰掑睘鐖朵换鍔￠」鐩€?
### 棣栭〉浠诲姟璇︽儏绉诲姩绔祫婧愬尯锛?026-05-31锛?
- `HomePage._buildResourceRow` 鎸夊彲鐢ㄥ搴﹀垏鎹㈠竷灞€锛氭闈繚鎸佸瓙浠诲姟/闄勪欢/妫€鏌ラ」妯帓锛涚獎灞忎笅瀛愪换鍔″崟鐙竴琛岋紝闄勪欢鍜屾鏌ラ」缁勬垚鐙珛璧勬簮琛屻€?
### 浠诲姟鍒犻櫎璺ㄧ鍚屾锛?026-05-31锛?
- `TaskRepository.syncFromJson` 瀵硅繙绔?`deleted=1` 澧撶煶浣跨敤 `updatedAt` 鍋?LWW锛氳繙绔洿鏂版椂瑕嗙洊鏈湴娲讳换鍔★紝鏈湴鏇存柊鏃惰烦杩囪繃鏈熷鐭炽€?- `TaskSyncService.syncAll` 涓嶅啀鐢ㄦ湰鍦版椿浠诲姟鏃犳潯浠惰鐩栦簯绔鐭筹紝閬垮厤閲嶅惎鍏ㄩ噺瀵硅处鏃舵妸鍙︿竴绔凡鍒犻櫎鐨勬€濈淮瀵煎浘鑺傜偣澶嶆椿銆?- `TaskSyncService` 澧炲姞 `changes` 骞挎挱锛沗HomePage` 鐩戝惉浠诲姟鍚屾鍙樻洿骞?debounce 瑙﹀彂 `LoadTasks`锛岃浠诲姟椤?鎬濈淮瀵煎浘鍦ㄨ繙绔柊澧炪€佹洿鏂般€佸垹闄ゅ悗鍒锋柊銆?
### 鎵嬫満楠岃瘉鐮佺櫥褰曪紙2026-05-31锛?
- `SupabaseService` 灏佽 `signInWithOtp(phone: ...)` 鍙戦€佺煭淇￠獙璇佺爜锛屽皝瑁?`verifyOTP(type: OtpType.sms)` 鏍￠獙楠岃瘉鐮佸苟杩斿洖 Supabase 鐢ㄦ埛浼氳瘽銆?- `AuthBloc` 鏂板 `PhoneOtpRequested`銆乣PhoneOtpVerified`銆乣PhoneOtpSent`锛屾墜鏈哄彿楠岃瘉鐮佺櫥褰曟垚鍔熷悗杩涘叆鐜版湁 `Authenticated` 鐘舵€併€?- `LoginPage` 澧炲姞閭/鎵嬫満楠岃瘉鐮佺櫥褰曟ā寮忓垏鎹紱鎵嬫満鍙蜂笉甯?`+` 涓斾负涓浗澶ч檰 11 浣嶆墜鏈哄彿鏃惰嚜鍔ㄨˉ `+86`銆?
### 鍏ㄥ眬鎺掗櫎椤圭洰锛?026-05-31锛?
- `LocalStorageService.excludedProjectIds` 浣跨敤 SharedPreferences 鎸佷箙鍖栨帓闄ら」鐩?ID 鍒楄〃銆?- `TaskNewBloc._onLoadTasks` 鍦ㄥ姞杞戒换鍔″垪琛ㄥ拰璁＄畻杩涘害鍓嶆帓闄よ繖浜涢」鐩紱琚帓闄ら」鐩笉杩涘叆浠诲姟椤靛垪琛ㄣ€佹€濈淮瀵煎浘鍜岃繘搴﹁绠椼€?- `HomePage` 鏋勫缓棣栭〉鏃堕棿杞存暟鎹墠鎺掗櫎杩欎簺椤圭洰锛屽洜姝ゆ椂闂磋酱銆佺粺璁″拰鍥涜薄闄愬潎浣跨敤鎺掗櫎鍚庣殑浠诲姟闆嗗悎锛涢椤甸」鐩瓫閫夌姸鎬佷娇鐢ㄩ」鐩?ID 闆嗗悎锛岃绠楁寜闆嗗悎杩囨护锛孶I 淇濈暀蹇€熷崟閫変笅鎷夊苟鎻愪緵澶氶€夊脊绐楀叆鍙ｃ€?- `CalendarPage` 鍔犺浇鏃ュ巻浠诲姟鏃舵帓闄よ繖浜涢」鐩紱鏃ュ巻椤圭洰绛涢€夌姸鎬佷娇鐢ㄩ」鐩?ID 闆嗗悎锛岃彍鍗曢」鍙閫?鍙栨秷銆?- `TaskNewBloc` 鐨?`LoadTasks.projectIds` 涓?`TaskNewLoaded.selectedProjectIds` 鎵胯浇浠诲姟妯″潡澶氶」鐩瓫閫夛紱浠诲姟椤?AppBar 鎻愪緵椤圭洰澶氶€夌瓫閫夊叆鍙ｅ拰鈥滄帓闄ら」鐩€濆閫夎缃叆鍙ｃ€?
### 鎻愰啋閫氱煡锛?026-05-31锛?
- `NotificationService` 璐熻矗鏈湴鎻愰啋璋冨害銆傜Щ鍔ㄧ浣跨敤 `flutter_local_notifications` 鐨?`zonedSchedule`锛岃皟搴﹀墠鍏滃簳璇锋眰閫氱煡鏉冮檺锛汚ndroid 鍚屾璇锋眰绮剧‘闂归挓鏉冮檺锛宨OS 鍓嶅彴灞曠ず鏄惧紡鍚敤 alert/badge/sound銆?- 妗岄潰绔粛鐢ㄨ繘绋嬪唴 `Timer` 瑙﹀彂鎻愰啋锛沇indows 瑙﹀彂鍚庢敼涓?PowerShell `MessageBox` 甯搁┗寮圭獥锛岀敤鎴风偣鍑?OK 鍓嶄笉浼氳嚜鍔ㄦ秷澶便€?- `PermissionService.showNotificationGuideIfNeeded` 浠嶅彧鍦ㄧЩ鍔ㄧ棣栨灞曠ず閫氱煡鏉冮檺寮曞锛汚ndroid 纭鍚庡悓鏃剁敵璇烽€氱煡鏉冮檺鍜岀簿纭椆閽熸潈闄愩€?
### 椤圭洰鍒嗙粍渚ц竟鏍忓睍绀猴紙2026-06-01锛?
- `ProjectSidebar` 鎺ユ敹 `projects` 涓?`groups`锛屽湪渚ц竟鏍忔寜鍒嗙粍娓叉煋椤圭洰銆?- 绌哄垎缁勭敱 `_buildGroupedProjects()` 涓殑 `ExpansionTile` 灞曠ず锛屽嵆浣垮垎缁勪笅娌℃湁椤圭洰涔熸樉绀衡€滄殏鏃犻」鐩€濆崰浣嶃€?- 浠呭綋 `projects` 涓?`groups` 鍚屾椂涓虹┖鏃讹紝渚ц竟鏍忔墠灞曠ず鏁翠綋绌虹姸鎬併€?
### 椤圭洰渚ф爮鍒嗙粍灞曞紑涓庢椂闂存帓搴忥紙2026-06-01锛?
- `TasksPage` 缁存姢椤圭洰渚ф爮鍒嗙粍灞曞紑闆嗗悎锛涢娆″姞杞芥垨鏂板鍒嗙粍榛樿灞曞紑锛屾柊寤洪」鐩€夋嫨鍒嗙粍鍚庝細鍦ㄦ淳鍙?`CreateProject` 鍓嶆妸璇ュ垎缁勫姞鍏ュ睍寮€闆嗗悎銆?- `ProjectSidebar` 鐨勫垎缁勫睍寮€鐘舵€佺敱 `expandedGroupIds` 鎺у埗锛屼笉鍐嶄緷璧?`ExpansionTile` 鐨?PageStorage 璁板繂锛涙爣棰樿鎻愪緵鍏ㄩ儴灞曞紑銆佸叏閮ㄦ敹缂╁拰鏃堕棿鎺掑簭鏂瑰悜鍒囨崲銆?- 椤圭洰渚ф爮灞曠ず灞傛寜 `createdAt` 瀵瑰垎缁勫拰缁勫唴椤圭洰鎺掑簭锛屼笉淇敼鏁版嵁搴撴帓搴忓瓧娈碉紱鎺掑簭鏂瑰悜閫氳繃 `LocalStorageService.projectSidebarTimeSortDesc` 鍐欏叆 SharedPreferences锛岄粯璁ゅ€掑簭銆?### 棣栭〉宓屽婊氳疆杈圭晫锛?026-06-01锛?- `HomePage` 涓洪椤垫椂闂磋酱浠诲姟鑺傜偣銆佷换鍔¤鎯呴檮浠跺尯鍜屾鏌ラ」鍖哄鍔犲眬閮ㄩ紶鏍囨粴杞竟鐣岋紱杈圭晫閫氳繃 `Listener.onPointerSignal` 娉ㄥ唽 `PointerScrollEvent`锛岄伩鍏嶈繖浜涘眬閮ㄥ尯鍩熺殑婊氳疆浜嬩欢缁х画瑙﹀彂澶栧眰棣栭〉 `CustomScrollView` 涓婁笅婊氬姩銆?- 棣栭〉闄勪欢鍖哄鐢?`AttachmentSection`锛屽灞傚鍔?`ConstrainedBox(maxHeight: 240)` 鍜屽眬閮?`SingleChildScrollView`锛岄檮浠惰緝澶氭椂鍦ㄩ檮浠跺尯鍐呴儴婊氬姩锛屼笉鏀瑰彉闄勪欢涓婁紶銆佹墦寮€銆佸垹闄ら€昏緫銆?

### 日历右键跳转思维导图节点（2026-06-01）
- `CalendarPage` 支持接收 `onJumpToMindMap` 回调，日历任务列表项、单日时间块和多日任务条右键调用该回调，不再把单日时间块右键直接绑定到删除。
- `HomePage` 将日历跳转回调转换为底部导航切到任务页，并向 `TaskNewBloc` 派发带 `focusTaskId/focusRequestToken` 的 `LoadTasks`。
- `TaskNewBloc` 在带聚焦任务的加载请求中切换到 `mindmap` 视图、清除日期过滤、保留项目过滤，并展开目标任务祖先节点；`TaskNewLoaded` 保存聚焦任务 ID 与请求 token。
- `TasksPage` 将聚焦请求透传给 `MindMapView`；`MindMapView` 消费一次 token 后居中并选中对应节点，找不到可见节点时显示轻提示。
