# 任务：checklist-obsidian-link

## 实施
- [ ] 1. 数据库 migration 新增 obsidian_uri 字段 (app_database.dart, schema 2→3)
- [ ] 2. 重新生成 Drift 代码 (dart run build_runner build)
- [ ] 3. ChecklistRepository 新增 setObsidianUri() 方法，create() 增加 obsidianUri 参数
- [ ] 4. BLoC 新增 SetChecklistItemObsidianUri event + 处理逻辑
- [ ] 5. 新建 obsidian_service.dart (跨平台 URI 启动)
- [ ] 6. checklist_section.dart: 长按菜单（编辑/关联/删除）+ 链接图标 + 关联对话框

## 验证
- [x] 数据库升级 v2→v3 不丢数据，已有检查项 obsidianUri 为 null
- [x] 检查项可绑定 Obsidian URI（两种方式：结构化输入 + 粘贴完整 URI）
- [x] 点击链接图标跳转到 Obsidian 对应文档
- [x] 支持 vault + file + heading 三级定位
- [x] 可移除关联，图标消失
- [x] URI 格式校验：非 obsidian:// 开头的拒绝保存
- [x] Obsidian 未安装时 Toast 提示
- [x] 无链接的检查项 UI 保持现状不变
