import 'rrule.dart';

/// Pairs (by index) of intervals that overlap. Intervals that only touch (one ends exactly when the other starts) do not conflict.
/// Times are minutes (of a day, or any common scale). Throws `invalid_interval` if an interval ends at or before its start.
List<List<int>> findConflicts(List<List<int>> intervals) {
  for (final iv in intervals) {
    if (iv[1] <= iv[0]) {
      throw const PlannerException('invalid_interval');
    }
  }
  final out = <List<int>>[];
  for (var i = 0; i < intervals.length; i++) {
    for (var j = i + 1; j < intervals.length; j++) {
      if (intervals[i][0] < intervals[j][1] && intervals[j][0] < intervals[i][1]) {
        out.add(<int>[i, j]);
      }
    }
  }
  return out;
}

/// Suggested study blocks inside a day window. Busy periods (grown by [buffer] on both sides) are removed; every remaining gap of at
/// least [minLen] minutes yields one block starting at the gap start and no longer than [maxLen]. The 2.5 to 4 hour range is a
/// soft preference: callers may pass other values.
List<List<int>> freeSlots({
  required int windowStart,
  required int windowEnd,
  required List<List<int>> busy,
  required int minLen,
  required int maxLen,
  required int buffer,
}) {
  if (minLen > maxLen || minLen <= 0 || windowEnd <= windowStart || buffer < 0) {
    throw const PlannerException('invalid_range');
  }
  final expanded = <List<int>>[
    for (final b in busy)
      if (b[1] > windowStart && b[0] < windowEnd) <int>[_max(windowStart, b[0] - buffer), _min(windowEnd, b[1] + buffer)],
  ]..sort((a, b) => a[0] != b[0] ? a[0].compareTo(b[0]) : a[1].compareTo(b[1]));
  final merged = <List<int>>[];
  for (final e in expanded) {
    if (merged.isNotEmpty && e[0] <= merged.last[1]) {
      merged.last[1] = _max(merged.last[1], e[1]);
    } else {
      merged.add(<int>[e[0], e[1]]);
    }
  }
  final gaps = <List<int>>[];
  var cursor = windowStart;
  for (final m in merged) {
    if (m[0] > cursor) {
      gaps.add(<int>[cursor, m[0]]);
    }
    cursor = _max(cursor, m[1]);
  }
  if (cursor < windowEnd) {
    gaps.add(<int>[cursor, windowEnd]);
  }
  return <List<int>>[
    for (final g in gaps)
      if (g[1] - g[0] >= minLen) <int>[g[0], g[0] + _min(g[1] - g[0], maxLen)],
  ];
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;

/// Soft planning hint only ('short', 'within' or 'long'). Users can always create any duration.
String durationHint(int minutes, {int low = 150, int high = 240}) => minutes < low ? 'short' : (minutes > high ? 'long' : 'within');
