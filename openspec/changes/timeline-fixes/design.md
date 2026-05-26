# 设计：timeline-fixes

## 需求澄清依据
修复时间轴多余红点、完成任务的删除按钮无反应、红点下加标题备注

## 当前状态
实施前根据现有代码、规范和失败信号确认；不得跳过最小读取计划。

## 方案
执行本次最小改动，不扩大范围。

## 业务规则处理
- 原 Requirement / Scenario：无
- 本次处理方式：MODIFIED

## 回归测试方案
- 用例文件：`regression-tests/cases/timeline-fixes.md`
- 批量测试接口 / 命令：实施时填写最小可复现命令或手工验证记录。

## 回滚方案
删除 `openspec/changes/timeline-fixes/` 目录。
