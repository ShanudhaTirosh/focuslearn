class Profile {
  const Profile({
    required this.userId,
    required this.displayName,
    required this.stream,
    required this.birthYear,
    required this.isDiscoverable,
    required this.timeZone,
    required this.subjects,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
        stream: json['stream'] as String,
        birthYear: json['birth_year'] as int,
        isDiscoverable: json['is_discoverable'] as bool,
        timeZone: json['tz'] as String,
        subjects: List<String>.from(json['subjects'] as List<dynamic>),
      );

  final String userId;
  final String displayName;
  final String stream;
  final int birthYear;
  final bool isDiscoverable;
  final String timeZone;
  final List<String> subjects;
}

class UserPreferences {
  const UserPreferences({required this.language, required this.theme});

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(language: json['language'] as String, theme: json['theme'] as String);

  static const UserPreferences defaults = UserPreferences(language: 'en', theme: 'system');

  final String language;
  final String theme;
}
