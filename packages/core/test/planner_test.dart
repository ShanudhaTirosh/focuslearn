// Runs the shared planner vectors (test-vectors/planner.json) against the Dart implementation.
// A Python reference reproduces the same vectors (packages/core/tools/test_planner_contract.py).
// Run from packages/core:  dart test
import 'dart:convert';
import 'dart:io';

import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_core/focuslearn_tz.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

Map<String, dynamic> _loadVectors() =>
    jsonDecode(File('../../test-vectors/planner.json').readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _list(dynamic v) => (v as List<dynamic>).map((dynamic e) => e as Map<String, dynamic>).toList();

LocalTime _local(String s) {
  final parts = s.split('T');
  final d = parts[0].split('-').map(int.parse).toList();
  final t = parts[1].split(':').map(int.parse).toList();
  return LocalTime(d[0], d[1], d[2], t[0], t[1]);
}

List<List<int>> _intervals(dynamic v) =>
    (v as List<dynamic>).map((dynamic e) => (e as List<dynamic>).map((dynamic x) => x as int).toList()).toList();

Matcher _plannerError(String code) => throwsA(isA<PlannerException>().having((e) => e.code, 'code', code));

void main() {
  tzdata.initializeTimeZones();
  final v = _loadVectors();

  group('zone resolver (synthetic offsets, no time-zone database)', () {
    // Offset 0 before 2026-03-29T01:00Z and +60 after: a spring-forward gap from 01:00 to 02:00 local.
    final springForward = DateTime.utc(2026, 3, 29, 1).millisecondsSinceEpoch;
    final forward = OffsetZoneResolver((ms) => ms < springForward ? 0 : 60);
    // Offset +60 before 2026-10-25T01:00Z and 0 after: 01:00 to 02:00 local happens twice.
    final fallBack = DateTime.utc(2026, 10, 25, 1).millisecondsSinceEpoch;
    final back = OffsetZoneResolver((ms) => ms < fallBack ? 60 : 0);

    test('a time that does not exist moves forward by the gap', () {
      expect(isoUtc(forward.localToUtc(2026, 3, 29, 1, 30)), '2026-03-29T01:30:00Z');
    });
    test('times either side of the gap are unaffected', () {
      expect(isoUtc(forward.localToUtc(2026, 3, 29, 0, 30)), '2026-03-29T00:30:00Z');
      expect(isoUtc(forward.localToUtc(2026, 3, 29, 2, 30)), '2026-03-29T01:30:00Z');
    });
    test('a time that happens twice means the first one', () {
      expect(isoUtc(back.localToUtc(2026, 10, 25, 1, 30)), '2026-10-25T00:30:00Z');
    });
    test('times either side of the overlap are unaffected', () {
      expect(isoUtc(back.localToUtc(2026, 10, 25, 0, 30)), '2026-10-24T23:30:00Z');
      expect(isoUtc(back.localToUtc(2026, 10, 25, 2, 30)), '2026-10-25T02:30:00Z');
    });
    test('utcToLocal returns the wall clock in force at the instant', () {
      final t = forward.utcToLocal(DateTime.utc(2026, 3, 29, 1, 30));
      expect((t.hour, t.minute), (2, 30));
    });
    test('a fixed offset zone (Asia/Colombo, +05:30)', () {
      final z = FixedOffsetResolver(330);
      expect(isoUtc(z.localToUtc(2026, 10, 20, 19, 30)), '2026-10-20T14:00:00Z');
      final t = z.utcToLocal(DateTime.utc(2026, 10, 20, 14));
      expect((t.day, t.hour, t.minute), (20, 19, 30));
    });
  });

  group('the zone database agrees with the fixed-offset assumption for Colombo', () {
    test('Asia/Colombo is +05:30 in 2026', () {
      final z = zoneResolverFor('Asia/Colombo');
      expect(isoUtc(z.localToUtc(2026, 10, 20, 19, 30)), '2026-10-20T14:00:00Z');
      expect(isoUtc(z.localToUtc(2026, 1, 1, 0, 0)), '2025-12-31T18:30:00Z');
    });
  });

  group('rrule', () {
    for (final c in _list((v['rrule'] as Map<String, dynamic>)['valid'])) {
      test('valid: ${c['in']}', () {
        expect(RecurrenceRule.canonical(c['in'] as String), c['canonical']);
        expect(RecurrenceRule.canonical(c['canonical'] as String), c['canonical']);
      });
    }
    for (final c in _list((v['rrule'] as Map<String, dynamic>)['invalid'])) {
      test('invalid (${c['code']}): ${(c['in'] as String).length > 40 ? '${(c['in'] as String).substring(0, 40)}...' : c['in']}', () {
        expect(() => RecurrenceRule.parse(c['in'] as String), _plannerError(c['code'] as String));
      });
    }
  });

  group('expand', () {
    for (final c in _list(v['expand'])) {
      test(c['name'] as String, () {
        final got = expandRecurrence(
          rule: c['rule'] as String,
          start: _local(c['start'] as String),
          zone: zoneResolverFor(c['zone'] as String),
          durationMinutes: c['durationMin'] as int,
          from: parseIsoUtc(c['from'] as String),
          to: parseIsoUtc(c['to'] as String),
          skips: <DateTime>{for (final s in c['skip'] as List<dynamic>) parseIsoUtc(s as String)},
          overrides: <OccurrenceOverride>[
            for (final o in _list(c['override']))
              OccurrenceOverride(
                original: parseIsoUtc(o['original'] as String),
                start: parseIsoUtc(o['start'] as String),
                end: parseIsoUtc(o['end'] as String),
              ),
          ],
        );
        final expected = _list(c['expect']);
        expect(got.map((o) => isoUtc(o.start)).toList(), expected.map((e) => e['s']).toList());
        expect(got.map((o) => isoUtc(o.end)).toList(), expected.map((e) => e['e']).toList());
        expect(got.map((o) => o.isOverride).toList(), expected.map((e) => e['o'] == true).toList());
      });
    }
  });

  group('split', () {
    for (final c in _list(v['split'])) {
      test(c['name'] as String, () {
        final zone = zoneResolverFor(c['zone'] as String);
        final start = _local(c['start'] as String);
        final at = parseIsoUtc(c['at'] as String);
        if (c.containsKey('error')) {
          expect(() => splitSeries(rule: c['rule'] as String, start: start, zone: zone, splitAt: at), _plannerError(c['error'] as String));
          return;
        }
        final r = splitSeries(rule: c['rule'] as String, start: start, zone: zone, splitAt: at);
        expect(r.first, c['first']);
        expect(r.second, c['second']);
        expect(isoUtc(r.secondStartUtc), c['secondStartUtc']);

        // The two halves together must reproduce the original series.
        final from = DateTime.utc(2026);
        final to = DateTime.utc(2028);
        List<String> starts(String rule, LocalTime s) =>
            expandRecurrence(rule: rule, start: s, zone: zone, durationMinutes: 150, from: from, to: to).map((o) => isoUtc(o.start)).toList();
        final secondLocal = zone.utcToLocal(r.secondStartUtc);
        final both = <String>[...starts(r.first, start), ...starts(r.second, secondLocal)];
        expect(both, starts(c['rule'] as String, start));
      });
    }
  });

  group('conflicts', () {
    for (final c in _list(v['conflicts'])) {
      test(c['name'] as String, () {
        if (c.containsKey('error')) {
          expect(() => findConflicts(_intervals(c['in'])), _plannerError(c['error'] as String));
        } else {
          expect(findConflicts(_intervals(c['in'])), c['expect']);
        }
      });
    }
  });

  group('freeSlots', () {
    for (final c in _list(v['freeSlots'])) {
      test(c['name'] as String, () {
        final window = (c['window'] as List<dynamic>).map((dynamic x) => x as int).toList();
        List<List<int>> run() => freeSlots(
              windowStart: window[0],
              windowEnd: window[1],
              busy: _intervals(c['busy']),
              minLen: c['min'] as int,
              maxLen: c['max'] as int,
              buffer: c['buffer'] as int,
            );
        if (c.containsKey('error')) {
          expect(run, _plannerError(c['error'] as String));
        } else {
          expect(run(), c['expect']);
        }
      });
    }
  });

  group('durationHint', () {
    for (final c in _list(v['durationHint'])) {
      test('${c['minutes']} minutes is ${c['expect']}', () {
        expect(durationHint(c['minutes'] as int), c['expect']);
      });
    }
  });

  group('meetingUrl', () {
    for (final c in _list(v['meetingUrl'])) {
      test(c['name'] as String, () {
        final r = validateMeetingUrl(c['in'] as String);
        expect(r.code, c['code']);
        expect(r.provider, c['provider']);
        expect(r.normalized, c['normalized']);
      });
    }
  });

  group('reminders', () {
    for (final c in _list(v['reminders'])) {
      test(c['name'] as String, () {
        final q = c['quiet'] as List<dynamic>?;
        final got = planReminders(
          starts: (c['starts'] as List<dynamic>).map((dynamic s) => parseIsoUtc(s as String)).toList(),
          offsets: (c['offsets'] as List<dynamic>).map((dynamic x) => x as int).toList(),
          now: parseIsoUtc(c['now'] as String),
          zone: zoneResolverFor(c['zone'] as String),
          quiet: q == null ? null : (q[0] as int, q[1] as int),
        );
        final expected = _list(c['expect']);
        expect(got.map((r) => isoUtc(r.event)).toList(), expected.map((e) => e['event']).toList());
        expect(got.map((r) => isoUtc(r.fire)).toList(), expected.map((e) => e['fire']).toList());
        expect(got.map((r) => r.shifted).toList(), expected.map((e) => e['shifted']).toList());
      });
    }
  });

  test('limits match the vectors (and so the database)', () {
    final l = v['limits'] as Map<String, dynamic>;
    expect(PlannerRules.titleMax, l['titleMax']);
    expect(PlannerRules.locationMax, l['locationMax']);
    expect(PlannerRules.notesMax, l['notesMax']);
    expect(PlannerRules.reminderOffsetMax, l['reminderOffsetMax']);
    expect(PlannerRules.reminderCountMax, l['reminderCountMax']);
    expect(PlannerRules.meetingUrlMax, l['meetingUrlMax']);
    expect(PlannerRules.eventMaxHours, l['eventMaxHours']);
    expect(PlannerRules.categories, l['categories']);
    expect(<int>[PlannerRules.preferredBlockMinMinutes, PlannerRules.preferredBlockMaxMinutes], l['preferredBlockMinutes']);
  });
}
