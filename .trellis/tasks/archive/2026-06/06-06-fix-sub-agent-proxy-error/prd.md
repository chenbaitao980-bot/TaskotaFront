# fix: claude sub-agent proxy error prompt

## Goal

修复 Claude Code 在使用 DeepSeek API 代理时频繁提示子 agent 代理错误的问题。

## What I already know

* 全局配置 `C:\Users\Administrator\.claude\settings.json` 使用 DeepSeek API 作为 Anthropic 兼容代理
* `ANTHROPIC_BASE_URL`: `https://api.deepseek.com/anthropic`
* 主模型: `deepseek-v4-pro`（疑似无效模型名）
* 子 agent 模型: `deepseek-chat` via `CLAUDE_CODE_SUBAGENT_MODEL`
* DeepSeek 当前官方有效模型: `deepseek-chat`（V3）和 `deepseek-reasoner`（R1）
* `deepseek-v4-pro` 不是 DeepSeek 的官方模型 ID，可能导致 API 调用失败

## Assumptions (temporary)

* 错误根因是 `deepseek-v4-pro` 模型名无效，DeepSeek API 返回 404 或 model_not_found 错误
* 或者子 agent 代理端点 `/anthropic` 对某些工具/功能兼容性有问题

## Open Questions

* 用户看到的具体错误信息是什么？（例如 model not found / connection error / tool use not supported）

## Requirements (evolving)

* 修复全局 settings.json 中无效的模型名
* 确保子 agent 调用可以正常完成

## Acceptance Criteria (evolving)

* [ ] 子 agent 不再报代理错误
* [ ] Claude Code 正常完成需要子 agent 的任务（如 trellis-research）

## Definition of Done

* 修改后在实际任务中验证子 agent 正常工作
* 无新的报错提示

## Out of Scope

* 切换到其他 AI 提供商
* 修改单个项目的 settings.json

## Technical Notes

* 配置文件: `C:\Users\Administrator\.claude\settings.json`
* DeepSeek 官方文档模型列表: deepseek-chat / deepseek-reasoner
* telemetry 显示实际调用模型为 deepseek-chat（子 agent 侧）
