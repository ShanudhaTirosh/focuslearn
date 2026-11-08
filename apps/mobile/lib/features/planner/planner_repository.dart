import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import 'planner_models.dart';

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  return PlannerRepository(ref.watch(supabaseClientProvider));
});

final subjectsProvider = FutureProvider.autoDispose<List<Subject>>((ref) {
  return ref.watch(plannerRepositoryProvider).loadSubjects();
});

final timetableEventsProvider = FutureProvider.autoDispose<List<TimetableEvent>>((ref) {
  return ref.watch(plannerRepositoryProvider).loadEvents();
});

final assignmentsProvider = FutureProvider.autoDispose<List<Assignment>>((ref) {
  return ref.watch(plannerRepositoryProvider).loadAssignments();
});

class PlannerRepository {
  PlannerRepository(this._supabase);

  final SupabaseClient _supabase;
  static const String _subjectsKey = 'focuslearn_planner_subjects';
  static const String _eventsKey = 'focuslearn_planner_events';
  static const String _assignmentsKey = 'focuslearn_planner_assignments';

  // ---------------------------------------------------------------- Subjects
  Future<List<Subject>> loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_subjectsKey);
    List<Subject> list = <Subject>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        list = decoded.map((e) => Subject.fromJson(e as Map<String, dynamic>)).toList();
      } on Object {
        list = <Subject>[];
      }
    }

    // Try sync online if authenticated
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('subjects').select();
        final remote = (data as List<dynamic>).map((e) => Subject.fromJson(e as Map<String, dynamic>)).toList();
        await prefs.setString(_subjectsKey, jsonEncode(remote.map((s) => s.toJson()).toList()));
        return remote;
      }
    } on Object {
      // Return local cache on network error
    }
    return list;
  }

  Future<void> saveSubject(Subject subject) async {
    final existing = await loadSubjects();
    final index = existing.indexWhere((s) => s.id == subject.id);
    if (index >= 0) {
      existing[index] = subject;
    } else {
      existing.add(subject);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subjectsKey, jsonEncode(existing.map((s) => s.toJson()).toList()));

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('subjects').upsert(subject.toJson());
      }
    } on Object {
      // Offline fallback
    }
  }

  // ---------------------------------------------------------------- Timetable Events
  Future<List<TimetableEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_eventsKey);
    List<TimetableEvent> list = <TimetableEvent>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        list = decoded.map((e) => TimetableEvent.fromJson(e as Map<String, dynamic>)).toList();
      } on Object {
        list = <TimetableEvent>[];
      }
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('timetable_events').select();
        final remote = (data as List<dynamic>).map((e) => TimetableEvent.fromJson(e as Map<String, dynamic>)).toList();
        await prefs.setString(_eventsKey, jsonEncode(remote.map((ev) => ev.toJson()).toList()));
        return remote;
      }
    } on Object {
      // Offline fallback
    }
    return list;
  }

  Future<void> saveEvent(TimetableEvent event) async {
    final existing = await loadEvents();
    final index = existing.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      existing[index] = event;
    } else {
      existing.add(event);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eventsKey, jsonEncode(existing.map((e) => e.toJson()).toList()));

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('timetable_events').upsert(event.toJson());
      }
    } on Object {
      // Offline fallback
    }
  }

  Future<void> deleteEvent(String id) async {
    final existing = await loadEvents();
    existing.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eventsKey, jsonEncode(existing.map((e) => e.toJson()).toList()));

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('timetable_events').delete().eq('id', id);
      }
    } on Object {
      // Offline fallback
    }
  }

  // ---------------------------------------------------------------- Assignments
  Future<List<Assignment>> loadAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_assignmentsKey);
    List<Assignment> list = <Assignment>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        list = decoded.map((e) => Assignment.fromJson(e as Map<String, dynamic>)).toList();
      } on Object {
        list = <Assignment>[];
      }
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('assignments').select();
        final remote = (data as List<dynamic>).map((e) => Assignment.fromJson(e as Map<String, dynamic>)).toList();
        await prefs.setString(_assignmentsKey, jsonEncode(remote.map((a) => a.toJson()).toList()));
        return remote;
      }
    } on Object {
      // Offline fallback
    }
    return list;
  }

  Future<void> saveAssignment(Assignment assignment) async {
    final existing = await loadAssignments();
    final index = existing.indexWhere((a) => a.id == assignment.id);
    if (index >= 0) {
      existing[index] = assignment;
    } else {
      existing.add(assignment);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_assignmentsKey, jsonEncode(existing.map((a) => a.toJson()).toList()));

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('assignments').upsert(assignment.toJson());
      }
    } on Object {
      // Offline fallback
    }
  }

  // ---------------------------------------------------------------- Expansion & Conflicts
  List<ExpandedEvent> expandForDay(List<TimetableEvent> events, DateTime day) {
    final dayStart = DateTime.utc(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final expanded = <ExpandedEvent>[];

    for (final ev in events) {
      if (ev.rrule != null && ev.rrule!.isNotEmpty) {
        try {
          final occurrences = expandRecurrence(
            rule: ev.rrule!,
            start: LocalTime(ev.startUtc.year, ev.startUtc.month, ev.startUtc.day, ev.startUtc.hour, ev.startUtc.minute),
            zone: OffsetZoneResolver((_) => 330),
            durationMinutes: ev.endUtc.difference(ev.startUtc).inMinutes,
            from: dayStart,
            to: dayEnd,
          );
          for (final occ in occurrences) {
            expanded.add(ExpandedEvent(event: ev, start: occ.start, end: occ.end, isOverride: occ.isOverride));
          }
        } on Object {
          // If rule cannot parse, fallback to single check
          if (!ev.endUtc.isBefore(dayStart) && !ev.startUtc.isAfter(dayEnd)) {
            expanded.add(ExpandedEvent(event: ev, start: ev.startUtc, end: ev.endUtc));
          }
        }
      } else {
        if (!ev.endUtc.isBefore(dayStart) && !ev.startUtc.isAfter(dayEnd)) {
          expanded.add(ExpandedEvent(event: ev, start: ev.startUtc, end: ev.endUtc));
        }
      }
    }

    expanded.sort((a, b) => a.start.compareTo(b.start));
    return expanded;
  }

  /// Finds indices of conflicting events in an expanded list.
  Set<int> findConflictIndices(List<ExpandedEvent> expanded) {
    final conflictIndices = <int>{};
    for (var i = 0; i < expanded.length; i++) {
      for (var j = i + 1; j < expanded.length; j++) {
        final a = expanded[i];
        final b = expanded[j];
        // Touching boundaries (a.end == b.start) is NOT a conflict
        if (a.start.isBefore(b.end) && b.start.isBefore(a.end)) {
          conflictIndices.add(i);
          conflictIndices.add(j);
        }
      }
    }
    return conflictIndices;
  }
}
