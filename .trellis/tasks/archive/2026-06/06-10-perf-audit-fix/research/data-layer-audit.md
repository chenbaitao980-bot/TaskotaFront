# Research: 数据层性能审计（lib/data + lib/domain + blocs 热路径）

- **Query**: 扫描数据层与调用数据层的热路径，找出阻塞 UI / 拖慢响应的弱点
- **Scope**: internal
- **Date**: 2026-06-10

说明：行号基于当前 master 工作区。影响评估 = 高/中/低 + 触发场景。

---

## W1. 每次任务变更同步等待全量云对账 syncAll（最严重）

- **文件:行号**: `lib/presentation/blocs/task_new/task_bloc.dart:525-552`（`_runOptimisticTaskChange`）
- **类别**: 3 网络同步阻塞用户操作路径 + 1 N+1
- **代码摘录**:

```dart
final previous = state as TaskNewLoaded;
final rollbackSnapshot = await taskRepository.getAllRaw(); // 每次变更全表快照
try {
  await action();
  await _emitTaskSnapshot(previous, emit, adjustSnapshot: adjustSnapshot);
  try {
    await TaskSyncService.instance.syncAll(rethrowErrors: true); // 阻塞 handler
  } catch (e) { ... }
```

- **影响**: **高**。CreateTask / UpdateTask / DeleteTask / ToggleTaskStatus / MoveTaskToParent / ReorderTaskSiblings 全部走此路径。`syncAll` = 拉取云端全表 + 逐行合并 + 逐行 HTTP push（见 W2）。Bloc 默认顺序处理事件，handler 被网络占住期间，用户后续操作（连续勾选多个任务、连续拖拽）全部排队，弱网下每次操作延迟数秒。虽然 UI 快照在 syncAll 之前已 emit（视觉上乐观），但事件队列被堵死才是卡顿根源。
- **建议**: syncAll 改为不 await 的后台防抖任务（如 300ms debounce 合并多次变更只触发一次）；失败用单独的"同步状态"通道提示而非依赖 handler 内 rethrow。回滚快照 `getAllRaw()` 改为只记录受影响行，或仅在删除等危险操作前做。

---

## W2. TaskSyncService.syncAll：N+1 合并 + 串行逐条 HTTP push + 无事务

- **文件:行号**: `lib/services/task_sync_service.dart:36-153`
- **类别**: 1 N+1 / 3 网络 / 7 事务缺失 / 10 日志热路径
- **代码摘录**:

```dart
for (final row in rows) {                       // 云端每行
  await _taskRepo!.syncFromJson(_rowToJson(map)); // 每行=1 SELECT + 1 INSERT/UPDATE
}
...
for (final t in localRows) {                    // 本地每行
  if (remote == null || t.updatedAt > remoteUpdated) {
    await push(t, rethrowErrors: rethrowErrors); // 每行一次 HTTP upsert，串行
  }
}
```

- **影响**: **高**。1000 条任务 ⇒ 拉取阶段 2000 次 SQL（无外层事务，每条 UPDATE/INSERT 单独 fsync），推送阶段最坏 N 次串行 HTTP 往返。该函数在每次任务变更（W1）、App 回前台（home_page.dart:104-115）、登录后（home_page.dart:220-228）都执行。另外 `getAllRaw()` 在一次 syncAll 内被调用 3 次（:50、:91、:112），且每行 2~4 条 `flog`（见 W12）。
- **建议**: 合并循环包入 `_db.transaction()`；推送改 Supabase 批量 `upsert(List)`（单请求）；用 `updated_at > lastSyncAt` 增量拉取代替全表；删除/采样化逐行 debug 日志。`ChecklistSyncService.syncAll`（checklist_sync_service.dart:22-55）存在完全相同的模式，需一并修复。

---

## W3. getDescendants：BFS 每节点一次查询（N+1）

- **文件:行号**: `lib/data/repositories/task_repository.dart:280-292`
- **类别**: 1 N+1
- **代码摘录**:

