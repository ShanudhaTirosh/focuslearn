import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile.dart';

/// Reads and writes the signed-in user's own rows. Row level security in the database is the real access control;
/// nothing here is trusted to enforce it.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  String _requireUid() {
    final uid = _uid;
    if (uid == null) {
      throw StateError('not signed in');
    }
    return uid;
  }

  Future<Profile?> fetchMine() async {
    final uid = _uid;
    if (uid == null) {
      return null;
    }
    final row = await _client.from('profiles').select().eq('user_id', uid).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  Future<void> createProfile({
    required String displayName,
    required int birthYear,
    required String stream,
    required List<String> subjects,
    required String timeZone,
  }) async {
    await _client.from('profiles').insert(<String, dynamic>{
      'user_id': _requireUid(),
      'display_name': displayName,
      'birth_year': birthYear,
      'stream': stream,
      'subjects': subjects,
      'tz': timeZone,
    });
  }

  /// Appends one consent event (grant or revoke). The table is append-only.
  Future<void> recordConsent({required String kind, required String version, required String action}) async {
    await _client.from('consents').insert(<String, dynamic>{'kind': kind, 'version': version, 'action': action});
  }

  /// Creates the preferences row once. An existing row (unique violation) is fine.
  Future<void> ensurePreferences(String language) async {
    try {
      await _client.from('user_preferences').insert(<String, dynamic>{'language': language});
    } on PostgrestException catch (e) {
      if (e.code != '23505') {
        rethrow;
      }
    }
  }

  Future<UserPreferences> fetchPreferences() async {
    final uid = _requireUid();
    final row = await _client.from('user_preferences').select().eq('user_id', uid).maybeSingle();
    return row == null ? UserPreferences.defaults : UserPreferences.fromJson(row);
  }

  Future<void> updatePreferences({String? language, String? theme}) async {
    final uid = _requireUid();
    final changes = <String, dynamic>{
      if (language != null) 'language': language,
      if (theme != null) 'theme': theme,
    };
    if (changes.isEmpty) {
      return;
    }
    await ensurePreferences(language ?? UserPreferences.defaults.language);
    await _client.from('user_preferences').update(changes).eq('user_id', uid);
  }

  /// The scheduled deletion time of a pending request, or null if none is pending.
  Future<DateTime?> fetchPendingDeletion() async {
    final uid = _requireUid();
    final row = await _client.from('deletion_requests').select('scheduled_for').eq('user_id', uid).eq('status', 'pending').maybeSingle();
    return row == null ? null : DateTime.parse(row['scheduled_for'] as String).toLocal();
  }

  Future<void> requestDeletion() async {
    await _client.from('deletion_requests').insert(<String, dynamic>{'user_id': _requireUid()});
  }

  Future<void> cancelDeletion() async {
    await _client.from('deletion_requests').update(<String, dynamic>{'status': 'cancelled'}).eq('user_id', _requireUid()).eq('status', 'pending');
  }
}
