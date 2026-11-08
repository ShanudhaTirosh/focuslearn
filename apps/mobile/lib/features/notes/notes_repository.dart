import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import 'notes_models.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(supabaseClientProvider));
});

final notesProvider = FutureProvider.autoDispose<List<Note>>((ref) {
  return ref.watch(notesRepositoryProvider).loadNotes();
});

class NotesRepository {
  NotesRepository(this._supabase);

  final SupabaseClient _supabase;
  static const String _prefKey = 'focuslearn_study_notes';

  Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    List<Note> list = <Note>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        list = decoded.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
      } on Object {
        list = <Note>[];
      }
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('notes').select();
        final remote = (data as List<dynamic>).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
        await prefs.setString(_prefKey, jsonEncode(remote.map((n) => n.toJson()).toList()));
        return remote;
      }
    } on Object {
      // Offline fallback
    }

    return list;
  }

  Future<void> saveNote(Note note) async {
    final existing = await loadNotes();
    final index = existing.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      existing[index] = note;
    } else {
      existing.insert(0, note);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(existing.map((n) => n.toJson()).toList()));

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('notes').upsert(note.toJson());
      }
    } on Object {
      // Offline fallback
    }
  }

  Future<void> deleteNote(String id) async {
    final existing = await loadNotes();
    existing.removeWhere((n) => n.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(existing.map((n) => n.toJson()).toList()));

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('notes').delete().eq('id', id);
      }
    } on Object {
      // Offline fallback
    }
  }
}