```dart
Future<List<Task>> getDescendants(String taskId) async {
  final result = <Task>[];
  final queue = <String>[taskId];
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    final children = await getSubTasks(current); // 每个节点一次 SELECT
    ...
```

- **影响**: **高**。N 节点子树 = N 次往返。被 delete、archiveTask、setStatusCascade、allDescendantsCompleted、_cascadeProjectId、bloc 的 _onDeleteTask/_onLoadSubTree/_onMergeSubTasksToChecklist、ai_decompose_section.dart:257/530 大量调用。Web WASM 下每次查询经 worker 消息往返，放大更明显。`queue.removeAt(0)` 还是 O(n) 移除。
- **建议**: 改 `WITH RECURSIVE` 递归 CTE 一次取回整棵子树（已有 idx_tasks_parent_id 索引支撑）；或一次 `getAll` 后内存建 parentId 索引遍历。

---

## W4. 批量写后逐条回读 + 逐条 HTTP push（archive/delete/cascade/reorder）

- **文件:行号**: `lib/data/repositories/task_repository.dart:142-147`（archiveTask）、`518-521`（delete）、`590-595`（setStatusCascade）、`485-489`（_cascadeProjectId）、`344-349`（reorderSubTasks）
- **类别**: 1 N+1 + 3 网络
- **代码摘录**（delete 为例）:

```dart
await _db.batch((batch) { ... });   // 批量写 OK
for (final tid in ids) {
  final row = await _getRaw(tid);   // 逐条回读 N 次 SELECT
  if (syncImmediately && row != null) _syncService?.push(row); // 逐条 HTTP
}
```

- **影响**: **高**（删除/归档大子树时）。50 个后代 = 50 次 SELECT + 50 次未 await 的并发 HTTP upsert（请求风暴，且与 W1 的 syncAll 重复推送同一批行）。
- **建议**: 用一条 `isIn(ids)` SELECT 批量回读；push 改批量 upsert；既然 W1 已兜底 syncAll，这些 `syncImmediately` 路径可只推根节点或彻底交给防抖同步。

---

## W5. TaskRepository.create 同步 await 网络 push

- **文件:行号**: `lib/data/repositories/task_repository.dart:404-412`
- **类别**: 3 网络阻塞用户操作
- **代码摘录**:

```dart
final result = await (_db.select(_db.tasks)..where((t) => t.id.equals(id))).get();
final task = result.first;
print('[TaskRepo.create] id=${task.id}, ...');
if (syncImmediately) await _syncService?.push(task); // await HTTP upsert
return task;
```

- **影响**: **高**。`_onCreateTask` 以 `syncImmediately: true` 调用（task_bloc.dart:647-658），用户点"创建"后必须等一次 Supabase 往返才走到乐观 emit；弱网/断网（push 内部 catch 但要等超时）下新建任务明显卡顿。模板克隆 `cloneTree` 幸好传了 false。
- **建议**: create 不 await push（fire-and-forget 或入队），本地写完立即返回；失败由对账兜底。同时移除 `print`。

---

## W6. 首屏 LoadTasks await 云端 fetchPreferences

- **文件:行号**: `lib/presentation/blocs/task_new/task_bloc.dart:326-341`；`lib/services/supabase_service.dart:268-280`
- **类别**: 3 网络阻塞 / 8 Web 首屏
- **代码摘录**:

```dart
if (state is! TaskNewLoaded) {
  final localPrefs = _storage.getTaskFilterState();
  final cloudPrefs = await supabaseService?.fetchPreferences(); // 首次加载等网络
  final prefs = cloudPrefs ?? localPrefs;
```

- **影响**: **高**。任务页首次 LoadTasks 在 emit 之前同步等待一次 Supabase 查询，弱网下首屏白屏/Loading 时间 = 网络 RTT（最坏到超时）。Web 端（WASM + 冷启动）尤为明显。
- **建议**: 先用 localPrefs 立即 emit 首屏，云端 prefs 异步到达后若有差异再补发一次 LoadTasks。

