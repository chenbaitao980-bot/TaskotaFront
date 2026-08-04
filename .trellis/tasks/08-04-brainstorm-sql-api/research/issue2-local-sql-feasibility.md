# Research: 本地 SQL 替代远程 API 可行性（issue2）

- **Query**: 评估 Taskora 把远程 API（Supabase）查询改成本地 SQL（drift/SQLite）、所有数据查询交互走本地、优化"联网太卡"的可行性
- **Scope**: mixed（内部代码 + 外部架构）
- **Date**: 2026-08-04

## 核心结论（先说）

**本项目读路径已经 100% 走 drift 本地，写路径是"本地优先 + fire-and-forget 推送 + 全量对账"。"联网卡"的瓶颈不在读，而在：① 每次回前台/登录触发**全表拉取**的 `syncAll`/`forcePullAll`（无超时、无增量游标）；② 6 条常驻 Realtime WebSocket；③ 少量旧代码路径（日程/旧任务）仍直连远程表。**本地化改造目标应聚焦"同步层"而非"读层"。**

---

## 1. 数据流清单表

| 数据类型 | drift 本地表 | 读走哪 | 写走哪 | 远程同步 | 是否阻塞 UI | 网络卡影响 |
|---|---|---|---|---|---|---|
| 任务 Tasks | `Tasks` (app_database.dart:40-66) | drift（task_repository.dart:17-35 getAll / 71-90 getToday / 92-100 getImportant / 103-128 getArchived） | drift 本地优先，fire-and-forget push（task_repository.dart:454） | `user_tasks` + Realtime | 读否；push 不阻塞 | 读无感；push/sync 受卡影响 |
| 项目 Projects | `Projects` (app_database.dart:22-38) | drift（project_repository.dart:14-16 / 21-28） | drift + pushProject | `projects` + Realtime | 读否 | 同上 |
| 项目组 ProjectGroups | `ProjectGroups` (app_database.dart:8-20) | drift（project_group_repository.dart:12-17） | drift + pushGroup | `project_groups` + Realtime | 读否 | 同上 |
| 子任务（树） | `Tasks.parentId` | drift（getSubTasks/getDescendants task_repository.dart:200-299） | drift | 同 Tasks | 读否 | 读无感 |
| 清单 ChecklistItems | `ChecklistItems` (app_database.dart:83-97) | drift（checklist_repository.dart:12-25） | drift + push | `checklist_items` + Realtime | 读否 | 读无感 |
| 便签摘要（浮动便签） | 无表，由 Tasks 实时计算 | drift `getAllRaw()`（desktop_floating_tab_controller.dart:262-294） | n/a（仅展示） | n/a | 否 | **纯本地** |
| 懒人日志草稿 | `LazyLogDrafts` (app_database.dart:101-131) | drift（lazy_log_draft_repository.dart:14-52 watch 流） | drift | **无云端同步** | 否 | 无 |
| 懒人日志 AI 结构化 | n/a | **远程 dio → LLM**（home_lazy_log_service.dart:34） | 结果写 drift | LLM API | 否（unawaited 后台） | **明显受卡**（AI 固有） |
| 设置/主题/筛选 | SharedPreferences | 本地（local_storage_service.dart:445-535） | 本地 + 任务筛选偏好云同步（非阻塞） | `app_preferences_sync` | 否 | 无 |
| 附件 metadata | `TaskAttachments` (app_database.dart:68-81) | drift（attachment_sync_service 拉取后本地） | drift + push | `task_attachments` + Realtime | 读否 | 读无感 |
| 附件文件本体 | 本地文件 + Supabase storage | 本地文件；缺时按需 download（task_attachment_service_io.dart:290） | upload storage（:163/:244） | storage bucket | 否 | 打开附件时受卡 |
| 节点模板 NodeTemplates | `NodeTemplates` (app_database.dart:133-152) | drift（node_template_repository.dart:17-22） | drift + push | `node_templates` + Realtime | 读否 | 读无感 |
| 订阅/会员状态 | SharedPreferences 缓存 | 本地缓存 init（subscription_service.dart:51-53）；后台 refresh 远程 | 服务端只写 | `user_subscriptions`/`vip_whitelist` + Realtime | 否（3s 超时） | 缓存足够首屏 |
| 会员配置 member config | SharedPreferences 缓存 | 本地缓存 + 后台 refresh（member_config_service.dart:180-228，3s 超时） | 远程 | 三张表 | 否 | 非阻塞 |
| 帮助/关于 app_config | SharedPreferences 缓存 | 本地缓存 + 后台 refresh（app_config_service.dart:41-69，3s 超时） | 远程 | `app_config` | 否 | 非阻塞 |
| 支付 payment | n/a | 远程 Edge Function | 远程 | `create-order`/`order-status` | 支付流程必然等待 | **必须远程** |
| 日程 schedules（旧） | **无 drift 表**，走 SharedPreferences JSON | 本地 getSchedules（local_storage_service.dart:61-78） | 本地 + ScheduleBloc 远程写 `schedules`（home_page.dart:369-374/459-462） | `schedules` | 写远程不 await | 显示本地，写卡 |
| 旧任务 TaskBreakdown（旧） | **无 drift 表**，走 SharedPreferences JSON | 本地 getTasks（local_storage_service.dart:139-190），首页合并为次要源（home_page.dart:880-898） | 本地 + `local_task_sync` JSON 快照 | `task_breakdowns` / `local_task_sync` | `_initStorage` 有 await（:201） | **见热点 1** |
| 认证 auth | n/a | 远程 Supabase auth | 远程 | auth | 登录流程 | 必须远程 |

