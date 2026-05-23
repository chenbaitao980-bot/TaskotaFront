# 设计：smart-butler-core-intelligence

基于 [产品设计文档 三、产品核心设计](E:/黑曜石/obsidian/智能小管家.md) 实现 P1 四块核心智能。

## 一、用户画像构建（F7）

### 显式信息（Onboarding）
首次启动时弹出3步问卷：
1. **基本信息**：姓名、职业 → 存储到 `UserProfile`
2. **目标**：最多3个长期目标 → 存储到 `UserProfile.primaryGoals`
3. **能力水平**：每个目标的当前水平（零基础/初级/中级/高级）

### 隐式推断（自动学习）
`_loadStats` 中统计并存储：
- `energyPattern`：按时间段统计已完成任务（morning/afternoon/evening）
- `completionRate`：已完成任务 / 总任务
- `preferredWorkHours`：根据已完成日程的时间段推断

### 数据流
```
OnboardingPage(问卷) → UserProfile → LocalStorageService.saveProfile()
_loadStats(自动) → UserProfile.implicitProfile → 实时更新 completionRate
```

## 二、个性化任务拆解（F8）

### AI Prompt 注入用户画像
在 `ai_service.dart` system prompt 中新增：

```
## 用户画像
- 姓名：{name}
- 目标：{goals}
- 当前水平：{levels}
- 任务完成率：{rate}
- 偏好工作时间：{hours}
根据用户画像调整拆解粒度和建议语气。
```

### 实现方式
- 每次 `chat` 调用时，从 `LocalStorageService` 读取 `UserProfile`
- 拼接到 system prompt 中

## 三、冲突检测与建议（F9）

### 检测逻辑
创建日程时检查：
```dart
bool _hasConflict(DateTime start, DateTime end) {
  final existing = _storage.getSchedules(startDate: start, endDate: end);
  return existing.any((s) => s.startTime.isBefore(end) && s.endTime.isAfter(start));
}
```

### AI 决策建议
检测到冲突后，调用 AI 生成3个选项：
- `ai_service.detectConflict(newSchedule, conflictingSchedule, userProfile)`
- 返回结构化 JSON：`{options: [{action, risk, benefit}, ...]}`

### UI 交互
弹出 `ConflictDialog`，展示3个选项按钮，每个附收益/风险标签：
```
[② 婚礼前早起背单词]
  收益：不耽误学习进度
  风险：早起影响白天精力
```

## 四、动态提醒策略（F10）

### 紧迫性评分
```dart
double _urgencyScore(Schedule s) {
  final timeUntilStart = s.startTime.difference(DateTime.now()).inMinutes;
  final priorityWeight = {'P0': 1.0, 'P1': 0.7, 'P2': 0.4, 'P3': 0.1}[s.priority] ?? 0.4;
  final timeFactor = timeUntilStart <= 60 ? 1.0 : (120.0 / timeUntilStart).clamp(0.1, 1.0);
  return (priorityWeight * 0.6 + timeFactor * 0.4).clamp(0.0, 1.0);
}
```

### 提醒规则
| 紧迫性 | 提前提醒 | 方式 |
|--------|---------|------|
| >0.8 | 2倍任务时长 | 推送 |
| >0.5 | 1倍任务时长 | 推送 |
| >0.3 | 15-30分钟 | 推送 |
| <0.3 | 15分钟 | 推送 |

### 实现
- `NotificationService.scheduleDynamicReminder(schedule)` 替换原有固定15分钟

## 业务规则处理
- 主 spec `AI任务拆解` 下新增 Scenario：个性化拆解
- `日历视图` 下新增 Scenario：新建时冲突检测
- 不与现有功能冲突

## 历史 BugFixSpecs 命中
- 命中文件：无

## 回滚方案
移除 Onboarding 流程和画像注入逻辑，恢复固定15分钟提醒。