---

## W7. reorder 系列：循环逐条 UPDATE 无事务（多次 fsync）

- **文件:行号**: `lib/data/repositories/task_repository.dart:334-343`（reorderSubTasks）、`761-772`（reorder）；`lib/data/repositories/checklist_repository.dart:126-139`（reorderItems）
- **类别**: 7 事务缺失 + 1 N+1
- **代码摘录**:

```dart
for (var i = 0; i < orderedIds.length; i++) {
  await (_db.update(_db.tasks)..where((t) => t.id.equals(orderedIds[i])))
      .write(TasksCompanion(sortOrder: Value(i), updatedAt: ...)); // 每条独立提交
}
```

- **影响**: **中**。拖拽排序 N 条 = N 次独立事务/fsync；reorderItems 之后还逐条 `_push`（N 次 SELECT + N 次 HTTP）。拖拽是高频交互，Windows 机械盘和 Web WASM 上可感知。
- **建议**: 包 `_db.batch()` 或 `transaction()`；push 批量化。

---

## W8. syncFromJson 全量合并无外层事务

- **文件:行号**: `lib/data/repositories/task_repository.dart:631-759`；`lib/data/repositories/checklist_repository.dart:160-189`；调用方 task_sync_service.dart:80-88
- **类别**: 7 事务缺失 + 1 N+1
- **代码摘录**:

```dart
for (final row in rows) {
  ...
  await _taskRepo!.syncFromJson(_rowToJson(map)); // 内部: _getRaw SELECT + 单条写
}
```

- **影响**: **中**（与 W2 叠加成高）。每行一次 SELECT 判存在 + 一次独立提交写；全量同步 N 行 = 2N SQL + N fsync。
- **建议**: 调用方一次性取本地 `getAllRaw()` 建 Map 后内存判断 LWW，胜出行统一 `batch insertOnConflictUpdate`，整体包事务。

---

## W9. 无 watch/响应式查询：每个事件全表重查 + 全量进度重算

- **文件:行号**: `lib/presentation/blocs/task_new/task_bloc.dart:554-637`（_emitTaskSnapshot）、`1114-1127`（_calculateProgress）；全库无任何 Drift `.watch()`（已验证 grep 0 命中）
- **类别**: 5 查询粒度过粗（反向形态：手动全量重查） + 2 主 isolate 大列表计算
- **代码摘录**:

```dart
final allTasks = (await taskRepository.getAll())...; // 全表
...
final matchedIds = await taskRepository.searchTaskIds(...); // 两表 LIKE
final progress = await _calculateProgress(allTasks);  // 全部任务+全部清单项递归
final groups = await projectGroupRepository?.getAll();
```

- **影响**: **中**。每次任意一条任务变更，_emitTaskSnapshot 执行 6~8 个查询（projects、templateProjects、getAll、getToday/getImportant、searchTaskIds、getByTaskIds、groups）并在主 isolate 上对全量任务做多遍 where/toList + 递归进度计算。LoadChecklistItems 勾一个清单项也触发 `getAll()` + 全量进度重算（:871-897）。千条任务量级在低端 Android / Web 上会出现可感掉帧。
- **建议**: 进度计算增量化（只重算受影响子树/项目）或挪 `compute()`；引入 Drift `watch()` 流按 projectId 粒度订阅，去掉"事件后手动全量重查"模式。

---

## W10. COUNT 用全行拉取实现（select 后 .length）

- **文件:行号**: `lib/data/repositories/task_repository.dart:48-54`（getActiveCountForProject）；`lib/data/repositories/checklist_repository.dart:141-157`（getCompletedCount/getTotalCount）；`lib/data/repositories/project_repository.dart:44-52`
- **类别**: 4 取全表后内存过滤
- **代码摘录**:

```dart
Future<int> getActiveCountForProject(String projectId) async {
  final result = await (_db.select(_db.tasks)
        ..where((t) => t.projectId.equals(projectId) & ...)).get();
  return result.length; // 拉全部行只为数数
}
```

