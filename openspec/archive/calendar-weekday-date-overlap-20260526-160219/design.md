# 设计：calendar-weekday-date-overlap

## 需求澄清依据
修复日历模块 TableCalendar 星期标签与日期数字重叠

## 方案
在 `_buildTableCalendar()` 中增加三个配置项：
1. `daysOfWeekHeight: 28` — 将星期行高度从默认 16 提升至 28，给中文星期标签足够空间
2. `daysOfWeekStyle: DaysOfWeekStyle(dowTextFormatter: ...)` — 用 `dowTextFormatter` 将星期标签格式化为单字符（"一","二","三"），避免双字符横向溢出
3. `calendarStyle.tablePadding: EdgeInsets.only(top: 4)` — 在星期行与日期网格之间添加 4px 间距，杜绝视觉重叠

## 影响面
- 仅修改 `lib/presentation/pages/calendar/calendar_page.dart` 的 `_buildTableCalendar()` 方法
- 无 API/数据/状态变更
- 不影响 `calendar_date_picker.dart` (自定义弹窗)
- 不影响周时间线视图布局

## 回归测试
- 用例文件：`regression-tests/cases/calendar-weekday-date-overlap.md`
- 运行记录：`regression-tests/runs/calendar-weekday-date-overlap.json`
