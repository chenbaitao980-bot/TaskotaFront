# 设计：task-auto-save-edit

## 需求澄清依据
目标：任务详情页和子任务编辑页改为自动保存；范围：任务编辑相关 UI 与保存触发逻辑；非目标：不改项目/日程/数据库结构；验收：编辑后无需保存按钮，返回后改动保留。

## 方案
执行本次最小改动，不扩大范围。

## 回归测试
- 用例文件：`regression-tests/cases/task-auto-save-edit.md`
- 运行记录：`regression-tests/runs/task-auto-save-edit.json`
