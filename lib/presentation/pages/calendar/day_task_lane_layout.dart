class DayTaskLaneInput<T> {
  final T item;
  final DateTime segmentStart;
  final DateTime segmentEnd;

  const DayTaskLaneInput({
    required this.item,
    required this.segmentStart,
    required this.segmentEnd,
  });
}

class DayTaskLaneAssignment<T> {
  final T item;
  final int laneIndex;
  final int laneCount;

  const DayTaskLaneAssignment({
    required this.item,
    required this.laneIndex,
    required this.laneCount,
  });
}

List<DayTaskLaneAssignment<T>> assignDayTaskLanes<T>(
  List<DayTaskLaneInput<T>> inputs,
) {
  if (inputs.isEmpty) return const [];

  final sorted = [...inputs]
    ..sort((a, b) {
      final startCompare = a.segmentStart.compareTo(b.segmentStart);
      if (startCompare != 0) return startCompare;
      return a.segmentEnd.compareTo(b.segmentEnd);
    });

  final assignments = <DayTaskLaneAssignment<T>>[];
  var groupStartIndex = 0;
  var groupEnd = sorted.first.segmentEnd;

  for (var i = 1; i <= sorted.length; i++) {
    final startsNewGroup =
        i == sorted.length || !sorted[i].segmentStart.isBefore(groupEnd);

    if (startsNewGroup) {
      assignments.addAll(_assignGroup(sorted.sublist(groupStartIndex, i)));
      if (i < sorted.length) {
        groupStartIndex = i;
        groupEnd = sorted[i].segmentEnd;
      }
      continue;
    }

    if (sorted[i].segmentEnd.isAfter(groupEnd)) {
      groupEnd = sorted[i].segmentEnd;
    }
  }

  return assignments;
}

List<DayTaskLaneAssignment<T>> _assignGroup<T>(
  List<DayTaskLaneInput<T>> group,
) {
  final laneEnds = <DateTime>[];
  final laneIndexes = <int>[];

  for (final input in group) {
    var laneIndex = -1;
    for (var i = 0; i < laneEnds.length; i++) {
      if (!input.segmentStart.isBefore(laneEnds[i])) {
        laneEnds[i] = input.segmentEnd;
        laneIndex = i;
        break;
      }
    }

    if (laneIndex == -1) {
      laneEnds.add(input.segmentEnd);
      laneIndex = laneEnds.length - 1;
    }
    laneIndexes.add(laneIndex);
  }

  final laneCount = laneEnds.length;
  return [
    for (var i = 0; i < group.length; i++)
      DayTaskLaneAssignment<T>(
        item: group[i].item,
        laneIndex: laneIndexes[i],
        laneCount: laneCount,
      ),
  ];
}
