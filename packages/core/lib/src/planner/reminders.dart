import 'zone.dart';

class PlannedReminder {
  const PlannedReminder({required this.event, required this.fire, required this.shifted});

  final DateTime event;
  final DateTime fire;
  final bool shifted;
}

/// Fire times (UTC) for reminders: each event start minus each offset (minutes). Past ones are dropped. A reminder that would
/// fire inside quiet hours (local minutes of the day, [start, end), may wrap midnight; start == end means none) moves to the end
/// of quiet hours, but only if that is still after [now] and before the event starts; otherwise it is dropped.
List<PlannedReminder> planReminders({
  required List<DateTime> starts,
  required List<int> offsets,
  required DateTime now,
  required ZoneResolver zone,
  (int, int)? quiet,
}) {
  final out = <PlannedReminder>[];
  final sortedOffsets = offsets.toSet().toList()..sort((a, b) => b.compareTo(a));
  for (final s in starts) {
    for (final off in sortedOffsets) {
      var fire = s.subtract(Duration(minutes: off));
      if (!fire.isAfter(now)) {
        continue;
      }
      var shifted = false;
      if (quiet != null && quiet.$1 != quiet.$2) {
        final (qs, qe) = quiet;
        final local = zone.utcToLocal(fire);
        final m = local.minutesOfDay;
        final inside = qs < qe ? (m >= qs && m < qe) : (m >= qs || m < qe);
        if (inside) {
          final sameDay = qs < qe || m < qe;
          final day = sameDay ? local.date : DateTime.utc(local.year, local.month, local.day + 1);
          fire = zone.localToUtc(day.year, day.month, day.day, qe ~/ 60, qe % 60);
          shifted = true;
          if (!fire.isBefore(s) || !fire.isAfter(now)) {
            continue;
          }
        }
      }
      out.add(PlannedReminder(event: s, fire: fire, shifted: shifted));
    }
  }
  out.sort((a, b) {
    final c = a.fire.compareTo(b.fire);
    return c != 0 ? c : a.event.compareTo(b.event);
  });
  return out;
}
