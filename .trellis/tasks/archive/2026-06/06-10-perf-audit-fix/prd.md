# brainstorm: 性能体验弱点排查与修复

## Goal

系统性找出 Taskora 应用中所有可能影响用户性能体验的弱点（卡顿、慢启动、掉帧、I/O 阻塞等），并逐项修复，让用户可感知的流畅度提升。

## What I already know

* 用户原话：「找出所有可能影响用户性能体验的弱点修复掉」—— 范围广、目标是"用户可感知的性能体验"
* 项目为 Flutter 应用（Taskora），多端：Android、Windows 桌面、Web（Vercel 部署）
* 关键大文件：`lib/presentation/pages/tasks/tasks_page.dart`（1591 行）、`lib/presentation/blocs/task_new/task_bloc.dart`（1526 行），且两者当前有未提交改动
* `.trellis/spec/frontend/quality-guidelines.md` 已沉淀性能铁律：VLB 替代 setState、Canvas 分层渲染、build() 中 O(n²) 必须提取 Set、SharedPreferences 写入防抖
* 数据层：Drift 数据库（Web 用 WASM）、Supabase 远端同步

## Assumptions (temporary)

* 用户没有具体指出某个卡顿场景，需要全面审计而非单点修复
* "性能体验"以用户可感知为准：启动时间、列表滚动帧率、页面切换、输入响应、同步阻塞 UI

## Open Questions

（已全部解决）

## Decisions

* **平台范围：全平台（Android + Windows + Web）一起审计**，部分修复需平台分支处理
* **无单点痛点，做无差别全面体检**：启动、列表/滚动、交互响应均纳入审计面
* **修复深度：一次全修到位**，包括重构级优化（拆分大 build、分层渲染改造等），按数据流追踪铁律逐项验证防回归
* **审计面 = UI 渲染层 + 数据层（Drift/Supabase）+ 启动链路**；性能埋点/自测页排除
* **在途归档改动已单独提交（a76d769）**，性能修复从干净工作区开始
* **用户明确授权：审计清单无需拍板，直接连续修复到底，最后一次性汇报**（本任务内豁免逐项选择题确认）

## Requirements

* 全面审计 presentation 层（pages/blocs/widgets）的渲染性能反模式：setState 大面积重建、build() 中 O(n²)、未防抖 I/O、缺 const、ListView 未懒加载、不必要的全量 BlocBuilder 等
* 审计数据层：Drift 查询是否在主 isolate 跑重计算、Supabase 同步是否阻塞 UI、是否有 N+1 查询
* 审计启动链路：main() 初始化顺序、首屏前的同步等待、可延迟初始化项
* 每项弱点：定位（文件:行号）→ 影响评估 → 数据流追踪 → 修复 → flutter analyze 验证

## Acceptance Criteria

* [x] 产出完整弱点清单（文件:行号 + 类别 + 影响评估），记录在任务目录 research/ 下
* [x] 清单内 H/M 级弱点修复完成（H1-H7 全部修复；M1-M10 全部修复；W1-W12 高/中影响全部修复；启动链 W1-W15 高/中影响全部修复）
* [x] flutter analyze 通过，修改文件 0 lint 错误，无回归
* [ ] L 级弱点（L1-L6）与 W14-W17 为远期优化，暂不阻塞发布

## Definition of Done (team quality bar)

* Lint / analyze 通过
* 修复模式符合 quality-guidelines.md 既有铁律
* 新发现的通用模式回写 spec（trellis-update-spec）
* 同步网页版部署（git push 触发 Vercel CI）

## Out of Scope (explicit)

* （待与用户确认）

## Spec Conflicts

* 无冲突 —— 需求与 quality-guidelines.md 性能规范方向一致

## Technical Notes

* 已查阅：.trellis/spec/frontend/quality-guidelines.md（性能铁律）、index.md
* 现有未提交改动涉及 tasks_page.dart / task_bloc.dart，审计时需注意不覆盖
