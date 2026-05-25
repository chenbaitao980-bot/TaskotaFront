# 设计方案

## 1. `_parsePlanDate` 增加夹紧

```dart
DateTime _parsePlanDate(String text, DateTime fallback) {
    final md = RegExp(r'(\d{1,2})[/-](\d{1,2})').firstMatch(text);
    if (md != null) {
      final month = int.tryParse(md.group(1) ?? '') ?? fallback.month;
      final day = int.tryParse(md.group(2) ?? '') ?? fallback.day;
      return _clampToThisWeek(DateTime(fallback.year, month.clamp(1, 12), day.clamp(1, 31)));
    }
    final dayIndex = _weekdayIndex(text);
    if (dayIndex >= 0) {
      final base = DateTime(fallback.year, fallback.month, fallback.day);
      return _clampToThisWeek(base.add(Duration(days: dayIndex)));
    }
    return _clampToThisWeek(fallback);
}
```

每个 return 路径都经过 `_clampToThisWeek`。

## 2. `_defaultPlanStart` 溢出错峰

当 index 超出本周可用天数时，将多出的行分配到剩余天的不同时间槽：

```dart
DateTime _defaultPlanStart(int index) {
    final now = DateTime.now();
    final slots = DateTime.sunday - now.weekday + 1; // 7
    if (index < slots) {
      return DateTime(now.year, now.month, now.day, 9).add(Duration(days: index));
    }
    // 溢出：放在最后一天，按时间错峰（9+overflow_hour）
    final overflowHour = 9 + (index - slots + 1);
    final lastDay = DateTime(now.year, now.month, now.day, overflowHour.clamp(9, 23));
    return lastDay.add(Duration(days: (DateTime.sunday - now.weekday)));
}
```

## 3. 时间线排序加二级键

```dart
final sorted = List<_PlanRow>.from(rows)
    ..asMap().entries.toList()
      ..sort((a, b) {
        final cmp = a.value.start.compareTo(b.value.start);
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });
```
