# 设计：检查项关联 Obsidian 文档

## 1. 需求概述

任务详情中的检查项（ChecklistItem）支持关联本地 Obsidian 文档，点击后跳转到 Obsidian 并定位到指定文档和标题。典型场景：检查项 "实现用户登录" → 关联设计笔记 `系统设计/登录模块设计.md`，点击直接打开。

## 2. 当前架构

### 2.1 数据层
- **ORM**: Drift (SQLite)，表定义在 `lib/data/database/app_database.dart`
- `ChecklistItems` 表字段: `id, taskId, title, status, sortOrder, completedTime, createdAt, updatedAt`
- 当前 **没有** 链接/URI 相关字段
- `ChecklistItem` 数据类由 Drift 自动生成: `lib/data/database/app_database.g.dart` (~L1488)

### 2.2 仓储层
- `lib/data/repositories/checklist_repository.dart` — 标准 CRUD，无链接相关方法

### 2.3 状态管理层 (BLoC)
- Event: `lib/presentation/blocs/task_new/task_event.dart`
  - `AddChecklistItem(taskId, title)` — title 仅字符串
  - `UpdateChecklistItem(id, title)` — 同上
- State: `lib/presentation/blocs/task_new/task_state.dart`
  - `TaskNewLoaded.checklistItems`: `Map<String, List<ChecklistItem>>`

### 2.4 UI 层
- 页面: `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
- 组件: `lib/presentation/pages/tasks/task_detail/widgets/checklist_section.dart`
  - 每个检查项: 复选框 + 标题 + 删除按钮
  - 双击编辑标题
  - 当前 **无** 链接图标/跳转交互

### 2.5 依赖
- 项目 `pubspec.yaml` 中 **无** `url_launcher` 依赖
- Windows 平台需考虑自定义协议启动方式

## 3. Obsidian URI 协议分析

### 3.1 标准 Obsidian URI
```
obsidian://open?vault=<VaultName>&file=<path/to/note.md>
```
- 打开指定 Vault（必须已打开或 `Obsidian.exe` 可自动打开）
- 文件路径相对于 Vault 根目录
- 文件路径中的空格和特殊字符需 URL 编码

### 3.2 定位到标题 (Advanced URI 插件)
```
obsidian://adv-uri?vault=<VaultName>&filepath=<path/to/note.md>&heading=<Heading>
```
- 需要安装 [Advanced URI](https://github.com/Vinzent03/obsidian-advanced-uri) 社区插件
- 支持定位到 `# heading`、`## heading` 等任意级别标题
- heading 参数需 URL 编码

### 3.3 Windows 平台启动方式
| 方式 | 说明 |
|------|------|
| `url_launcher` 包 | 跨平台但不稳定支持自定义协议 |
| `Process.run('cmd', ['/c', 'start', '', 'obsidian://...'])` | Windows 原生，最可靠 |
| `Process.run('start', ['obsidian://...'])` | 仅 shell 环境 |

**结论**: Windows 桌面应用推荐使用 `dart:io` 的 `Process.run` 方式启动，避免额外依赖。

### 3.4 存储方案设计

**方案 A: 存储完整 URI 字符串**
```
obsidian_uri TEXT: "obsidian://open?vault=MyVault&file=notes/design.md"
```
- 优点: 灵活，支持任意 Obsidian URI 格式（包括插件扩展）
- 缺点: URI 可能很长，vault 改名后 URI 失效

**方案 B: 存储结构化字段**
```
vault TEXT, file_path TEXT, heading TEXT (可选)
```
- 优点: 结构化可查询，URI 构建灵活
- 缺点: 需要多个字段，迁移复杂

**选择方案 A** — 存储单一 `obsidian_uri` 字段。理由：
1. 最小改动原则：只需一个字段
2. 灵活性：支持 Obsidian 生态中任意 URI 扩展
3. 用户可粘贴 Obsidian 中右键 "Copy Obsidian URL" 得到的完整 URI

## 4. 详细方案

### 4.1 数据库迁移

`app_database.dart` 中 `ChecklistItems` 表新增字段：

