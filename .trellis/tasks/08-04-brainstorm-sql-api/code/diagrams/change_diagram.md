# 变更设计图：断连本地化 + 便签定位修复（PRD 全量，Stage 1-4）

> 类型：workflow + architecture（改前 vs 改后）。触发来源：云端墓碑级联软删 + V3 便签定位失效 + 弱网同步卡顿。
> 影响检查：`gitnexus impact(restoreFullWindow, upstream)` = 0 调用者/LOW；`detect_changes` = 12 文件/3 执行流/medium，无 HIGH/CRITICAL。

## 改前链路（红色 = 被移除的破坏/低效路径）

```mermaid
flowchart TB
    subgraph CLOUD["☁️ 云端 Supabase（弱网卡 + 数据破坏）"]
        TOMB["projects 16 墓碑<br/>deleted=1"]
        RT["6 条 Realtime"]
        PGRST["push PGRST204 失败"]
    end
    subgraph APP["📱 应用（改前）"]
        UI["UI"] -->|回前台/登录/变更| SYNC["同步层 forcePullAll/syncAll<br/>subscribe×5/startRealtime"]
        SYNC -->|拉墓碑| CASCADE["级联软删本地任务 ❌"]
        CASCADE --> GONE["任务消失"]
        SYNC -->|弱网悬挂| LAG["回前台卡顿"]
        NOTE["便签点击"] --> RESTORE["restoreFullWindow<br/>不重建/不触发消费 ❌"]
        RESTORE --> NOLOCATE["不定位"]
        QUAD["四象限点击"] --> HSCROLL["横向滚动不可见 ❌"]
    end
```

## 改后链路（绿色 = 保留路径）

```mermaid
flowchart TB
    subgraph LOCAL["💾 本地 drift 唯一真源 + LocalOnlyCloudSyncGateway"]
        DB["AppDatabase (7 表)<br/>WAL 已启用"]
        GW["CloudSyncGateway 接口<br/>LocalOnly: 同步 no-op + 快照导出/导入桥"]
        BACKEND["DataBackendConfig = local"]
    end
    subgraph APP2["📱 应用（改后）"]
        UI2["UI/Bloc/Repository"] --> DB
        DB --> TASKS["任务存活 ✅"]
        NOTE2["便签点击"] -->|notifyListeners + 监听| FOCUS["消费 pendingFocusTaskId<br/>_selectTask 选中+滚动 ✅"]
        QUAD2["四象限点击"] -->|ensureVisible 竖向回滚| FOCUS
        CREATE2["日历创建"] -->|bloc focusTaskId| FOCUS
        LOAD2["首页加载"] -->|自动选 nearest 切 day/hour| FOCUS
        GW -.->|将来阿里云| ALIYUN["AliyunCloudSyncGateway"]
    end
```

## 停用点清单（4 阶段）

| # | 位置 | 停用/新增 |
|---|---|---|
| 1 止血 | `_upsertProjectFromRow` 级联块 | 注释级联软删 |
| 2 架构 | `lib/data/sync/` 3 文件 + connection_native WAL | 新增 gateway 接口/LocalOnly/DataBackend + WAL |
| 3 断连 | 6 sync_service ×22 守卫、home_page 日程 3 处 + `_initStorage`、task_bloc 2 处 | 云操作 no-op、日程本地、Realtime 全停 |
| 4 便签 | controller `restoreFullWindow` + home_page 监听/`_processBlocFocusTask`/`_selectTaskFromQuadrant`/A3 兜底 | A1-A5 定位链路打通 |

## 关键保护（⚠️）
- 重启云同步前必须给级联加"任务 updatedAt > 墓碑 updated_at"保护，否则仍误删墓碑项目下新建任务。
- 日程暂存 SharedPreferences（已 100% 本地）；drift 表迁移 + TaskBreakdown 双轨收敛为后续专项。
