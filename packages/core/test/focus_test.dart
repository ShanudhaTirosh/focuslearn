// Runs the shared focus vectors (test-vectors/focus.json) against the Dart mirror of the rules.
// The Python reference passes the same vectors, and the SQL functions are tested with pgTAP assertions generated from them.
// Run from packages/core:  dart test
import 'dart:convert';
import 'dart:io';

import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:test/test.dart';

List<Map<String, dynamic>> _list(dynamic v) => (v as List<dynamic>).map((dynamic e) => e as Map<String, dynamic>).toList();

List<FocusDay> _days(dynamic v) => (v as List<dynamic>).map((dynamic e) {
      final pair = e as List<dynamic>;
      return FocusDay(pair[0] as String, pair[1] as int);
    }).toList();

void main() {
  final v = jsonDecode(File('../../test-vectors/focus.json').readAsStringSync()) as Map<String, dynamic>;

  group('validated seconds', () {
    for (final c in _list(v['validated'])) {
      test(c['name'] as String, () {
        expect(
          validatedSeconds(
            planned: c['planned'] as int,
            started: DateTime.parse(c['started'] as String),
            ended: DateTime.parse(c['ended'] as String),
            paused: c['paused'] as int,
            reported: c['reported'] as int,
            received: DateTime.parse(c['received'] as String),
          ),
          c['expect'],
        );
      });
    }
  });

  group('tree stage and counted', () {
    for (final c in _list(v['tree'])) {
      test('${c['validated']} seconds', () {
        expect(treeStage(c['validated'] as int), c['stage']);
        expect(isCounted(c['validated'] as int), c['counted']);
      });
    }
  });

  group('streak', () {
    for (final c in _list(v['streak'])) {
      test(c['name'] as String, () {
        final s = focusStreak(_days(c['days']), c['today'] as String, goal: c['goal'] as int);
        expect(s.streak, c['streak']);
        expect(s.restDays, c['rest_days']);
      });
    }
  });

  group('longest streak', () {
    for (final c in _list(v['longest'])) {
      test(c['name'] as String, () {
        expect(longestFocusStreak(_days(c['days']), goal: c['goal'] as int), c['expect']);
      });
    }
  });

  group('achievements', () {
    for (final c in _list(v['achievements'])) {
      test(c['name'] as String, () {
        expect(
          focusAchievements(countedSessions: c['sessions'] as int, totalCountedSeconds: c['total_seconds'] as int, longest: c['longest'] as int),
          c['expect'],
        );
      });
    }
  });

  test('the constants match the vectors (and so the database)', () {
    final k = v['constants'] as Map<String, dynamic>;
    expect(FocusRules.skewSeconds, k['skewSeconds']);
    expect(FocusRules.staleDays, k['staleDays']);
    expect(FocusRules.overrunSeconds, k['overrunSeconds']);
    expect(FocusRules.maxSessionSeconds, k['maxSessionSeconds']);
    expect(FocusRules.countedMinSeconds, k['countedMinSeconds']);
    expect(FocusRules.restDaySpacing, k['restDaySpacing']);
    expect(FocusRules.defaultGoalSeconds, k['defaultGoalSeconds']);
    expect(FocusRules.treeStages.reversed.map((s) => <Object>[s.$1, s.$2]).toList(), k['treeStages']);
    expect(FocusRules.achievementOrder.length, 7);
  });
}
