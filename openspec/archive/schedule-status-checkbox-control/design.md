# 设计：schedule-status-checkbox-control

## 当前状态
Schedule 模型没有 status 字段，无法标记完成状态。HomePage 和 CalendarPage 的日程列表只显示文本信息，无可勾选的交互控件。

## 方案

### 1. Schedule 模型添加 status 字段
```dart
@Default('in_progress') String status,  // 可选: in_progress, completed
```
- freezed 模型需要运行 `dart run build_runner build --delete-conflicting-outputs` 重新生成
- LocalStorageService 的 JSON 序列化自动兼容（新字段有默认值）

### 2. 首页日程列表添加 checkbox
`_buildRecentSchedules` 中每个日程卡片 ListTile 的 leading 改为：
```dart
leading: Checkbox(
  value: s.status == 'completed',
  onChanged: (checked) {
    final newStatus = checked == true ? 'completed' : 'in_progress';
    storage.updateSchedule(s.copyWith(status: newStatus));
    onRefresh();
  },
),
```

### 3. 日历周视图添加 checkbox
`_buildDraggableEventBlock` 中事件块添加 checkbox 在标题前：
```dart
Checkbox(
  value: event.status == 'completed',
  onChanged: ...同上...
  visualDensity: VisualDensity.compact,
),
```

### 4. 日历事件列表添加 checkbox
`_buildEventList` 中每个 ListTile 的 leading 改为 checkbox。

### 5. 打包规范写入 spec
追加到 project-baseline spec 和 project.md：
```markdown
### Requirement: Windows 桌面打包
每次代码变更后打包时，SHALL 执行 flutter clean 后全量 build，确保无增量编译缓存残留。

#### Scenario: 交付 Windows 包
- WHEN 用户要求打包 Windows 桌面版
- THEN AI SHALL 先执行 flutter clean
- AND 执行 flutter build windows --release
- AND 复制产物到 release 目录并打包为 ZIP
```

## 业务规则处理
- 原 Scenario：编辑/删除日程（spec 只覆盖编辑和删除）
- 本次处理方式：MODIFIED，追加状态控制 Scenario
- 非 ADDED：属于 Calendar view 能力扩展

## 历史 BugFixSpecs 命中
- 命中文件：无

## 数据生命周期
写入链：用户点击 checkbox → onChanged 回调 → schedule.copyWith(status: newStatus) → _storage.updateSchedule() → SharedPreferences JSON 持久化
读取链：页面 build → _storage.getSchedules() → JSON 反序列化 → status 字段填充 → checkbox value 绑定

## 回归测试方案
- 用例文件：`regression-tests/cases/schedule-status-checkbox-control.md`
- 手动验证：勾选完成→checkbox checked→撤销→checkbox unchecked

## 回滚方案
移除 status 字段，删除 checkbox 组件，还原 spec。
