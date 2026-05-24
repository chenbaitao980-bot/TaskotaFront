# 设计：claude-ui-and-progressive-ai

## Claude Code UI 风格调研成果

### 色彩系统（来自 Claude 官方品牌 + VS Code 主题参考）

| 用途 | 色名 | Hex | 使用位置 |
|------|------|-----|---------|
| 主强调色 | Crail | `#C15F3C` | FAB、选中态、链接、按钮 |
| 暗色背景 | - | `#1A1A2E` | Scaffold 背景 |
| 表面/卡片 | - | `#1E1E2E` | Card、AppBar |
| 输入区背景 | - | `#252536` | 输入框填充色 |
| 主文本 | - | `#EAEAEA` | 标题、正文 |
| 次文本 | Cloudy | `#B1ADA1` | 副标题、时间 |
| 边框/分割 | - | `#2D2D3F` | Divider、Card border |

### 设计语言关键词
- **暗色主导**：全应用深色背景（非纯黑，带微妙蓝紫调）
- **暖橙点缀**：C15F3C 作为唯一活跃色，克制使用
- **大圆角**：Card 12px、Button 8px
- **低对比度柔和**：Card 背景与 Scaffold 背景接近但可区分
- **无强阴影**：用背景色差区分层级而非 elevation
- **简洁克制**：减少渐变色、减少装饰性元素

## 方案

### 一、配色系统改造（app_theme.dart）

```dart
// Claude 配色
static const Color claudeOrange = Color(0xFFC15F3C);
static const Color claudeOrangeLight = Color(0xFFD47A5A);
static const Color bgPrimary = Color(0xFF1A1A2E);
static const Color bgCard = Color(0xFF1E1E2E);
static const Color bgInput = Color(0xFF252536);
static const Color textPrimary = Color(0xFFEAEAEA);
static const Color textSecondary = Color(0xFFB1ADA1);
static const Color borderSubtle = Color(0xFF2D2D3F);
```

- **强制暗色主题**：`main.dart` 设置 `themeMode: ThemeMode.dark`
- **圆角统一**：Card `BorderRadius.circular(12)`，Button `8`
- **BottomNav**：背景 `bgCard`，选中 `claudeOrange`
- **AppBar**：背景透明无 elevation

### 二、首页改造（home_page.dart）
- 今日概览卡片：背景 `bgCard` + 1px `borderSubtle` 边框替代渐变
- 统计数字用 `claudeOrange`
- 快捷操作卡片用 `OutlinedButton` 样式
- 日程列表卡片圆角 8px，border 替代阴影

### 三、日历改造（calendar_page.dart）
- SegmentedButton 选中色 `claudeOrange`
- TableCalendar todayDecoration/selectedDecoration 用 `claudeOrange`
- 事件块配色维度保持（红/橙/绿/蓝），降低饱和度

### 四、AI 聊天渐进式对话重构（ai_chat_page.dart + ai_service.dart）

**核心思路**：AI 引导式多轮对话，每一步只问最关键的问题。

#### 交互流程
```
用户输入目标 → AI 确认理解 + 问第1个关键问题（如"你目前什么水平？"）
              → 用户回答
              → AI 问第2个问题（如"每周可用多少时间？"）
              → 用户回答
              → AI 问第3个问题（如"希望什么时间节点完成？"）
              → 用户回答
              → AI 展示完整拆解计划（含确认/修改按钮）
```

#### Prompt 策略（ai_service.dart）
1. **第一轮**：识别用户目标，提取关键信息，**只问 1 个最关键的缺失信息**
2. **后续轮**：根据已有信息 + 新回答，**再问 1 个关键问题**
3. **最后一轮**：生成完整三层拆解（战略→战术→执行），以结构化卡片展示
4. **强制约束 Prompt**：`每次只问一个最关键的缺失信息，不要一次性列出所有问题`

#### 消息气泡样式
- 用户消息：`bgInput` 背景，右对齐，暖橙色左边框
- AI 消息：`bgCard` 背景，左对齐
- Markdown 渲染支持（标题/列表/粗体）

### 五、FAB 可见性控制（home_page.dart）

**当前问题**：HomePage 外 Scaffold 的 floatingActionButton 被所有子页面共享，导致「+新建」按钮在日历/AI助手/我的Tab 依然可见；且按钮文字「新建」占用空间，应只保留图标。

**方案**：FAB 改为条件渲染 + 纯图标模式。

```dart
floatingActionButton: _currentIndex == 0
    ? FloatingActionButton(
        onPressed: _createSchedule,
        child: const Icon(Icons.add),
      )
    : null,
```

### 六、AI 快捷选项区域（ai_chat_page.dart）

**当前问题**：AI 助手页面只有纯文本框输入，用户无引导、不知道该说什么。

**方案 A（已实现）**：对话开始前，消息列表上方显示快捷选项 Chip。
**方案 B（新增）**：AI 发出包含问题的消息后，自动在该消息气泡下方显示建议回复按钮。

当 AI 消息以 `？` 或 `?` 结尾时，根据关键词生成建议回复：

| AI 关键词 | 建议回复按钮 |
|---|---|
| 水平/基础 | "零基础"、"会一点点"、"有基础" |
| 时间/每天/每周 | "每天30分钟"、"每天1小时"、"每天2小时" |
| 其他提问 | "好的继续"、"让我想想"、"换个方向" |

实现方式：`_callAI` 中解析 response 文本 → 生成 `suggestions` 数组存入消息 → `_buildBubble` 渲染 Chip 按钮。

**Bug 修复：关键词匹配顺序导致选项不匹配**
- **根因**：`_generateSuggestions` 先检查「水平/基础」再检查「时间」。当 AI 回复"好的，你零基础开始，那每天能抽出多少时间练习吉他？"同时包含"基础"+"每天"时，前者先命中
- **修复**：交换检查顺序，时间关键字优先于水平

### 七、首页概览精简（home_page.dart）

**当前问题**：今日概览显示「待办/进行中/已完成」三条统计。
**方案**：移除 `_buildTodayOverview` 中的 `_buildStatItem('进行中', ...)` 行，将 spaceAround 调整为均分。

### 八、统计按今日过滤（home_page.dart）

**当前问题**：`_loadStats()` 未传日期参数，统计了全部数据。
- `_storage.getTasks()` → 全量任务，应按 `createdAt` 过滤今日
- `_storage.getSchedules()` → 按 `startDate/endDate` 过滤
- `_inProgressCount` 已移除，不需要

**方案**：
```dart
void _loadStats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final tasks = _storage.getTasks();
    final schedules = _storage.getSchedules(startDate: todayStart, endDate: todayEnd);
    setState(() {
      _pendingCount =
          tasks.where((t) => t.status == 'pending' && _isToday(t.createdAt)).length
          + schedules.length;
      _completedCount =
          tasks.where((t) => t.status == 'completed' && _isToday(t.createdAt)).length;
    });
}
```

辅助方法 `_isToday`：判断 `DateTime` 是否为今天。

## 业务规则处理
- 原 Scenario：AI 先询问必要信息 → AI 输出三层拆解
- 本次 MODIFIED：AI 分步引导提问（每次只问 1 个）+ 快捷选项降低输入门槛
- FAB 可见性：仅首页可见，其他 Tab 不展示
- 首页概览：去掉「进行中」，仅保留待办和已完成
- 统计范围：待办和已完成限定为今日数据
- 不影响其他功能

## 历史 BugFixSpecs 命中
- 命中文件：无

## 回滚方案
还原 `app_theme.dart` 为紫色系，还原 `ai_chat_page.dart` 为一轮式对话，移除 FAB 条件渲染。
