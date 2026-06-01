# Changelog

## 2026-06-01 (子任务自动延后只计算子任务)

### 修复
- 原因：父任务或普通根任务的时间范围会参与子任务创建冲突/延后计算，导致 2026-06-01 创建子任务时被父任务长条推迟到 2026-06-05 后。
- `lib/presentation/pages/tasks/widgets/task_create_sheet.dart`：新增统一过滤规则，冲突检测、自动延后和自动插入只把未完成、未删除、`parentId != null`、非跨天的子任务传给 `SubtaskScheduler`。
- `test/subtask_scheduler_test.dart`：补充父任务/根任务被排除、不同父任务子任务仍参与避让的回归测试。
- 验证：`flutter test test\subtask_scheduler_test.dart` 通过。
- 风险/TODO：本次不调整 `SubtaskScheduler` 通用算法；后续若需要“仅同父子任务避让”，需再改变过滤范围。

## 2026-06-01 (日历顶部横条折叠展开)

### 修改
- 原因：周视图顶部跨天/父任务横条数量多时占用时间轴视野。
- `lib/presentation/pages/calendar/calendar_page.dart`：新增 `_isMultiDayLaneCollapsed`，顶部多日任务区域支持折叠为 30px 高的展开按钮行，展开状态保留原有最多 6 行滚动横条并增加右上折叠按钮。
- 影响：不改任务模型、仓库、Bloc、排程逻辑和多日任务判定规则。
- 验证：`flutter analyze lib\presentation\pages\calendar\calendar_page.dart` 已运行，仅剩 `_startOfWeek` 和 `_isDragging` 两个既有 warning。

## 2026-06-01 (任务节点乐观刷新)

### 修改
- 原因：完成、创建等任务节点操作需要先展示动画和本地刷新，避免等待云同步和全量加载造成卡顿。
- `lib/presentation/blocs/task_new/task_bloc.dart`：创建、更新、删除、完成切换、父节点移动、同级排序改为本地写入后即时刷新 `TaskNewLoaded`，再执行云同步；同步失败恢复任务表快照并发出回退提示。
- `lib/data/repositories/task_repository.dart`、`lib/services/task_sync_service.dart`、`lib/presentation/blocs/task_new/task_state.dart`、`lib/presentation/pages/tasks/tasks_page.dart`：新增跳过即时 push、任务快照恢复、同步失败抛出和回退 SnackBar 提示。
- 验证：`dart analyze lib\presentation\blocs\task_new lib\data\repositories\task_repository.dart lib\services\task_sync_service.dart lib\presentation\pages\tasks\tasks_page.dart` 通过但仍有既有 info；`flutter test test\task_progress_calculator_test.dart`、`flutter test test\task_sync_service_test.dart` 通过。
- 风险/TODO：同步失败回退以任务表快照为准，任务操作期间若并发写入其他任务也会被一并恢复。
## 2026-06-01 (棣栭〉宓屽婊氳疆涓叉粴淇)

### 淇
- 鍘熷洜锛氱敤鎴峰弽棣堥紶鏍囧仠鍦ㄩ椤甸檮浠躲€佹鏌ラ」鎴栨椂闂磋酱浠诲姟鑺傜偣涓婃粴杞椂锛屽灞傞椤典篃浼氳甯﹀姩涓婁笅婊氬姩銆?- `lib/presentation/pages/home/home_page.dart`锛氫负鏃堕棿杞翠换鍔¤妭鐐广€侀椤甸檮浠跺尯鍜屾鏌ラ」鍖哄鍔犲眬閮ㄦ粴杞竟鐣岋紱棣栭〉闄勪欢鍖哄鍔犲彈闄愰珮搴﹀唴閮ㄦ粴鍔ㄥ鍣ㄣ€?- 褰卞搷锛氫粎璋冩暣棣栭〉灞€閮ㄦ粴杞簨浠惰竟鐣屽拰闄勪欢鍖烘粴鍔ㄥ澹筹紝涓嶆敼浠诲姟銆侀檮浠躲€佹鏌ラ」鏁版嵁璇诲啓閫昏緫銆?- 椋庨櫓/TODO锛氫粛闇€鍦ㄦ闈㈢瀹為檯榧犳爣婊氳疆楠岃瘉涓夊灞€閮ㄦ粴鍔ㄦ墜鎰熴€?
## 2026-06-01 (瀵煎嚭鍏ㄩ儴椤圭洰鍖呭惈鏈垎閰嶄换鍔?

### 淇
- 鍘熷洜锛氱敤鎴烽€夋嫨 2026-06 鏃堕棿鑼冨洿鍜屽叏閮ㄩ」鐩鍑烘椂锛屽瓨鍦ㄩ」鐩爣绛炬樉绀轰负鈥滄湭鍒嗛厤鈥濈殑浠诲姟锛屼絾瀵煎嚭缁撴灉鎻愮ず鏃犳暟鎹€?- `lib/presentation/pages/profile/task_export_page.dart`锛氬綋鍏ㄩ儴椤圭洰琚€変腑鏃讹紝瀵煎嚭璋冪敤鏀逛负浼犵┖椤圭洰闆嗗悎锛岃〃绀轰笉鎸夐」鐩繃婊わ紝浠庤€屽寘鍚湭鍒嗛厤/鏈尮閰嶉」鐩换鍔°€?- `test/task_export_service_test.dart`锛氭柊澧炴湭鍖归厤椤圭洰浠诲姟鍦ㄧ┖椤圭洰绛涢€変笅浠嶄細杩涘叆瀵煎嚭宸ヤ綔绨跨殑鏂█銆?- 楠岃瘉锛歚flutter test test\task_export_service_test.dart` 閫氳繃锛沗dart analyze lib\presentation\pages\profile\task_export_page.dart lib\services\task_export_service.dart test\task_export_service_test.dart` 閫氳繃銆?- 椋庨櫓/TODO锛氬鏋滃彧鍕鹃€夋煇涓叿浣撻」鐩紝鏈垎閰嶄换鍔′粛涓嶄細瀵煎嚭锛涢渶閫夆€滃叏閮ㄩ」鐩€濆寘鍚湭鍒嗛厤浠诲姟銆?
## 2026-06-01 (鎬濈淮瀵煎浘鑺傜偣杩炵嚎鍔熻兘)

### 鏂板
- 鍘熷洜锛氭€濈淮瀵煎浘鍙兘閫氳繃 `+` 鎸夐挳鏂板缓瀛愯妭鐐癸紝鏃犳硶鎶婁袱涓凡鏈夎妭鐐规墜鍔ㄨ繛绾垮缓绔嬬埗瀛愬叧绯汇€?- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`锛?  - `+` 鎸夐挳鏀寔闀挎寜鎷栨嫿鍑烘鐨瓔杩炵嚎鍒扮洰鏍囪妭鐐癸紝鏉炬墜鍚庣洰鏍囪妭鐐规垚涓哄綋鍓嶈妭鐐圭殑瀛愯妭鐐癸紙璋冪敤宸叉湁 `onMoveToParent`锛夛紱
  - `_MindMapLinesPainter` 澧炲姞 `connectingFrom`/`connectingTo` 鍙傛暟锛屾嫋鎷借繃绋嬩腑缁樺埗铏氱嚎璐濆灏旀鐨瓔 + 缁堢偣鍦嗙偣锛?  - `_MindMapNodeCard` 鏂板 `onConnectStart/Update/End/Cancel` 鍥涗釜鍥炶皟锛?  - 鍙抽敭鐐瑰嚮鑺傜偣杩炵嚎鍖哄煙寮瑰嚭"鏂紑杩炴帴"鑿滃崟锛屾柇寮€鍚庡瓙鑺傜偣鍥炲埌鏍圭骇锛?  - ESC 閿悓鏃舵竻闄よ繛绾挎嫋鎷界姸鎬侊紱
  - 杩炵嚎鏈熼棿 `_nodeDragging=true`锛岄槻姝㈢敾甯冭窡闅忓钩绉汇€?- `lib/presentation/blocs/task_new/task_bloc.dart`锛歚_onMoveTaskToParent` 寤虹珛鐖跺瓙鍏崇郴鍚庤嚜鍔ㄦ墿灞曠埗鑺傜偣鐨勬棩鏈熻寖鍥达紙startDate 鍙栨渶鏃┿€乨ueDate 鍙栨渶鏅氾級浠ュ寘鍚瓙鑺傜偣鏃ユ湡锛屼娇鏃ュ巻妯潯鑷姩瑕嗙洊姝ｇ‘鍖洪棿銆?- 鏃ュ巻鏃ュ巻宸叉湁 `_isMultiDayTask 鈫?_hasChildren` 閫昏緫锛岀埗鑺傜偣杩炵嚎鍚庤嚜鍔ㄥ憟鐜颁负妯潯锛屾棤闇€棰濆鏀瑰姩銆?- 楠岃瘉锛歚flutter analyze --no-fatal-infos` 鏃?error銆?- 椋庨櫓/TODO锛氭鐨瓔杩炵嚎缁堢偣鍛戒腑妫€娴嬩互鑺傜偣鍖呭洿鐩掍负鍑嗭紙_hitTestNode锛夛紝鑺傜偣绱у瘑鎺掑垪鏃剁洰鏍囧彲鑳戒笉濡傞鏈燂紱鍙抽敭鍒犻櫎绾跨殑鍛戒腑鍗婂緞鍥哄畾 24px锛屽彲鎸夐渶璋冩暣銆?
## 2026-06-01 (鐧诲綍淇涓庢垜鐨勬ā鍧楀鍑?

### 淇/鏂板
- 鍘熷洜锛氱敤鎴峰弽棣堢櫥褰曢〉涔辩爜銆佹墜鏈哄彿鍙戦€侀獙璇佺爜鍚庨〉闈㈣烦鍥炲垵濮嬫€侊紝骞惰姹傗€滄垜鐨勨€濇ā鍧楁敮鎸佹寜鏃堕棿鑼冨洿銆侀」鐩拰閲嶈绾у埆瀵煎嚭 Excel銆?- `lib/presentation/pages/auth/login_page.dart`锛氫慨澶嶇櫥褰曢〉娈嬬暀涔辩爜鏂囨銆?- `lib/main.dart`銆乣lib/presentation/blocs/auth/auth_bloc.dart`锛氶潪璁よ瘉鎴愬姛鐘舵€佺户缁繚鐣?`LoginPage`锛岄伩鍏嶉獙璇佺爜鍙戦€佷腑涓㈠け鎵嬫満妯″紡锛涙墜鏈哄彿鏍煎紡鍜?Supabase Phone Auth/SMS Provider 閰嶇疆闂杩斿洖涓枃鎻愮ず銆?- `lib/services/task_export_service.dart`銆乣lib/presentation/pages/profile/task_export_page.dart`銆乣lib/presentation/pages/profile/profile_page.dart`銆乣lib/presentation/pages/home/home_page.dart`锛氭柊澧炴垜鐨勯〉瀵煎嚭鍏ュ彛銆佺瓫閫夐〉鍜屽 Sheet 鏍戝舰 Excel 瀵煎嚭锛涙柊澧?`excel`銆乣archive`銆乣xml` 渚濊禆锛屼笉鏀规暟鎹簱缁撴瀯銆?- `test/login_page_test.dart`銆乣test/task_export_service_test.dart`銆乣test/profile_page_test.dart`銆乣test/widget_test.dart`锛氭柊澧?鏇存柊楠岃瘉鐮佺姸鎬併€佸鍑烘湇鍔°€佸鍑哄叆鍙ｅ拰鐧诲綍椤典腑鏂囨枃妗堟祴璇曘€?- 楠岃瘉锛歚flutter test test\login_page_test.dart test\profile_page_test.dart test\widget_test.dart` 閫氳繃锛沗flutter test test\task_export_service_test.dart` 閫氳繃锛沗flutter analyze` 鍙畬鎴愪絾浠撳簱浠嶆湁鏃㈡湁 97 涓?info/warning銆?- 椋庨櫓/TODO锛氳嫢椤甸潰涓嶅啀璺冲洖鍚庝粛鏀朵笉鍒扮煭淇★紝闇€瑕佸湪 Supabase 鎺у埗鍙扮‘璁?Phone Auth 宸插惎鐢ㄥ苟閰嶇疆鐭俊鏈嶅姟鍟嗐€?
## 2026-06-01 (鎴戠殑妯″潡缂栬緫璧勬枡)

### 鏂板
- 鍘熷洜锛氱敤鎴疯姹傝皟鐮斺€滄垜鐨勨€濇ā鍧楀簲鍏佽缂栬緫鍝簺璧勬枡锛屽苟澧炲姞缂栬緫璧勬枡鍔熻兘銆?- `lib/presentation/pages/profile/profile_page.dart`锛氳鍙栨湰鍦版樉寮忚祫鏂欙紝澶撮儴鏄剧ず鏄电О銆佽亴涓?韬唤鍜屽煄甯傦紱鈥滅紪杈戣祫鏂欌€濇寜閽烦杞紪杈戦〉骞跺湪淇濆瓨鍚庡埛鏂般€?- 鏂板 `lib/presentation/pages/profile/profile_edit_page.dart`锛氬厑璁哥紪杈戞樀绉般€佽亴涓氭垨韬唤銆佹墍鍦ㄥ煄甯傘€佺洰鏍囧煄甯傘€佷富瑕佺洰鏍囷紱璐﹀彿閭/鎵嬫満鍙蜂綔涓鸿璇佷俊鎭彧璇绘彁绀猴紱淇濆瓨鍒?`LocalStorageService.saveExplicitProfile()`銆?- `test/profile_page_test.dart`锛氭柊澧炵紪杈戣祫鏂欎繚瀛樺悗鍥炴樉鍜屾湰鍦板瓨鍌ㄦ柇瑷€銆?- 楠岃瘉锛歚dart analyze lib\presentation\pages\profile\profile_page.dart lib\presentation\pages\profile\profile_edit_page.dart test\profile_page_test.dart` 閫氳繃锛沗flutter test test\profile_page_test.dart` 閫氳繃銆?- 椋庨櫓/TODO锛氬綋鍓嶈祫鏂欏彧鍐欐湰鍦?SharedPreferences锛屾湭鍚屾 Supabase `user_profiles`銆?
## 2026-05-31 (鑺傚亣鏃ャ€侀€€鍑虹櫥褰曘€佸瓙浠诲姟鍚屾銆佺Щ鍔ㄧ璧勬簮甯冨眬)

### 淇
- 鍘熷洜锛氱敤鎴峰弽棣?2026 骞翠簲涓€浼戞伅鏃ユ湭瀹屾暣灞曠ず銆佹垜鐨勯〉閫€鍑虹櫥褰曟棤鍙嶅簲銆佹闈㈢瀛愪换鍔℃棤娉曞悓姝ュ埌绉诲姩绔€佺Щ鍔ㄧ棣栭〉妫€鏌ラ」鍜岄檮浠跺悓鎺掓樉绀恒€?- `lib/services/holiday_service.dart`锛氭柊澧炰腑鍥?2026 鍔冲姩鑺傛湰鍦板厹搴曡鐩栵紝琛ラ綈 2026-05-01 鑷?2026-05-05 浼戞伅鏃ワ紝浠ュ強 2026-04-26銆?026-05-09 琛ョ彮鏃ャ€?- `lib/presentation/pages/profile/profile_page.dart`锛氶€€鍑虹櫥褰曡彍鍗曟淳鍙?`LoggedOut`锛屽苟涓烘祴璇曚繚鐣欏彲娉ㄥ叆 `onLogout` 鍥炶皟銆?- `lib/presentation/blocs/task_new/task_bloc.dart`銆乣lib/services/task_sync_service.dart`锛氫换鍔″悓姝ュ叆鍙ｆ敼鐢?`TaskSyncService.syncAll()` 鐨?`user_tasks` 閫愯鍚屾閾捐矾锛涙柊澧?`taskToSyncRow`/`syncRowToTaskJson` 楠岃瘉 `parent_id` 涓?`parentId` 鏄犲皠銆?- `lib/presentation/pages/home/home_page.dart`锛氱獎灞忛椤典换鍔¤鎯呰祫婧愬尯鏀逛负闄勪欢銆佹鏌ラ」绾靛悜鍒嗗尯锛涙闈㈢浠嶆í鍚戝睍绀恒€?- 鏂板 `test/holiday_service_test.dart`銆乣test/task_sync_service_test.dart`銆乣test/profile_page_test.dart` 瑕嗙洊鏈淇銆?- 楠岃瘉锛歚flutter test test\holiday_service_test.dart test\task_sync_service_test.dart test\profile_page_test.dart` 閫氳繃锛涘叏閲?`flutter test` 浠嶅け璐ヤ簬鏃㈡湁 `create_schedule_dialog_test.dart` ListTile/DecoratedBox 鏂█鍜?`widget_test.dart` 鐧诲綍椤垫枃妗堟柇瑷€銆?
## 2026-05-31 (鎬濈淮瀵煎浘锛氳嚜鍔ㄩ攣瀹氭渶杩戜换鍔?

### 鏂板
- 鍘熷洜锛氱敤鎴烽渶瑕佸湪鎬濈淮瀵煎浘鍙充笂瑙掓柊澧炲叆鍙ｏ紝鐐瑰嚮鍚庤嚜鍔ㄦ妸瑙嗚鍒囨崲鍒板綋鍓嶆椂闂存渶杩戠殑浠诲姟鑺傜偣銆?- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`锛氭柊澧炩€滆嚜鍔ㄩ攣瀹氣€濆皬鎮诞鎸夐挳锛屾寜 `startDate ?? dueDate` 鏌ユ壘鏈€杩戝彲瑙佷换鍔★紝淇濇寔褰撳墠缂╂斁姣斾緥骞跺钩绉荤敾甯冨埌鑺傜偣涓績锛涙棤甯︽椂闂磋妭鐐规椂鏄剧ず鎻愮ず銆?- 褰卞搷锛氫粎褰卞搷鎬濈淮瀵煎浘瑙嗚瀹氫綅锛屼笉淇敼浠诲姟鏁版嵁銆佸竷灞€缂撳瓨銆佹嫋鎷戒繚瀛樻垨閲嶇疆甯冨眬閫昏緫銆?- 椋庨櫓锛歚flutter analyze` 鍜?`dart analyze` 鍦ㄦ湰鏈哄潎瓒呮椂锛岄渶鍚庣画鍦ㄥ彲鐢?Flutter 宸ュ叿閾句笅澶嶈窇銆?
## 2026-05-31 (浠诲姟鍒涘缓鑷姩鎻掑叆)

### 淇敼
- 鍘熷洜锛氬垱寤轰换鍔″彂鐢熸椂闂村啿绐佹椂锛岄渶瑕佹敮鎸佸己鍒朵繚鐣欐柊浠诲姟鏃堕棿锛屽苟鎶婅鎸ゅ崰鐨勫悗缁换鍔＄骇鑱斿悗绉汇€?- `lib/services/subtask_scheduler.dart`锛氭柊澧?`ScheduledTaskShift` 鍜?`autoInsert`锛屾寜鏂颁换鍔℃椂闂存銆佸伐浣滄椂娈点€?5 鍒嗛挓缂撳啿璁＄畻琚悗绉讳换鍔°€?- `lib/presentation/pages/tasks/widgets/task_create_sheet.dart`锛氬啿绐佸脊绐楁柊澧炩€滆嚜鍔ㄦ彃鍏モ€濓紝鎵€鏈変紶鍏?`TaskRepository` 鐨勫垱寤轰换鍔￠兘浼氭娴嬪啿绐佸苟杩斿洖 `shiftedTasks`銆?- `lib/presentation/blocs/task_new/task_event.dart`銆乣task_bloc.dart`锛歚CreateTask` 鏂板 `shiftedTasks`锛屽垱寤哄悗鎵归噺鏇存柊琚悗绉讳换鍔℃椂闂淬€?- `tasks_page.dart`銆乣subtask_tree_section.dart`銆乣calendar_page.dart`锛氬垱寤哄叆鍙ｄ紶閫?`shiftedTasks`锛涙棩鍘嗗垱寤哄叆鍙ｄ紶鍏?`TaskRepository`銆?- 鏂板 `test/subtask_scheduler_test.dart` 瑕嗙洊鍚屾鎻掑叆銆佽繛缁骇鑱斿悗绉汇€佽法宸ヤ綔鏃舵鍚庣Щ銆?- 楠岃瘉锛歚dart format` 宸叉牸寮忓寲鏈 Dart 淇敼锛沗flutter test test\subtask_scheduler_test.dart` 閫氳繃锛沗flutter analyze` 鍙畬鎴愪絾浠撳簱浠嶆湁鏃㈡湁 info/warning锛涘叏閲?`flutter test` 澶辫触鍦ㄦ棦鏈?`create_schedule_dialog_test.dart` ListTile/DecoratedBox 鏂█鍜?`widget_test.dart` 鎵句笉鍒扳€滄櫤鑳藉皬绠″鈥濄€?
## 2026-05-31 (涓汉鎺у埗鍙伴潤鎬佺珯鐐?

