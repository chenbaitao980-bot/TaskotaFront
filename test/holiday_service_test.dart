import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/services/holiday_service.dart';

void main() {
  test(
    'china 2026 labor day override marks five rest days and makeup workday',
    () {
      final holidays = HolidayService.chinaOfficialOverridesForYear(2026);

      for (var day = 1; day <= 5; day++) {
        final holiday = HolidayService.getHoliday(
          holidays,
          DateTime(2026, 5, day),
        );
        expect(holiday, isNotNull);
        expect(holiday!.type, HolidayType.statutory);
        expect(holiday.name, '劳动节');
      }

      final makeupWorkday = HolidayService.getHoliday(
        holidays,
        DateTime(2026, 5, 9),
      );
      expect(makeupWorkday, isNotNull);
      expect(makeupWorkday!.type, HolidayType.makeupWork);
    },
  );
}
