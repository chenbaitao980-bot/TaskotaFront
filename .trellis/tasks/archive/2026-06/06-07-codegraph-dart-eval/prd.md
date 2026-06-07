# codegraph + graphify Flutter Dart 工作流规范

## Goal

在本 Flutter/Dart 项目中正式集成 codegraph + graphify，建立节约 token、精准定位代码结构的完整工作流规范，覆盖修 bug 和开发新功能两种场景。

## 评估结论（已验证）

### 工具能力对比

| 工具 | Dart 支持 | 核心价值 | 局限 |
|------|-----------|---------|------|
| **codegraph** | ✅ 优秀（364类/1799方法/行号/签名） | 精确结构查询：callers/impact/context | 需定期 init 同步 |
| **graphify** | ⚠️ 文件级（重建后136节点/14边） | 概念搜索：找哪些文件和 X 相关 | Dart import 边提取弱，不适合调用链 |

### 图谱现状

- codegraph: `.codegraph/codegraph.db`，122 Dart 文件，3666 节点，7846 边
- graphify: `.graphify/`，重建后 136 节点（99% Dart），14 边，122 社区
- `.graphifyignore` 已配置，排除 node_modules/.trellis/.claude/docs 等噪音

### Token 节约估算

| 场景 | 直接 Read 文件 | codegraph_context | 节约比 |
|------|--------------|-------------------|--------|
| 理解一个功能模块（5文件） | ~2500 token | ~300-500 token | ~5-8x |
| 找调用方（callers） | Read 全库 grep | 精准返回列表 | ~20x+ |
| 改前 impact 分析 | 经验判断 | 量化影响半径 | 质变（防漏改） |

## 完整工作流规范

### 场景 A：修 Bug / 追调用链

```
1. graphify query "<症状描述>"
   → 找候选文件范围（概念级）

2. codegraph_callers("<怀疑的符号>")
   → 追调用方，确认影响范围

3. codegraph_impact("<符号>")
   → 查改动影响半径（HIGH/CRITICAL 先告知用户）

4. 只 Read codegraph 返回的 file:line 片段
   → 不全量扫描文件

5. 改动 → 验证调用方不需要同步修改
```

### 场景 B：开发新功能

```
1. graphify query "<功能概念>"
   → 定位相关文件集合（找参考模式）

2. codegraph_context("<任务描述>")
   → 拉取精准上下文，替代读多个文件

3. 理解现有模式 → 实现新功能

4. 实现后：codegraph_impact("<新符号>")
   → 确认不意外影响其他层
```

### 降级方案（codegraph 返回空/不准时）

- codegraph_context 无结果 → 用 graphify query 缩小范围后再 Grep
- codegraph_callers 缺失 → Grep pattern 搜索（不跳过，只是换工具）

### 索引维护

- 新文件加入后：`npx @colbymchenry/codegraph init`（全量重建，< 30秒）
- graphify 增量更新：`npx @nodesify/graphify update .`
- `.graphifyignore` 提交到 git，团队共享（已配置）

## Requirements

- [x] graphify 重建，排除噪音（5177→136 节点，Dart 占 99%）
- [x] `.graphifyignore` 配置到位
- [ ] 工作流规范写入记忆（本文档通过 trellis-update-spec 固化）
- [ ] codegraph MCP 工具实际调用验证（需 MCP 连接状态确认）

## Acceptance Criteria

- [ ] graphify query "notification scheduling" 返回正确 Dart 文件（已验证 ✅）
- [ ] codegraph_context 查询实际节约 token（待 MCP 连接后验证）
- [ ] 工作流铁律记录在 codegraph-workflow 记忆中

## Decision (ADR-lite)

**Context**: 项目 134 个 Dart 文件，需要在修 bug/新功能时减少盲目 Read 文件的 token 消耗  
**Decision**: codegraph 做结构主力（callers/impact/context），graphify 做概念预筛（query），两工具互补不替代  
**Consequences**: 需维护两份索引；graphify 对 Dart 边支持弱，调用链查询必须用 codegraph 而非 graphify

## Out of Scope

- 替换 Grep/Glob（仍作为 codegraph 降级方案）
- graphify 边提取 Dart import 的修复（上游工具限制）
- 自动 git hook 触发重建（当前手动维护够用）

## Technical Notes

- graphify v0.2.2（全局安装），不支持 `--ignore` flag，通过 `.graphifyignore` 控制
- codegraph `@colbymchenry/codegraph` 版本待确认
- 重建命令：删 `.graphify/` 目录后 `npx @nodesify/graphify run .`