### 鏂板
- 鍘熷洜锛氱敤鎴烽渶瑕佷竴涓渶浣庢垚鏈€佷粎鏈汉鍙闂殑缃戠珯锛岀敤浜庨厤缃姩鎬佸瘑閽ャ€佸姩鎬佹暟鎹苟绠＄悊鍚勭被 App銆?- `personal_admin_site/index.html`銆乣styles.css`銆乣app.js`锛氭柊澧為潤鎬佷釜浜烘帶鍒跺彴锛屾敮鎸?Supabase Email OTP 鐧诲綍銆佸姩鎬佸瘑閽?鍔ㄦ€佹暟鎹?App 涓夌被绠＄悊瑙嗗浘锛涘瘑閽ュ€煎湪娴忚鍣ㄧ鍔犲瘑鍚庝繚瀛樸€?- `personal_admin_site/supabase.sql`锛氭柊澧?Supabase 琛ㄧ粨鏋勩€佹洿鏂版椂闂磋Е鍙戝櫒銆丷LS 绛栫暐鍜岄偖绠?allowlist 绀轰緥銆?- `personal_admin_site/config.js`銆乣config.example.js`銆乣README.md`锛氭柊澧炲墠绔?Supabase 閰嶇疆鍗犱綅銆佹湰鍦伴厤缃€丼upabase 鍒濆鍖栧拰 Cloudflare Pages 鍏嶈垂閮ㄧ讲璇存槑銆?- 褰卞搷锛氭柊澧炵嫭绔嬬珯鐐圭洰褰曪紝涓嶄慨鏀圭幇鏈?Flutter 搴旂敤浠ｇ爜銆?- 椋庨櫓/TODO锛氬皻鏈疄闄呯嚎涓婂彂甯冿紱闇€瑕佺敤鎴锋挙閿€宸叉毚闇茬殑 Supabase Personal Access Token锛屽苟鎻愪緵 Supabase `Project URL`銆乣anon public key`銆佸厑璁哥櫥褰曢偖绠卞強 Cloudflare/Git 鎵樼鍙戝竷鏉冮檺鍚庢墠鑳藉畬鎴愪笂绾裤€?
### 琛ュ厖
- `personal_admin_site/_headers`锛氭柊澧?Cloudflare Pages 瀹夊叏鍝嶅簲澶淬€?- `personal_admin_site/DEPLOYMENT_PLAN.md`锛氭柊澧?0 缇庡厓鍥哄畾鎴愭湰閮ㄧ讲鏂规銆佸畼鏂逛緷鎹摼鎺ャ€佷笂绾挎楠ゅ拰鍙戝竷鍓嶆鏌ラ」銆?- `personal_admin_site/deploy-check.ps1`锛氭柊澧炲彂甯冨墠妫€鏌ヨ剼鏈紝闃绘鍗犱綅 Supabase 閰嶇疆鍜屾晱鎰熷瘑閽ヨ繘鍏ュ墠绔€?- `personal_admin_site/build-cloudflare.sh`銆乣build-local.ps1`锛氭柊澧?Cloudflare 鐜鍙橀噺鏋勫缓鍜屾湰鍦?Direct Upload 閰嶇疆鐢熸垚鑴氭湰銆?- `personal_admin_site/app.js`锛歋upabase 鏈厤缃椂鏄剧ず鏄庣‘鎻愮ず锛岄伩鍏嶉〉闈㈤潤榛樺垵濮嬪寲澶辫触銆?- `personal_admin_site_template.zip`锛氭柊澧為潤鎬佺珯鐐逛笂浼犳ā鏉垮寘銆?- 楠岃瘉锛歚node --check personal_admin_site\app.js` 閫氳繃锛涙湰鍦?Node 闈欐€佹湇鍔¤姹?`/` 杩斿洖 `200` 涓斿寘鍚?`Personal Control Desk`锛涚敤涓存椂鐜鍙橀噺鎵ц `build-local.ps1` + `deploy-check.ps1` 閫氳繃锛岄殢鍚庡凡鎭㈠ `config.js` 涓哄崰浣嶉厤缃€?
## 2026-05-31 (鎴戠殑妯″潡琛ュ叏)

### 淇敼
- 鍘熷洜锛氱敤鎴疯姹傚幓鎺夋垜鐨勬ā鍧楃殑"鎻愰啋璁剧疆"锛屽苟琛ュ叏"璁剧疆/甯姪涓庡弽棣?鍏充簬"鍐呭銆?- `lib/presentation/pages/profile/profile_page.dart`锛氱Щ闄?鎻愰啋璁剧疆"鑿滃崟椤癸紱"璁剧疆/甯姪涓庡弽棣?鍏充簬"鎺ュ叆椤甸潰璺宠浆锛汚I 鎺掔▼璺宠繃鍛ㄦ湯寮€鍏充粠鎴戠殑椤电Щ鍒拌缃〉銆?- 鏂板 `app_settings_page.dart`銆乣help_feedback_page.dart`銆乣about_page.dart`锛氳缃〉鍖呭惈 AI 鎺掔▼璺宠繃鍛ㄦ湯銆佷富棰樺叆鍙ｃ€侀€氱煡璇存槑銆佹暟鎹鏄庯紱甯姪椤靛寘鍚姛鑳藉府鍔┿€佸父瑙侀棶棰樺拰鍙嶉璇存槑锛涘叧浜庨〉灞曠ず浜у搧鍚嶃€佺増鏈?`1.0.0+3`銆佹牳蹇冭兘鍔涖€佹暟鎹悓姝ュ拰闅愮鏉冮檺璇存槑銆?- 褰卞搷锛氫笉鏀逛换鍔?鏃ョ▼璇︽儏涓殑鎻愰啋璁剧疆涓庨€氱煡璋冨害閫昏緫銆?- 椋庨櫓锛氱増鏈彿鍦ㄥ叧浜庨〉鎸夊綋鍓?`pubspec.yaml` 闈欐€佸睍绀猴紝鍚庣画鍙戠増闇€鍚屾鏇存柊銆?
## 2026-05-31 (棣栭〉浠诲姟璇︽儏锛氳祫婧愬尯鍚岃)

### 淇敼
- 鍘熷洜锛氱敤鎴疯姹傞椤电殑闄勪欢鍜屾鏌ラ」鏀惧埌鍚屼竴琛屻€?- `lib/presentation/pages/home/home_page.dart`锛氬皢棣栭〉 DB 浠诲姟璇︽儏搴曢儴鐨勮祫婧愬尯鏀逛负 `_buildResourceRow`锛屽瓙浠诲姟鏍戙€侀檮浠躲€佹鏌ラ」鍦ㄥ悓涓€妯悜琛屽睍绀猴紱绉婚櫎瀛愪换鍔℃爲鍐呴儴棰濆椤堕儴闂磋窛銆?- 褰卞搷锛氫粎璋冩暣棣栭〉浠诲姟璇︽儏鍗″竷灞€锛屼笉鏀归檮浠?妫€鏌ラ」/瀛愪换鍔＄殑鏁版嵁璇诲啓閫昏緫銆?- 椋庨櫓锛氱獎灞忎笅妯悜涓夊垪鍙敤瀹藉害鍙樺皬銆?
## 2026-05-30 (鏃ュ巻鍛ㄨ鍥撅細婊戝姩鏃跺ご閮ㄦ棩鏈熶笌涓嬫柟缃戞牸鍚屾)

### 浼樺寲
- 鍘熷洜锛氬懆瑙嗗浘宸﹀彸鎷栧姩鍒囨崲鏃ユ湡鏃讹紝浠呬笅鏂?body锛堟椂闂村垪+缃戞牸+浠诲姟鍧楋級璺熸墜骞崇Щ锛岄《閮?鏄熸湡+鏃ユ湡"澶撮儴涓嶅姩锛屽鑷翠袱鑰呮í鍚戦敊浣嶃€佽瑙夎劚绂?- `lib/presentation/pages/calendar/calendar_page.dart`锛?  - `_buildDayStripHeader` 鐨?鏄熸湡+鏃ユ湡"琛屽灞傚寘瑁?`ClipRect` + `Transform.translate(offset: Offset(_dragOffset, 0))`锛屽鐢?body 鍚屾 `_dragOffset`锛屼娇澶撮儴涓庝笅鏂圭綉鏍煎垪鎷栧姩杩囩▼涓í鍚戝悓姝ュ钩绉?  - 鏈堜唤瀵艰埅琛岋紙`< 骞存湀 >`锛変繚鎸佸浐瀹氾紝涓嶅弬涓庡钩绉?- 褰卞搷锛氫粎澶撮儴娓叉煋鍖呰锛屾湭鏀?`_dragOffset` 璧嬪€?鎷栧姩鍥炶皟/鍚搁檮鍒囨崲閫昏緫锛涙湀瑙嗗浘銆佺旱鍚戞粴鍔ㄣ€佺缉鏀俱€佷换鍔″潡鎷栨嫿鍧囦笉鍙楀奖鍝?- 椋庨櫓锛氫綆

## 2026-05-30 (棣栭〉浠诲姟璇︽儏锛氭柊澧炶祫婧愬尯)

### 鏂板
- 鍘熷洜锛氶椤典换鍔¤鎯呭崱鐨勬鏌ラ」鍖哄煙浠呬负鍙棰勮锛堟渶澶?鏉★級锛屼笖鏃犻檮浠跺叆鍙ｏ紝鏃犳硶鍦ㄩ椤电洿鎺ユ搷浣?- `lib/presentation/pages/home/home_page.dart`锛?  - 鏂板 `_dbTaskCache`锛坄Map<String, Task?>`锛夌紦瀛?DB Task 瀵硅薄锛屼緵 `AttachmentSection` 浣跨敤
  - 鏂板 `_loadDbTask` / `_homeToggleChecklist` / `_homeDeleteChecklist` / `_homeEditChecklist` / `_homeAddChecklist` / `_homeSetObsidianUri` 鍏釜鏂规硶锛屽鎺?`ChecklistRepository` CRUD
  - 鏂板 `_buildResourceSection` / `_buildAttachmentWidget` / `_buildChecklistWidget`锛氬乏鍙充袱鍒楀竷灞€锛屽乏鍒楀鐢?`AttachmentSection`锛屽彸鍒楀鐢?`ChecklistSection`锛堟敮鎸佸嬀閫?娣诲姞/鍙屽嚮缂栬緫/闀挎寜 Obsidian 鍏宠仈锛?  - 鍒犻櫎鍙鐨?`_buildChecklistPreview` 鏂规硶
  - `_buildTaskDetail` 搴曢儴鏇挎崲涓鸿祫婧愬尯锛屼粎瀵?`source == 'db'` 浠诲姟鏄剧ず
