# init-project

## 为什么
基于E:\黑曜石\obsidian\智能小管家.md中的产品方案，搭建AI智能日程管家Flutter项目骨架。该产品定位为"不是记录日程的工具，而是帮你拆解目标、消除不确定性、修正人生路径的AI秘书管家"。

## 影响面
- 新建项目，无现有代码影响
- 需要配置Flutter + Supabase + DeepSeek API技术栈
- 影响目录：smart_assistant/下所有文件

## 改动范围
- pubspec.yaml - 添加依赖（flutter_bloc, supabase_flutter, table_calendar等）
- lib/main.dart - 应用入口，初始化Supabase和Bloc
- lib/core/ - 主题、路由、常量配置
- lib/models/ - 数据模型（Schedule, TaskBreakdown, UserProfile等）
- lib/services/ - Supabase服务封装
- lib/presentation/ - 页面和状态管理目录结构
- assets/ - 资源目录

## 验收
- [ ] 项目能正常编译运行
- [ ] 目录结构符合Clean Architecture分层
- [ ] 包含完整的主题配置和路由配置
- [ ] 包含数据模型定义
- [ ] `gitnexus detect-changes` 无异常范围外变更