```dart
class ChecklistItems extends Table {
  // ... 现有字段 ...
  TextColumn? get obsidianUri => text().nullable()();  // 新增
}
```

SchemaVersion 从 `2` → `3`，Migration 添加：

```dart
onUpgrade: (m, from, to) async {
  if (from < 2) {
    await m.addColumn(tasks, tasks.parentId);
  }
  if (from < 3) {
    await m.addColumn(checklistItems, checklistItems.obsidianUri);
  }
}
```

**重新生成**: 运行 `dart run build_runner build` 重新生成 `app_database.g.dart`，`ChecklistItem` 类将自动包含 `obsidianUri` 属性。

### 4.2 Repository 扩展

`checklist_repository.dart` 修改：

1. `create()` 方法增加 `obsidianUri` 可选参数
2. 新增 `updateObsidianUri(String id, String? obsidianUri)` 方法
3. 新增 `setObsidianUri(String id, String? uri)` 方法（便捷方法）

```dart
Future<ChecklistItem> create({
  required String taskId,
  required String title,
  String? obsidianUri,  // 新增
}) async { ... }

Future<void> setObsidianUri(String id, String? uri) async {
  await (_db.update(_db.checklistItems)..where((c) => c.id.equals(id))).write(
    ChecklistItemsCompanion(
      obsidianUri: uri != null ? Value(uri) : Value(null),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ),
  );
}
```

### 4.3 BLoC 层

**新增 Event**:
```dart
class SetChecklistItemObsidianUri extends TaskEvent {
  final String id;
  final String taskId;
  final String? obsidianUri;
}
```

**新增 State 处理**: BLoC 中处理对应 Event，调用 repository 更新后重新加载 checklist。

### 4.4 UI 层改造

#### 4.4.1 关联入口（两种方式）

**方式 1: 双击编辑对话框扩展**
- 现有双击编辑标题的 Dialog 中增加一个 "Obsidian 链接" 输入框
- 用户粘贴完整的 `obsidian://open?vault=...&file=...` URI
- 或者粘贴 `vault/文件路径` 的简化格式，由应用自动构建 URI

**方式 2: 右键菜单 / 长按菜单**
- 长按检查项弹出菜单: "编辑标题"、"关联 Obsidian"、"删除"
- 选择 "关联 Obsidian" 后弹出输入 Dialog

**推荐**: 方式 2（长按菜单）+ 也支持在编辑 Dialog 中设置。避免双击冲突。

#### 4.4.2 关联对话框设计

```
┌─────────────────────────────────────┐
│  关联 Obsidian 文档                  │
├─────────────────────────────────────┤
│                                     │
│  📁 Vault 名称:  [MyKnowledge    ]  │
│  📄 文件路径:    [设计/登录方案.md ]  │
│  📌 标题(可选):  [## 实现方案     ]  │
│                                     │
│  或直接粘贴 Obsidian URI:            │
│  [obsidian://open?vault=..._________]│
│                                     │
│          [取消]       [确认]        │
└─────────────────────────────────────┘
```

交互逻辑：
1. 默认显示结构化输入（Vault + 路径 + 标题），方便手填
2. 底部 URI 输入框支持粘贴 Obsidian 的 "Copy Obsidian URL"
3. 系统自动从粘贴的 URI 中解析出 Vault/路径/标题，回填到结构化字段
4. 最终存储为完整 URI 字符串

#### 4.4.3 检查项 UI

已关联 Obsidian 的检查项在标题右侧显示 📎 图标：

```
┌──────────────────────────────────────┐
│  ○ 实现用户登录  📎                   │  ← 有链接
│  ● 编写单元测试                       │  ← 无链接（已完成）
│  ○ 部署到测试环境  📎                  │  ← 有链接
└──────────────────────────────────────┘
```

- 📎 图标点击 → 调用 `Process.run` 打开 `obsidian://open?...` URI
- 无链接的检查项不显示图标，保持现状
- 图标用 `Icons.open_in_new` 或自定义 `Icons.link`

### 4.5 URI 启动服务

新增独立服务 `lib/services/obsidian_service.dart`:

```dart
import 'dart:io';

class ObsidianService {
  /// 打开 Obsidian URI
  /// 返回 true 表示启动成功
  static Future<bool> openUri(String uri) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          'cmd',
          ['/c', 'start', '', uri],
        );
        return result.exitCode == 0;
      } else if (Platform.isMacOS) {
        await Process.run('open', [uri]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [uri]);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
```

### 4.6 URI 构建辅助

为了方便用户，提供快捷构建方法（在 Repository 或 Service 中）：

```dart
/// 从结构化字段构建 Obsidian URI
static String buildObsidianUri({
  required String vault,
  required String filePath,
  String? heading,
}) {
  final buffer = StringBuffer('obsidian://open?vault=');
  buffer.write(Uri.encodeComponent(vault));
  buffer.write('&file=');
  buffer.write(Uri.encodeComponent(filePath));
  if (heading != null && heading.isNotEmpty) {
    // 使用 adv-uri 参数（需要 Advanced URI 插件）
    buffer.clear();
    buffer.write('obsidian://adv-uri?vault=');
    buffer.write(Uri.encodeComponent(vault));
    buffer.write('&filepath=');
    buffer.write(Uri.encodeComponent(filePath));
    buffer.write('&heading=');
    buffer.write(Uri.encodeComponent(heading));
  }
  return buffer.toString();
}
```

## 5. 文件改动清单

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `lib/data/database/app_database.dart` | 修改 | 新增 `obsidianUri` 字段，schema version 3 |
| `lib/data/database/app_database.g.dart` | 重新生成 | build_runner 自动更新 |
| `lib/data/repositories/checklist_repository.dart` | 修改 | create 增加参数，新增 setObsidianUri |
| `lib/presentation/blocs/task_new/task_event.dart` | 修改 | 新增 SetChecklistItemObsidianUri event |
| `lib/presentation/blocs/task_new/task_bloc.dart` | 修改 | 处理新 event |
| `lib/presentation/pages/tasks/task_detail/widgets/checklist_section.dart` | 修改 | 增加链接图标、长按菜单、关联对话框 |
| `lib/services/obsidian_service.dart` | 新增 | Obsidian URI 启动服务 |

## 6. 边界情况与风险

| 场景 | 处理方式 |
|------|----------|
| Obsidian 未安装 | 启动失败时 Toast 提示 "Obsidian 未安装或无法打开" |
| Vault 不存在/未打开 | 标准 URI 会自动打开 Obsidian 并切换 Vault；如果 Vault 名错误则 Obsidian 提示错误 |
| 文件路径不存在 | Obsidian 会提示文件不存在，可选择创建 |
| Advanced URI 插件未安装 | 定位到标题功能失效，仅打开文件；首次使用时提示安装插件 |
| URI 格式错误 | 保存前做格式校验：必须以 `obsidian://` 开头 |
| 特殊字符 (空格/中文) | 使用 `Uri.encodeComponent` 编码 |
| 用户删除关联 | 长按菜单提供 "移除关联" 选项，将 obsidianUri 设为 null |

## 7. 扩展考虑（本期不做）

- **文件浏览器**: 直接浏览 Vault 目录选择文件（需要读取本地文件系统权限）
- **双向同步**: 在 Obsidian 中完成检查项后自动勾选（需要 Obsidian 插件配合）
- **批量关联**: 从 Obsidian 笔记批量生成检查项
- **笔记预览**: 点击前预览笔记摘要
- **Vault 配置**: 在设置中配置默认 Vault，简化后续关联操作

## 8. 测试要点

- [ ] 新建检查项时可设置 Obsidian 链接
- [ ] 已有检查项可通过长按菜单关联 Obsidian
- [ ] 点击链接图标成功打开 Obsidian
- [ ] 定位到指定文档
- [ ] 定位到指定标题（需 Advanced URI 插件）
- [ ] 移除关联后图标消失
- [ ] 无效 URI 保存时格式校验提示
- [ ] Obsidian 未安装时的错误提示
- [ ] 数据库升级从 v2 → v3 不丢数据
