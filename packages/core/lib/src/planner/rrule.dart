/// A planner rule failed validation. [code] is one of the stable codes in test-vectors/planner.json.
class PlannerException implements Exception {
  const PlannerException(this.code);

  final String code;

  @override
  String toString() => 'PlannerException($code)';
}

const List<String> _weekdays = <String>['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
const Set<String> _allowedKeys = <String>{'FREQ', 'INTERVAL', 'BYDAY', 'BYMONTHDAY', 'COUNT', 'UNTIL'};

/// The supported subset of RFC 5545 recurrence rules: DAILY, WEEKLY and MONTHLY with INTERVAL, BYDAY (weekly),
/// BYMONTHDAY (monthly, 1 to 31 or -1 for the last day), COUNT or UNTIL. Nothing else is accepted.
class RecurrenceRule {
  const RecurrenceRule({
    required this.freq,
    this.interval = 1,
    this.byDay = const <String>[],
    this.byMonthDay = const <int>[],
    this.count,
    this.until,
  });

  final String freq;
  final int interval;
  final List<String> byDay;
  final List<int> byMonthDay;
  final int? count;
  final DateTime? until;

  RecurrenceRule copyWith({int? count, DateTime? until, bool clearCount = false, bool clearUntil = false}) => RecurrenceRule(
        freq: freq,
        interval: interval,
        byDay: byDay,
        byMonthDay: byMonthDay,
        count: clearCount ? null : (count ?? this.count),
        until: clearUntil ? null : (until ?? this.until),
      );

  /// The canonical text form stored in the database (the database accepts only this order).
  String serialize() {
    final parts = <String>['FREQ=$freq'];
    if (interval > 1) {
      parts.add('INTERVAL=$interval');
    }
    if (byDay.isNotEmpty) {
      final days = List<String>.of(byDay)..sort((a, b) => _weekdays.indexOf(a).compareTo(_weekdays.indexOf(b)));
      parts.add('BYDAY=${days.join(',')}');
    }
    if (byMonthDay.isNotEmpty) {
      final days = List<int>.of(byMonthDay)
        ..sort((a, b) {
          final an = a < 0 ? 1 : 0;
          final bn = b < 0 ? 1 : 0;
          return an != bn ? an.compareTo(bn) : a.compareTo(b);
        });
      parts.add('BYMONTHDAY=${days.join(',')}');
    }
    if (count != null) {
      parts.add('COUNT=$count');
    }
    if (until != null) {
      parts.add('UNTIL=${_formatUntil(until!)}');
    }
    return parts.join(';');
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatUntil(DateTime d) {
    final u = d.toUtc();
    return '${u.year.toString().padLeft(4, '0')}${_two(u.month)}${_two(u.day)}T${_two(u.hour)}${_two(u.minute)}${_two(u.second)}Z';
  }

  static final RegExp _whitespace = RegExp(r'\s');
  static final RegExp _intervalPattern = RegExp(r'^[1-9][0-9]{0,2}$');
  static final RegExp _monthDayPattern = RegExp(r'^(-1|[1-9]|[12][0-9]|3[01])$');
  static final RegExp _countPattern = RegExp(r'^([1-9][0-9]{0,2}|1000)$');
  static final RegExp _untilPattern = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$');

  /// Parses any order of keys; throws [PlannerException] with a stable code when the rule is not supported.
  static RecurrenceRule parse(String s) {
    if (s.isEmpty) {
      throw const PlannerException('empty');
    }
    if (s.length > 200) {
      throw const PlannerException('too_long');
    }
    if (_whitespace.hasMatch(s)) {
      throw const PlannerException('invalid_syntax');
    }
    final kv = <String, String>{};
    for (final part in s.split(';')) {
      if (part.isEmpty || '='.allMatches(part).length != 1) {
        throw const PlannerException('invalid_syntax');
      }
      final i = part.indexOf('=');
      final k = part.substring(0, i);
      final v = part.substring(i + 1);
      if (k.isEmpty || v.isEmpty) {
        throw const PlannerException('invalid_syntax');
      }
      if (!_allowedKeys.contains(k)) {
        throw const PlannerException('unsupported_key');
      }
      if (kv.containsKey(k)) {
        throw const PlannerException('duplicate_key');
      }
      kv[k] = v;
    }
    final freq = kv['FREQ'];
    if (freq == null) {
      throw const PlannerException('missing_freq');
    }
    if (freq != 'DAILY' && freq != 'WEEKLY' && freq != 'MONTHLY') {
      throw const PlannerException('unsupported_freq');
    }
    var interval = 1;
    if (kv.containsKey('INTERVAL')) {
      if (!_intervalPattern.hasMatch(kv['INTERVAL']!)) {
        throw const PlannerException('invalid_interval');
      }
      interval = int.parse(kv['INTERVAL']!);
    }
    var byDay = <String>[];
    if (kv.containsKey('BYDAY')) {
      if (freq != 'WEEKLY') {
        throw const PlannerException('byday_needs_weekly');
      }
      final days = kv['BYDAY']!.split(',');
      if (days.any((d) => !_weekdays.contains(d)) || days.toSet().length != days.length) {
        throw const PlannerException('invalid_byday');
      }
      byDay = days;
    }
    var byMonthDay = <int>[];
    if (kv.containsKey('BYMONTHDAY')) {
      if (freq != 'MONTHLY') {
        throw const PlannerException('bymonthday_needs_monthly');
      }
      final vals = kv['BYMONTHDAY']!.split(',');
      if (vals.any((x) => !_monthDayPattern.hasMatch(x)) || vals.toSet().length != vals.length) {
        throw const PlannerException('invalid_bymonthday');
      }
      byMonthDay = vals.map(int.parse).toList();
    }
    int? count;
    if (kv.containsKey('COUNT')) {
      if (!_countPattern.hasMatch(kv['COUNT']!)) {
        throw const PlannerException('invalid_count');
      }
      count = int.parse(kv['COUNT']!);
    }
    DateTime? until;
    if (kv.containsKey('UNTIL')) {
      final m = _untilPattern.firstMatch(kv['UNTIL']!);
      if (m == null) {
        throw const PlannerException('invalid_until');
      }
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      final h = int.parse(m.group(4)!);
      final mi = int.parse(m.group(5)!);
      final se = int.parse(m.group(6)!);
      final candidate = DateTime.utc(y, mo, d, h, mi, se);
      // DateTime normalises impossible dates (month 13, 31 April, 24:00): accept only a value that round-trips.
      if (candidate.year != y || candidate.month != mo || candidate.day != d || candidate.hour != h || candidate.minute != mi || candidate.second != se) {
        throw const PlannerException('invalid_until');
      }
      until = candidate;
    }
    if (count != null && until != null) {
      throw const PlannerException('count_and_until');
    }
    return RecurrenceRule(freq: freq, interval: interval, byDay: byDay, byMonthDay: byMonthDay, count: count, until: until);
  }

  /// Parses and re-serialises: the form that is stored.
  static String canonical(String s) => parse(s).serialize();
}
