# Delta: calendar-weekday-date-overlap

## 与主规范关系
Fix / Enhancement

## 变更类型
MODIFIED

## 新规则
不改变业务规则；仅执行本次最小修复或调整。

## 具体变更
### 文件：`lib/presentation/pages/calendar/calendar_page.dart`
- **`_buildTableCalendar()`** 方法增加：
  - `daysOfWeekHeight: 28`，提升星期行高度至 28px
  - `DaysOfWeekStyle.dowTextFormatter` 单字符格式输出星期标签
  - `CalendarStyle.tablePadding: EdgeInsets.only(top: 4)` 增加星期行与网格间距

## 约束
- 不修改设计结构，仅添加配置参数
- 保持 Week 视图和 Month 视图使用同一份配置
