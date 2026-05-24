# Delta: fix-ai-options-fallback

## 与主规范关系
Bug Against Spec

## 命中的主规范
- Capability: `smart-butler`
- Requirement: `TBD`
- Scenario: `TBD`

## 变更类型
不改spec只修代码

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | smart-butler |
| 关系判断 | Bug Against Spec |
| 其他 active change 撞车 | 无 |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 否；已有Req覆盖 |
| 归档完整性 | ✅ |

## 原规则
AI拆分对话时，_generateSuggestions使用关键词匹配（按每天/小时/分钟→水平→希望/目标的顺序），导致包含多个维度关键词的AI回复匹配到错误的选项分支

## 新规则
完全依赖AI生成的[OPTIONS:]结构化标记作为选项来源；移除_generateSuggestions内容关键词匹配，强制AI每轮提问均输出[OPTIONS:]；无[OPTIONS:]时不显示任何选项卡，用户直接输入回答

## 改动明细
- 文件：`TBD`
- 位置：第 N 行
- 改前：AI拆分对话时，_generateSuggestions使用关键词匹配（按每天/小时/分钟→水平→希望/目标的顺序），导致包含多个维度关键词的AI回复匹配到错误的选项分支
- 改后：完全依赖AI生成的[OPTIONS:]结构化标记作为选项来源；移除_generateSuggestions内容关键词匹配，强制AI每轮提问均输出[OPTIONS:]；无[OPTIONS:]时不显示任何选项卡，用户直接输入回答
