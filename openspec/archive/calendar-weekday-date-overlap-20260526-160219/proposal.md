# calendar-weekday-date-overlap

## 需求澄清摘要
修复日历模块 TableCalendar 星期标签与日期数字重叠

## 为什么
星期标签(周二)与日期数字(26)在日历视图中重叠，影响可读性

## 影响面
- 修改文件：`lib/presentation/pages/calendar/calendar_page.dart`
- 仅添加 `TableCalendar` 配置参数，不改变逻辑结构
- 无 API/数据层/状态管理影响

## 业务规范关系
- 命中的主 spec：无
- 关系判断：Fix / Enhancement
- 推荐动作：MODIFIED

## 验收
- [x] 完成本次最小改动
- [ ] 回归测试最近一次运行通过
