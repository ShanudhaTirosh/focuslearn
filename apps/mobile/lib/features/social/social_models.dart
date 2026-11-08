/// Models for social friendships, study groups, and group messaging.
class Friend {
  const Friend({
    required this.id,
    required this.displayName,
    this.stream = 'other',
    this.avatarKey,
  });

  final String id;
  final String displayName;
  final String stream;
  final String? avatarKey;

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        id: json['id'] as String,
        displayName: (json['display_name'] as String?) ?? 'Student',
        stream: (json['stream'] as String?) ?? 'other',
        avatarKey: json['avatar_key'] as String?,
      );
}

class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    this.description,
    this.role = 'member',
  });

  final String id;
  final String name;
  final String? description;
  final String role;

  factory StudyGroup.fromJson(Map<String, dynamic> json) => StudyGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        role: (json['role'] as String?) ?? 'member',
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        senderName: (json['sender_name'] as String?) ?? 'Student',
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

