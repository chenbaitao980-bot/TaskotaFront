# Regression Cases: calendar-weekday-date-overlap

## Test Environment
- App: SmartAssistant (Flutter)
- Test type: static check plus manual UI verification
- Last command: `flutter analyze`

## Cases

### TC1: 星期几文字不与日期数字重叠
1. 打开日历页面，切换到周视图
2. 确认星期几文字（一、二、三…）与日期数字（1、2、3…）不重叠
3. 滑动切换不同周
4. Expected: 所有周的星期几文字和日期数字都清晰无重叠

### TC2: 不同日期格式下不重叠
1. 确保日期跨月（如月末/月初）
2. 确认跨月日期显示无重叠

## Pass Criteria
- All manual cases pass.
- flutter analyze exits with code 0.