- 椋庨櫓锛氫綆锛涢檮浠?妫€鏌ラ」渚濊禆宸叉湁 service/repo锛岃涓轰笌浠诲姟璇︽儏椤靛畬鍏ㄤ竴鑷达紱鏃堕棿杞磋楂樹笉鍙楀奖鍝?
## 2026-07-17 (鎬濈淮瀵煎浘锛氫慨澶嶇偣鍑荤┖鐧藉鍙栨秷妗嗛€変笉鐢熸晥)

### 淇敼
- 鍘熷洜锛氬師鏈?`Listener` 鏀惧湪 `InteractiveViewer` 鍐呴儴 Stack 搴曞眰锛屾闈㈢ `InteractiveViewer` 鐨?`ScaleGestureRecognizer` 鎷︽埅鎸囬拡浜嬩欢锛屽鑷村瓙绾?`Listener.onPointerUp` 鏀朵笉鍒?鈫?鐐瑰嚮绌虹櫧澶勬棤娉曟竻绌?`_selectedIds`
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`锛?  - 鍒犻櫎 Stack 鍐呭眰鐨?`Positioned.fill` + `Listener`锛堝惈 debugPrint锛?  - 鍦?`_buildMindMapCanvas` 鐨勫灞?Stack 涓紝鐢?`Listener`锛坄HitTestBehavior.translucent`锛夊寘瑁?`InteractiveViewer`锛屽悓鏍烽€昏緫锛歱ointerDown 璁板綍浣嶇疆锛宲ointerUp 璺濈 <8px 涓?`_selectedIds` 闈炵┖鍒欐竻绌?  - 澶栧眰 Listener 涓嶉樆濉炲瓙绾ф墜鍔匡紙鎷栨嫿鑺傜偣銆丆trl+妗嗛€夈€佸钩绉荤敾甯冨潎姝ｅ父锛?- 椋庨櫓锛氫綆锛屼粎鏀瑰彉 Listener 灞傜骇浣嶇疆锛岃涓洪€昏緫涓嶅彉

## 2026-05-30 (鎬濈淮瀵煎浘锛氱偣鍑荤┖鐧藉鍙栨秷妗嗛€?

### 淇敼
- 鍘熷洜锛欳trl+宸﹂敭妗嗛€夎妭鐐瑰悗锛屾澗寮€ Ctrl 閫変腑楂樹寒鎸佺画淇濈暀锛屾棤鎵嬪娍鍙竻绌猴紝浣撻獙涓?鏃犳硶鍙栨秷"
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`锛?  - `canvasContent()` 鐨?`Stack` 鏈€搴曞眰鏂板鍏ㄥ睆鑳屾櫙 `Listener`锛坄HitTestBehavior.translucent`锛夛紝`onPointerUp` 鏃惰嫢鎸変笅鍒版姮璧蜂綅绉?<8px 涓?`_selectedIds` 闈炵┖鍒欐竻绌哄苟 `setState`
  - 鏂板瀛楁 `_bgPointerDownPos` 璁板綍鎸変笅浣嶇疆锛岀敤浜庡尯鍒?鐐瑰嚮"涓?骞崇Щ"
  - 鏀圭敤 `Listener`锛堢粫杩囨墜鍔跨珵鎶€鍦猴級鑰岄潪 `GestureDetector.onTap`锛氬悗鑰呬綔涓?`InteractiveViewer` 瀛愯妭鐐规椂绌虹櫧澶?tap 浼氳鍏剁缉鏀捐瘑鍒櫒鎶㈣蛋锛屽鑷撮鐗堟棤鏁?- 椋庨櫓锛氫綆锛屾湭鏀瑰姩鐜版湁妗嗛€?鎷栨嫿/閿洏閫昏緫锛涘钩绉讳粛姝ｅ父锛堜綅绉?8px 涓嶈Е鍙戞竻绌猴級

## 2026-07-15 (鏃ュ巻鍛ㄨ鍥炬嫋鎷芥敼涓?Transform 璺熸墜骞崇Щ)

### 淇敼
- 鍘熷洜锛氭嫋鎷戒笉璺熸墜鈥斺€旈槇鍊兼柟寮忎笉鎻愪緵瑙嗚鍙嶉锛屾闈㈤紶鏍?delta 澶ф椂涓€娆¤烦澶氬ぉ
- `lib/presentation/pages/calendar/calendar_page.dart`锛?  - 鏂板 `_dragOffset` / `_cachedDayWidth` 瀛楁
  - `_buildWeekTimeline`锛歚GestureDetector` + `Transform.translate` 鍖呰９澶氭棩鏍?鏃堕棿绾匡紝`_dragOffset` 椹卞姩骞崇Щ
  - `_onCalendarHorizontalDragUpdate`锛氱疮鍔?`details.delta.dx` 鍒?`_dragOffset` + `setState`
  - `_onCalendarHorizontalDragEnd`锛歚-(_dragOffset / _cachedDayWidth).round()` 绠楀ぉ鏁板亸绉?鈫?鏇存柊 `_focusedDay` 鈫?褰掗浂 `_dragOffset`

## 2026-05-30 (澶氫富棰樺垏鎹細鏋佸厜钃?+ 鏇滅煶榛?

### 鏂板
- 鍘熷洜锛氬師浠呬竴濂楀啓姝荤殑 Claude 鏆栫強鐟氳壊涓婚锛宲rofile"涓婚"鑿滃崟涓虹┖澹筹紙`onTap: () {}`锛夛紱闇€鍦ㄩ粯璁や富棰樺澧炲姞涓ゅ澶у巶鏍囧噯鍙垏鎹富棰?- 閲嶆瀯 `lib/core/theme/app_theme.dart`锛氭娊鍑?`AppPalette` 璋冭壊鏉挎ā鍨嬶紙鎸佹湁鍏ㄩ儴棰滆壊 token + `ThemeData build()`锛夛紝瀹氫箟涓夊瀹炰緥 `claude`/`auroraBlue`锛圙oogle Material 3 钃濓級/`obsidian`锛堟繁鑹叉ā寮忥級锛沗AppTheme` 棰滆壊 token 鐢?`static const` 鏀逛负濮旀墭 `_current` 璋冭壊鏉跨殑 `static get`锛屽澶?API 鍚嶄笉鍙橈紝653 澶勫紩鐢ㄩ浂鏀瑰姩
- 鏂板 `lib/core/theme/theme_controller.dart`锛歚ThemeController`锛圕hangeNotifier锛夋寔涔呭寲 + 閫氱煡閲嶅缓锛屽叏灞€鍗曚緥 `themeController`
- 鏂板 `lib/presentation/pages/profile/theme_settings_page.dart`锛氫笁寮犻瑙堝崱閫夋嫨椤碉紝瀹炴椂鍒囨崲
- `lib/services/local_storage_service.dart`锛氭柊澧?`_themeKey`/`themeId`/`setThemeId`锛圫haredPreferences 鎸佷箙鍖栵級
- `lib/main.dart`锛歚main()` 鍔?`await themeController.load()`锛沗MaterialApp` 澶栧寘 `ListenableBuilder`锛宍theme/darkTheme: AppTheme.themeData`锛宍themeMode` 闅忓綋鍓嶈皟鑹叉澘浜?鏆楀垏鎹?- `profile_page.dart`锛氫富棰樿彍鍗曟帴鍏?`Navigator.push` 鍒拌缃〉
- 褰卞搷锛氬洜棰滆壊 token 鐢?const 鍙?getter锛?15 澶?const 涓婁笅鏂囧紩鐢紙25 鏂囦欢锛夊幓闄?`const`锛堣剼鏈壒閲?+ 5 澶?const 鍒楄〃瀛楅潰閲忔墜宸ユ敼 final锛?- 椋庨櫓锛氬幓 const 鍚庝骇鐢?~89 涓?`prefer_const` info 绾ф彁绀猴紙闈炶嚧鍛斤級锛涙洔鐭抽粦娣辫壊涓嬩釜鍒啓姝?`Colors.white/black` 澶勯渶鐩瀵规瘮搴︼紱鍒囨崲椤典竴娆℃€ц绠楋紝鎬ц兘褰卞搷鍙拷鐣?
## 2026-05-30 (涓汉涓績缁熻鍗＄湡瀹炴暟鎹?

