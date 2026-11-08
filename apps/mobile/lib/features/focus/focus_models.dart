/// A local or synced study session.
class StudySession {
  const StudySession({
    required this.clientUuid,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.clientReportedSeconds,
    this.pauseSeconds = 0,
    this.status = 'completed',
    this.validatedSeconds = 0,
    this.tree = 'none',
    this.counted = false,
    this.synced = false,
  });

  final String clientUuid;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedSeconds;
  final int clientReportedSeconds;
  final int pauseSeconds;
  final String status;
  final int validatedSeconds;
  final String tree;
  final bool counted;
  final bool synced;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'client_uuid': clientUuid,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'planned_s': plannedSeconds,
        'client_reported_s': clientReportedSeconds,
        'pause_s': pauseSeconds,
        'status': status,
        'validated_s': validatedSeconds,
        'tree': tree,
        'counted': counted,
        'synced': synced,
      };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        clientUuid: json['client_uuid'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: DateTime.parse(json['ended_at'] as String),
        plannedSeconds: json['planned_s'] as int,
        clientReportedSeconds: json['client_reported_s'] as int,
        pauseSeconds: (json['pause_s'] as int?) ?? 0,
        status: (json['status'] as String?) ?? 'completed',
        validatedSeconds: (json['validated_s'] as int?) ?? 0,
        tree: (json['tree'] as String?) ?? 'none',
        counted: (json['counted'] as bool?) ?? false,
        synced: (json['synced'] as bool?) ?? false,
      );

  StudySession copyWith({
    int? validatedSeconds,
    String? tree,
    bool? counted,
    bool? synced,
  }) =>
      StudySession(
        clientUuid: clientUuid,
        startedAt: startedAt,
        endedAt: endedAt,
        plannedSeconds: plannedSeconds,
        clientReportedSeconds: clientReportedSeconds,
        pauseSeconds: pauseSeconds,
        status: status,
        validatedSeconds: validatedSeconds ?? this.validatedSeconds,
        tree: tree ?? this.tree,
        counted: counted ?? this.counted,
        synced: synced ?? this.synced,
      );
}

/// Badge progress or status.
class BadgeStatus {
  const BadgeStatus({
    required this.kind,
    required this.name,
    required this.description,
    required this.earned,
  });

  final String kind;
  final String name;
  final String description;
  final bool earned;
}
