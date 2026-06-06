import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/presentation/pages/calendar/day_task_lane_layout.dart';

void main() {
  test('overlapping group does not narrow later independent tasks', () {
    final assignments = _assign([
      _input('a', 14, 0, 15, 0),
      _input('b', 14, 30, 15, 30),
      _input('c', 16, 0, 17, 0),
    ]);

    expect(assignments['a']?.laneCount, 2);
    expect(assignments['b']?.laneCount, 2);
    expect(assignments['c']?.laneCount, 1);
    expect(assignments['c']?.laneIndex, 0);
  });

  test('touching ranges are not overlapping', () {
    final assignments = _assign([
      _input('a', 9, 0, 10, 0),
      _input('b', 10, 0, 11, 0),
    ]);

    expect(assignments['a']?.laneCount, 1);
    expect(assignments['b']?.laneCount, 1);
    expect(assignments['a']?.laneIndex, 0);
    expect(assignments['b']?.laneIndex, 0);
  });

  test('transitive overlap stays in one lane group', () {
    final assignments = _assign([
      _input('a', 9, 0, 10, 0),
      _input('b', 9, 30, 10, 30),
      _input('c', 10, 0, 11, 0),
    ]);

    expect(assignments['a']?.laneCount, 2);
    expect(assignments['b']?.laneCount, 2);
    expect(assignments['c']?.laneCount, 2);
    expect(assignments['a']?.laneIndex, 0);
    expect(assignments['b']?.laneIndex, 1);
    expect(assignments['c']?.laneIndex, 0);
  });
}

Map<String, DayTaskLaneAssignment<String>> _assign(
  List<DayTaskLaneInput<String>> inputs,
) {
  return {
    for (final assignment in assignDayTaskLanes(inputs))
      assignment.item: assignment,
  };
}

DayTaskLaneInput<String> _input(
  String id,
  int startHour,
  int startMinute,
  int endHour,
  int endMinute,
) {
  return DayTaskLaneInput(
    item: id,
    segmentStart: DateTime(2026, 6, 2, startHour, startMinute),
    segmentEnd: DateTime(2026, 6, 2, endHour, endMinute),
  );
}
