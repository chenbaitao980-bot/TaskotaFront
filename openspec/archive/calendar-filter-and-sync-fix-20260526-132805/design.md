# 设计：calendar-filter-and-sync-fix

## 需求澄清依据
修复日历项目筛选无法切回全部项目(bug1)、日历拖拽时间后切换任务页面时间未同步(bug2)、优化时间线拖拽热区太小及跨日任务不可拖拽(优化1)。范围：calendar_page.dart / home_page.dart，不改bloc只加通知调用。

## 当前状态
实施前根据现有代码、规范和失败信号确认；不得跳过最小读取计划。

## 方案
执行本次最小改动，不扩大范围。

## 业务规则处理
- 原 Requirement / Scenario：无
- 本次处理方式：MODIFIED

## 回归测试方案
- 用例文件：`regression-tests/cases/calendar-filter-and-sync-fix.md`
- 批量测试接口 / 命令：实施时填写最小可复现命令或手工验证记录。

## 回滚方案
删除 `openspec/changes/calendar-filter-and-sync-fix/` 目录。
