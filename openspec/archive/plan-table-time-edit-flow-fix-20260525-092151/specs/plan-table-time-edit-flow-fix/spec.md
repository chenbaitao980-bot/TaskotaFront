# Delta：plan-table-time-edit-flow-fix

## 与主规格关系
本次变更属于 `smart-butler` 能力下的既有行为修改，命中“AI 任务拆解”需求。

## Requirement：AI 任务拆解

### Scenario：计划表展示精确时间
- WHEN AI 助手返回可执行训练计划
- THEN 计划表 SHALL 展示每行的开始时间和结束时间
- AND 时间 SHALL 精确到分钟
- AND 时间 SHALL 可被用户直接修改。

### Scenario：计划流程完整展示
- WHEN AI 助手返回多于 7 个计划节点
- THEN 思维导图或流程图 SHALL 展示全部节点
- AND 界面 SHALL 通过横向滚动或换行保证内容可访问
- AND 不得因为到周日或固定数量限制而截断后续节点。

### Scenario：一键分配标题正确
- WHEN 用户从计划表执行一键分配任务
- THEN 任务标题 SHALL 来自具体训练主题或动作标题
- AND 任务标题 SHALL NOT 使用表头“主题”
- AND 任务说明 SHALL 使用训练内容。

### Scenario：计划表字段可直接编辑
- WHEN 用户查看最终计划表
- THEN 用户 SHALL 能直接修改时间、主题和训练内容
- AND 修改后的值 SHALL 用于后续一键分配任务。