- **影响**: **中**。`getActiveCountForProject` 在**每次** `create()` 任务时执行（配额检查），把项目下所有任务整行取回并反序列化只为计数；模板克隆 N 个子任务 = N 次全行计数。
- **建议**: 改 `selectOnly + countAll()`（Drift 聚合），单值返回。

---

## W11. LocalStorageService：SharedPreferences 存整表 JSON，读写全量编解码 + 全量快照落盘

- **文件:行号**: `lib/services/local_storage_service.dart:61-78, 133-137, 140-190, 386-390`；`lib/services/local_data_service_io.dart:90-94, 202-227`（persistPreferencesSnapshot）
- **类别**: 2 主 isolate 大 JSON 编解码 + 9 序列化开销 + 10 同步落盘
- **代码摘录**:

```dart
Future<void> _saveTasks(List<TaskBreakdown> tasks) async {
  final jsonList = tasks.map((t) => t.toJson()).toList();
  await _prefs?.setString(_tasksKey, json.encode(jsonList)); // 整表重编码
  await LocalDataService().persistPreferencesSnapshot();      // 全部 prefs 转缩进 JSON 写文件 flush:true
}
```

- **影响**: **中**。schedules/TaskBreakdown 每次读取全量 `json.decode` + 逐条 fromJson（主 isolate）；每次任何小改动（创建一条日程、改主题、改筛选）都触发 `persistPreferencesSnapshot()`：遍历全部 prefs → `JsonEncoder.withIndent` 编码 → 同步 flush 写文件。`checkAndAutoCompleteParent`/`refreshParentFlag` 递归中每层都 `updateTask` → 每层一次全量编解码 + 落盘 + `_syncTasksToCloud()`（内含拉云合并 + 推送）。
- **建议**: 快照写入防抖（如 2s 合并）；TaskBreakdown/Schedule 迁入 Drift；递归传播改为批处理最后一次性持久化。

---

## W12. flog 热路径日志：无条件 print + 每行多条插值

- **文件:行号**: `lib/core/utils/file_logger_io.dart:81-84`；重灾区 `lib/services/task_sync_service.dart:54-79, 113-121`、`lib/data/repositories/task_repository.dart:637-717`
- **类别**: 10 日志热路径
- **代码摘录**:

```dart
void flog(String message) {
  FileLogger.instance.log(message); // 缓冲 OK（500ms 定时 flush）
  print(message);                   // release 也执行，且参数插值总被求值
}
```

- **影响**: **中**。文件写已有 500ms 缓冲（设计正确），但 `print` 无 kReleaseMode 守卫；syncAll 对每条子任务打 2~4 条日志（合并前快照、云端 child、本地 child、syncFromJson 内 3~5 条），千条任务一次全量同步产生数千次字符串拼接 + print（Windows 控制台 / Android logcat 同步开销）。`task_repository.dart:408` 还有裸 `print`。
- **建议**: `if (kReleaseMode) return;` 或日志等级开关；逐行 DEBUG 日志降级为汇总统计（条数、耗时）。

---

## W13. ApplyTemplate / 模板克隆：逐条 create 链式放大

- **文件:行号**: `lib/presentation/blocs/task_new/task_bloc.dart:1376-1448`（cloneTree）、`730-750`（_createTemplateSubtaskTree）
- **类别**: 1 N+1
- **代码摘录**:

```dart
final newTask = await taskRepository.create(...);  // 每条: 计数查询+配额检查+INSERT+回读 SELECT
for (final item in items) {
  await checklistRepository.create(taskId: newTask.id, title: item.title); // 每条: getByTask+INSERT+回读+push
}
```

- **影响**: **中**。克隆 30 节点模板 ≈ 30×(2 查询+1 插入) + 清单项 N×(1 查询+1 插入+1 回读+1 HTTP push（checklist create 无 syncImmediately 开关，永远 push）)，全程在 _runOptimisticTaskChange 内，最后再跟一次全量 syncAll。
- **建议**: 提供批量 createMany（单事务）；checklist create 增加 syncImmediately 参数；配额检查在循环外做一次。

