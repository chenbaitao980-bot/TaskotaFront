# 设计：task-progress-calculation

## 需求澄清依据
目标：为任务模块增加进度概念；范围：任务/项目进度计算、检查项和子任务状态变更后的刷新、必要 UI 展示与测试；非目标：不重做任务模块交互、不改无关样式或数据结构；验收：无子任务按检查项/自身状态计算，有子任务递归纳入子任务、自身检查项与无检查项任务，项目按任务完成度汇总。

## 当前状态
实施前根据现有代码、规范和失败信号确认；不得跳过最小读取计划。

## 方案
执行本次最小改动，不扩大范围。

## 业务规则处理
- 原 Requirement / Scenario：无
- 本次处理方式：MODIFIED

## 回归测试方案
- 用例文件：`regression-tests/cases/task-progress-calculation.md`
- 批量测试接口 / 命令：实施时填写最小可复现命令或手工验证记录。

## 回滚方案
删除 `openspec/changes/task-progress-calculation/` 目录。
