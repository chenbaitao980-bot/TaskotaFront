# 收敛懒人日志检查项生成

## Goal

懒人日志生成任务时，`checklist` 必须严格来自用户日志原文中明确写出的步骤、验收点或待检查事项；如果日志里没有写这些内容，就不要生成检查项，避免 AI 发散补充。

## Requirements

* 收紧懒人日志结构化提示词，明确禁止根据“复杂/步骤多”的推断自行生成 checklist。
* 只有用户输入明确列出步骤、验收点、待检查事项、检查清单等内容时，才允许写入 `tasks[].checklist`。
* 未明确写出检查项时，`tasks[].checklist` 必须返回空数组或省略，不能生成泛化检查项。
* 保持现有 `description` 生成、项目路由、周任务时间归一化等行为不变。

## Acceptance Criteria

* [x] 系统提示词包含“只从原文明确检查项生成 checklist”的硬约束。
* [x] 模型返回的普通任务仍可被解析并进入 `tasks`。
* [x] 测试覆盖：没有明确检查项的日志不会被提示词鼓励生成 checklist。
* [x] 现有懒人日志服务测试通过。

## Definition of Done

* 相关 Dart 测试通过。
* `dart format` 已应用到改动文件。
* GitNexus/CodeGraph 影响面已检查。

## Technical Approach

修改 `HomeLazyLogService._systemPrompt` 中 checklist 的字段说明和规则 10，增加规则要求 checklist 必须逐条对应用户原文中的明确事项。补充服务测试，捕获系统提示词并断言不再包含旧的“复杂时填写”发散表述，同时包含新的约束。

## Out of Scope

* 不改懒人日志 UI。
* 不增加后处理过滤器。
* 不改变任务标题、描述、项目路由或时间归一化逻辑。

## Technical Notes

* 主要文件：`lib/services/home_lazy_log_service.dart`
* 覆盖测试：`test/home_lazy_log_service_test.dart`
* CodeGraph 显示 `HomeLazyLogService` 只有首页一处调用，测试文件为 `test/home_lazy_log_service_test.dart`。
