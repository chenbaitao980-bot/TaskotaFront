# 任务：task-management-redesign

## 阶段1：数据层
- [ ] 1.1 添加 drift 及相关依赖到 pubspec.yaml
- [ ] 1.2 创建 AppDatabase（drift Database，含 projects/tasks/checklist_items 三张表）
- [ ] 1.3 创建 ProjectRepository（CRUD）
- [ ] 1.4 创建 TaskRepository（CRUD + 筛选/排序）
- [ ] 1.5 创建 ChecklistRepository（CRUD）

## 阶段2：任务管理 UI
- [ ] 2.1 创建新版 TaskBloc（blocs/task_new/）
- [ ] 2.2 创建 TasksPage + ProjectSidebar（左侧 Drawer 含快捷筛选和项目列表）
- [ ] 2.3 创建 TaskListView + TaskCard（含左滑完成/删除操作）
- [ ] 2.4 创建 TaskCreateSheet（创建任务 BottomSheet）
- [ ] 2.5 创建 TaskEditPage（编辑任务全屏页）
- [ ] 2.6 创建 TaskDetailPage + ChecklistSection + TaskInfoSection

## 阶段3：导航集成
- [ ] 3.1 修改 HomePage 底部导航 4→5 项，加入「任务」Tab
- [ ] 3.2 在 main.dart 中初始化 drift 数据库和注入新 TaskBloc

## 验证
- [x] V1. 项目创建/编辑/删除全流程测试
- [x] V2. 任务创建/编辑/删除/完成全流程测试
- [x] V3. 检查项添加/编辑/删除/勾选全流程测试
- [x] V4. 底部导航任务Tab正常显示和切换（4 Tab 切换不受影响）
- [x] V5. 旧系统正常运行（日历、AI聊天、旧任务页面不受影响）
- [x] V6. drift 数据库读写正常，数据持久化可靠