> 图例：drift = 本地 SQLite（`AppDatabase`，connection 走 `NativeDatabase.createInBackground` 后台 isolate，connection_native.dart:12 / Web 走 Wasm + drift_worker.dart.js，connection_web.dart:6-12）。**所有业务实体读均为本地**。

---

## 2. 本地库现状

### drift schema（app_database.dart，schemaVersion=13）
共 7 张表：`Projects` / `Tasks` / `ChecklistItems` / `ProjectGroups` / `TaskAttachments` / `NodeTemplates` / `LazyLogDrafts`。迁移写在代码内（app_database.dart:172-275），非 SQL 文件。

**覆盖缺口**（本地无表、远程才有）：
- 日程 `schedules`（旧路径 SharedPreferences）
- 旧任务 `task_breakdowns`
- 用户资料 `user_profiles`
- 订阅 `user_subscriptions` / `vip_whitelist`
- 支付订单 / 会员配置 / app_config（这些属于"服务端权威 + 本地缓存"更合理，不适合入业务表）

### `database/` 目录的性质
- `data.db`：**0 字节占位文件**，不是样例库。
- `migration_001~010` + `create_sync_table.sql` + `migration_wechat_reminder.sql`：**全是 Supabase（PostgreSQL）DDL**，用于 Supabase SQL Editor，与 drift schema **无直接关系**（本地 SQLite 结构只由 app_database.dart 驱动）。`create_sync_table.sql` 单独创建 `local_task_sync` 快照表（旧 TaskBreakdown 云同步用）。

---

## 3. 同步架构

**明确是"本地优先 + 后台同步"（local-first + background sync），不是远程优先缓存**：
- 读：全走 drift（见上表）。
- 写：本地事务写完 → fire-and-forget `push()`（task_repository.dart:454 显式注释 "本地写完立即返回，推送失败由全量对账兜底"）；`_runOptimisticTaskChange` 里 syncAll 也是 `unawaited` 后台（task_bloc.dart:571-575）。
- 同步 = 双向 LWW 全量对账（含墓碑 tombstone 保护），见 `syncAll()`：task_sync_service.dart:36-153、project_sync_service.dart:72-121、checklist_sync_service.dart:22-55、node_template_sync_service.dart:26-54、attachment_sync_service.dart:25-50。

### Realtime channels（6 条常驻）
| channel | 表 | 位置 |
|---|---|---|
| `user_tasks_sync` | user_tasks | task_sync_service.dart:189-219 |
| `projects_sync` | projects + project_groups | project_sync_service.dart:197-276 |
| `checklist_items_sync` | checklist_items | checklist_sync_service.dart:74-95 |
| `node_templates_sync` | node_templates | node_template_sync_service.dart:70-91 |
| `attachments_sync` | task_attachments | attachment_sync_service.dart:76-111 |
| `user_subscriptions_$userId` | user_subscriptions | subscription_service.dart:108-130 |

全部在登录后启动（home_page.dart:269-275）。**离线时读本地完全可行**——本地库就是主数据源。

---

## 4. 远程 API 清单

