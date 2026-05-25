# 设计文档：AI 计划时间线改造与 WBS 思维导图

## 受影响文件清单

| 文件路径 | 改动类型 | 说明 |
|---|---|---|
| `lib/presentation/pages/ai_chat/ai_chat_page.dart` | 修改+新增 | 时间约束修复、标签改名、时间线UI改造、新增WBS组件 |
| `lib/presentation/pages/ai_chat/ai_chat_page.dart` | 修改 | AI Prompt 指令段（system prompt 后处理） |

## 一、时间约束解析修复

### 现状问题

```dart
DateTime _defaultPlanStart(int index) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 9).add(Duration(days: index));
}
```

- 从今天开始逐日递增 `index` 天，不考虑"本周"边界
- 如果计划有 12 行，第 12 行 = 5月25 + 12天 = 6月6日

### 修复方案

**方案：添加"本周边界"约束**

```dart
DateTime _defaultPlanStart(int index) {
  final now = DateTime.now();
  // 计算本周末（周日）
  final daysUntilSunday = DateTime.sunday - now.weekday; // DateTime.sunday = 7
  final thisSunday = DateTime(now.year, now.month, now.day + daysUntilSunday);
  final candidate = DateTime(now.year, now.month, now.day, 9).add(Duration(days: index));
  return candidate.isAfter(thisSunday) ? thisSunday : candidate;
}
```

但这种方式太粗暴。更合理的方案：

**1. Prompt 指令增强**

在 AI 生成计划前的 system prompt 中增加：
```
- 日期约束：如果用户指定了"这周"、"本周"，所有日期必须在本周日之前（含周日）。
- 当前日期：2026年5月25日（周一），本周日为5月31日。
- 时间约束：用户说"早上"指 6:00-12:00，"下午"指 12:00-18:00，"晚上"指 18:00-24:00。
```

**2. 后处理边界校验**

```dart
DateTime _defaultPlanStart(int index) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 9).add(Duration(days: index));
}

// 新增：截断到本周日
DateTime _clampToThisWeek(DateTime date) {
  final now = DateTime.now();
  final daysUntilSunday = DateTime.sunday - now.weekday; // sunday=7, weekday mon=1
  final lastDay = DateTime(now.year, now.month, now.day + daysUntilSunday, 23, 59);
  return date.isAfter(lastDay) ? lastDay : date;
}
```

**3. `_weekdayIndex` 锚定修复**

当前代码将星期索引加到今天的日期上，这是对的——"周日" index=6, today(Mon 5/25) + 6 = 5/31(周日)。但问题在于 `_defaultPlanStart` 中的 `index` 参数可能导致超出本周。

### 关键改动点

1. 所有解析出来的 `DateTime` 在经过 `_clampToThisWeek` 后处理
2. Prompt 中加入显式日期约束

## 二、标签改名

### 改动点

`ai_chat_page.dart` 第 1086 行：

```
'思维导图' → '时间线'
```

同时修改相关的语义变量名（可选）：

```
_buildPlanFlow → _buildTimeline
_buildScreenshotPlanFlow → _buildTimelineView
```

## 三、时间线 UI 改造

### 现状

`_buildScreenshotPlanFlow` 使用 `Wrap` + 横向箭头连接，每个节点是一个彩色卡片。现有问题是：
- 节点较多时换行后顺序混乱（从左到右折行后从上到下）
- 尺寸较大，不够紧凑

### 改造方案

改为**紧凑横向时间轴**，保留横向布局优化尺寸和顺序：

```
时间线
┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐
│05-25 │→│05-26 │→│05-27 │→│05-28 │→ ...
│09:00 │  │09:00 │  │09:00 │  │09:00 │
│基础体 │  │球感训│  │战术训│  │恢复训│
│能训练 │  │练    │  │练    │  │练    │
└──────┘  └──────┘  └──────┘  └──────┘
```

