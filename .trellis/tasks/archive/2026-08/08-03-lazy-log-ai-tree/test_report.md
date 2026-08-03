# 测试报告 — 懒人日志 AI 思考控制 + 审核页父任务树状选择

## 一、概述

- **测试任务**: `/trellis-test` 懒人日志 AI 思考控制（需求1）+ 审核页父任务树状选择（需求2）
- **分支**: deploy-branch  **HEAD**: a4d8a7f
- **运行时间**: 2026-08-03
- **总测试数（用例级）**: 46 | **通过**: 46 | **失败**: 0 | **错误**: 0 | **跳过**: 0
- **其中**: 历史回归测试数 7 | 本次新增测试数 14（边界 8 + 审核页门控 6）
- **涉及文件**:
  - 变更文件: `lib/models/assistant/assistant_models.dart`、`lib/presentation/pages/assistant/assistant_page.dart`、`lib/presentation/pages/home/home_page.dart`、`lib/presentation/pages/home/lazy_log_creation_dialog.dart`、`lib/presentation/pages/home/lazy_log_draft_review_sheet.dart`、`lib/presentation/widgets/task_tree_picker_sheet.dart`、`lib/services/home_lazy_log_service.dart`、`test/home_lazy_log_service_test.dart`、`test/task_tree_picker_sheet_test.dart`
  - 爆炸半径文件: 上述 lib 源文件 + `test/lazy_log_draft_repository_test.dart`（引用审核页模型）
- **运行时长**: 约 45 分钟（含 R-G-R 破坏性验证多轮编译）

## 二、爆炸范围覆盖完整性

| 符号 | 风险 | 已有测试 | 状态 |
|------|------|---------|------|
| AssistantModelConfig.reasoningEffort | 中 | service 1 + boundary 3 | 完整覆盖 |
| AssistantModelConfig.copyWith | 中 | service（持久化链路） | 完整覆盖 |
| AssistantModelConfig.toJson | 中 | service（持久化） | 完整覆盖 |
| AssistantModelConfig.fromJson | 中 | service（默认 auto） | 完整覆盖 |
| HomeLazyLogService.structure | 中 | service 7 + boundary 8 + 回归 2 | 完整覆盖 |
| HomeLazyLogService._thinkingParams | 中 | service 7 + boundary 8 | 完整覆盖 |
| HomeLazyLogService._omitTemperature | 低 | service 2 + boundary 4 | 完整覆盖 |
| LazyLogParentOption | 中 | 树 11 + 审核页 6 | 完整覆盖 |
| TaskTreePickerSheet | 中 | 树 11（D1-D7+搜索+空态+chevron） | 完整覆盖 |
| _ParentTaskButton | 中 | 审核页门控 6 | 完整覆盖 |
| _ProjectDropdown.onChanged | 低 | 审核页切项目清失效 | 完整覆盖 |
| _openPicker | 中 | 审核页哨兵消费 3 分支 | 完整覆盖 |

**覆盖率门禁**: ✅ 通过（12/12 = 100%，需 ≥90%）

**无未覆盖符号**。

## 二（续）爆炸半径历史回归映射

| 受影响符号 | 所在文件 | 回归到的历史 Fix | 回归测试文件 |
|-----------|---------|-----------------|------------|
| LazyLogResult.parentTitle | lazy_log_models.dart | 3237d44（父任务上下文创建） | test_regr_lazy_log_parent.dart |
| LazyLogResult.projectHint/projectGroupHint | lazy_log_models.dart | 0d55b30（项目按 group hints 路由） | test_regr_lazy_log_parent.dart |
| HomeLazyLogService.structure | home_lazy_log_service.dart | 23d8cb6（空输入边界） | test_regr_lazy_log_parent.dart |

**无历史回归覆盖的符号**: ⚠️ 无（爆炸半径内 3 个历史 fix 均已生成回归用例）

## 三、变更测试明细

### 变更点 1：AI 思考控制（需求1）
- **变更内容**: `_thinkingParams`（home_lazy_log_service.dart:93）按思考等级+模型前缀分发思考控制参数；`_omitTemperature`（:112）OpenAI 推理模型省略 temperature；`AssistantModelConfig.reasoningEffort` 字段+序列化（assistant_models.dart:11,49,67,76）；配置弹窗思考等级下拉（assistant_page.dart:697）
- **改前行为**: AI 请求体无思考控制参数，模型默认思考模式开启，消耗大、延迟高
- **改后行为**: `off` 按厂商分发原生关闭（glm/deepseek→thinking.disabled、qwen→enable_thinking:false、kimi→reasoning_effort:low、o1/o3/gpt-5→none）；effort 非 auto 时发送 reasoning_effort；推理模型省略 temperature 防 400
- **分支条件**: effort 空/auto→不发参数；effort=off→按模型分发；effort=low/high→发送对应值
- **架构图**: [任务变更总览](diagrams/fix-overview-lazy-log-ai-tree.html)