### 4.1 Supabase 表直连 `.from(...)`（远程）
| 表 | 操作 | 文件:行 |
|---|---|---|
| `user_tasks` | pull 全量 / upsert / delete | task_sync_service.dart:61-64 / :164 / :174 |
| `projects` / `project_groups` | pull / push / delete | project_sync_service.dart:48-58 / :130/:165 / :151/:183 |
| `checklist_items` | pull / push | checklist_sync_service.dart:27-30 / :61 |
| `node_templates` | pull / push | node_template_sync_service.dart:31-34 / :60 |
| `task_attachments` | pull / push / delete | attachment_sync_service.dart:29-32 / :54 / task_attachment_service_io.dart:163/:244/:346 |
| `user_subscriptions` / `vip_whitelist` | 查询（3s 超时） | subscription_service.dart:71 / :95 |
| `member_types` / `member_discount_codes` / `member_recharge_tiers` | 查询（3s 超时） | member_config_service.dart:195-202 |
| `app_config` | 查询（3s 超时） | app_config_service.dart:51 |
| `schedules` | 查/增/改/删（旧路径） | supabase_service.dart:77-120 |
| `task_breakdowns` | 查/增/改/删（旧路径） | supabase_service.dart:123-163 |
| `local_task_sync` | upsert / fetch JSON 快照 | supabase_service.dart:177 / :201 |
| `user_profiles` | 查/增/改 | supabase_service.dart:225-250 |
| `app_preferences_sync` | upsert / fetch | supabase_service.dart:260 / :272 |
| `get_user_count` (rpc) | 注册人数 | supabase_service.dart:13 |

### 4.2 Edge Functions（远程，supabase/functions/）
| 函数 | 用途 | 调用点 |
|---|---|---|
| `create-order` / `order-status` | 支付 | payment_service.dart:30 / :50 |
| `register-device` | 阿里云推送注册 | aliyun_push_service_io.dart:141 |
| `schedule-push` / `alipay-notify` / `member-config` | 推送/回调/配置 | 服务端侧 |
| （fcm 推送） | | fcm_service.dart:60 |

### 4.3 外部 HTTP（dio）
| 目标 | 用途 | 位置 |
|---|---|---|
| 用户配置 LLM endpoint | 懒人日志结构化 | home_lazy_log_service.dart:34 |
| 用户配置 LLM endpoint | AI 对话 | assistant_chat_service.dart:133 |
| 用户配置 LLM endpoint | AI 拆解 | task_decomposition_service.dart:101 |
| timor.tools 节假日 API | 节假日 | holiday_service.dart:145 |

### 4.4 分类
- **纯查询（本地已有/可本地化）**：user_tasks、projects、project_groups、checklist_items、node_templates、task_attachments、schedules、task_breakdowns
- **写操作（必须同步，可队列化）**：上述各表的 upsert/delete
- **实时订阅**：6 条 Realtime channel（可降级为可选/轮询）
- **认证**：Supabase auth（signIn/signUp/OTP，supabase_service.dart:18-61）→ 必须远程
- **支付/订阅**：payment Edge Functions + user_subscriptions/vip_whitelist → 必须远程（服务端权威）
- **推送**：register-device、fcm、schedule-push → 必须远程
- **AI**：LLM dio → 必须远程（能力固件）

---

## 5. 本地化可行性评估（3 档）

### A) 已本地化 / 可立即本地化的读路径（改动≈0）
任务、项目、项目组、子任务、清单、节点模板、附件 metadata、懒人日志草稿、便签摘要、设置/主题/筛选、订阅/会员配置/app_config 本地缓存——**读已全走 drift/SharedPreferences**，无需改动即可离线使用。

### B) 需要补本地表/同步策略的
1. **日程 schedules**：显示已本地（SharedPreferences），但 ScheduleBloc 写仍远程 `schedules`（home_page.dart:369-374）。建议补 drift 表统一；中等改动。
2. **旧任务 TaskBreakdown 双轨**：SharedPreferences JSON + `local_task_sync` 快照 + 首页合并（home_page.dart:880-898）。建议逐步并进 drift `Tasks`（目前两套 ID/状态体系并存，是迁移风险点）。
3. **同步增量游标**：`syncAll` 每次全表 `.select().eq('user_id', ...)` 无 `updated_at > cursor` 过滤 → 需补增量拉取。
4. **懒人日志历史**：如需持久历史列表，需新建表；当前仅草稿表 + AI 结果写 draft。

### C) 不适合本地化的
认证、支付下单/查状态、订阅/白名单权威判定、跨设备 Realtime 实时一致、AI 结构化/对话/拆解、推送注册、节假日数据源、附件文件本体存储。

---

## 6. 性能瓶颈现状（"联网卡"根因）

