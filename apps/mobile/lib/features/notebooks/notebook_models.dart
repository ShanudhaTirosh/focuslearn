class Notebook {
  const Notebook({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    this.color = '#4F46E5',
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String color;
  final DateTime createdAt;

  factory Notebook.fromJson(Map<String, dynamic> json) {
    return Notebook(
      id: json['id'] as String,
      ownerId: (json['owner_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Untitled Notebook',
      description: json['description'] as String?,
      color: (json['color'] as String?) ?? '#4F46E5',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class NotebookSource {
  const NotebookSource({
    required this.id,
    required this.notebookId,
    required this.sourceType,
    required this.title,
    this.r2Key,
    this.charCount = 0,
    this.pageCount = 1,
    this.status = 'ready',
    required this.createdAt,
  });

  final String id;
  final String notebookId;
  final String sourceType;
  final String title;
  final String? r2Key;
  final int charCount;
  final int pageCount;
  final String status;
  final DateTime createdAt;

  factory NotebookSource.fromJson(Map<String, dynamic> json) {
    return NotebookSource(
      id: json['id'] as String,
      notebookId: json['notebook_id'] as String,
      sourceType: (json['source_type'] as String?) ?? 'note',
      title: (json['title'] as String?) ?? 'Source Document',
      r2Key: json['r2_key'] as String?,
      charCount: (json['char_count'] as int?) ?? 0,
      pageCount: (json['page_count'] as int?) ?? 1,
      status: (json['status'] as String?) ?? 'ready',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class NotebookCitation {
  const NotebookCitation({
    required this.sourceTitle,
    required this.pageNumber,
    required this.snippet,
  });

  final String sourceTitle;
  final int pageNumber;
  final String snippet;

  factory NotebookCitation.fromJson(Map<String, dynamic> json) {
    return NotebookCitation(
      sourceTitle: (json['sourceTitle'] as String?) ?? 'Source',
      pageNumber: (json['pageNumber'] as int?) ?? 1,
      snippet: (json['snippet'] as String?) ?? '',
    );
  }
}

class NotebookChatMessage {
  const NotebookChatMessage({
    required this.id,
    required this.notebookId,
    required this.role,
    required this.content,
    this.citations = const [],
    required this.createdAt,
  });

  final String id;
  final String notebookId;
  final String role; // 'user' or 'assistant'
  final String content;
  final List<NotebookCitation> citations;
  final DateTime createdAt;

  factory NotebookChatMessage.fromJson(Map<String, dynamic> json) {
    final rawCitations = json['citations'];
    final citList = <NotebookCitation>[];
    if (rawCitations is List) {
      for (final c in rawCitations) {
        if (c is Map<String, dynamic>) {
          citList.add(NotebookCitation.fromJson(c));
        }
      }
    }

    return NotebookChatMessage(
      id: json['id'] as String,
      notebookId: json['notebook_id'] as String,
      role: (json['role'] as String?) ?? 'assistant',
      content: (json['content'] as String?) ?? '',
      citations: citList,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class StudyArtifact {
  const StudyArtifact({
    required this.id,
    required this.notebookId,
    required this.artifactType,
    required this.title,
    required this.data,
    required this.createdAt,
  });

  final String id;
  final String notebookId;
  final String artifactType; // 'guide', 'flashcards', 'quiz', 'audio_overview'
  final String title;
  final dynamic data;
  final DateTime createdAt;

  factory StudyArtifact.fromJson(Map<String, dynamic> json) {
    return StudyArtifact(
      id: json['id'] as String,
      notebookId: json['notebook_id'] as String,
      artifactType: (json['artifact_type'] as String?) ?? 'guide',
      title: (json['title'] as String?) ?? 'Study Guide',
      data: json['data'],
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
