import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import 'notebook_models.dart';

final notebookRepositoryProvider = Provider<NotebookRepository>((ref) {
  return NotebookRepository(ref.watch(supabaseClientProvider));
});

final myNotebooksProvider = FutureProvider.autoDispose<List<Notebook>>((ref) {
  return ref.watch(notebookRepositoryProvider).fetchNotebooks();
});

class NotebookRepository {
  NotebookRepository(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<Notebook>> fetchNotebooks() async {
    final uid = currentUserId;
    if (uid == null) return const [];

    try {
      final res = await _client
        .from('notebooks')
        .select()
        .order('created_at', ascending: false);

      final list = <Notebook>[];
      for (final row in (res as List<dynamic>)) {
        list.add(Notebook.fromJson(row as Map<String, dynamic>));
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<Notebook?> createNotebook({
    required String title,
    String? description,
    String color = '#4F46E5',
  }) async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final res = await _client
        .from('notebooks')
        .insert({
          'owner_id': uid,
          'title': title,
          'description': description,
          'color': color,
        })
        .select()
        .single();

      return Notebook.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteNotebook(String notebookId) async {
    try {
      await _client.from('notebooks').delete().eq('id', notebookId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<NotebookSource>> fetchSources(String notebookId) async {
    try {
      final res = await _client
        .from('notebook_sources')
        .select()
        .eq('notebook_id', notebookId)
        .order('created_at', ascending: true);

      final list = <NotebookSource>[];
      for (final row in (res as List<dynamic>)) {
        list.add(NotebookSource.fromJson(row as Map<String, dynamic>));
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<NotebookSource?> addTextSource({
    required String notebookId,
    required String title,
    required String content,
  }) async {
    try {
      final sourceRes = await _client
        .from('notebook_sources')
        .insert({
          'notebook_id': notebookId,
          'source_type': 'text',
          'title': title,
          'char_count': content.length,
          'status': 'processing',
        })
        .select()
        .single();

      final source = NotebookSource.fromJson(sourceRes);

      // Trigger server chunking and embedding
      await _client.functions.invoke(
        'ai-notebook-rag',
        body: {
          'action': 'index_source',
          'notebookId': notebookId,
          'sourceId': source.id,
          'title': title,
          'text': content,
        },
      );

      return source;
    } catch (_) {
      return null;
    }
  }

  Future<List<NotebookChatMessage>> fetchChats(String notebookId) async {
    try {
      final res = await _client
        .from('notebook_chats')
        .select()
        .eq('notebook_id', notebookId)
        .order('created_at', ascending: true);

      final list = <NotebookChatMessage>[];
      for (final row in (res as List<dynamic>)) {
        list.add(NotebookChatMessage.fromJson(row as Map<String, dynamic>));
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<NotebookChatMessage?> askGroundedQuestion({
    required String notebookId,
    required String question,
  }) async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      // 1. Save user query in chat
      await _client.from('notebook_chats').insert({
        'notebook_id': notebookId,
        'user_id': uid,
        'role': 'user',
        'content': question,
      });

      // 2. Call RAG Edge function
      final edgeRes = await _client.functions.invoke(
        'ai-notebook-rag',
        body: {
          'action': 'grounded_chat',
          'notebookId': notebookId,
          'query': question,
        },
      );

      final data = edgeRes.data as Map<String, dynamic>?;
      final answer = (data?['answer'] as String?) ?? 'Unable to generate response from sources.';
      final rawCitations = data?['citations'] as List<dynamic>? ?? [];

      // 3. Save assistant response with citations
      final botMsgRes = await _client
        .from('notebook_chats')
        .insert({
          'notebook_id': notebookId,
          'user_id': uid,
          'role': 'assistant',
          'content': answer,
          'citations': rawCitations,
        })
        .select()
        .single();

      return NotebookChatMessage.fromJson(botMsgRes);
    } catch (e) {
      return null;
    }
  }

  Future<List<StudyArtifact>> fetchArtifacts(String notebookId) async {
    try {
      final res = await _client
        .from('study_artifacts')
        .select()
        .eq('notebook_id', notebookId)
        .order('created_at', ascending: false);

      final list = <StudyArtifact>[];
      for (final row in (res as List<dynamic>)) {
        list.add(StudyArtifact.fromJson(row as Map<String, dynamic>));
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<StudyArtifact?> generateArtifact({
    required String notebookId,
    required String artifactType, // 'guide', 'flashcards', 'quiz', 'audio_overview'
  }) async {
    try {
      final res = await _client.functions.invoke(
        'ai-notebook-rag',
        body: {
          'action': 'generate_artifact',
          'notebookId': notebookId,
          'artifactType': artifactType,
        },
      );

      final data = res.data as Map<String, dynamic>?;
      if (data != null && data.containsKey('artifact')) {
        return StudyArtifact.fromJson(data['artifact'] as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