### 变更点 2：父任务树状选择（需求2）
- **变更内容**: `LazyLogParentOption` 新增 projectId/parentId（lazy_log_creation_dialog.dart:20-31）；`_ParentTaskButton` 门控（review_sheet:552-575）；`_openPicker` 消费契约（:578-601）；`TaskTreePickerSheet` 新组件（点选不关+完成按钮+默认收缩+一键展开+哨兵）
- **改前行为**: 父任务为扁平列表，未选项目也可选，点选即关闭弹层
- **改后行为**: 未选项目→按钮禁用提示"先选项目"；树形层级展示；点选不关窗口、底部"完成"提交、X/点外关闭不保存；再点已选节点→clearSelection 哨兵→取消选择
- **分支条件**: _openPicker 三分支（null忽略/clearSelection清空/节点选中）；_ProjectDropdown.onChanged 切项目清失效父任务
- **架构图**: [任务变更总览](diagrams/fix-overview-lazy-log-ai-tree.html)

## 四、新生成测试清单

| 测试文件 | 测试用例 | 预期值 | 实际值 | 判定 |
|---------|---------|-------|-------|------|
| test_thinking_params_boundary.dart | effort 大写 OFF 等价 off | thinking.disabled | thinking.disabled | 一致 |
| test_thinking_params_boundary.dart | effort 混合大小写 Low | reasoning_effort low | reasoning_effort low | 一致 |
| test_thinking_params_boundary.dart | effort 两侧空白被 trim | enable_thinking false | enable_thinking false | 一致 |
| test_thinking_params_boundary.dart | effort 仅空白不发参数 | 无 thinking/effort | 无 thinking/effort | 一致 |
| test_thinking_params_boundary.dart | gpt-5 off 省略 temperature | 无 temperature + effort none | 无 temperature + effort none | 一致 |
| test_thinking_params_boundary.dart | o3-mini 省略 temperature | 无 temperature | 无 temperature | 一致 |
| test_thinking_params_boundary.dart | o1 high 发 effort 省略 temperature | 无 temperature + high | 无 temperature + high | 一致 |
| test_thinking_params_boundary.dart | 非推理模型保留 temperature | 有 temperature | 有 temperature | 一致 |
| test_review_sheet_parent_gate.dart | 未选项目→按钮禁用"先选项目" | onPressed null | onPressed null | 一致 |
| test_review_sheet_parent_gate.dart | 已选项目→"选择父任务"可点 | onPressed 非 null | onPressed 非 null | 一致 |
| test_review_sheet_parent_gate.dart | 已选父任务→显示标题 | 子任务A1 | 子任务A1 | 一致 |
| test_review_sheet_parent_gate.dart | 树选中节点+完成→写 parentTaskId | A1 | A1 | 一致 |
| test_review_sheet_parent_gate.dart | 再点已选+完成→哨兵清父任务 | parentTaskId null | parentTaskId null | 一致 |
| test_review_sheet_parent_gate.dart | 切项目→失效父任务清除 | projectId p2 + parentTaskId null | projectId p2 + parentTaskId null | 一致 |

## 五、历史回归测试清单

| Fix Commit | 原 Bug | 回归测试文件 | 预期值 | 实际值 | 判定 | 状态 |
|-----------|--------|------------|-------|-------|------|------|
| 3237d44 | 父任务上下文丢失 | test_regr_lazy_log_parent.dart | parentTitle 正确解析 | parentTitle 正确解析 | 一致 | 通过 |
| 3237d44 | parentTitle 缺省异常 | 同上 | 默认空字符串 | 默认空字符串 | 一致 | 通过 |
| 0d55b30 | 项目路由 hints 丢失 | 同上 | projectHint/GroupHint 解析 | 正确解析 | 一致 | 通过 |
| 0d55b30 | hints 缺省异常 | 同上 | 默认空字符串 | 默认空字符串 | 一致 | 通过 |
| 23d8cb6 | 空输入触发 AI 流程 | 同上 | 空结果不发请求 | 空结果不发请求 | 一致 | 通过 |
| 23d8cb6 | 空输入边界（完整配置） | 同上 | 空结果 | 空结果 | 一致 | 通过 |
| 3237d44 | parentTitle 空白 isEmpty 误判 | 同上 | isEmpty true | isEmpty true | 一致 | 通过 |

