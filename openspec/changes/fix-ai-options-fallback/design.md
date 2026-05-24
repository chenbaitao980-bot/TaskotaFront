# 设计：fix-ai-options-fallback

## 当前状态
TBD

## 方案
TBD

## 业务规则处理
- 原 Requirement / Scenario：无
- 本次处理方式：不改spec只修代码

## 历史 BugFixSpecs 命中
- 命中文件：E:\claude\project2\smart_assistant\openspec\bugfixspecs\smart-butler\ai-suggestion-mismatch.md
- 历史根因：关键词匹配方案（_generateSuggestions）使用顺序固定的contains检查，AI回复可能同时包含多个维度的关键词，导致匹配到错误分支。已连续出现2次（bugfix_count=2），关键词匹配方案被证实不可靠
- 本次防重蹈覆辙措施：完全移除内容关键词匹配；所有选项必须来自AI的[OPTIONS:]标记；future变更新增对话问题时必须同步更新system prompt中的[OPTIONS:]示例

## 回归测试方案
- 用例文件：`regression-tests/cases/fix-ai-options-fallback.md`
- 批量测试接口 / 命令：TBD

## 回滚方案
删除 `openspec/changes/fix-ai-options-fallback/` 目录。
