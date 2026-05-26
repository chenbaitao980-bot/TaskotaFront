# 设计：task-detail-enhancements

## 需求澄清依据
1.归档当前变更 2.首页任务详情增加编辑按钮 3.任务详情新增附件上传+AI拆分子任务 4.任务详情支持勾选完成 5.首页支持按项目筛选任务

## 当前状态
实施前根据现有代码、规范和失败信号确认；不得跳过最小读取计划。

## 方案
执行本次最小改动，不扩大范围。

## 业务规则处理
- 原 Requirement / Scenario：无
- 本次处理方式：MODIFIED

## 回归测试方案
- 用例文件：`regression-tests/cases/task-detail-enhancements.md`
- 批量测试接口 / 命令：实施时填写最小可复现命令或手工验证记录。

## 回滚方案
删除 `openspec/changes/task-detail-enhancements/` 目录。