## 五·五、行为反转确认

**本轮无行为反转**。历史 fix 与最新行为方向一致（3237d44 父任务上下文、0d55b30 项目路由、23d8cb6 空输入边界均未被反向修改）。

## 六、手动验证建议

| 验证点 | 验证方法 | 预期结果 | 优先级 |
|--------|---------|---------|-------|
| 懒人日志 AI 请求携带思考参数 | 在真实环境打开懒人日志输入日志并整理，用抓包或服务端日志查看请求体 | glm/deepseek 发 thinking.disabled、qwen 发 enable_thinking=false、OpenAI 推理模型不发 temperature | 强制 |
| 审核页父任务树展开收起 | 打开审核页选择一个项目，点父任务按钮打开树，用一键展开/收起按钮切换 | 树能整体展开/收起，点节点仅勾选不关闭窗口 | 强制 |
| 审核页未选项目父任务禁用 | 打开审核页不选项目，看父任务按钮 | 按钮显示"先选项目"且点击无反应 | 建议 |
| 切项目清失效父任务 | 先选项目A并选中其父任务，再切换项目B | 父任务被清除，按钮回到"选择父任务" | 建议 |

## 七、AB 验证（红-绿-红）

| 变更文件 | 变更内容 | A 状态 | B 状态 | A 测试结果 | B 测试结果 | 代码已恢复 |
|---------|---------|--------|--------|-----------|-----------|----------|
| home_lazy_log_service.dart | _thinkingParams 思考参数分发 | 返回空 | 全厂商分发 | FAIL(+3-5) | PASS(+8) | 确认 |
| task_tree_picker_sheet.dart | _confirm 哨兵分发 | pop(node) | pop(node??哨兵) | FAIL(D7+0-1) | PASS(+1) | 确认 |
| assistant_models.dart | fromJson 默认 auto | 'off' | 'auto' | FAIL(+0-1) | PASS(+1) | 确认 |
| lazy_log_draft_review_sheet.dart | 门控 selectable | 去 projectId 条件 | 带 projectId 条件 | FAIL(+0-1) | PASS(+6) | 确认 |
| home_page.dart | 候选全量任务+parentId 透传 | — | — | 代码审查确认 | 代码审查确认 | 确认 |
| assistant_page.dart | 思考等级下拉 | — | — | 代码审查确认 | 代码审查确认 | 确认 |
| lazy_log_creation_dialog.dart | parentId/projectId 字段 | — | — | 代码审查确认 | 代码审查确认 | 确认 |

## 八、自愈修复统计

| 指标 | 值 |
|------|-----|
| 初始失败数 | 10（均为测试代码 bug，非产品代码） |
| 修复轮次 | 3 |
| 总修复次数 | 2（SharedPreferences mock + testWidgets/pump 重构） |
| 最终结果 | 46/46 全部通过 |
| 耗时 | 约 45 分钟（含 R-G-R） |

## 九、Spec 合规审计

| Spec 文件 | 检查规则 | 结论 |
|----------|---------|------|
| component-guidelines.md:202 | 折叠展开用 Set 存展开态 + 条件渲染 | 通过（_expanded Set + _buildTreeRows 沿用） |
| state-management.md | 状态变更走 setState/仓库方法 | 通过（_selectedId 内部 setState + updateDraft 仓库方法） |

## 十、降级记录

| Step | 降级点 | 验证证据（命令输出/退出码） | 兜底产物 | 是否影响完整性 |
|------|--------|--------------------------|---------|--------------|
| Step 1b | gitnexus 无新增/私有符号（TaskTreePickerSheet/_ParentTaskButton） | gitnexus impact 返回 "not found"；已收录符号正常返回 | codegraph + grep 补查 | 不影响（核心符号均经 gitnexus 评估） |
| 无 | archify 架构图 | 实际调用 render-workflow.mjs 成功（node v22.22.2） | archify HTML 图（含 toolbar/aria-label/SVG） | 不影响 |

---

**结论**: 本次懒人日志 AI 思考控制 + 父任务树状选择变更，46/46 测试全部通过，覆盖率门禁 100%，4 个核心文件 R-G-R 破坏性验证通过，历史 3 条 fix 回归测试全绿。无产品代码 bug 遗留。
