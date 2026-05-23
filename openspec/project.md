# Project Baseline

## 项目目标
AI智能日程管家 — 不是记录日程的工具，而是帮你拆解目标、消除不确定性、修正人生路径的AI秘书管家。

## 技术栈
- 客户端：Flutter 3.x (iOS + Android + Windows Desktop)
- 状态管理：flutter_bloc
- 云端服务：Supabase (PostgreSQL + Auth + Realtime)
- AI模型：DeepSeek V3 (任务拆解)
- 语音识别：speech_to_text (系统原生ASR)
- 日历：table_calendar
- 路由：命名路由 (无第三方路由库依赖)

## 全局约束
- 编码约束：UTF-8
- 提交约束：不主动 git commit / push，等待用户明确指令
- 变更约束：代码修改必须先走 OpenSpec change
- 查询约束：编辑已有 symbol 前优先 GitNexus impact
- 复盘约束：修 bug 前先查 openspec/bugfixspecs，归档时沉淀高频 bug 根因
- 回归约束：每个 change 维护最小回归测试用例，归档前必须批量测试通过
- 打包约束：每次打包 Windows 桌面版必须先 `flutter clean` 全量 rebuild，不得依赖增量编译缓存

## 非目标
- 不做用户未要求的功能
- 不主动引入重型依赖
- 不做移动端专属功能（当前聚焦 Windows Desktop）
