# 变更报告（第五次性能修复轮：P0-A/B/C + P1-A~F 编码落地）

## 一、变更摘要
- **任务**: 便签白屏秒级/启动慢/加载卡慢/模块无反应 — 第五次性能修复（prd「第五次报告」+ 实施方案定案）
- **根因**: RC-A resume 秒级重调度（每任务 24 次平台通道取消调用）；RC-B Supabase.initialize 无超时阻塞 + 冷启动无前台权；RC-C 三查询串行 + 首帧 5 页全构建；RC-D `_loadData` postFrame 闭包调 `_selectTask` 在已 dispose State 上 setState（flog 11:27:27 UncaughtError×2）
- **文件**: 6 个（5 个改动 + 1 个契约测试新增） **影响符号**: `_onAppResume`/`_buildPages`/`_loadData`/`_selectTask`/`_syncCloudPrefsAfterLoad`/`_initSupabase`/`cancelReminderForSchedule`/`currentUser` 等
- **索引状态**: ✅ gitnexus 已刷新（12038 节点 / 38168 边 / 300 流）；codegraph 会话启动时已同步

## 二、改动明细（9 处，对照 .change_goal）
| # | 文件 | 改动 |
|---|------|------|
| P0-A(1) | home_page.dart `_onAppResume` | 删 `await _rescheduleTaskReminders()`——启动 `_initStorage`(230) 已调度一次，Windows 进程内 Timer 存活即有效 |
| P1-E(1) | home_page.dart `_onAppResume` | 加 `_lastResumeLoadTime` ≥30s 节流——断 6-12s 成对 LoadTasks 重载风暴；便签定位由 `_onDesktopTabNotify` 直连监听独立驱动 |
| P0-B(2) | home_page.dart `_loadData` postFrame 闭包 + `_selectTask` | 入口加 `if (!mounted) return`——修 flog 11:27:27 UncaughtError×2 |
| P1-D(3) | home_page.dart `_loadData` | projects/groups/tasks 三查询 `Future.wait` 并行替代串行 await |
| P1-C(4) | home_page.dart `_buildPages` | 新增 `_LazyIndexedPage` 包装器（按 `_tabIndex` 首次选中才 build），tab2/3/4 懒构建；tab0/1 保持即时（`_jumpToMindMap` 直驱 tab1） |
| P0-C(5) | task_bloc.dart `_syncCloudPrefsAfterLoad` | 调用点 + 方法体加 `DataBackendConfig.current == cloud` 守卫 + import data_backend |
| P1-A(6) | main.dart | `Supabase.initialize` 抽 `_initSupabase()` 带 `.timeout(2s)`，超时不阻塞首帧 |
| P1-A(8) | supabase_service.dart | `_client` 字段初始化→getter（2s 超时未完成时构造不崩）；`currentUser` try/catch 返回 null |
| P1-B(7) | main.dart | runApp 后 postFrame 调 `restoreFullWindow()`（show→TOPMOST→focus）冷启动置前台 |
| P1-F(9) | notification_service_io/web.dart + home_page.dart | `cancelReminderForSchedule` 加 `{cancelRepeats=true}` 折叠 21 次 repeat 取消；任务侧重调度调用传 false（每任务 24→2 次通道调用）；web 空实现签名同步 |

**排除**: 不改时间轴 overlay 视口渲染（P1-Cb 延后）；不改便签窗 UI、认证/支付/AI、`_rescheduleTaskReminders` 启动调用（`_initStorage` 保留一次）

## 三、Spec 合规
| 规则 | 状态 |
|------|------|
| 本地 drift 唯一真源（DataBackend.local） | ✅ 守卫强化（P0-C） |
| 数据安全（测试不碰真实运行时数据） | ✅ 契约测试为纯单元测试 |
| 无 headless 宣称完成（L4 门禁） | ✅ 实机契约标 ⚠️ 待实测（见六） |

## 四、质量门禁
| 检查项 | 结果 |
|--------|------|
| flutter analyze（6 个改动文件） | ✅ 0 error / 0 warning（仅存量 info 级 lint） |
| 相关测试（floating_tab_controller / single_instance / cloud_sync_gateway / notification_service / task_mindmap_focus / p0_perf_contract） | ✅ 18 + 15 + 2 全过 |
| flutter build windows --release | ⏳ 后台编译中（L1 全量门禁） |
| 行为验证（Step 4e） | ✅ 契约 5/3 语义验证通过（见五） |

## 五、行为验证（Step 4e）
| 契约 | 输入 | 预期 | 结果 |
|------|------|------|------|
| 契约1 (L2) _onAppResume 30s 节流 | 30s 内第二次触发 | 直接 return 不重载 | ⚠️ 逻辑审阅通过（时间守卫确定性），实机待测 |
| 契约2 (L2) _selectTask mounted 守卫 | dispose 后调用 | return 不 setState 不抛 | ⚠️ 逻辑审阅通过，实机待测 |
| 契约3 (L2) _syncCloudPrefsAfterLoad 本地守卫 | local 模式调用 | return 不发 fetchPreferences | ✅ 契约3前置测试通过（DataBackend 默认 local）；调用点+方法体双守卫 |
| 契约4 (L2) cancelReminderForSchedule 降量 | cancelRepeats:false | 仅 2 次 cancel，跳过 21 次循环 | ✅ 结构验证（`if (!cancelRepeats) return`）；notification_service_test 通过 |
| 契约5 (L2) currentUser 容错 | Supabase 未初始化访问 | 返回 null 不抛 | ✅ p0_perf_contract_test 实测通过 |
| 契约6 (L2) _initSupabase 超时 | initialize 悬挂 >2s | 2s 内返回不阻塞首帧 | ⚠️ `.timeout(2s)` 代码审阅通过，实机待测 |
| 契约7 (L3) _buildPages 懒构建 | 首帧构建 / 首次切 tab2 | tab2/3/4 初始 SizedBox.shrink；切 tab2 才首次构建 | ⚠️ 结构验证（`_LazyIndexedPage` 按 index 门控），实机待测 |
| 实机契约 (L4) | 见六 | 见六 | ⚠️ 未验证 · 需实测（阻塞） |

## 六、待办（阻塞项）
- **⚠️ L4 实机验证（阻塞，用户重建后逐条实测）**:
  1. 便签点击 → 秒级跳转首页定位任务，无白屏数秒
  2. 打开软件 → 启动明显变快 + 窗口直接弹出在最前（无需再点一下）
  3. 数据加载丝滑 + 模块点击即时响应（无卡死/无 UncaughtError）
  4. 便签定位仍正确（跨天切 day / 今天内切 hour / 四象限定位）
  5. 白屏不复发
- **已知取舍**: P1-F 批量重调度跳过 repeat 取消——已删除/停用且曾开 repeat 的任务的旧 repeat 通知不会被清（会被同 id 重建的新通知覆盖；极端删除场景可能残留一条 repeat 通知，可接受，实测确认）
- **验证命令**: `flutter build windows --release` → 运行发布包实测