### 淇敼
- 鍘熷洜锛氫釜浜轰腑蹇?鎬讳换鍔?瀹屾垚鐜?杩炵画"涓哄啓姝荤殑 128/78%/15澶╋紝闇€鎸夌湡瀹炰换鍔℃暟鎹覆鏌?- `ProfilePage` 澧炲姞 `taskRepository` 鍙┖鍙傛暟锛沗_init()` 涓媺鍙?`getAll()` 璁＄畻鎬讳换鍔℃暟銆佸畬鎴愮巼锛坰tatus==2 鍗犳瘮鍥涜垗浜斿叆锛夈€佽繛缁ぉ鏁帮紙鎸?`completedTime` 鏈湴鏃ユ湡杩炵画鍥炴函锛屼粖鏃ユ湭瀹屾垚鍒欎粠鏄ㄦ棩璧风畻锛?- `_buildStatsSection` 鐢?`_total/_completionRate/_streak` 鏇挎崲鍐欐鍊?- `home_page.dart` 灏?`const ProfilePage()` 鏀逛负浼犲叆 `widget.taskRepository`
- 鏂囦欢锛歭ib/presentation/pages/profile/profile_page.dart, lib/presentation/pages/home/home_page.dart
- 椋庨櫓锛歚taskRepository` 涓虹┖鏃剁粺璁℃樉绀?0锛涘垏鎹㈠埌"鎴戠殑"椤垫椂涓€娆℃€ц绠楋紝鏂板/瀹屾垚浠诲姟鍚庨渶閲嶈繘璇ラ〉鍒锋柊

## 2026-06-06 (鍥涜薄闄愬垪婧㈠嚭 + 鍘婚€炬湡鎻愮ず)

### 淇敼
- 绉婚櫎 `_buildQuadrantChart` 涓?`q.removeRange(5, q.length)` 纭笂闄愭埅鏂?- 绉婚櫎椤堕儴 `"N 涓换鍔″凡閫炬湡"` 绾㈣壊妯箙鍙?`overdueCount` 鍙橀噺
- 绉婚櫎 `_buildQuadrant` 搴曢儴 `"N 閫炬湡"` 绾㈣壊鏂囧瓧
- 閲嶅啓 `_buildQuadrant`锛氫换鍔℃寜姣忓垪 5 鏉″垎鐗囷紝澶氬垪 `SingleChildScrollView` 妯悜婊氬姩锛屽垪闂?1px 鍒嗛殧绾匡紝绉婚櫎 `tasks.take(4)` + `"+N 鏇村"`
- 鏂囦欢锛歭ib/presentation/pages/home/home_page.dart

## 2026-06-06 (鎬濈淮瀵煎浘 Ctrl+妗嗛€夊鑺傜偣鍔熻兘)

### 淇
- 璐熷潗鏍囪妭鐐瑰啀鎷栧姩鈫掑叏鑱斿姩锛氱敾甯冨昂瀵?`abs()` 鈫?鎭㈠鍘熷姝ｅ悜鎵╁睍锛岄伩鍏?InteractiveViewer 閲嶈皟 viewport
- 鑺傜偣鎵€鏈夋柟鍚戣嚜鐢辨嫋鎷斤細绉婚櫎 `clamp(0,鈭?` / `clamp(6,鈭?` 闄愬埗
- Ctrl+妗嗛€夐噸鍐欙細`ValueNotifier<_ctrlPressed>` + `ValueListenableBuilder` + `IgnorePointer` 鍗虫椂鍒囨崲鏋舵瀯锛沗GestureDetector` overlay 鎷︽埅妗嗛€夋墜鍔?- 閫変腑鑺傜偣钃濊壊杈规楂樹寒 + Esc 娓呴櫎閫変腑
- 鏂囦欢锛歭ib/presentation/pages/tasks/widgets/mind_map_view.dart

## 2026-06-06 (鎬濈淮瀵煎浘鎵嬪娍淇 + 棣栭〉缁熻浼樺寲)

### 淇
- 鎬濈淮瀵煎浘鑺傜偣涓婃嫋鍚?+"鎸夐挳鐐逛笉鍔細`_MindMapNodeCard` 鑷敱鎷栨嫿妯″紡 GestureDetector 鏀圭敤 `onPanDown`锛堟瘮 `onPanStart` 鏇存棭瑙﹀彂锛岃 `_nodeDragging=true`锛? 鏂板 `onPanCancel` 娓呯悊銆? 鎸夐挳鍔?`HitTestBehavior.opaque` + 鐑尯 28脳28銆?- 鎷栭噸鍙犺妭鐐瑰鑷存暣妫垫爲涓€璧锋嫋鍔細鍚屼笂锛宍onPanDown` 鏇夸唬 `onPanStart` 纭繚 InteractiveViewer 鐨?pan 鍦?hit test 闃舵琚鐢紝`onPanCancel` 闃叉 `_nodeDragging` 娈嬬暀銆?
### 浼樺寲
- 棣栭〉"涓嬪崍濂?涓庣粺璁″崱鐗囷紙浠婃棩浠诲姟/瀹屾垚鐜?閫炬湡锛夊悎骞朵负鍚屼竴琛?Row 甯冨眬锛岀粺璁″崱鐗囨敼涓虹揣鍑?inline 鏍峰紡锛岀偣鍑诲彲灞曞紑瀹屾暣璇︽儏锛堝惈鍛ㄦ湡鍒囨崲锛夈€?- 鍛ㄦ湡鍒囨崲绉昏嚦璇︽儏寮圭獥鍐咃紝涓婚〉闈粎鏄剧ず褰撳墠鍛ㄦ湡鏁版嵁銆?
## 2026-05-30 (浠诲姟妯″潡 6 椤?Bug 淇)

### 淇
- 鏃ユ湡绛涢€夋竻闄ゅけ鏁堬細`LoadTasks` 鏂板 `clearDateRange`锛宍task_bloc._onLoadTasks` 娓呴櫎鏃跺己鍒舵妸 `dateFrom/dateTo` 缃?null锛堝師 `?? preservedDateFrom` 浼氫繚鐣欐棫绛涢€夊鑷存竻涓嶆帀銆佹棤娉曢噸璁撅級銆俙tasks_page` 娓呴櫎鍒嗘敮浼?`clearDateRange: true`銆?- 鑺傚亣鏃ヤ笉鏄剧ず锛歚holiday_service._fetchChina` 鏁版嵁婧?`timor.tools` 宸蹭笉鍙揪锛屽け璐?绌虹粨鏋滄椂鍥為€€ `date.nager.at`锛圕N锛屼粎娉曞畾鑺傚亣鏃ワ紝鏃犺皟浼戣ˉ鐝級銆?- 瀛愪换鍔℃椂闂村啿绐佹娴嬩粎鎬濈淮瀵煎浘鍏ュ彛鐢熸晥锛氳鎯呴〉 `subtask_tree_section._showAddSubTaskDialog` 鍘熶负绾爣棰樺璇濇銆佹棤鏃堕棿鏃犳娴嬶紝鏀逛负澶嶇敤 `TaskCreateSheet`锛堝惈寮€濮?鎴鏃堕棿 + `_checkConflict` 鍐茬獊妫€娴嬶級锛岃繑鍥炲悗娲惧彂 `CreateTask(parentId)` 骞跺埛鏂板瓙鏍戙€?- 鎬濈淮瀵煎浘鑺傜偣涓婃嫋鍚?+"鐐逛笉鍔細`mind_map_view` `onDragUpdate` 閽冲埗鑺傜偣鍧愭爣 `dx>=0/dy>=6`锛岄槻姝㈣秺鍑虹敾甯?`SizedBox` 瀵艰嚧 `Clip.none` 婧㈠嚭鍖烘棤娉曞懡涓€?- 鎷栧崟涓妭鐐规暣鐗囩敾甯冭仈鍔細鏂板 `_nodeDragging` 鏍囪锛岃妭鐐规嫋鎷芥湡闂?`InteractiveViewer.panEnabled = !_nodeDragging`锛岄伩鍏嶇敾甯冨钩绉讳笌鑺傜偣鎷栨嫿鍚屾椂瑙﹀彂锛堟挙閿€涓婁竴鐗?鎭掍负 true"鐨勫垽鏂級銆?
### 淇敼
- `tasks_page.dart`锛氱Щ闄?AppBar 鍙充笂瑙?鏂板缓椤圭洰"鎸夐挳锛堟娊灞夊唴鍏ュ彛淇濈暀锛夈€?
---

## 2026-05-30 (鐢诲竷鎷栧姩淇 + 瀛愪换鍔℃椂闂村啿绐佹娴?

### 淇
- `mind_map_view.dart`锛歚InteractiveViewer` 鐨?`panEnabled` 鐢?`!_freeDragMode`锛? false锛夋敼涓?`true`锛屾仮澶嶇敾甯冭嚜鐢卞钩绉汇€侳lutter 鎵嬪娍绔炴妧鍦鸿嚜鍔ㄥ鐞嗚妭鐐规嫋鎷戒笌鐢诲竷鎷栨嫿鐨勪紭鍏堢骇锛屼笉闇€瑕佹墜鍔ㄥ叧闂€?
### 鏂板
- `task_create_sheet.dart`锛氭柊澧?`TaskRepository? taskRepository` 鍙€夊弬鏁般€傚綋鍒涘缓瀛愪换鍔★紙`initialParentId != null`锛夋椂锛宍_submit` 鍦ㄦ彁浜ゅ墠鏌ヨ宸叉湁浠诲姟鏃堕棿娈碉紝妫€娴嬪尯闂撮噸鍙狅紝寮瑰啿绐佹彁绀哄脊绐楋紝鏀寔涓夌澶勭悊鏂瑰紡锛氬苟琛岋紙淇濇寔鍘熸椂闂达級銆佸彇娑堛€佽嚜鍔ㄥ欢鍚庯紙鍒╃敤 `SubtaskScheduler` 璁＄畻涓嬩竴绌洪棽鏃舵锛夈€?
### 淇敼
- `tasks_page.dart`锛歚_showCreateTaskSheet` 浼犲叆 `taskRepository` 缁?`TaskCreateSheet`
- `calendar_page.dart`锛歚_showCreateTaskSheet` 浼犲叆 `taskRepository` 缁?`TaskCreateSheet`

### 椋庨櫓
- 鑷姩寤跺悗浣跨敤 `SubtaskScheduler`锛屽伐浣滄椂娈甸檺瀹?09:00鈥?1:00锛涜嫢鎵€鏈夋椂娈靛凡婊★紙鐞嗚鏋佺鎯呭喌锛夛紝杩斿洖 null锛屾鏃朵繚鎸佸師鏃堕棿鍒涘缓

## 2026-05-30 (鎵嬫満绔换鍔℃彁閱掑彲闈犳€т慨澶?+ 鏉冮檺寮曞)

### 淇
- Android/iOS 绔彁閱掓敼鐢?`zonedSchedule`锛堢郴缁?AlarmManager锛夛紝涓嶅啀渚濊禆 Flutter 杩涚▼瀛樻椿锛汚pp 琚潃/鍚庡彴鍚庨€氱煡浠嶅彲瑙﹀彂
- 绉婚櫎 Android/iOS 鍒嗘敮鐨?Timer 璺緞锛涙闈㈢淇濈暀 Timer

### 鏂板
- `AndroidManifest.xml`锛氭坊鍔?`RECEIVE_BOOT_COMPLETED` 鏉冮檺 + `ScheduledNotificationBootReceiver`锛岄噸鍚悗鑷姩鎭㈠宸茶皟搴﹂€氱煡
- `lib/services/permission_service.dart`锛氬皝瑁呰繍琛屾椂閫氱煡鏉冮檺鐢宠锛坄requestNotificationPermission`锛? 棣栨鍚姩寮曞 dialog锛坄showNotificationGuideIfNeeded`锛夛紝鐢?`SharedPreferences` 闃叉閲嶅寮瑰嚭

### 淇敼
- `pubspec.yaml`锛氭坊鍔?`timezone: ^0.10.1`锛宍notification_service.dart` 鍦?`init()` 涓皟鐢?`tz.initializeTimeZones()`
- `lib/presentation/pages/home/home_page.dart`锛氶娆¤繘鍏?`HomePage` 鏃堕€氳繃 `addPostFrameCallback` 瑙﹀彂閫氱煡鏉冮檺寮曞
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`锛歚_reminderEnabled` 绫诲瀷鐢?`int` 鏀逛负 `bool`锛屾秷闄や笌 model 灞?bool 鐨勭被鍨嬩笉涓€鑷?
### 椋庨櫓
- `zonedSchedule` 闇€瑕佽澶囨敮鎸佺簿纭椆閽燂紙`SCHEDULE_EXACT_ALARM`锛夛紝Android 12+ 鐢ㄦ埛鑻ュ湪绯荤粺璁剧疆鍏抽棴绮剧‘闂归挓鏉冮檺锛岄€氱煡浠嶅彲鑳藉欢杩?- 閲嶅惎鍚庢仮澶嶄緷璧?`flutter_local_notifications` 鍐呯疆 Receiver 宸ヤ綔姝ｅ父锛岄渶鐪熸満楠岃瘉

## 2026-05-30 (鏃ュ巻鑺傚亣鏃ユ樉绀?+ 澶氬浗鍒囨崲)

### 鍔熻兘
鏃ュ巻椤甸潰鏀寔鏄剧ず娉曞畾鑺傚亣鏃ワ紙绾㈣壊锛夈€佽皟浼戣ˉ鐝紙钃濊壊锛夛紝鍙垏鎹㈠浗瀹讹紙榛樿涓浗锛夛紝鏁版嵁浠?API 瀹炴椂鎷夊彇骞剁紦瀛?7 澶┿€?
### 鏂板
- `lib/services/holiday_service.dart`锛氳妭鍋囨棩鏈嶅姟锛屼腑鍥界敤 timor.tools API锛屽叾浠栧浗瀹剁敤 date.nager.at锛沗SharedPreferences` 7 澶╃紦瀛?+ 鏂綉闄嶇骇

### 淇敼
- `lib/presentation/pages/calendar/calendar_page.dart`锛?  - AppBar 鏂板鍥芥棗鎸夐挳锛屽垏鎹?馃嚚馃嚦馃嚭馃嚫馃嚡馃嚨馃嚞馃嚙馃嚢馃嚪 浜斿浗鑺傚亣鏃?  - 鍛ㄨ鍥炬棩鏈熷ご锛坄_buildCustomWeekHeader`锛夛細鑺傚亣鏃ュ悕绉版樉绀哄湪鏃ユ湡鍦嗗湀涓嬫柟
  - 鏈堣鍥撅紙`_buildTableCalendar`锛夛細浣跨敤 `calendarBuilders` 鍦ㄦ牸瀛愬唴鏄剧ず鑺傚亣鏃ュ皬瀛?  - 骞翠唤鍒囨崲鏃惰嚜鍔ㄦ媺鍙栨柊骞翠唤鏁版嵁

### 椋庨櫓
- 澶栭儴 API锛坱imor.tools / date.nager.at锛変笉鍙敤鏃朵粎鏄剧ず缂撳瓨鏁版嵁锛涘垵娆′娇鐢ㄦ棤缂撳瓨鍒欒妭鍋囨棩涓虹┖
- timor.tools 鐩墠鍙彁渚涜繎 2 骞存暟鎹紝瓒呭嚭鑼冨洿鐨勫勾浠借繑鍥炵┖

## 2026-05-30 (淇鎬濈淮瀵煎浘瀛愪换鍔℃秷澶?

### 鏍瑰洜
`ProjectSyncService._upsertProjectFromRow` 鏀跺埌浜戠椤圭洰澧撶 (`deleted=1`) 鍚庯紝**鏃犳潯浠剁骇鑱旇蒋鍒犺椤圭洰涓嬪叏閮ㄤ换鍔?*锛屼笖鑷韩鏃犲纰戜繚鎶ゃ€?鍚姩鏃?`ProjectSyncService.syncAll()` 鍏堜簬 `TaskSyncService.syncAll()` 鎵ц锛屼换鍔″湪浠诲姟鍚屾寮€濮嬪墠灏辫娓呮帀銆?
鍚屾椂淇浜?`_onRemoteDelete` (task) 鍜岄」鐩?Realtime DELETE 鍥炶皟鐨勫悓绫婚棶棰樸€?
### 淇
- `lib/services/project_sync_service.dart`: `_upsertProjectFromRow` 鍔犲纰戜繚鎶も€斺€旀湰鍦板瓨娲婚」鐩嫆缁濊繙绔纰戯紝涓嶇骇鑱斿垹浠诲姟锛涢」鐩?Realtime DELETE 鍥炶皟鍔犲纰戜繚鎶?- `lib/services/task_sync_service.dart`: `_onRemoteDelete` 鍔犲纰戜繚鎶?- `lib/data/repositories/task_repository.dart`: `delete()` 鍔犳棩蹇?
### 褰卞搷鏂囦欢
- `lib/services/project_sync_service.dart`
- `lib/services/task_sync_service.dart`
- `lib/data/repositories/task_repository.dart`

## 2026-06-04 (鎬濈淮瀵煎浘鎷栧姩鎬ц兘浼樺寲)

### 鏍瑰洜
1. `_lineAnimController` 姣忔 `onPanUpdate` 閲嶇疆鍔ㄧ敾鍒?锛宎nimation listener 棰濆瑙﹀彂 ~18 娆?`setState`锛屾瘡甯у疄闄呰Е鍙?2+ 娆″叏閲?rebuild
2. 姣忔 `setState` 瑙﹀彂瀹屾暣 `build()` 鈫?閲嶆柊鎵ц `_buildTree / _layoutTree / _collectNodes` 绛?O(n) 璁＄畻
3. 姣忓抚鍏ㄩ噺閲嶅缓鎵€鏈夎妭鐐?Widget锛屾棤 RepaintBoundary 闅旂
4. `build()` 鍐呮湁澶ч噺 `print` 璋冭瘯鏃ュ織

### 淇敼鍐呭
1. 鍒犻櫎 `_lineAnimController` 鍔ㄧ敾鎺у埗鍣?+ `_animatedPositions` + `_manualOffsets`
2. 鏂板甯冨眬缂撳瓨锛坄_cachedPendingNodes/Lines/CanvasSize` 绛夛級锛宍initState` / `didUpdateWidget` 涓绠楋紝`build()` 鐩存帴璇荤紦瀛?3. 鎷栨嫿鏀逛负 `ValueNotifier<Offset>` 姣忚妭鐐圭嫭绔?+ `ValueListenableBuilder`锛屽彧閲嶅缓琚嫋鎷借妭鐐?4. 杩炵嚎灞傜敤 `AnimatedBuilder` + `Listenable.merge` 鐩戝惉鎵€鏈?notifier锛屽彧閲嶅缓 `CustomPaint`
5. 鍒犻櫎 `build()` 鍐呮墍鏈?`print` 璋冭瘯鏃ュ織
6. 姣忎釜鑺傜偣澶栧寘 `RepaintBoundary`

### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`

## 2026-06-04 (鎷栨嫿浣嶇疆鎸佷箙鍖?+ 鐢ㄦ埛闅旂)

### 淇敼鍐呭
1. `MindMapView` 鏂板 `userId` 鍙傛暟
2. `_loadOffsets()` 鈥?浠?SharedPreferences 鍔犺浇宸蹭繚瀛樺亸绉伙紝key 涓?`mindmap_offsets_<userId>`
3. `_saveOffsets()` 鈥?鎷栨嫿缁撴潫鏃跺皢 `_draggedIds` 瀵瑰簲浣嶇疆搴忓垪鍖栦负 JSON 淇濆瓨
4. `onDragEnd` 鍥炶皟璋冪敤 `_saveOffsets()` 鈥?鏉惧紑榧犳爣鍗冲埢鎸佷箙鍖?5. 閲嶇疆鎸夐挳鍚屾椂娓呴櫎鎸佷箙鍖栨暟鎹?6. `TasksPage` 浠?`AuthBloc` 鎻愬彇 userId锛圫upabase `user.id` 鎴栨湰鍦?`local_<email>`锛夊苟浼犲叆

### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`

## 2026-05-30 (淇鎬濈淮瀵煎浘瀛愪换鍔￠噸鍚悗琚簯绔鐭宠鐩栧垹闄?

### 鏍瑰洜
`syncAll` 浠庝簯绔媺鍙栨椂锛屼簯绔畫鐣欐棫鐨?`deleted=1` 澧撶煶璁板綍锛宍syncFromJson` 鐨?LWW 閫昏緫灏嗘湰鍦版椿浠诲姟(deleted=0)瑕嗙洊涓?deleted=1銆傚悓鏃?`taskRepository.create` 涓?`push` 鏈?await锛屽瓨鍦ㄧ珵鎬併€?
### 淇敼鍐呭
1. `task_repository.dart:syncFromJson` 鈥?鏂板鍙嶅悜澧撶煶淇濇姢锛氭湰鍦版椿浠诲姟(deleted=0)涓嶈杩滅澧撶煶(deleted=1)瑕嗙洊
2. `task_repository.dart:create` 鈥?`push` 鏀逛负 await锛屾秷闄ょ珵鎬?3. `task_sync_service.dart:syncAll` 鈥?鏈湴娲讳絾浜戠鏄鐭虫椂涓诲姩鎺ㄩ€佽鐩栵紝淇娈嬬暀澧撶煶
4. 鏂板 `file_logger.dart` 鏂囦欢鏃ュ織宸ュ叿 + 鍏抽敭璺緞璇婃柇鏃ュ織

### 褰卞搷鏂囦欢
- `lib/data/repositories/task_repository.dart`
- `lib/services/task_sync_service.dart`
- `lib/presentation/blocs/task_new/task_bloc.dart`
- `lib/main.dart`
- `lib/core/utils/file_logger.dart`锛堟柊澧烇級

### 椋庨櫓
- 浣庯細鍙嶅悜澧撶煶淇濇姢鍙兘瀵艰嚧鐢ㄦ埛鍦ㄥ叾浠栬澶囧垹闄ょ殑浠诲姟鍦ㄦ湰璁惧"澶嶆椿"锛屼絾浼樺厛淇濊瘉鏁版嵁涓嶄涪澶?
## 2026-05-31 (淇鎬濈淮瀵煎浘妯″紡瀛愪换鍔℃秷澶?

### 淇敼鍐呭
1. `_onLoadTasks` 琛ュ叏鐘舵€佷繚鐣欙細`viewMode`銆乣dateFrom`銆乣dateTo` 浠庝笂涓€涓?`TaskNewLoaded` 鐘舵€佺户鎵?2. 涔嬪墠 `CreateTask` 鈫?`LoadTasks` 鈫?`emit TaskNewLoaded` 鏃舵湭浼犲叆 `viewMode`锛岄粯璁ゅ洖閫€涓?`'mindmap'`
3. 鏃ユ湡绛涢€?`dateFrom`/`dateTo` 鍚屾牱涓㈠け锛屽鑷存坊鍔犲瓙浠诲姟鍚庢棩鏈熺瓫閫夎娓呴櫎

### 褰卞搷鏂囦欢
- `lib/presentation/blocs/task_new/task_bloc.dart`

### 椋庨櫓
- 浣庯細绾閲忎繚鐣欙紝涓嶅奖鍝嶇幇鏈夐€昏緫

## 2026-05-30 (鎬濈淮瀵煎浘鑷敱鎷栨嫿 + 杩炵嚎寤惰繜鍔ㄧ敾)

### 淇敼鍐呭
1. **鑷敱鎷栨嫿妯″紡**锛氬彸涓嬭鏂板鍔犻攣/瑙ｉ攣鍒囨崲鎸夐挳锛岃В閿佸悗鑺傜偣鍙嚜鐢辨嫋鍔ㄥ埌鐢诲竷浠绘剰浣嶇疆
2. **杩炵嚎寤惰繜鍙樼煭鍔ㄧ敾**锛氭嫋鍔ㄨ妭鐐规椂杩炵嚎甯?300ms easeOut 鎯€ц繃娓★紝鏉炬墜鍚庡钩婊戠缉鐭嚦鏈€缁堜綅缃?3. **`_ConnectorLine` 閲嶆瀯**锛氫粠瀛樻鍧愭爣鏀逛负瀛?`parentId`/`childId`锛宍_MindMapLinesPainter` 鍔ㄦ€佹煡琛ㄧ粯鍒?4. **`_MindMapNodeCard` 澧炲己**锛氭柊澧?`freeDragMode`/`onDragUpdate` 鍙傛暟锛岃嚜鐢辨ā寮忎笅鐢?`GestureDetector` 澶勭悊鎷栧姩
5. **`InteractiveViewer.panEnabled` 鎸夋ā寮忓垏鎹?*锛氳嚜鐢辨嫋鎷芥椂绂佺敤鐢诲竷骞崇Щ閬垮厤鎵嬪娍鍐茬獊锛岀缉鏀句粛鍙敤

### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`

### 椋庨櫓
- 鑷敱鎷栨嫿妯″紡涓嬬敾甯冩棤娉曞钩绉伙紙浠呭彲缂╂斁锛夛紝闇€鍒囨崲鍥炶嚜鍔ㄥ竷灞€妯″紡鍚庢仮澶嶅钩绉?
## 2026-05-29 (鎬濈淮瀵煎浘鎷栧姩/甯冨眬/鏃堕棿缂栬緫/瀛愪换鍔℃秷澶变慨澶?

### 淇敼鍐呭
1. **鏃犻檺鎷栧姩**锛歚boundaryMargin` 鏀逛负 `double.infinity`锛岀缉灏忓悗涔熷彲鑷敱宸﹀彸鎷栧姩
2. **甯冨眬闂磋窛浼樺寲**锛歏Gap 16鈫?8, HGap 80鈫?00, Padding 40鈫?00锛岃妭鐐逛笉鍐嶇揣璐存尋鍦ㄤ竴璧?3. **灞曞紑鎸夐挳绉诲埌鏍囬琛?*锛氫粠浼樺厛绾ц绉诲埌鏍囬鏂囨湰鍙充晶锛岃瑙夋洿鍚堢悊
4. **鏃堕棿鍒嗗紑缂栬緫**锛氬紑濮?缁撴潫鏃堕棿鍚勮嚜鐙珛鐐瑰嚮寮?picker 缂栬緫锛屼笉鍐嶈繛缁脊涓ゆ
5. **瀛愪换鍔℃秷澶变慨澶?*锛歚_onCreateTask` 淇濈暀褰撳墠 filter/projectId锛屽苟璋冪敤 `_syncTasksToCloud()`
6. **娣诲姞瀛愪换鍔″悗鑷姩灞曞紑鐖惰妭鐐?*

### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/blocs/task_new/task_bloc.dart`

### 椋庨櫓
- 瀛愪换鍔℃秷澶遍棶棰樼殑鏍瑰洜鍙兘杩樻湁鍏朵粬鍥犵礌锛堝 Realtime 鍥炶皟锛夛紝宸蹭慨澶嶆渶鏄庢樉鐨?filter 涓㈠け闂

## 2026-05-29 (鎬濈淮瀵煎浘瑙嗗浘浼樺寲 + 妫€鏌ラ」婧㈠嚭淇)

### 淇敼鍐呭
1. **鎬濈淮瀵煎浘鍗＄墖鍙充晶 "+" 鎸夐挳**锛氭瘡涓换鍔″崱鐗囧彸渚т腑闂存柊澧炲渾褰?"+" 鎸夐挳锛岀偣鍑荤洿鎺ュ垱寤哄瓙浠诲姟锛堥璁?parentId锛?2. **鎬濈淮瀵煎浘椤圭洰鍒囨崲**锛氬崱鐗囦笂椤圭洰鍚嶅彲鐐瑰嚮寮瑰嚭椤圭洰閫夋嫨鑿滃崟锛岀洿鎺ュ垏鎹㈡墍灞為」鐩?3. **鏃堕棿灞曠ず浼樺寲**锛氬崱鐗囨樉绀哄畬鏁存椂闂磋寖鍥达紙寮€濮嬧啋缁撴潫锛夛紝鐐瑰嚮鍙垎鍒慨鏀瑰紑濮嬪拰缁撴潫鏃堕棿
4. **鐢诲竷鎷栨嫿浼樺寲**锛氬澶?boundaryMargin 鑷?800px锛岀缉鏀捐寖鍥磋皟鏁翠负 0.15~3.0锛屾敮鎸佺伒娲荤殑宸﹀彸涓婁笅鎷栨嫿鍜岀缉鏀?5. **鍘绘帀 Slidable**锛氱Щ闄ゆ€濈淮瀵煎浘鍗＄墖鐨勫乏婊戞墜鍔匡紙瀹屾垚/鍒犻櫎锛夛紝閬垮厤涓庣敾甯冩嫋鎷藉啿绐?6. **鍙充笂瑙?"-" 鍒犻櫎鎸夐挳**锛氭瘡涓崱鐗囧彸涓婅鍥哄畾绾㈣壊 "-" 鎸夐挳锛屾敮鎸佸揩鎹峰垹闄?7. **妫€鏌ラ」婧㈠嚭淇**锛氬皢 `Flexible` 鏇挎崲涓?`ConstrainedBox(maxHeight: 240)`锛岃В鍐?"BOTTOM OVERFLOWED BY 8.0 PIXELS" 榛勮壊婧㈠嚭鎶ラ敊

### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/pages/tasks/widgets/task_create_sheet.dart`
- `lib/presentation/pages/tasks/task_detail/widgets/checklist_section.dart`

### 椋庨櫓
- 椤圭洰閫夋嫨鑿滃崟鍦ㄩ」鐩緢澶氭椂鍙兘闇€瑕佹粴鍔ㄤ紭鍖?
## 2026-05-29 (鎬濈淮瀵煎浘浠诲姟瑙嗗浘 + 绯荤粺鎵樼洏淇)

### 淇敼鍐呭
1. **鎬濈淮瀵煎浘浠诲姟瑙嗗浘**锛氭柊澧?`mind_map_view.dart`锛屼换鍔″垪琛ㄦ敮鎸佹按骞虫€濈淮瀵煎浘灞曠ず锛堟牴鑺傜偣鍦ㄥ乏锛屽瓙鑺傜偣鍚戝彸鍒嗘敮锛岃礉濉炲皵鏇茬嚎杩炴帴绾匡級銆備繚鐣欐嫋鎷姐€佸睍寮€/鎶樺彔銆佷紭鍏堢骇銆丼lidable绛夊叏閮ㄤ氦浜掋€傛闈㈢榛樿鎬濈淮瀵煎浘锛屽彲閫氳繃 AppBar 鎸夐挳鍒囨崲鍒楄〃/瀵煎浘瑙嗗浘銆?2. **绯荤粺鎵樼洏鍥炬爣涓€鑷存€?*锛氱敤 `windows/runner/resources/app_icon.ico` 鏇挎崲 `assets/icons/tray_icon.ico`锛岀‘淇濇墭鐩樺浘鏍囦笌搴旂敤鍥炬爣涓€鑷淬€?3. **鍗曞疄渚嬩繚鎶?*锛歚windows/runner/main.cpp` 娣诲姞 Named Mutex锛岄槻姝㈠寮€銆傜浜屼釜瀹炰緥浼氭縺娲诲凡鏈夌獥鍙ｅ悗閫€鍑恒€?4. **閫€鍑哄欢杩熶慨澶?*锛氭墭鐩?閫€鍑?鑿滃崟鏀逛负 `windowManager.destroy()` + `exit(0)`锛岃В鍐冲叧闂欢杩熴€?
### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`锛堟柊寤猴級
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/blocs/task_new/task_state.dart`
- `lib/presentation/blocs/task_new/task_event.dart`
- `lib/presentation/blocs/task_new/task_bloc.dart`
- `lib/main.dart`
- `windows/runner/main.cpp`
- `assets/icons/tray_icon.ico`

### 椋庨櫓
- 澶ч噺浠诲姟鏃舵€濈淮瀵煎浘鍙兘闇€瑕佹€ц兘浼樺寲
- InteractiveViewer 涓?Draggable 鎵嬪娍鍐茬獊闇€鍏虫敞

## 2026-05-29 (淇妯℃嫙鍣ㄨ仈缃?

### 淇敼鍐呭
- **open_emulator.bat**锛氭敼涓虹洿鎺ヨ皟鐢?`emulator.exe -avd <name> -dns-server 8.8.8.8,114.114.114.114` 鍚姩妯℃嫙鍣紝淇妯℃嫙鍣?DNS 瑙ｆ瀽澶辫触瀵艰嚧 Supabase 鏃犳硶杩炴帴鐨勯棶棰樸€?- **android/app/src/debug/AndroidManifest.xml**锛氭坊鍔?`usesCleartextTraffic="true"` + `networkSecurityConfig`銆?- **android/app/src/main/res/xml/network_security_config.xml**锛氭柊寤猴紝debug 鏋勫缓鍏佽 cleartext 娴侀噺 + 淇′换鐢ㄦ埛 CA 璇佷功銆?
### 鍘熷洜
妯℃嫙鍣?`flutter run` 鏃舵棤娉曡仈缃戯紙鏃ュ巻鍒蜂笉鍑烘潵锛夛紝鎵撳寘 APK 瀹夎鐪熸満姝ｅ父銆傛牴鍥犳槸妯℃嫙鍣?DNS 瑙ｆ瀽澶辫触瀵艰嚧鏃犳硶杩炴帴 Supabase銆?
## 2026-05-29 (鏂板鑴氭湰)

### 淇敼鍐呭
- **open_emulator.bat**锛氭柊澧炰竴閿墦寮€ Android 妯℃嫙鍣ㄨ剼鏈紝鑷姩妫€娴嬪彲鐢ㄦā鎷熷櫒骞跺惎鍔紝鏀寔澶氭ā鎷熷櫒閫夋嫨銆?
## 2026-05-29 (6椤筓I/UX鏀硅繘)

## 2026-05-29 (6椤筓I/UX鏀硅繘)

### 淇敼鍐呭
1. **SnackBar鐐瑰嚮娑堝け**锛氭柊澧?`showAppSnackBar` 鍏ㄥ眬宸ュ叿鍑芥暟锛屾墍鏈夋彁绀烘秷鎭偣鍑诲嵆娑堝け銆傜粺涓€鏇挎崲浜嗗叏閮?7澶?`ScaffoldMessenger.showSnackBar` 璋冪敤銆?2. **棣栭〉浠诲姟璇︽儏鏃ユ湡缂栬緫**锛歚_TimelineTask` 鏂板 `endDate` 瀛楁锛岃鎯呭尯鍩熸樉绀?寮€濮?鈫?缁撴潫"涓や釜鍙偣鍑绘棩鏈燂紝鍒嗗埆缂栬緫寮€濮嬪拰缁撴潫鏃堕棿銆?3. **浠诲姟璇︽儏椤垫棩鏈熺紪杈戜慨澶?*锛歚_timeChip()` 绉婚櫎澶栧眰 `onTap`锛屽紑濮嬪拰缁撴潫鏃ユ湡鍚勮嚜鐙珛 `InkWell`锛屼袱涓棩鏈熷潎鍙崟鐙偣鍑荤紪杈戙€?4. **棣栭〉浠诲姟璇︽儏椤圭洰淇敼**锛氶」鐩爣绛炬敮鎸佺偣鍑诲脊鍑洪」鐩€夋嫨鍣紝鐩存帴鍒囨崲浠诲姟鎵€灞為」鐩€?5. **椤圭洰鍒犻櫎涓嶆敹鍥濪rawer**锛氬垹闄?`_confirmDeleteProject` 涓殑 `Navigator.pop(context)`锛屽垹闄ゅ悗渚ц竟鏍忎繚鎸佹墦寮€銆?6. **搴旂敤鍥炬爣**锛氳璁℃竻鍗?闃冲厜椋庢牸鍥炬爣锛堟殩姗欐笎鍙樿儗鏅?+ 鐧借壊娓呭崟 + 灏忓お闃筹級锛岄€氳繃 `flutter_launcher_icons` 鐢熸垚 Android 鍜?Windows 鍥炬爣銆?7. **鏃ュ巻姘村钩鎷栧姩瀵艰埅**锛氬懆瑙嗗浘鏃堕棿杞村尯鍩熸敮鎸侀紶鏍?鎵嬫寚姘村钩鎷栧姩锛屽疄鏃惰窡鎵嬪垏鎹㈡棩鏈燂紙绱Н瓒呰繃 0.6 鍊?dayWidth 鍗冲亸绉?澶╋級銆?
### 褰卞搷鏂囦欢
- `lib/core/utils/snackbar_helper.dart`锛堟柊澧烇級
- `lib/presentation/pages/home/home_page.dart`
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/pages/calendar/calendar_page.dart`
- `assets/icons/app_icon.svg`, `assets/icons/app_icon_1024.png`锛堟柊澧烇級
- `android/app/src/main/res/mipmap-*/ic_launcher.png`锛堟洿鏂帮級
- `pubspec.yaml`锛堟坊鍔?flutter_launcher_icons锛?- 14涓枃浠剁殑 SnackBar 璋冪敤鏇挎崲

### 椋庨櫓/TODO
- 鏃ュ巻姘村钩鎷栧姩涓庝换鍔″潡鎷栧姩鍏卞瓨锛氫换鍔″潡浣跨敤 pan 鎵嬪娍鍦?gesture arena 涓紭鍏堢骇鏇撮珮锛岀┖鐧藉尯鍩熸墠鍝嶅簲姘村钩鎷栧姩
- 鍥炬爣鍦ㄦ繁鑹茶儗鏅笂瀵规瘮搴﹁冻澶燂紝娴呰壊鑳屾櫙涓婂渾瑙掑彲鑳界暐鏄炬煍鍜?
## 2026-05-29 (鏃ュ巻/浠诲姟鍒楄〃澧炲己 + 鍚屾BUG淇)

### 淇敼鍐呭
- **鏃ュ巻鍛ㄨ鍥惧ご閮ㄥ悓姝?*锛氬垏鎹㈡樉绀哄ぉ鏁?1-15澶?鏃讹紝澶撮儴鏄熸湡鏍囩鍜屾棩鏈熸暟瀛楅殢涔嬪彉鍖栵紝涓嶅啀鍥哄畾鏄剧ず7澶┿€傛柊澧?`_buildCustomWeekHeader()` 鏇夸唬 `TableCalendar` 鐨勫浐瀹氬懆澶淬€?- **绉诲姩绔棩鍘嗘枃瀛楄嚜閫傚簲**锛氫换鍔″潡鏂囧瓧鏍规嵁鍙敤瀹藉害鍔ㄦ€佺缉鏀撅紙鏈€灏?px锛夛紝鏋佺獎鏃堕殣钘忔椂闂村拰鐖舵爣绛撅紝浣跨敤 `FittedBox` 纭繚鏍囬鍙銆?- **妗岄潰绔彸閿彍鍗?*锛氫换鍔″崱鐗囨敮鎸佸彸閿脊鍑?缂栬緫/鍒犻櫎"涓婁笅鏂囪彍鍗曪紙`GestureDetector.onSecondaryTapUp` + `showMenu`锛夈€?- **浠诲姟鍗＄墖椤圭洰鏍囩**锛氶」鐩悕浠庢爣棰樹笅鏂圭Щ鍒板崱鐗囧乏涓婅锛屼互褰╄壊灏忔爣绛惧舰寮忔樉绀恒€?- **鏃ユ湡鍖洪棿绛涢€?*锛氫换鍔″垪琛?AppBar 鏂板鏃ユ湡绛涢€夋寜閽紝BLoC 灞傛敮鎸?`dateFrom/dateTo` 鍙傛暟锛岃繃婊や换鍔℃椂闂磋寖鍥翠笌閫夊畾鍖洪棿鏈変氦闆嗙殑浠诲姟銆?- **鍚屾BUG淇**锛?  - `syncFromJson` 淇濈暀杩滅 `updatedAt` 鏃堕棿鎴筹紝閬垮厤鏈湴瑕嗙洊浜戠鏂版暟鎹?  - 澧撶煶淇濇姢锛氭湰鍦板凡鍒犻櫎涓旀椂闂存埑>=杩滅鏃讹紝涓嶈杩滅鏈垹闄ょ姸鎬佸娲?  - Realtime 鍥炶皟涓茶鍖栵紙`_enqueue` 闃熷垪锛夛紝闃叉骞跺彂鍐欏叆瀵艰嚧 SQLite database locked

### 褰卞搷鏂囦欢
- `lib/presentation/pages/calendar/calendar_page.dart`
- `lib/presentation/pages/tasks/widgets/task_card.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/blocs/task_new/{task_event,task_state,task_bloc}.dart`
- `lib/data/repositories/task_repository.dart`
- `lib/services/task_sync_service.dart`

### 椋庨櫓/TODO
- 鏃ュ巻鑷畾涔夊ご閮ㄥ湪澶╂暟>7鏃舵棩鏈熷彲鑳借法鏈堬紝宸叉纭鐞?- `FittedBox` 鍦ㄦ瀬绐勫潡涓婂彲鑳藉鑷存枃瀛楄繃灏忎絾浠嶅彲瑙侊紝鏄鏈熻涓?- 鍚屾淇闇€瑕佽法璁惧楠岃瘉锛屽缓璁竻绌轰簯绔兊灏告暟鎹悗娴嬭瘯

## 2026-05-29 (鍏ㄤ笟鍔℃暟鎹弻绔悓姝ワ細杞垹闄ゅ鐭?+ 鍙屽悜 LWW 瀵硅处 + checklist 涓婁簯)

### 淇敼鍐呭
- **缁熶竴杞垹闄わ紙澧撶煶锛?*锛歚Tasks/Projects/ProjectGroups/ChecklistItems` 鍚勫姞 `deleted` 鍒楋紙NOT NULL DEFAULT 0锛夛紝schemaVersion 6鈫?锛宍onUpgrade if(from<7)` 鍏滃簳鍔犲垪銆傚垹闄や竴寰嬬疆 `deleted=1, updatedAt=now` 骞舵帹閫佸鐭筹紝涓嶅啀鐗╃悊鍒犻櫎 鈫?鍒犻櫎闈犲鐭宠法绔紶鎾€侀噸鍚笉澶嶆椿銆?- **鍙屽悜 LWW 鍏ㄩ噺瀵硅处**锛歚TaskSyncService/ProjectSyncService/ChecklistSyncService/AttachmentSyncService` 鏂板/鍗囩骇 `syncAll()`锛氭媺浜戠锛堝惈澧撶煶锛夊悎骞跺埌鏈湴 + 鏈湴锛堝惈澧撶煶锛夊嚒浜戠缂哄け鎴栨湰鍦?`updatedAt` 鏇存柊鍒欐帹閫佷笂浜戙€備慨澶?瀛愪换鍔℃爲涓嶅悓姝?"绂荤嚎鍒犻櫎涓嶄紶鎾?銆?- **checklist 棣栨涓婁簯**锛氭柊寤?`lib/services/checklist_sync_service.dart` + 浜戣〃 `public.checklist_items`锛圧LS + REPLICA IDENTITY FULL + 鍔犲叆 supabase_realtime publication锛夛紱`ChecklistRepository` 娉ㄥ叆 syncService锛屽鍒犳敼 push銆佽蒋鍒犮€佽鏌ヨ杩囨护 `deleted=0`銆佹柊澧?`syncFromJson`銆?- **鍒犻櫎绌?catch / NPE 瀹堝崼**锛歚TaskSyncService` 鍘绘帀 `catch(_){}` 淇濈暀鏃ュ織锛宍currentUser!` 鈫?`currentUser?` 瀹堝崼銆?- **鍚姩鎸夌櫥褰曟€侀棬鎺?*锛歚home_page` 绉婚櫎鏈櫥褰曞嵆瑙﹀彂鐨?task pull锛屾墍鏈?`syncAll()+subscribe()` 缁熶竴鍦ㄧ櫥褰曞悗鍚姩锛宍signedIn/initialSession` 姣忔閲嶈窇鍏ㄩ噺瀵硅处銆?- **椤圭洰鍒犻櫎绾ц仈杞垹**锛歱roject 鍒犻櫎鏃剁骇鑱旇蒋鍒犲叾涓?tasks/checklist锛涜繙绔」鐩鐭冲埌杈炬椂鏈湴鍚屾牱绾ц仈杞垹銆?- **闃舵0 娓呯┖鍏ㄩ儴鏁版嵁**锛氫簯绔?`user_tasks/task_attachments/projects/project_groups` 宸?DELETE 娓呯┖锛沗AppDatabase.wipeAllData()` 浜嬪姟娓呯┖鏈湴鍚勮〃骞堕噸寤?inbox銆?
### 褰卞搷鏂囦欢
- `lib/data/database/app_database.dart`锛? 鐢熸垚鐗?`.g.dart`锛?- `lib/data/repositories/{task,project,project_group,checklist}_repository.dart`
- `lib/services/{task_sync,project_sync,attachment_sync,checklist_sync}_service.dart`锛坈hecklist 涓烘柊寤猴級
- `lib/presentation/pages/home/home_page.dart`銆乣lib/main.dart`
- `test/task_progress_calculator_test.dart`锛堟瀯閫犺ˉ `deleted`锛?- `database/migration_004_soft_delete_checklist_realtime.sql`锛堜簯绔暀鐥曪級

### 椋庨櫓/TODO
- **鏈湴蹇呴』娓呯┖**锛氭闈?DB 娓呯┖鏃舵枃浠惰鍗犵敤锛圓pp 杩愯涓級鏈垹鎴愬姛銆傞』鍏堝叧闂?App 鍐嶈繍琛?`clear_data.bat`锛堟垨鍒?`%USERPROFILE%\Documents\smart_assistant.db`锛夛紱鍚﹀垯涓嬫鍚姩 `syncAll` 浼氭妸鏈湴鏃ф暟鎹弽鎺ㄥ洖宸叉竻绌虹殑浜戠銆傜Щ鍔ㄧ闇€鍗歌浇閲嶈鎴栧悗缁帴鍏ュ簲鐢ㄥ唴 `wipeAllData()` 鍏ュ彛銆?- `clear_data.bat` 浠呭垹 `.db/-journal`锛屾湭鍒?`-wal/-shm`锛圖rift 榛樿闈?WAL锛屽奖鍝嶅皬锛夈€?- `syncAll` 涓?O(n) 鍏ㄩ噺 upsert锛屽綋鍓嶆暟鎹噺灏忥紱鍚庣画鍙壒閲忓寲銆?- `migration_004` 浠呬綔鐣欑棔锛屽疄闄呭凡閫氳繃 Management API 鎵ц锛坱oken 涓嶅叆搴擄級銆?
## 2026-05-29 (浠诲姟鍒楄〃鏍戝舰缁撴瀯 UI 浼樺寲)

### 淇敼鍐呭
- 鏍戝舰杩炴帴绾匡細鏂板 `_TreeLinesPainter`锛圕ustomPaint锛夛紝瀛愯妭鐐规樉绀?鈹溾攢鈹€ / 鈹斺攢鈹€ 杩炴帴绾匡紝闈炴渶鍚庣鍏堝眰鎸佺画绔栫嚎
- 灞傜骇鏍囩锛氭瘡涓妭鐐瑰乏渚ф樉绀?R0/R1/R2 灏忔爣绛?- 缂╃獎宸︿晶鍖哄煙锛氭嫋鎷芥墜鏌?icon 浠?20鈫?6锛宲adding horizontal 浠?2鈫?
- 绉婚櫎 TaskCard 鍐呴儴 `depth * 24` 缂╄繘锛堜紶 depth:0锛夛紝缂╄繘缁熶竴鐢卞灞傛爲褰㈢嚎璐熻矗

### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/task_list_view.dart`
- `lib/presentation/pages/tasks/widgets/task_card.dart`

### 椋庨櫓/TODO
- 宸插畬鎴愬尯鍧楋紙completedTreeNodes锛夋湭鍔犳爲褰㈢嚎锛屼繚鎸佸師鏍?
## 2026-05-27 (鎵归噺浼樺寲 + AI 鎺掔▼ + 椤圭洰鍒嗙粍 + 鏃ュ巻鎷栧姩閲嶅啓)

### 鏂板鍔熻兘

- **椤圭洰鍒嗙粍**锛團6锛夛細鏂板缓 `ProjectGroups` 琛?+ `groupId` 澶栭敭锛屼晶杈规爮鎸夊垎缁?ExpansionTile 灞曞紑锛岀粍杩涘害 = 缁勫唴椤圭洰鍔犳潈绱姞锛堝悓椤圭洰鍙ｅ緞锛夈€?- **AI 浼版椂 + 鑷姩鎺掔▼**锛團2锛夛細
  - `task_decomposition_service` system prompt 寮哄埗鍙跺瓙鑺傜偣杩斿洖 `minutes`锛堚墹480锛夛紱闈炲彾瀛愮敱瀛愯妭鐐圭疮鍔犮€?  - 鏂板缓 `subtask_scheduler.dart`锛?:00鈥?1:00 宸ヤ綔鏃舵銆? 鍒嗛挓鍚搁檮銆?5 鍒嗛挓缂撳啿銆侀伩璁╁凡鍗犵敤鏃舵銆乣skipWeekends` 鍙€夛紱杈撳嚭鍙跺瓙鎺掔▼缁撴灉锛屽苟鎶婄埗浠诲姟鍥炲啓涓?`startOfDay(min) 鈫?endOfDay(max)` 寮哄埗璺ㄥぉ锛岃嚜鍔ㄦ覆鏌撲负鏃ュ巻椤堕儴闀挎潯銆?  - `ai_decompose_section` 鎺ュ叆 scheduler锛屾媶瀹屽嵆鎺掔▼锛涢粯璁ゅ紑鍚彁閱掞紙鎻愬墠 5 鍒嗛挓锛夈€?- **浠诲姟鎸傞」鐩骇鑱斿埌瀛愪换鍔?*锛團1锛夛細`TaskRepository.update` 妫€娴?`projectId` 鍙樻洿鏃讹紝鎵归噺鏇存柊鎵€鏈夊悗浠?+ sync push銆?- **棣栭〉鏃堕棿杞磋嚜閫傚簲楂樺害**锛團5锛夛細鏍规嵁褰撳墠鍙鍒楃殑鏈€澶т换鍔℃暟鍔ㄦ€佺畻楂樺害锛?0鈥?10px锛夛紝鑺傜偣鍐呭厑璁镐笂涓嬫粴鍔ㄧ湅瀹屾墍鏈変换鍔°€?- **棣栭〉鎻忚堪鍥哄畾楂樺害鍙粴鍔?*锛團4锛夛細240px 楂樺害鍐呮粴鍔紝瓒呰繃 1000 瀛楁埅鏂?+ "灞曞紑鍏ㄦ枃"璺宠浆缂栬緫椤点€?- **浠诲姟鍒楄〃浼樺厛绾?PopupMenuButton**锛團3锛夛細鏇挎崲鏄撹瑙︾殑缁嗚壊鏉★紝鏂板甯﹂鑹插渾鐐?+ "楂?涓?浣?鏃? 鏍囩鐨勮兌鍥婁笅鎷夈€?- **鏂板缓浠诲姟榛樿鏃堕棿**锛團7锛夛細寮€濮嬫椂闂?= 褰撳墠锛屾埅姝?= 褰撳墠+1h銆?- **璁剧疆锛欰I 鎺掔▼璺宠繃鍛ㄦ湯**锛歚profile_page` 鍔犲紑鍏筹紝`LocalStorage.skipWeekends`銆?- **浜戝悓姝?*锛歚projects` / `project_groups` 涓婁簯锛坄migration_002_groups_and_estimate.sql`锛夛紝`user_tasks` 鍔?`estimated_minutes` 鍒楋紱鏂板缓 `ProjectSyncService` 鎻愪緵 pull / push / subscribe銆?
### Bug 淇

- **B1 绉诲姩绔棩鍘嗛暱鎸夊悗鏃犳硶鎷栨嫿杈圭紭鏀规椂闂?*锛歳esize hot zone 鏀圭敤 5 鍒嗛挓鍚搁檮绮掑害锛岃窡鎵嬪搷搴斻€?- **B2 鏃ュ巻浠诲姟鍧楁嫋鍔ㄦ墜鎰熷樊**锛氬幓鎺?`Draggable`/`DragTarget`锛屾敼 `Listener` + `Transform.translate` 鍘熷昂瀵歌窡鎵嬶紝5 鍒嗛挓鍚搁檮锛岃法鏃ユ寜 `dayWidth` 璁＄畻鍒楀亸绉伙紱澶氭棩 bar 鍚屾牱鏀瑰啓銆?- **B3 鍒嗛挓閫夋嫨鍣ㄦ敼涓嬫媺妗?*锛氬垹闄?ListWheelScrollView锛屾敼涓?鏃?涓€鑷寸殑 `_timeDropdown`锛? 鍒嗛挓涓€妗ｃ€?- **B4 鏈堣鍥惧彸鍒囦笅鏂逛换鍔″垪琛ㄤ笉鍒锋柊**锛歚onPageChanged` 鍔?`setState`锛屾妸 `_selectedDay` 鍚屾鍒版柊鏈堝悓鍙锋棩銆?- **澶氭棩闀挎潯 lane 鑷姩鎾戦珮**锛歚_buildMultiDayLane` 鎸夊眰绾ф繁搴︽帓搴忥紙鏍逛换鍔″湪涓婏級锛宭ane 鏁板姩鎬佽绠楋紝>6 鏃跺唴閮ㄧ旱鍚戞粴鍔ㄣ€?
### 鏁版嵁妯″瀷鍙樻洿

- Drift `schemaVersion` 4 鈫?5锛氭柊琛?`project_groups`锛宍projects.group_id`銆乣tasks.estimated_minutes` 鍒椼€?- `TaskNewLoaded` 鍔?`groups` / `groupProgress` 瀛楁銆?- `TaskProgressCalculator` 鏂板 `groupProgress` 璁＄畻銆?
### 褰卞搷鏂囦欢
- 鏁版嵁灞傦細`app_database.dart` (+ .g.dart)銆乣task_repository.dart`銆乣project_repository.dart`銆佹柊寤?`project_group_repository.dart`
- 鏈嶅姟灞傦細鏂板缓 `subtask_scheduler.dart`銆乣project_sync_service.dart`锛涙敼 `task_sync_service.dart`銆乣task_decomposition_service.dart`銆乣local_storage_service.dart`銆乣notification_service.dart` 鎺ュ叆
- 琛ㄧ幇灞傦細`home_page.dart`銆乣calendar_page.dart`銆乣profile_page.dart`銆乣task_card.dart`銆乣task_create_sheet.dart`銆乣project_sidebar.dart`銆乣calendar_date_picker.dart`銆乣ai_decompose_section.dart`
- Bloc锛歚task_bloc.dart` / `task_state.dart`
- 浜戠 SQL锛氭柊寤?`database/migration_002_groups_and_estimate.sql`锛?*闇€鐢ㄦ埛鍦?Supabase Dashboard SQL Editor 鎵ц**锛?
### 鍚庣画 TODO / 椋庨櫓

- 浠?`flutter analyze` 閫氳繃锛?9 涓?info/warning锛屾棤 error锛夛紝瀹炴満鍔熻兘鏈窇閫氾紱寤鸿鍦ㄦ闈㈢ + 绉诲姩绔悇璺戜竴閬?AI 鎷嗗垎銆佹棩鍘嗘嫋鍔ㄣ€佹湀瑙嗗浘鍒囨崲銆侀」鐩垎缁勩€佽法璁惧鍚屾娴佺▼銆?- AI 鎺掔▼涓?璐績椤哄簭濉厖"锛屼笉鍋氬叏灞€鏈€浼橈紱鍚屼竴鏃舵澶氭 AI 鎷嗗垎鍙兘鎵庡爢鎺掑湪杩滄湭鏉ャ€?- 鐖朵换鍔¤法澶╁己鍒朵负 00:00鈥?3:59锛屼細璁╁鏃?bar 鍦ㄦ湀瑙嗗浘瑕嗙洊瀹屾暣鏃舵锛屾槸棰勬湡琛屼负銆?
---

## 2026-05-27 (login fix + 闀挎寜缂栬緫 + pinch 缂╂斁)

### Fixed

- **鐧诲綍棣栨鏃犲搷搴?*锛歋upabase 璺緞涓?`_login()` 鎶婁簨浠朵涪缁?BLoC 鍚庣珛鍗冲叧闂?`_isLoading`锛孊LoC 寮傛杩樺湪椋炪€傛敼涓?Supabase 妯″紡瀹屽叏鐢?BLoC 鐘舵€侊紙`AuthLoading`锛夐┍鍔ㄦ寜閽?disable銆?- **绉诲姩绔暱鎸夌紪杈戞ā寮忥紙婊寸瓟娓呭崟鏂规锛?*锛氶暱鎸変换鍔″潡杩涘叆缂栬緫妯″紡锛屾樉绀鸿摑鑹查珮浜竟妗?+ 椤堕儴/搴曢儴澶ф嫋鎷芥墜鏌勶紙36px 楂橈紝钃濊壊 primaryColor锛夈€傛嫋鎷借皟鏁存椂闂村悗鑷姩閫€鍑虹紪杈戞ā寮忋€傜偣鍑荤┖鐧藉尯鍩熶篃閫€鍑恒€傛闈㈢淇濇寔鍘熸湁 hover 灏忕櫧绾胯涓恒€?- **绉诲姩绔弻鎸?pinch 缂╂斁鏃ュ巻鏃堕棿杞?*锛氱敤 `Listener` 鐨?`onPointerDown/Move/Up/Cancel` 杩借釜澶氱偣瑙︽帶锛屽弻鎸囨椂鎸夎窛绂绘瘮渚嬭皟鏁?`_hourHeight`锛屼笉骞叉壈 `SingleChildScrollView` 鐨勫崟鎸囨粴鍔ㄣ€?
---

## 2026-05-27 (release login + calendar fixes)

### Fixed

- **Release 妯″紡鏃犳硶鐧诲綍**锛歚INTERNET` 鏉冮檺鍙湪 debug manifest锛屼富 manifest 缂哄け銆傚凡娣诲姞鍒?`android/app/src/main/AndroidManifest.xml`銆?- **鏃ュ巻浠诲姟鍗＄墖 BOTTOM OVERFLOW**锛歚_buildBlockContent` 鍐呭瓒呭嚭 28px 鏈€灏忛珮搴︿笖 `Stack(clipBehavior: Clip.none)` 涓嶈鍓€傛敼鐢?`Material(clipBehavior: Clip.hardEdge)` + Column 鍘绘帀 `mainAxisSize: MainAxisSize.min` 璁╁唴瀹瑰～鍏呭苟瑁佸壀銆?- **鍒囨崲 1澶?2澶╄鍥句笉灞呬腑鍒颁粖澶?*锛歚onChanged` 鍙敼澶╂暟涓嶆敼 `_focusedDay`锛屼笖 `_startOfWeek` 鎬诲洖閫€鍒板懆涓€銆傚ぉ鏁?< 7 鏃剁洿鎺ヤ粠 `_focusedDay` 寮€濮嬶紝鈮?3 澶╂椂閲嶇疆鍒颁粖澶┿€?- **绉诲姩绔?resize 鐑尯澶皬**锛氬簳閮ㄦ嫋鎷界儹鍖轰粠 8px 鎵╁ぇ鍒?24px锛屽悜涓嬪亸绉?8px銆?
---

## 2026-05-27 (perf: overflow + jank fixes)

### Fixed

- **BOTTOM OVERFLOWED BY 21 PIXELS** on calendar page: removed manual `viewInsets.bottom` padding in `calendar_date_picker.dart` and `task_create_sheet.dart` that double-compensated with `isScrollControlled: true`. Wrapped calendar picker content in `SingleChildScrollView`.
- **Edit page lag (all interactions, not just keyboard)**: added `listenWhen` to `BlocListener` in `task_detail_page.dart` so `setState` only fires when checklist data actually changes; added `buildWhen` to `BlocBuilder` in `subtask_tree_section.dart` so the tree only rebuilds when its own subtree/expanded-nodes change.
- **Keyboard animation jank**: removed `MediaQuery.viewInsetsOf(context).bottom` subscriptions that caused per-frame rebuilds during keyboard show/hide animation.
- **Calendar page keyboard interference**: set `resizeToAvoidBottomInset: false` on calendar Scaffold (no text inputs on that page).
- **Repaint isolation**: wrapped `SubtaskTreeSection`, `ChecklistSection`, `AttachmentSection`, `AiDecomposeSection` in `RepaintBoundary` in task detail page; wrapped timeline scroll area in `RepaintBoundary` in calendar page.

### Files modified

- `lib/presentation/widgets/calendar_date_picker.dart`
- `lib/presentation/pages/tasks/widgets/task_create_sheet.dart`
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
- `lib/presentation/pages/tasks/task_detail/widgets/subtask_tree_section.dart`
- `lib/presentation/pages/calendar/calendar_page.dart`

### Verification

- `dart analyze` on all 5 modified files: 0 errors (4 pre-existing deprecation infos).
- `flutter build apk --debug` succeeded, installed and launched on emulator-5554.

---

## 2026-05-27

### Changed

- Reduced mobile text-input save pressure in [lib/presentation/pages/tasks/task_detail/task_detail_page.dart](/E:/claude/project2/smart_assistant/lib/presentation/pages/tasks/task_detail/task_detail_page.dart).
- Title and description edits on the newer task detail page now mark the form dirty without scheduling the debounced autosave pipeline on each text change.
- Text changes are still persisted when editing completes, focus leaves the field, or the page closes, so the edit flow stays safe while avoiding repeated write/sync churn during typing.

### Investigation

- Traced the likely mobile lag source to the newer task detail page, where text editing sits inside a heavy page that also hosts subtasks, checklist, attachments, reminder controls, and AI decomposition.
- Confirmed that the existing autosave path reaches `TaskNewBloc._onUpdateTask()`, which writes through the repository layer and then reloads task data, making it too expensive for frequent text-entry pauses on mobile.
- Confirmed the local Android toolchain is installed, but there is currently no connected Android device and no configured emulator image on this machine.

### Verification

- `flutter test test/widget_test.dart test/local_storage_service_test.dart test/task_progress_calculator_test.dart` passed on 2026-05-27.
- `flutter analyze lib/presentation/pages/tasks/task_detail/task_detail_page.dart` reported only pre-existing deprecation infos for `RadioListTile`.

### Risks / Notes

- This change targets the newer task detail editing page only. Other mobile forms may still deserve profiling if you see similar lag elsewhere.
- `adb.exe` exists under `E:\android-sdk\platform-tools`, but the current shell session does not expose `adb` directly on `PATH`.

## 2026-05-27

### Changed

- Updated desktop reminder delivery in [lib/services/notification_service.dart](/E:/claude/project2/smart_assistant/lib/services/notification_service.dart) so Windows prefers the native Windows notification plugin and only falls back to the existing PowerShell toast path if native delivery is unavailable.
- Added desktop runtime decision helpers in [lib/core/desktop/desktop_runtime.dart](/E:/claude/project2/smart_assistant/lib/core/desktop/desktop_runtime.dart) for tray-event handling and desktop notification channel selection.
- Updated [lib/main.dart](/E:/claude/project2/smart_assistant/lib/main.dart) so tray right-click opens the context menu, which restores access to the desktop "閫€鍑? action.
- Reduced reminder-section overflow risk by adjusting `SwitchListTile` layout in:
  [lib/presentation/widgets/create_schedule_dialog.dart](/E:/claude/project2/smart_assistant/lib/presentation/widgets/create_schedule_dialog.dart)
  [lib/presentation/pages/task/task_detail_page.dart](/E:/claude/project2/smart_assistant/lib/presentation/pages/task/task_detail_page.dart)
  [lib/presentation/pages/tasks/task_detail/task_detail_page.dart](/E:/claude/project2/smart_assistant/lib/presentation/pages/tasks/task_detail/task_detail_page.dart)
- Updated notification dependencies in [pubspec.yaml](/E:/claude/project2/smart_assistant/pubspec.yaml) and [pubspec.lock](/E:/claude/project2/smart_assistant/pubspec.lock).

### Tests

- Added [test/desktop_runtime_test.dart](/E:/claude/project2/smart_assistant/test/desktop_runtime_test.dart) to cover tray right-click behavior and Windows notification channel selection.
- Added [test/create_schedule_dialog_test.dart](/E:/claude/project2/smart_assistant/test/create_schedule_dialog_test.dart) to guard the desktop reminder dialog against overflow on short window heights.
- Updated [test/local_storage_service_test.dart](/E:/claude/project2/smart_assistant/test/local_storage_service_test.dart) to initialize mocked preferences before Supabase so the full Flutter test suite can run in one pass.

### Verification

- `flutter test` passed on 2026-05-27.
- `flutter analyze` completed with pre-existing infos/warnings, but no new compile errors from this change.

### Risks / Notes

- `npx gitnexus detect-changes --repo smart-assistant` reported `critical`, but the report included many unrelated pre-existing dirty-worktree files outside this task. That result should not be interpreted as the blast radius of only the reminder/tray fix.
# 2026-05-31 涓婄嚎鍙樼幇鍑嗗鏂囨。

## 鏂板
- 鏂板 `docs/launch/PLATFORM_RESEARCH_CN.md`锛氫腑鍥藉ぇ闄嗕釜浜哄紑鍙戣€呬笂绾垮钩鍙拌皟鐮旓紝寤鸿棣栧彂 Windows 瀹樼綉/绉佸煙 + 鍥藉唴瀹夊崜娓犻亾寮曟祦銆?- 鏂板 `docs/launch/LAUNCH_CHECKLIST.md`锛氫笂绾挎潗鏂欍€佸悎瑙勩€佹妧鏈獙鏀跺拰棣栧彂鎵ц娓呭崟銆?- 鏂板 `docs/launch/PRIVACY_POLICY_DRAFT.md`銆乣docs/launch/TERMS_OF_SERVICE_DRAFT.md`锛氶殣绉佹斂绛栧拰鐢ㄦ埛鍗忚鑽夋銆?- 鏂板 `docs/launch/STORE_LISTING_COPY.md`銆乣docs/launch/PRICING_AND_GO_TO_MARKET.md`锛氬簲鐢ㄥ晢搴楁枃妗堛€佸畾浠峰拰鑾峰鏂规銆?- 鏂板 `docs/launch/RISK_REGISTER.md`銆乣docs/launch/RELEASE_EVIDENCE.md`锛氫笂绾块闄╃櫥璁板拰褰撳墠鍙戝竷璇佹嵁璁板綍銆?
## 璇存槑
- 鏈鍙柊澧炴枃妗ｏ紝涓嶄慨鏀逛笟鍔′唬鐮併€佷笉鏇存崲 DeepSeek Key銆佷笉鏀瑰彉鏋勫缓鑴氭湰鎴栧簲鐢ㄥ姛鑳姐€?- 宸茬煡椋庨櫓缁х画淇濈暀锛欴eepSeek Key 瀹㈡埛绔唴缃€丄ndroid release 浣跨敤 debug 绛惧悕銆丄ndroid 鍖呭悕浠嶄负 `com.example.smart_assistant`銆?
# 2026-05-31 鏃ュ巻鑺傚亣鏃ヤ笌浼戞伅鏃ュ睍绀?
## 淇敼
- `lib/services/holiday_service.dart`锛歚HolidayCountry` 鎵╁睍寰峰浗銆佹硶鍥姐€佸姞鎷垮ぇ銆佹境澶у埄浜氥€佸嵃搴︺€?- `lib/presentation/pages/calendar/calendar_page.dart`锛氭帴鍏?`HolidayService`锛孉ppBar 鏂板鑺傚亣鏃ュ浗瀹跺垏鎹紱鍛ㄨ鍥炬棩鏈熷ご鍜屾湀瑙嗗浘鏃ユ湡鏍煎睍绀烘硶瀹氳妭鍋囨棩銆佽皟浼戣ˉ鐝€佹櫘閫氬懆鏈紤鎭棩銆?- `lib/services/holiday_service.dart`锛氫腑鍥借妭鏃ュ鍔犳湰鍦拌ˉ鍏咃紝鍎跨鑺傜瓑闈炴斁鍋囪妭鏃ヤ娇鐢?`HolidayType.observance` 灞曠ず锛屼笉鍙備笌浼戞伅鏃ュ垽鏂€?- `lib/presentation/pages/calendar/calendar_page.dart`锛歚HolidayType.observance` 浣跨敤宸ヤ綔鏃ヨ妭鏃ユ牱寮忓睍绀恒€?- `ARCHITECTURE.md`锛氬悓姝ヨ褰曟棩鍘嗚妭鍋囨棩/浼戞伅鏃ュ睍绀虹粨鏋勩€?
## 楠岃瘉
- `flutter analyze lib/services/holiday_service.dart lib/presentation/pages/calendar/calendar_page.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 2 涓棦鏈?warning銆?
## 椋庨櫓
- 澶栭儴鑺傚亣鏃?API 鍒濇涓嶅彲鐢ㄤ笖鏃犵紦瀛樻椂锛屽彧鑳藉睍绀烘湰鍦板懆鏈紤鎭棩銆?
# 2026-05-31 绉婚櫎棣栭〉璁よ瘑寮曞

## 淇敼
- `lib/presentation/pages/home/home_page.dart`锛氱Щ闄ら椤靛垵濮嬪寲鏃惰嚜鍔ㄨ烦杞?`OnboardingPage` 鐨勯€昏緫锛屼繚鐣欓€氱煡鏉冮檺寮曞銆?- `ARCHITECTURE.md`锛氳褰曢椤靛惎鍔ㄥ紩瀵肩粨鏋勫彉鍖栥€?
## 楠岃瘉
- `flutter analyze lib/presentation/pages/home/home_page.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 5 涓棦鏈?lint/info銆?
## 椋庨櫓
- `OnboardingPage` 鏂囦欢浠嶄繚鐣欙紝鑻ュ叾浠栧叆鍙ｅ紩鐢ㄤ笉浼氬彈鏈淇敼褰卞搷銆?
# 2026-05-31 瀛愪换鍔￠粯璁ょ户鎵跨埗浠诲姟椤圭洰

## 淇敼
- `lib/presentation/pages/tasks/tasks_page.dart`锛氫粠浠诲姟鏍?鎬濈淮瀵煎浘鐖惰妭鐐规柊澧炲瓙浠诲姟鏃讹紝榛樿椤圭洰浼樺厛鍙栫埗浠诲姟椤圭洰銆?- `lib/presentation/pages/tasks/widgets/task_create_sheet.dart`锛氬垵濮嬪寲鍜屽垏鎹㈢埗浠诲姟鏃跺悓姝ラ€変腑鐖朵换鍔＄殑椤圭洰銆?- `ARCHITECTURE.md`锛氳褰曞瓙浠诲姟鍒涘缓榛樿椤圭洰閫昏緫銆?
## 楠岃瘉
- `flutter analyze lib/presentation/pages/tasks/tasks_page.dart lib/presentation/pages/tasks/widgets/task_create_sheet.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 7 涓棦鏈?lint/info銆?
## 椋庨櫓
- 浠呰鐩栨柊浠诲姟寮圭獥璺緞锛涗换鍔¤鎯呴〉瀛愪换鍔″叆鍙ｆ鍓嶅凡浼犲叆鐖朵换鍔￠」鐩€?
# 2026-05-31 绉诲姩绔椤典换鍔¤鎯呰祫婧愬尯閫傞厤

## 淇敼
- `lib/presentation/pages/home/home_page.dart`锛氶椤?DB 浠诲姟璇︽儏璧勬簮鍖烘寜瀹藉害鍒囨崲甯冨眬锛涚Щ鍔ㄧ瀛愪换鍔＄嫭鍗犱竴琛岋紝闄勪欢鍜屾鏌ラ」鍗曠嫭缁勬垚涓€琛屻€?- `ARCHITECTURE.md`锛氳褰曢椤典换鍔¤鎯呯Щ鍔ㄧ璧勬簮鍖哄竷灞€瑙勫垯銆?
## 楠岃瘉
- `flutter analyze lib/presentation/pages/home/home_page.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 5 涓棦鏈?lint/info銆?
## 椋庨櫓
- 浠?`640px` 浣滀负绐勫睆闃堝€硷紝瀹為檯璁惧缁嗚妭浠嶉渶鐪熸満纭銆?
# 2026-05-31 鎬濈淮瀵煎浘鍒犻櫎璺ㄧ鍚屾

## 淇敼
- `lib/data/repositories/task_repository.dart`锛氳繙绔换鍔″鐭充笉鍐嶈鏈湴娲讳换鍔℃棤鏉′欢鎷掔粷锛屾敼涓烘寜 `updatedAt` LWW 鍒ゆ柇銆?- `lib/services/task_sync_service.dart`锛氬叏閲忓悓姝ヤ笉鍐嶇敤鏈湴娲讳换鍔℃棤鏉′欢瑕嗙洊浜戠澧撶煶锛涙柊澧炰换鍔″悓姝?`changes` 骞挎挱銆?- `lib/presentation/pages/home/home_page.dart`锛氱洃鍚?`TaskSyncService.changes`锛岃繙绔换鍔℃柊澧?鏇存柊/鍒犻櫎鍚庤Е鍙?`LoadTasks` 鍒锋柊浠诲姟椤靛拰鎬濈淮瀵煎浘銆?- `ARCHITECTURE.md`锛氳褰曚换鍔″垹闄よ法绔悓姝ラ€昏緫銆?
## 楠岃瘉
- `flutter analyze lib/data/repositories/task_repository.dart lib/services/task_sync_service.dart lib/presentation/pages/home/home_page.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 7 涓棦鏈?lint/info/warning銆?
## 椋庨櫓
- 闇€鍙岀鐧诲綍鍚屼竴璐﹀彿鐪熸満楠岃瘉 Realtime 鍒犻櫎浼犳挱锛涙湰鏈轰粎鍋氶潤鎬佸垎鏋愩€?
# 2026-05-31 鎵嬫満楠岃瘉鐮佺櫥褰?
## 淇敼
- `lib/services/supabase_service.dart`锛氭柊澧炴墜鏈哄彿鍙戦€侀獙璇佺爜鍜岀煭淇?OTP 鏍￠獙灏佽锛屼娇鐢?Supabase Flutter `signInWithOtp` / `verifyOTP`銆?- `lib/presentation/blocs/auth/auth_event.dart`銆乣auth_state.dart`銆乣auth_bloc.dart`锛氭柊澧炴墜鏈哄彿楠岃瘉鐮佽姹傘€佹牎楠屽拰宸插彂閫佺姸鎬併€?- `lib/presentation/pages/auth/login_page.dart`锛氱櫥褰曢〉鏂板閭/鎵嬫満楠岃瘉鐮佹ā寮忓垏鎹紝鎵嬫満妯″紡鏀寔鑾峰彇楠岃瘉鐮併€佽緭鍏ラ獙璇佺爜鐧诲綍锛涘ぇ闄?11 浣嶆墜鏈哄彿鑷姩琛?`+86`銆?- `ARCHITECTURE.md`锛氳褰曟墜鏈洪獙璇佺爜鐧诲綍娴佺▼銆?
## 楠岃瘉
- `flutter analyze lib/presentation/blocs/auth/auth_bloc.dart lib/services/supabase_service.dart lib/presentation/pages/auth/login_page.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 12 涓棦鏈?`print` info銆?
## 椋庨櫓
- 闇€瑕佸湪 Supabase 鍚庡彴寮€鍚?Phone provider 骞堕厤缃煭淇℃湇鍔★紱鏈満鏈疄闄呭彂閫佺煭淇°€?
# 2026-05-31 鍏ㄥ眬鎺掗櫎椤圭洰

## 淇敼
- `lib/services/local_storage_service.dart`锛氭柊澧?`excludedProjectIds` 鎸佷箙鍖栬缃€?- `lib/presentation/blocs/task_new/task_bloc.dart`锛氫换鍔℃ā鍧楀姞杞藉拰杩涘害璁＄畻鍓嶆帓闄よ缃腑鐨勯」鐩€?- `lib/presentation/pages/home/home_page.dart`锛氶椤垫椂闂磋酱婧愭暟鎹帓闄よ缃腑鐨勯」鐩紝褰卞搷鏃堕棿杞淬€佺粺璁°€佸洓璞￠檺銆?- `lib/presentation/pages/home/home_page.dart`锛氶椤甸」鐩瓫閫夊簳灞傜姸鎬佷粠鍗曢」鐩?ID 璋冩暣涓洪」鐩?ID 闆嗗悎锛岀浉鍏宠绠楁寜闆嗗悎杩囨护銆?- `lib/presentation/pages/home/home_page.dart`锛氶椤甸」鐩瓫閫夊鍔犲閫夊脊绐楀叆鍙ｏ紝鍘熶笅鎷変繚鐣欎负蹇€熷崟閫夈€?- `lib/presentation/pages/calendar/calendar_page.dart`锛氭棩鍘嗕换鍔″姞杞芥椂鎺掗櫎璁剧疆涓殑椤圭洰锛涙棩鍘嗛」鐩瓫閫夋敼涓洪」鐩?ID 闆嗗悎锛屽彲鍦ㄨ彍鍗曚腑澶氶€?鍙栨秷椤圭洰銆?- `lib/presentation/pages/tasks/tasks_page.dart`锛欰ppBar 鏂板鈥滄帓闄ら」鐩€濆閫夎缃叆鍙ｃ€?- `lib/presentation/blocs/task_new/task_event.dart`銆乣task_state.dart`銆乣task_bloc.dart`銆乣lib/presentation/pages/tasks/tasks_page.dart`锛氫换鍔℃ā鍧楃瓫閫夌姸鎬佹敮鎸佸椤圭洰闆嗗悎锛屼换鍔￠〉 AppBar 鏂板椤圭洰澶氶€夌瓫閫夊叆鍙ｃ€?- `ARCHITECTURE.md`锛氳褰曞叏灞€鎺掗櫎椤圭洰鏁版嵁娴併€?
## 楠岃瘉
- `dart format` 宸叉牸寮忓寲鏈鐩稿叧 Dart 鏂囦欢銆?- `flutter analyze lib/presentation/pages/home/home_page.dart lib/presentation/pages/calendar/calendar_page.dart lib/presentation/blocs/task_new/task_event.dart lib/presentation/blocs/task_new/task_state.dart lib/presentation/blocs/task_new/task_bloc.dart lib/presentation/pages/tasks/tasks_page.dart lib/services/notification_service.dart lib/services/permission_service.dart lib/services/local_storage_service.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 27 涓棦鏈?lint/info/warning銆?
## 椋庨櫓
- 棣栭〉鍘熼」鐩笅鎷変粛淇濈暀蹇€熷崟閫夛紝鏃佽竟澶氶€夋寜閽敤浜庡閫夌瓫閫夈€?
# 2026-05-31 绉诲姩绔拰妗岄潰绔彁閱掗€氱煡

## 淇敼
- `lib/services/notification_service.dart`锛氱Щ鍔ㄧ璋冨害閫氱煡鍓嶅厹搴曡姹傞€氱煡鏉冮檺鍜?Android 绮剧‘闂归挓鏉冮檺锛沬OS 鍓嶅彴閫氱煡鏄惧紡鍚敤 alert/badge/sound銆?- `lib/services/notification_service.dart`锛歐indows 妗岄潰鎻愰啋鏀逛负 PowerShell MessageBox锛岀敤鎴风偣鍑?OK 鍓嶄笉浼氳嚜鍔ㄦ秷澶便€?- `lib/services/permission_service.dart`锛欰ndroid 棣栨閫氱煡鎺堟潈寮曞鍚屾璇锋眰绮剧‘闂归挓鏉冮檺銆?
## 楠岃瘉
- `flutter analyze lib/services/notification_service.dart lib/services/permission_service.dart` 宸茶繍琛岋紝鏃犻棶棰樸€?
## 椋庨櫓
- Android 绮剧‘闂归挓鏉冮檺浼氳烦杞郴缁熸巿鏉冮〉锛屼粛闇€鐪熸満纭涓嶅悓鍘傚晢鍚庡彴淇濇椿绛栫暐銆?
# 2026-06-01 鏂板缓鍒嗙粍鍚庝晶杈规爮涓嶆樉绀?
## 淇敼
- `lib/presentation/pages/tasks/widgets/project_sidebar.dart`锛氱┖鐘舵€佸垽鏂敼涓洪」鐩拰鍒嗙粍閮戒负绌烘椂鎵嶆樉绀烘暣浣撶┖鐘舵€侊紝鍏佽鏃犻」鐩殑鍒嗙粍姝ｅ父娓叉煋銆?- `test/project_sidebar_test.dart`锛氭柊澧炲洖褰掓祴璇曪紝瑕嗙洊娌℃湁椤圭洰浣嗗瓨鍦ㄥ垎缁勬椂浠嶅睍绀哄垎缁勫悕绉般€?
## 楠岃瘉
- `flutter test test\project_sidebar_test.dart` 閫氳繃銆?- `flutter analyze lib\presentation\pages\tasks\widgets\project_sidebar.dart test\project_sidebar_test.dart` 閫氳繃銆?
## 椋庨櫓
- 鏈仛鐪熸満/杩愯鏃舵墜鍔ㄧ偣鍑婚獙璇侊紱鏈浠呰鐩栫粍浠舵覆鏌撲笌闈欐€佸垎鏋愩€?
# 2026-06-01 椤圭洰渚ф爮鍒嗙粍灞曞紑涓庢帓搴?
## 淇敼
- `lib/presentation/pages/tasks/widgets/project_sidebar.dart`锛氬垎缁勫睍寮€鏀逛负鍙楁帶鐘舵€侊紝鏂板鍏ㄩ儴灞曞紑銆佸叏閮ㄦ敹缂┿€佹椂闂存帓搴忔寜閽紱鍒嗙粍鍜岀粍鍐呴」鐩寜 `createdAt` 鎺掑簭銆?- `lib/presentation/pages/tasks/tasks_page.dart`锛氱淮鎶や晶鏍忓垎缁勫睍寮€闆嗗悎锛涙柊寤洪」鐩€夋嫨鍒嗙粍鍚庣珛鍗冲睍寮€璇ュ垎缁勶紱璇诲彇骞朵繚瀛樻帓搴忔柟鍚戙€?- `lib/services/local_storage_service.dart`锛氭柊澧?`projectSidebarTimeSortDesc` 鎸佷箙鍖栭厤缃紝榛樿鍊掑簭銆?- `test/project_sidebar_test.dart`銆乣test/local_storage_service_test.dart`锛氳ˉ鍏呬晶鏍忓睍寮€/鏀剁缉銆佹帓搴忓拰鎸佷箙鍖栨祴璇曘€?- `ARCHITECTURE.md`锛氳褰曢」鐩晶鏍忓垎缁勫睍寮€鍜屾帓搴忕粨鏋勩€?
## 楠岃瘉
- `dart format lib\presentation\pages\tasks\widgets\project_sidebar.dart lib\presentation\pages\tasks\tasks_page.dart lib\services\local_storage_service.dart test\project_sidebar_test.dart test\local_storage_service_test.dart` 宸叉墽琛屻€?- `flutter test test\project_sidebar_test.dart test\local_storage_service_test.dart` 閫氳繃銆?
## 椋庨櫓
- 鏈仛鐪熸満鎵嬪姩鐐瑰嚮楠岃瘉锛涘綋鍓嶈鐩?widget 琛屼负鍜屾湰鍦板瓨鍌ㄦ寔涔呭寲銆?

# 2026-06-01 日历右键跳转思维导图节点
## 修改
- `lib/presentation/pages/calendar/calendar_page.dart`：日历任务列表项、单日任务块、多日任务条右键改为触发思维导图跳转回调；单日任务块右键不再直接删除。
- `lib/presentation/pages/home/home_page.dart`：接收日历跳转任务后切到任务页，并派发带目标任务 ID 的 `LoadTasks`。
- `lib/presentation/blocs/task_new/task_event.dart`、`task_state.dart`、`task_bloc.dart`：新增聚焦任务请求字段，加载时强制思维导图视图并展开目标任务祖先节点。
- `lib/presentation/pages/tasks/tasks_page.dart`、`lib/presentation/pages/tasks/widgets/mind_map_view.dart`：透传并消费聚焦请求，居中选中目标节点。
- `test/task_mindmap_focus_test.dart`：新增聚焦请求字段测试。
## 验证
- `flutter test test/task_mindmap_focus_test.dart` 通过。
- `flutter analyze lib/presentation/pages/home/home_page.dart lib/presentation/pages/calendar/calendar_page.dart lib/presentation/pages/tasks/tasks_page.dart lib/presentation/pages/tasks/widgets/mind_map_view.dart lib/presentation/blocs/task_new/task_bloc.dart lib/presentation/blocs/task_new/task_event.dart lib/presentation/blocs/task_new/task_state.dart` 无新增编译错误；命令仍因既有 lint/warning 非零。
## 风险
- 未做真机/桌面手动右键验收；当前仅完成静态分析和字段级测试。
