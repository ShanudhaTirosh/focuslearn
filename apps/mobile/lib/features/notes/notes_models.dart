/// Model for student study notes.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.subjectId,
    this.folder,
    this.tags = const <String>[],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final String? subjectId;
  final String? folder;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'subject_id': subjectId,
        'folder': folder,
        'tags': tags,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        body: (json['body'] as String?) ?? '',
        subjectId: json['subject_id'] as String?,
        folder: json['folder'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? const <String>[],
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Note copyWith({
    String? title,
    String? body,
    String? subjectId,
    String? folder,
    List<String>? tags,
    DateTime? updatedAt,
  }) =>
      Note(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        subjectId: subjectId ?? this.subjectId,
        folder: folder ?? this.folder,
        tags: tags ?? this.tags,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

