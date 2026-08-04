# 变更设计图：第五次性能修复（P0-A/B/C + P1-A~F）

> 类型：sequence/workflow（改前 vs 改后时序）。触发来源：便签白屏数秒 + 启动慢/点两下 + 加载卡慢 + 模块无反应（flog 证据，RC-A~D）。
> 影响检查：`gitnexus impact` — `_onAppResume` LOW / `cancelReminderForSchedule`(IO) LOW / `_buildPages` LOW；`_loadData`/`_selectTask` HIGH、`SupabaseService` CRITICAL（多引用点，本次为内部并行+防御守卫+构造降级，不改公共签名）。

## 改前链路（红色 = 被移除的阻塞/风暴路径）

```mermaid
sequenceDiagram
    participant NOTE as 📌 便签窗(第二引擎)
    participant CTRL as DesktopFloatingTabController
    participant RES as AppLifecycle onResume
    participant NS as NotificationService
    participant UI as 首页 _HomeContent
    NOTE->>CTRL: 点击便签
    CTRL->>CTRL: setAlwaysOnTop 抢焦点
    CTRL->>RES: onResume 触发(反复)
    loop 每次 onResume
        RES->>NS: _rescheduleTaskReminders ❌
        Note over NS: 每任务 24 次平台通道取消<br/>(base+offset1+21 repeat 循环)<br/>115 任务 ≈ 6.4s
        RES->>UI: _debounceLoadTasks(6-12s 成对)
    end
    UI->>UI: 首帧 5 页 IndexedStack 全构建 ❌
    UI->>UI: 三查询串行 projects→groups→tasks ❌
    UI->>UI: postFrame 闭包 _selectTask<br/>State 已 dispose → setState → ❌ UncaughtError
    main->>main: Supabase.initialize 无超时<br/>refresh-token 网络 POST 悬挂 ❌
```

## 改后链路（绿色 = 保留/新增路径）

```mermaid
sequenceDiagram
    participant NOTE as 📌 便签窗(第二引擎)
    participant CTRL as DesktopFloatingTabController
    participant RES as AppLifecycle onResume
    participant UI as 首页 _HomeContent
    participant DB as drift 本地库
    participant MAIN as main.dart
    NOTE->>CTRL: 点击便签
    CTRL->>CTRL: setAlwaysOnTop 抢焦点
    CTRL-->>UI: _onDesktopTabNotify 直连监听 ✅
    UI->>UI: _processFloatingTabFocusTask 秒级定位<br/>(内存遍历 + 仓库直查兜底 + _selectTask 选中+滚动)
    Note over RES: 30s 节流 (_lastResumeLoadTime)<br/>仅 _debounceLoadTasks，无重调度 ✅
    RES-->>UI: resume 不触发 _rescheduleTaskReminders ✅
    UI->>DB: 三查询 Future.wait 并行 ✅
    UI->>UI: tab2/3/4 懒构建(_LazyIndexedPage)<br/>首帧仅 tab0/1 构建 ✅
    UI->>UI: mounted 守卫 → dispose 后 setState 直接 return ✅
    MAIN->>MAIN: _initSupabase .timeout(2s) ✅<br/>SupabaseService _client→getter + currentUser 容错 ✅
    MAIN->>CTRL: postFrame restoreFullWindow ✅<br/>(show→TOPMOST→focus 冷启动置前台)
    NS-->>NS: cancelReminderForSchedule cancelRepeats:false<br/>每任务 24→2 次通道调用 ✅
```

## 关键保护（⚠️）
- **L4 实机验证阻塞待办**：无头环境不能证明「秒级跳转/启动变快/窗口直弹/模块响应」，必须重建后逐条实测（见 change_report 待办）。
- **P1-F 取舍**：批量重调度跳过 repeat 取消——已删除/停用任务若曾开 repeat 可能残留一条旧 repeat 通知；同 id 重建覆盖主路径，极端删除场景可接受。
- **已知 HIGH/CRITICAL impact**：`_loadData`/`_selectTask`/`SupabaseService` 引用面广，本轮改动为内部并行 + 防御守卫 + 构造降级，均不改变公共签名与 happy-path 行为；若实机回归需优先复测便签定位（A1-A5 链路）。
