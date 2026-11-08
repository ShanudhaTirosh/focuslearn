/// Models for Planner, Subjects, Events, Recurrences, and Assignments.
class Subject {
  const Subject({
    required this.id,
    required this.name,
    this.color = 'primary',
    this.stream = 'other',
    this.createdAt,
  });

  final String id;
  final String name;
  final String color;
  final String stream;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'color': color,
        'stream': stream,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'] as String,
        name: json['name'] as String,
        color: (json['color'] as String?) ?? 'primary',
        stream: (json['stream'] as String?) ?? 'other',
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      );
}

class TimetableEvent {
  const TimetableEvent({
    required this.id,
    required this.title,
    required this.startUtc,
    required this.endUtc,
    this.ianaTz = 'Asia/Colombo',
    this.category = 'class',
    this.visibility = 'private',
    this.meetingUrl,
    this.subjectId,
    this.location,
    this.notes,
    this.rrule,
    this.createdAt,
  });

  final String id;
  final String title;
  final DateTime startUtc;
  final DateTime endUtc;
  final String ianaTz;
  final String category;
  final String visibility;
  final String? meetingUrl;
  final String? subjectId;
  final String? location;
  final String? notes;
  final String? rrule;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'start_utc': startUtc.toIso8601String(),
        'end_utc': endUtc.toIso8601String(),
        'iana_tz': ianaTz,
        'category': category,
        'visibility': visibility,
        'meeting_url': meetingUrl,
        'subject_id': subjectId,
        'location': location,
        'notes': notes,
        'rrule': rrule,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  factory TimetableEvent.fromJson(Map<String, dynamic> json) => TimetableEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        startUtc: DateTime.parse(json['start_utc'] as String),
        endUtc: DateTime.parse(json['end_utc'] as String),
        ianaTz: (json['iana_tz'] as String?) ?? 'Asia/Colombo',
        category: (json['category'] as String?) ?? 'class',
        visibility: (json['visibility'] as String?) ?? 'private',
        meetingUrl: json['meeting_url'] as String?,
        subjectId: json['subject_id'] as String?,
        location: json['location'] as String?,
        notes: json['notes'] as String?,
        rrule: json['rrule'] as String?,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      );
}

class Assignment {
  const Assignment({
    required this.id,
    required this.title,
    this.details,
    required this.dueUtc,
    this.subjectId,
    this.status = 'pending',
    this.createdAt,
  });

  final String id;
  final String title;
  final String? details;
  final DateTime dueUtc;
  final String? subjectId;
  final String status; // 'pending' or 'completed'
  final DateTime? createdAt;

  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'details': details,
        'due_utc': dueUtc.toIso8601String(),
        'subject_id': subjectId,
        'status': status,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: json['id'] as String,
        title: json['title'] as String,
        details: json['details'] as String?,
        dueUtc: DateTime.parse(json['due_utc'] as String),
        subjectId: json['subject_id'] as String?,
        status: (json['status'] as String?) ?? 'pending',
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      );

  Assignment copyWith({
    String? title,
    String? details,
    DateTime? dueUtc,
    String? subjectId,
    String? status,
  }) =>
      Assignment(
        id: id,
        title: title ?? this.title,
        details: details ?? this.details,
        dueUtc: dueUtc ?? this.dueUtc,
        subjectId: subjectId ?? this.subjectId,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}

/// An occurrence of a recurring or single event on a specific day.
class ExpandedEvent {
  const ExpandedEvent({
    required this.event,
    required this.start,
    required this.end,
    this.isOverride = false,
  });

  final TimetableEvent event;
  final DateTime start;
  final DateTime end;
  final bool isOverride;
}