---

## W14. getArchived：日期过滤在内存做 + archived 列无索引

- **文件:行号**: `lib/data/repositories/task_repository.dart:98-126`；索引清单 `lib/data/database/app_database.dart:188-199`
- **类别**: 4 无索引高频查询 + 内存过滤
- **代码摘录**:

```dart
var result = await query.get();        // 先取全部归档行
if (dateFrom != null && dateTo != null) {
  result = result.where((t) { ... }).toList(); // 内存过滤日期交集
}
```

- **影响**: **低-中**。v10 索引覆盖 project_id/parent_id/deleted/status/due_date，但 `archived` 没有索引，而**几乎所有**活动查询都带 `archived.equals(0)`，归档视图查询带 `archived.equals(1)` + LIKE。数据量大后全表扫描。日期交集条件可下推为 SQL（start/due 列均可索引）。
- **建议**: v12 迁移加 `idx_tasks_archived`（或复合 `(deleted, archived)`）；日期过滤改 where 子句；搜索量大再考虑 FTS5。

---

## W15. App 回前台 / 登录后串行五连 syncAll

- **文件:行号**: `lib/presentation/pages/home/home_page.dart:104-115, 220-228`
- **类别**: 3 网络 + 2 主 isolate 合并
- **代码摘录**:

```dart
Future<void> runSyncAll({bool forcePush = false}) async {
  await ProjectSyncService.instance.syncAll(forcePush: forcePush);
  await TaskSyncService.instance.syncAll();
  await ChecklistSyncService.instance.syncAll();
  await NodeTemplateSyncService.instance.syncAll();
  await AttachmentSyncService.instance.pullAll();
```

- **影响**: **低-中**。本身是后台 async（不直接阻塞帧），但五个服务串行全量拉取 + 每行合并都在主 isolate 上跑（W2/W8 的 SQL 与 JSON 处理穿插在 UI 事件循环中），回前台瞬间易掉帧；且每次 resume 都全量。Realtime 已订阅的情况下 resume 全量对账可减频。
- **建议**: 各服务增量同步（lastSyncAt 水位）；合并批量化后单事务执行；resume 对账加最小间隔节流。

---

## W16. NodeTemplates 表存 imagesJson（含图片数据）整行读出

- **文件:行号**: `lib/data/database/app_database.dart:101-120`；`lib/data/repositories/node_template_repository.dart:17-41`
- **类别**: 9 序列化开销 / 2 主 isolate 解码
- **代码摘录**:

```dart
TextColumn get imagesJson => text().customConstraint('NOT NULL DEFAULT \'[]\'')();
...
Future<List<NodeTemplate>> getAll() { return (_db.select(_db.nodeTemplates)...).get(); }
images: NodeTemplatePayload.decodeImages(template.imagesJson),
```

- **影响**: **低-中**（取决于图片是否 base64 内嵌，未能完全确认 payload 编码细节）。若 imagesJson 内嵌图片字节，模板列表 `getAll()` 会把所有模板的图片数据整行载入内存，payloadOf 在主 isolate jsonDecode。
- **建议**: 列表查询用 selectOnly 排除大列；图片改存附件目录只留引用；大 JSON decode 用 compute()。

---

## W17. 重复初始化（轻微）

- **文件:行号**: `lib/presentation/blocs/task_new/task_bloc.dart:38, 324, 563`（_storage.init 多次）；`LocalStorageService`/`LocalDataService`/`SupabaseService` 在 main.dart:216-233、home_page.dart:75 等处反复 new；`SharedPreferences.getInstance` 全库 20+ 处直呼
- **类别**: 6 重复初始化
- **影响**: **低**。SharedPreferences.getInstance 首次后有平台缓存，开销小；但 LocalStorageService 非单例导致 `_prefs` 多份引用、init 时序依赖（构造函数里 fire-and-forget `_storage.init()`，task_bloc.dart:38，存在初始化竞态而非性能问题）。数据库连接全局仅 1 个（main.dart:123），无多开问题 ✅。
- **建议**: LocalStorageService 改单例 + 显式 ready Future。

