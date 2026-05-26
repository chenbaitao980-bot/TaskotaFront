# 设计方案：task-ui-enhancements

## 1. SnackBar 轻量化 + 点按关闭

**改前**：SnackBar 默认黑色大条，停留时间长，遮挡操作按钮。

**改后**：
- SnackBar 高度缩小，内边距 8px（原 14px）
- 添加 `onTap` → 点任意位置立即关闭
- 使用 `SnackBarBehavior.floating` 浮动模式，不遮挡底部按钮
- 自动消失时间缩短至 1.5s

**涉及文件**：`home_page.dart`、`task_detail_page.dart` 等所有调用 `ScaffoldMessenger.showSnackBar` 的地方

## 2. 任务条快速操作优先级/日期

**改前**：任务条仅展示信息，点击进入详情页才能改优先级和日期。

**改后**：在首页任务详情区（`_buildTaskDetail`）的日期行和优先级行添加行内编辑：
- **优先级**：四个小圆点（P0红/P1橙/P2蓝/P3灰），点击直接修改
- **日期**：点击日期文本弹出日历选择器，选择后直接更新
- 修改后通过 `taskRepository.update()` 直接持久化

**涉及文件**：`home_page.dart`（`_buildTaskDetail` 方法）

## 3. 四象限复合评分算法

### 计分公式

```
urgency = 截止时间距离今天的天数（负值=已逾期）
priority_score = priority 映射值（P0=5, P1=3, P2=1, P3=0）

复合得分 = priority_score × 2 + urgency_penalty

urgency_penalty:
  - 已逾期（urgency < 0）→ +10（最高紧急）
  - 0-3天 → +5
  - 4-7天 → +2
  - 8-30天 → +0
  - >30天 → -2（不紧急）
```

### 象限分类

| 象限 | 条件 | 颜色 |
|------|------|------|
| Q1 紧急重要 | 已逾期 + 优先级≥P1 或 urgency≤3 + 优先级≥P1 | 红 |
| Q2 重要不紧急 | urgency>3 + 优先级≥P1 | 蓝 |
| Q3 紧急不重要 | 已逾期 + 优先级<P1 或 urgency≤3 + 优先级<P1 | 橙 |
| Q4 不重要不紧急 | 其余 | 灰 |

**限制**：每个象限最多展示 5 个任务，按复合得分降序排列。

**涉及文件**：`home_page.dart`（`_buildQuadrantChart` 方法）
