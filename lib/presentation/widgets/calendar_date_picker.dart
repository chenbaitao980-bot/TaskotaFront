import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 显示自定义日历日期+时间选择器（合并弹窗）
///
/// 弹窗为白色圆角卡片带阴影，包含：
/// - 月份标题 + 上下箭头切换
/// - 星期栏 日 一 二 三 四 五 六
/// - 月视图网格（含前后月日期灰显）
/// - 选中日期蓝色圆形高亮
/// - 底部时间下拉框（时 / 分）
Future<DateTime?> showCalendarDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String? title,
}) async {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CalendarPickerContent(
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2099),
      title: title,
    ),
  );
}

class _CalendarPickerContent extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? title;

  const _CalendarPickerContent({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.title,
  });

  @override
  State<_CalendarPickerContent> createState() => _CalendarPickerContentState();
}

class _CalendarPickerContentState extends State<_CalendarPickerContent> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  late int _selectedHour;
  late int _selectedMinute;

  static const List<String> _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  static const List<int> _hourOptions = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
    12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
  ];

  static const List<int> _minuteOptions = [0, 15, 30, 45];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _selectedHour = widget.initialDate.hour;
    // 就近取 15 分钟的整倍数
    final m = widget.initialDate.minute;
    _selectedMinute = _minuteOptions.firstWhere(
      (opt) => opt >= m,
      orElse: () => 0,
    );
  }

  DateTime get _result => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedHour,
        _selectedMinute,
      );

  void _goToPreviousMonth() {
    final prev = DateTime(_currentMonth.year, _currentMonth.month - 1);
    if (!prev.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month))) {
      setState(() => _currentMonth = prev);
    }
  }

  void _goToNextMonth() {
    final next = DateTime(_currentMonth.year, _currentMonth.month + 1);
    if (!next.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month))) {
      setState(() => _currentMonth = next);
    }
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  int _firstWeekdayOfMonth(int year, int month) =>
      DateTime(year, month, 1).weekday - 1; // Monday=0

  bool _isSelected(DateTime date) =>
      date.year == _selectedDate.year &&
      date.month == _selectedDate.month &&
      date.day == _selectedDate.day;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isInRange(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final first = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final last = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );
    return !d.isBefore(first) && !d.isAfter(last);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示条
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 标题行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentMonth.year}年${_currentMonth.month}月',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    _arrowButton(Icons.keyboard_arrow_up, _goToPreviousMonth),
                    const SizedBox(width: 4),
                    _arrowButton(Icons.keyboard_arrow_down, _goToNextMonth),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 星期栏
            Row(
              children: _weekdayLabels
                  .map((label) => Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // 日历网格
            _buildCalendarGrid(),
            const SizedBox(height: 12),
            const Divider(color: AppTheme.borderSubtle, height: 1),
            const SizedBox(height: 12),
            // 时间选择
            _buildTimeRow(),
            const SizedBox(height: 16),
            // 确认按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _result),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('确认', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRow() {
    return Row(
      children: [
        const Icon(Icons.access_time, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        const Text(
          '时间',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        const Spacer(),
        // 时
        _timeDropdown(
          value: _selectedHour,
          items: _hourOptions,
          format: (v) => '${v.toString().padLeft(2, '0')} 时',
          onChanged: (v) => setState(() => _selectedHour = v),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(':', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        // 分
        _timeDropdown(
          value: _selectedMinute,
          items: _minuteOptions,
          format: (v) => '${v.toString().padLeft(2, '0')} 分',
          onChanged: (v) => setState(() => _selectedMinute = v),
        ),
      ],
    );
  }

  Widget _timeDropdown({
    required int value,
    required List<int> items,
    required String Function(int) format,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgInput,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          items: items
              .map((v) => DropdownMenuItem<int>(
                    value: v,
                    child: Text(
                      format(v),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        ),
      ),
    );
  }

  Widget _arrowButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.bgInput,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = _daysInMonth(_currentMonth.year, _currentMonth.month);
    final firstWeekday =
        _firstWeekdayOfMonth(_currentMonth.year, _currentMonth.month);
    final prevMonthDays = _daysInMonth(
      _currentMonth.month == 1 ? _currentMonth.year - 1 : _currentMonth.year,
      _currentMonth.month == 1 ? 12 : _currentMonth.month - 1,
    );

    final totalCells = 42; // 6 rows x 7 cols
    final cells = <Widget>[];

    for (int i = 0; i < totalCells; i++) {
      final dayIndex = i - firstWeekday + 1;
      final Widget cell;

      if (dayIndex < 1) {
        final day = prevMonthDays + dayIndex;
        cell = _dayCell(day, isCurrentMonth: false, isEnabled: false);
      } else if (dayIndex > daysInMonth) {
        final day = dayIndex - daysInMonth;
        cell = _dayCell(day, isCurrentMonth: false, isEnabled: false);
      } else {
        final date =
            DateTime(_currentMonth.year, _currentMonth.month, dayIndex);
        final isEnabled = _isInRange(date);
        final isSelected = _isSelected(date);
        final isToday = _isToday(date);

        cell = _dayCell(
          dayIndex,
          isCurrentMonth: true,
          isEnabled: isEnabled,
          isSelected: isSelected,
          isToday: isToday,
          onTap: isEnabled
              ? () => setState(() => _selectedDate = date)
              : null,
        );
      }

      cells.add(cell);
    }

    return Column(
      children: List.generate(6, (row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: cells.sublist(row * 7, (row + 1) * 7),
          ),
        );
      }),
    );
  }

  Widget _dayCell(
    int day, {
    required bool isCurrentMonth,
    bool isEnabled = true,
    bool isSelected = false,
    bool isToday = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            shape: BoxShape.circle,
            border: isToday && !isSelected
                ? Border.all(color: AppTheme.primaryColor, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? Colors.white
                  : isCurrentMonth && isEnabled
                      ? AppTheme.textPrimary
                      : AppTheme.textHint.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