---

## 未发现 / 排除项

- 数据库连接：全局单实例（main.dart:123），无重复开库 ✅
- Drift Web：标准 WasmDatabase + worker（connection_web.dart），无同步等待 API；`missingFeatures` 仅 print，未对降级模式做容量预警（信息级）
- `restoreRawTasks`、`wipeAllData`、`ProjectRepository.delete` 已正确包事务 ✅
- 文件日志已有 500ms 缓冲 + 按天保留 1 天清理 ✅（问题只在 print 与日志量，见 W12）
- 主任务表已建 5 个关键索引（v10 迁移）✅（缺 archived，见 W14）

---

## 汇总表（按影响排序）

| # | 弱点 | 类别 | 影响 | 位置 |
|---|------|------|------|------|
| W1 | 每次任务变更 await 全量 syncAll，事件队列被网络堵死 | 3 | 高 | task_bloc.dart:525-552 |
| W2 | syncAll N+1 合并 + 串行逐条 HTTP push + 无事务 + 全表拉取 | 1/3/7 | 高 | task_sync_service.dart:36-153 |
| W3 | getDescendants BFS 每节点一次查询 | 1 | 高 | task_repository.dart:280-292 |
| W4 | 批量写后逐条回读 + 逐条 HTTP push（delete/archive/cascade） | 1/3 | 高 | task_repository.dart:142,485,518,590 |
| W5 | create() await 网络 push，新建任务等 HTTP 往返 | 3 | 高 | task_repository.dart:411 |
| W6 | 首屏 LoadTasks await 云端 fetchPreferences | 3/8 | 高 | task_bloc.dart:326-341 |
| W7 | reorder 循环逐条 UPDATE 无事务（N 次 fsync） | 7 | 中 | task_repository.dart:334,761; checklist_repository.dart:126 |
| W8 | syncFromJson 全量合并无外层事务（2N SQL + N fsync） | 7/1 | 中 | task_repository.dart:631; checklist_repository.dart:160 |
| W9 | 无 watch 流，每事件全表重查 + 主 isolate 全量进度重算 | 5/2 | 中 | task_bloc.dart:554-637,1114 |
| W10 | COUNT 用全行拉取实现，create 每次触发 | 4 | 中 | task_repository.dart:48; checklist_repository.dart:141 |
| W11 | SharedPreferences 存整表 JSON + 每次小改动全量快照落盘 | 2/9/10 | 中 | local_storage_service.dart:133,386; local_data_service_io.dart:90 |
| W12 | flog 无条件 print，同步循环每行多条日志 | 10 | 中 | file_logger_io.dart:81; task_sync_service.dart 多处 |
| W13 | 模板克隆逐条 create（计数+插入+回读+push 链式放大） | 1 | 中 | task_bloc.dart:1376-1448 |
| W14 | archived 列无索引；getArchived 内存日期过滤 | 4 | 低-中 | task_repository.dart:98-126; app_database.dart:188 |
| W15 | resume/登录五服务串行全量同步，无增量无节流 | 3 | 低-中 | home_page.dart:104,220 |
| W16 | NodeTemplates imagesJson 大列整行读出主 isolate 解码 | 9/2 | 低-中 | node_template_repository.dart:17-41 |
| W17 | LocalStorageService 非单例、init 竞态 | 6 | 低 | task_bloc.dart:38; home_page.dart:75 |

**修复优先级建议**：W1+W2 一起改（变更后防抖后台增量同步 + 批量 upsert + 事务化合并）收益最大；其次 W3（递归 CTE）与 W5/W6（去掉用户路径上的网络 await）；W7/W8/W10 属低风险快赢。
