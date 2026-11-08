import 'rrule.dart';
import 'zone.dart';

const int _maxIterations = 100000;

String isoUtc(DateTime d) {
  final u = d.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
}

DateTime parseIsoUtc(String s) => DateTime.parse(s).toUtc();

class Occurrence {
  const Occurrence(this.start, this.end, {this.isOverride = false});

  final DateTime start;
  final DateTime end;
  final bool isOverride;
}

/// Replaces one occurrence (identified by its ORIGINAL start) with another start and end.
class OccurrenceOverride {
  const OccurrenceOverride({required this.original, required this.start, required this.end});

  final DateTime original;
  final DateTime start;
  final DateTime end;
}

DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d);

/// Local calendar dates of the rule in ascending order, never before [d0]. DTSTART must match the rule (the app ensures it).
Iterable<DateTime> _candidates(RecurrenceRule rule, DateTime d0) sync* {
  final n = rule.interval;
  if (rule.freq == 'DAILY') {
    for (var k = 0; k < _maxIterations; k++) {
      yield _day(d0.year, d0.month, d0.day + k * n);
    }
  } else if (rule.freq == 'WEEKLY') {
    const names = <String>['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    final days = rule.byDay.isEmpty ? <int>[d0.weekday - 1] : (rule.byDay.map(names.indexOf).toList()..sort());
    final week0 = _day(d0.year, d0.month, d0.day - (d0.weekday - 1));
    for (var w = 0; w < _maxIterations; w++) {
      final base = _day(week0.year, week0.month, week0.day + w * n * 7);
      for (final wd in days) {
        final d = _day(base.year, base.month, base.day + wd);
        if (!d.isBefore(d0)) {
          yield d;
        }
      }
    }
  } else {
    final wanted = rule.byMonthDay.isEmpty ? <int>[d0.day] : rule.byMonthDay;
    for (var k = 0; k < _maxIterations; k++) {
      final index = d0.year * 12 + (d0.month - 1) + k * n;
      final y = index ~/ 12;
      final m = index % 12 + 1;
      final last = DateTime.utc(y, m + 1, 0).day;
      final resolved = <int>{
        for (final x in wanted)
          if (x == -1) last else if (x <= last) x,
      }.toList()
        ..sort();
      for (final day in resolved) {
        final d = _day(y, m, day);
        if (!d.isBefore(d0)) {
          yield d;
        }
      }
    }
  }
}

/// Occurrences whose (effective) start lies in [from, to). [skips] are ORIGINAL start instants removed from the series;
/// COUNT counts every generated occurrence, skipped or not.
List<Occurrence> expandRecurrence({
  required String rule,
  required LocalTime start,
  required ZoneResolver zone,
  required int durationMinutes,
  required DateTime from,
  required DateTime to,
  Set<DateTime> skips = const <DateTime>{},
  List<OccurrenceOverride> overrides = const <OccurrenceOverride>[],
}) {
  final r = RecurrenceRule.parse(rule);
  final d0 = start.date;
  final skipSet = skips.map((d) => d.millisecondsSinceEpoch).toSet();
  final ov = <int, OccurrenceOverride>{for (final o in overrides) o.original.millisecondsSinceEpoch: o};
  var limit = to.millisecondsSinceEpoch;
  for (final key in ov.keys) {
    if (key > limit) {
      limit = key;
    }
  }
  final fromMs = from.millisecondsSinceEpoch;
  final toMs = to.millisecondsSinceEpoch;
  final out = <Occurrence>[];
  var n = 0;
  for (final d in _candidates(r, d0)) {
    final s = zone.localToUtc(d.year, d.month, d.day, start.hour, start.minute);
    final sMs = s.millisecondsSinceEpoch;
    if (r.until != null && sMs > r.until!.millisecondsSinceEpoch) {
      break;
    }
    n++;
    if (r.count != null && n > r.count!) {
      break;
    }
    if (sMs > limit || n > _maxIterations) {
      break;
    }
    if (skipSet.contains(sMs)) {
      continue;
    }
    final DateTime effStart;
    final DateTime effEnd;
    final bool flagged;
    final o = ov[sMs];
    if (o != null) {
      effStart = o.start;
      effEnd = o.end;
      flagged = true;
    } else {
      effStart = s;
      effEnd = s.add(Duration(minutes: durationMinutes));
      flagged = false;
    }
    final e = effStart.millisecondsSinceEpoch;
    if (e >= fromMs && e < toMs) {
      out.add(Occurrence(effStart, effEnd, isOverride: flagged));
    }
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

class SplitResult {
  const SplitResult({required this.first, required this.second, required this.secondStartUtc});

  final String first;
  final String second;
  final DateTime secondStartUtc;
}

/// Editing "this and following": the old series ends just before [splitAt] and a new series starts at it.
/// Throws `split_at_first` (edit the whole series instead) or `not_an_occurrence`.
SplitResult splitSeries({
  required String rule,
  required LocalTime start,
  required ZoneResolver zone,
  required DateTime splitAt,
}) {
  final r = RecurrenceRule.parse(rule);
  final target = splitAt.millisecondsSinceEpoch;
  var before = 0;
  var found = false;
  var idx = 0;
  for (final d in _candidates(r, start.date)) {
    final sMs = zone.localToUtc(d.year, d.month, d.day, start.hour, start.minute).millisecondsSinceEpoch;
    if (r.until != null && sMs > r.until!.millisecondsSinceEpoch) {
      break;
    }
    if (r.count != null && idx + 1 > r.count!) {
      break;
    }
    if (sMs == target) {
      found = true;
      break;
    }
    if (sMs > target || idx >= _maxIterations) {
      break;
    }
    before++;
    idx++;
  }
  if (!found) {
    throw const PlannerException('not_an_occurrence');
  }
  if (before == 0) {
    throw const PlannerException('split_at_first');
  }
  final RecurrenceRule first;
  final RecurrenceRule second;
  if (r.count != null) {
    first = r.copyWith(count: before);
    second = r.copyWith(count: r.count! - before);
  } else {
    first = r.copyWith(until: splitAt.subtract(const Duration(seconds: 1)));
    second = r;
  }
  return SplitResult(first: first.serialize(), second: second.serialize(), secondStartUtc: splitAt.toUtc());
}
