import 'dart:math' as math;

/// The focus-session rules. The DATABASE decides what counts (private.focus_* functions); this mirror lets the app show an estimate
/// while a session runs or offline. Client reports are advisory. Behaviour is fixed by test-vectors/focus.json.
abstract final class FocusRules {
  static const int skewSeconds = 300;
  static const int staleDays = 14;
  static const int overrunSeconds = 300;
  static const int maxSessionSeconds = 28800;
  static const int countedMinSeconds = 300;
  static const int restDaySpacing = 7;
  static const int defaultGoalSeconds = 1800;
  static const int maxScanDays = 4000;

  /// Highest stage first.
  static const List<(int, String)> treeStages = <(int, String)>[(3000, 'grove'), (1500, 'tree'), (900, 'sapling'), (300, 'seedling')];

  static const List<String> achievementOrder = <String>['first_session', 'sessions_25', 'hours_10', 'hours_50', 'streak_3', 'streak_7', 'streak_30'];
}

/// Focus seconds the server would accept: never more than the clock allows, never more than reported, never more than the plan plus a
/// small overrun, never more than 8 hours. A bad or stale timestamp earns 0 (nothing is taken away).
int validatedSeconds({
  required int planned,
  required DateTime started,
  required DateTime ended,
  required int paused,
  required int reported,
  required DateTime received,
}) {
  if (!ended.isAfter(started) ||
      ended.isAfter(received.add(const Duration(seconds: FocusRules.skewSeconds))) ||
      received.difference(ended) > const Duration(days: FocusRules.staleDays)) {
    return 0;
  }
  final elapsed = ended.difference(started).inSeconds;
  final pausedClamped = math.min(math.max(paused, 0), elapsed);
  final active = elapsed - pausedClamped;
  final cap = math.min(planned + FocusRules.overrunSeconds, FocusRules.maxSessionSeconds);
  return math.max(0, math.min(math.min(math.max(reported, 0), active), cap));
}

bool isCounted(int validated) => validated >= FocusRules.countedMinSeconds;

/// `none`, `seedling`, `sapling`, `tree` or `grove`. An abandoned or ended-early session earns by its validated time like any other.
String treeStage(int validated) {
  for (final (floor, name) in FocusRules.treeStages) {
    if (validated >= floor) {
      return name;
    }
  }
  return 'none';
}

/// Seconds focused on one local calendar day (`YYYY-MM-DD`). Several rows for one day add up.
class FocusDay {
  const FocusDay(this.date, this.seconds);

  final String date;
  final int seconds;
}

class FocusStreak {
  const FocusStreak(this.streak, this.restDays);

  final int streak;
  final int restDays;
}

int _epochDay(String iso) {
  final p = iso.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]).millisecondsSinceEpoch ~/ 86400000;
}

Map<int, int> _totals(List<FocusDay> days) {
  final totals = <int, int>{};
  for (final d in days) {
    final k = _epochDay(d.date);
    totals[k] = (totals[k] ?? 0) + d.seconds;
  }
  return totals;
}

/// The current streak of days that reached [goal], ending today (or yesterday while today is still open).
/// A single missed day between two met days is a rest day: it neither breaks nor adds to the streak, and at most one rest day is allowed
/// in any 7 consecutive days.
FocusStreak focusStreak(List<FocusDay> days, String today, {int goal = FocusRules.defaultGoalSeconds}) =>
    _streakFrom(_totals(days), _epochDay(today), goal);

FocusStreak _streakFrom(Map<int, int> totals, int today, int goal) {
  bool met(int d) => (totals[d] ?? 0) >= goal;
  var d = met(today) ? today : today - 1;
  var count = 0;
  var rest = 0;
  int? lastForgiven;
  for (var i = 0; i < FocusRules.maxScanDays; i++) {
    if (met(d)) {
      count++;
    } else if (met(d - 1) && (lastForgiven == null || lastForgiven - d >= FocusRules.restDaySpacing)) {
      rest++;
      lastForgiven = d;
    } else {
      break;
    }
    d--;
  }
  return FocusStreak(count, rest);
}

int longestFocusStreak(List<FocusDay> days, {int goal = FocusRules.defaultGoalSeconds}) {
  final totals = _totals(days);
  var best = 0;
  for (final entry in totals.entries) {
    if (entry.value >= goal) {
      best = math.max(best, _streakFrom(totals, entry.key, goal).streak);
    }
  }
  return best;
}

List<String> focusAchievements({required int countedSessions, required int totalCountedSeconds, required int longest}) => <String>[
      if (countedSessions >= 1) 'first_session',
      if (countedSessions >= 25) 'sessions_25',
      if (totalCountedSeconds >= 36000) 'hours_10',
      if (totalCountedSeconds >= 180000) 'hours_50',
      if (longest >= 3) 'streak_3',
      if (longest >= 7) 'streak_7',
      if (longest >= 30) 'streak_30',
    ];
