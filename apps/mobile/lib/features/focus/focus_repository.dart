import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import 'focus_models.dart';

final focusRepositoryProvider = Provider<FocusRepository>((ref) {
  return FocusRepository(ref.watch(supabaseClientProvider));
});

final focusSessionsProvider = FutureProvider.autoDispose<List<StudySession>>((ref) {
  return ref.watch(focusRepositoryProvider).loadSessions();
});

class FocusRepository {
  FocusRepository(this._supabase);

  final SupabaseClient _supabase;
  static const String _prefKey = 'focuslearn_study_sessions';

  Future<List<StudySession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) {
      return <StudySession>[];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => StudySession.fromJson(item as Map<String, dynamic>)).toList();
    } on Object {
      return <StudySession>[];
    }
  }

  Future<void> saveSessions(List<StudySession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final list = sessions.map((s) => s.toJson()).toList();
    await prefs.setString(_prefKey, jsonEncode(list));
  }

  Future<StudySession> recordSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required int plannedSeconds,
    required int clientReportedSeconds,
    int pauseSeconds = 0,
    String status = 'completed',
  }) async {
    final now = DateTime.now().toUtc();
    final validated = validatedSeconds(
      planned: plannedSeconds,
      started: startedAt.toUtc(),
      ended: endedAt.toUtc(),
      paused: pauseSeconds,
      reported: clientReportedSeconds,
      received: now,
    );
    final tree = treeStage(validated);
    final counted = isCounted(validated);

    final session = StudySession(
      clientUuid: generateUuidV4(Random.secure()),
      startedAt: startedAt.toUtc(),
      endedAt: endedAt.toUtc(),
      plannedSeconds: plannedSeconds,
      clientReportedSeconds: clientReportedSeconds,
      pauseSeconds: pauseSeconds,
      status: status,
      validatedSeconds: validated,
      tree: tree,
      counted: counted,
      synced: false,
    );

    final existing = await loadSessions();
    existing.insert(0, session);
    await saveSessions(existing);

    // Sync in background if authenticated
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('study_sessions').insert(<String, dynamic>{
          'client_uuid': session.clientUuid,
          'started_at': session.startedAt.toIso8601String(),
          'ended_at': session.endedAt.toIso8601String(),
          'planned_s': session.plannedSeconds,
          'client_reported_s': session.clientReportedSeconds,
          'pause_s': session.pauseSeconds,
          'status': session.status,
        });
        // Mark synced
        final updated = existing.map((s) {
          if (s.clientUuid == session.clientUuid) {
            return s.copyWith(synced: true);
          }
          return s;
        }).toList();
        await saveSessions(updated);
      }
    } on Object {
      // Stored locally; will retry when next session is recorded or synced
    }

    return session;
  }
}