设计要素：
- **横向布局**：单行横向排列，保留 `SingleChildScrollView` 水平滚动
- **紧凑尺寸**：每个节点宽度从 252px 降到 160px，高度从 78px 降到 ~56px
- **排序保障**：在渲染前对 `rows` 按 `row.start` 升序排列
- **时间格式**：顶部显示 `MM-dd` 日期行 + 下一行显示 `HH:mm` 时间，均用小号字体
- **内容缩略**：节点只显示标题（1行），不显示副标题，滚动时查看全部
- **箭头**：保留箭头连接符，缩小尺寸（24px → 16px）
- **颜色**：保留彩色背景区分不同阶段，但背景色淡化为当前 50% 透明度

```dart
Widget _buildTimelineView(List<_PlanRow> rows) {
  // 1. 按 start 排序
  final sorted = List<_PlanRow>.from(rows)
    ..sort((a, b) => a.start.compareTo(b.start));
  
  // 2. 横向紧凑时间轴
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          _timelineCard(row: sorted[i]),
          if (i < sorted.length - 1) const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.textHint),
        ],
      ],
    ),
  );
}
```

每个节点尺寸：160px 宽 × 56px 高，内边距 8px，字体 12-13px。

## 四、WBS 任务分解思维导图

### 设计

在"一键分配任务"按钮下方新增"任务分解"区域。

**数据来源**：复用已有的 `_PlanRow` 列表，按 `stage` 分组构建树形结构。

**渲染结构**：

```
任务分解（WBS）
┌────────────────────────────────────┐
│ 📋 训练计划                         │
│  ├─ 基础体能训练 (05-25)           │
│  │  ├─ 跑步热身                    │
│  │  ├─ 核心激活                    │
│  │  └─ 拉伸放松                    │
│  ├─ 球感训练 (05-26)               │
│  │  ├─ 带球练习                    │
│  │  └─ 传球练习                    │
│  └─ 战术训练 (05-27)               │
│     ├─ 分组对抗                    │
│     └─ 位置跑位                    │
└────────────────────────────────────┘
```

**实现**：
```dart
Widget _buildWBSMindMap(List<_PlanRow> rows) {
  // 按 stage 分组
  final grouped = <String, List<_PlanRow>>{};
  for (final row in rows) {
    grouped.putIfAbsent(row.stage, () => []).add(row);
  }
  
  // 渲染树状结构
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 根节点：训练计划
      _wbsRootNode('📋 训练计划'),
      ...grouped.entries.map((entry) => _wbsStageNode(entry.key, entry.value)),
    ],
  );
}
```

交互：
- 默认展开第一层（阶段级）
- 用户可点击展开/收起子任务
- 节点带复选框（可选，后续迭代）

## 五、计划表时间行格式优化

### 现状

计划表的每行中，"开始"和"结束"是分开的标签，各占一行：

```
┌──────────┐
│ 开始     │
│ 05-25    │
│ 07:00    │
├──────────┤
│ 结束     │
│ 05-25    │
│ 07:30    │
└──────────┘
```

### 改造方案

合并到同一行，紧凑展示：

```
┌──────────────────────┐
│ 05-25 07:00 ~ 07:30  │
└──────────────────────┘
```

具体改动：
- 查找 `_editablePlanTableRow` 或 `_buildPlanTable` 中渲染"开始"和"结束"标签的代码
- 将两个独立的日期时间 Widget 合并为一个，拼接为 `MM-dd HH:mm ~ HH:mm` 格式
- 如果起止日期不同，显示为 `MM-dd HH:mm ~ MM-dd HH:mm`
- 仍保持可编辑（点击后弹出时间选择器）

## 六、UI 布局变更

改造后的计划区域布局：

```
[计划表 - 可编辑]
[一键分配任务] [按钮]
[时间线] ← 原来叫"思维导图"
[任务分解（WBS）] ← 新增
[查看原始计划]
```
