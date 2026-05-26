# checklist-obsidian-link

## 需求澄清摘要
任务详情中的检查项支持关联本地 Obsidian 文档。用户可为每个检查项设置一个 `obsidian://` URI 链接，点击后直接打开 Obsidian 并定位到指定文档，还支持定位到文档中的特定标题（需 Advanced URI 插件）。

## 为什么
用户在任务执行过程中频繁需要参考 Obsidian 知识库中的笔记（设计文档、方案记录、会议纪要等）。目前需要手动打开 Obsidian → 搜索文档 → 滚动到对应位置，上下文切换成本高、打断工作流。将文档引用直接附着在检查项上，可实现"看到检查项 → 一键跳转参考资料"的零摩擦工作流。

## 影响面

### 数据层
- `ChecklistItems` 表新增 `obsidian_uri` TEXT NULLABLE 字段
- Schema version: 2 → 3，Migration 仅 `addColumn`，不涉及数据迁移
- 已有数据兼容（新字段 nullable，默认 null）

### 业务层
- `ChecklistRepository` 新增 `setObsidianUri()` 方法
- BLoC 新增 `SetChecklistItemObsidianUri` event
- 不改变现有检查项的创建/编辑/删除行为

### UI 层
- `checklist_section.dart`: 已关联的检查项显示链接图标，长按弹出菜单
- 新增关联对话框 Dialog
- 新增 `obsidian_service.dart` 服务文件

### 依赖
- 不新增第三方依赖，使用 `dart:io` Process 启动 Obsidian

## 业务规范关系
- 命中的主 spec: 无（新增能力）
- 关系判断: New Capability
- 推荐动作: MODIFIED

## 验收
- [ ] 检查项可绑定 Obsidian URI（支持粘贴完整 URI 或结构化输入）
- [ ] 点击检查项链接图标跳转到 Obsidian 对应文档
- [ ] 支持 vault + file + heading 三级定位（heading 需 Advanced URI 插件）
- [ ] 可移除已有关联
- [ ] URI 格式校验（必须以 obsidian:// 开头）
- [ ] Obsidian 未安装时有友好错误提示
- [ ] 数据库升级不丢数据
