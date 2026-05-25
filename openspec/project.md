# Project Baseline

## 项目目标
SmartAssistant

## 技术栈
Flutter

## GitNexus
- GitNexus 别名：`smart_assistant`
- 约束：GitNexus query/impact/detect-changes SHALL 优先绑定当前项目图谱。

## 全局约束
- 编码约束：TBD
- 提交约束：不主动 git commit / push，等待用户明确指令
- 变更约束：代码修改必须先走 OpenSpec change
- 查询约束：编辑已有 symbol 前优先 GitNexus impact
- 复盘约束：修 bug 前先查 openspec/bugfixspecs，归档时沉淀高频 bug 根因
- 回归约束：每个 change 维护最小回归测试用例，归档前必须批量测试通过

## 非目标
- 不做用户未要求的功能
- 不主动引入重型依赖