**读不卡**：所有实体读是 drift 本地查询（home 页 `_loadData` home_page.dart:845-935 纯本地；task_bloc `_onLoadTasks` task_bloc.dart:292+ 纯本地）。

**真正的卡点（网络相关）：**
1. **每次回前台串行 await 全表拉取（无超时）**：`_onAppResume` home_page.dart:119-125 → `await forcePullAll(); await syncAll();`。弱网下 HTTPS 请求可长时间悬挂，直接拖住 resume 后的流程。`forcePullAll`（project_sync_service.dart:41-68）与 `syncAll`（task_sync_service.dart:36-153）**均无 timeout、全表下载、无增量游标**。
2. **首次登录串行 5 连拉**：`runSyncAll` home_page.dart:252-260（Project→Task→Checklist→NodeTemplate→Attachment 逐个 await）。
3. **`_initStorage` 阻塞 await 网络**：home_page.dart:201 `await _storage.fetchAndMergeFromCloud()`（local_storage_service.dart:596-625，无超时）。
4. **`_onSyncFromCloud` 事件 await syncAll**：task_bloc.dart:541，阻塞该事件直至网络完成（LoadTasks 是独立事件所以列表仍可用，但同步本身会悬挂）。
5. **6 条常驻 Realtime WebSocket**：弱网下持续心跳/重连开销（home_page.dart:269-275、subscription_service.dart:113-130）。
6. **每写一条 push 一条**：写路径网络请求多（fire-and-forget，不阻塞但制造流量）。

---

## 7. 方案对比

### 方案① 纯本地优先 + 后台增量同步（推荐）
把 drift 当唯一业务真源（现状 95% 已是），**把 syncAll 从全表改为增量**（`updated_at > last_sync_cursor`，墓碑用 deleted 时间戳兜底），给 forcePullAll/syncAll 加超时（复用现有 3s 模式），schedules/旧 TaskBreakdown 并入 drift，Realtime 降为可选。
- **pros**：直击"卡"根因；离线可用；与现有 local-first + LWW 墓碑代码 100% 契合；改动集中在同步层，读层不动。
- **cons**：增量拉取需处理墓碑/物理删除对账；需补同步游标持久化。
- **改动量**：中（同步服务 + 2 张表迁移）。**风险**：低-中（合并逻辑已成熟）。

### 方案② 只保留关键远程读 + 高频全部本地
最小化远程面：关掉 6 条 Realtime（改登出/回前台触发一次增量拉取），非关键远程（schedules/task_breakdowns）直接切断只留本地。
- **pros**：改动小、收益立竿见影（少 6 条 WebSocket）。
- **cons**：不做增量游标则回前台仍全表拉；跨设备实时一致被牺牲（需用户接受）。
- **改动量**：小。**风险**：低。适合作为①的先行步骤。

### 方案③ 中间层缓存 + 写队列（outbox）
在现有 push 基础上形式化一个写队列（本地 outbox 表 + 断网重放 + 幂等），订阅/会员/app_config 继续走"缓存优先 + 3s 超时刷新"（现状已是）。
- **pros**：弱网/离线写入最稳；订阅类已实现大半。
- **cons**：改动大；现有 fire-and-forget + 全量对账已能兜底，收益边际。
- **改动量**：大。**风险**：中。

---

## 8. 推荐方案

**方案①为主 + 方案②先行**：
1. 先关/降级 Realtime 或改为按需（收益最快，零风险）；`_onAppResume` 的串行 await 拆成 `unawaited` + 限流。
2. syncAll/forcePullAll 加超时 + 增量游标（这是根治"联网卡"的关键）。
3. 日程并入 drift 表，旧 TaskBreakdown 双轨逐步收敛。
4. 明确 **不本地化**：认证、支付、订阅权威、AI、推送、附件本体（这些保持远程，用本地缓存兜底）。

## Caveats / 未确认
- `local_storage_service.dart` / `schedule_bloc.dart` / 旧 `task_bloc.dart` 的远程路径是否还有活跃 UI 调用：首页/日历当前以 `_storage.getSchedules()`（本地）渲染，ScheduleBloc 仅用于写同步；但首页 `context.read<ScheduleBloc>()` 仍在（home_page.dart:369/459/513），迁移日程表前需确认调用面。
- 便签"便签摘要"确认是 DesktopFloatingTaskSummary（主窗计算推送），无独立存储，无需本地化。
- drift 本地库文件为 `smart_assistant.db`（database_config.dart:5），非 `database/data.db`（后者是 Supabase 空占位）。
