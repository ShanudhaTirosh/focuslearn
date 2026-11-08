import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/providers.dart';
import 'social_models.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(ref.watch(supabaseClientProvider));
});

final myGroupsProvider = FutureProvider.autoDispose<List<StudyGroup>>((ref) {
  return ref.watch(socialRepositoryProvider).fetchMyGroups();
});

final myFriendsProvider = FutureProvider.autoDispose<List<Friend>>((ref) {
  return ref.watch(socialRepositoryProvider).fetchMyFriends();
});

class SocialRepository {
  SocialRepository(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<StudyGroup>> fetchMyGroups() async {
    final uid = currentUserId;
    if (uid == null) return const [];

    try {
      final res = await _client
          .from('group_members')
          .select('role, groups (id, name, description)')
          .eq('user_id', uid);

      final list = <StudyGroup>[];
      for (final item in (res as List<dynamic>)) {
        final g = item['groups'] as Map<String, dynamic>?;
        if (g != null) {
          list.add(StudyGroup(
            id: g['id'] as String,
            name: g['name'] as String,
            description: g['description'] as String?,
            role: (item['role'] as String?) ?? 'member',
          ));
        }
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Friend>> fetchMyFriends() async {
    final uid = currentUserId;
    if (uid == null) return const [];

    try {
      final resA = await _client
          .from('friendships')
          .select('user_b, profiles!friendships_user_b_fkey(user_id, display_name, stream, avatar_key)')
          .eq('user_a', uid)
          .eq('status', 'accepted');

      final resB = await _client
          .from('friendships')
          .select('user_a, profiles!friendships_user_a_fkey(user_id, display_name, stream, avatar_key)')
          .eq('user_b', uid)
          .eq('status', 'accepted');

      final list = <Friend>[];
      for (final item in [...(resA as List<dynamic>), ...(resB as List<dynamic>)]) {
        final p = (item['profiles'] as Map<String, dynamic>?);
        if (p != null) {
          list.add(Friend(
            id: p['user_id'] as String,
            displayName: (p['display_name'] as String?) ?? 'Student',
            stream: (p['stream'] as String?) ?? 'other',
            avatarKey: p['avatar_key'] as String?,
          ));
        }
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<StudyGroup?> createGroup({required String name, String? description}) async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final groupRes = await _client
          .from('groups')
          .insert({
            'name': name,
            'description': description,
            'owner_id': uid,
          })
          .select('id, name, description')
          .single();

      final groupId = groupRes['id'] as String;

      await _client.from('group_members').insert({
        'group_id': groupId,
        'user_id': uid,
        'role': 'owner',
      });

      return StudyGroup(
        id: groupId,
        name: name,
        description: description,
        role: 'owner',
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> joinGroup(String inviteCode) async {
    final uid = currentUserId;
    if (uid == null) return false;

    try {
      final groupRes = await _client
          .from('groups')
          .select('id')
          .eq('invite_code', inviteCode.trim())
          .maybeSingle();

      if (groupRes == null) return false;
      final groupId = groupRes['id'] as String;

      await _client.from('group_members').insert({
        'group_id': groupId,
        'user_id': uid,
        'role': 'member',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<ChatMessage>> fetchMessages(String groupId) async {
    try {
      final res = await _client
          .from('messages')
          .select('id, sender_id, body, created_at, profiles(display_name)')
          .eq('group_id', groupId)
          .order('created_at', ascending: true)
          .limit(100);

      final list = <ChatMessage>[];
      for (final row in (res as List<dynamic>)) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        list.add(ChatMessage(
          id: row['id'] as String,
          senderId: row['sender_id'] as String,
          senderName: (profile?['display_name'] as String?) ?? 'Student',
          body: row['body'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
        ));
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<ChatMessage?> sendMessage({required String groupId, required String body}) async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final res = await _client
          .from('messages')
          .insert({
            'group_id': groupId,
            'sender_id': uid,
            'body': body,
          })
          .select('id, sender_id, body, created_at')
          .single();

      return ChatMessage(
        id: res['id'] as String,
        senderId: uid,
        senderName: 'You', // l10n-ok
        body: body,
        createdAt: DateTime.parse(res['created_at'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}
