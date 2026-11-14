/// Enforcement models for supervised and voluntary focus rules.
class EnforcementPolicy {
  const EnforcementPolicy({
    required this.id,
    required this.studentId,
    required this.creatorId,
    required this.title,
    required this.mode,
    required this.blockedPackages,
    required this.allowedPackages,
    required this.scheduleDays,
    this.startTime,
    this.endTime,
    this.dailyLimitMinutes = 0,
    this.allowEmergencyOverride = true,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory EnforcementPolicy.fromJson(Map<String, dynamic> json) {
    return EnforcementPolicy(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      creatorId: json['creator_id'] as String,
      title: json['title'] as String,
      mode: json['mode'] as String,
      blockedPackages: (json['blocked_packages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[],
      allowedPackages: (json['allowed_packages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[],
      scheduleDays: (json['schedule_days'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? <int>[],
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      dailyLimitMinutes: (json['daily_limit_minutes'] as num?)?.toInt() ?? 0,
      allowEmergencyOverride: json['allow_emergency_override'] as bool? ?? true,
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  final String id;
  final String studentId;
  final String creatorId;
  final String title;
  final String mode;
  final List<String> blockedPackages;
  final List<String> allowedPackages;
  final List<int> scheduleDays;
  final String? startTime;
  final String? endTime;
  final int dailyLimitMinutes;
  final bool allowEmergencyOverride;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'student_id': studentId,
        'creator_id': creatorId,
        'title': title,
        'mode': mode,
        'blocked_packages': blockedPackages,
        'allowed_packages': allowedPackages,
        'schedule_days': scheduleDays,
        'start_time': startTime,
        'end_time': endTime,
        'daily_limit_minutes': dailyLimitMinutes,
        'allow_emergency_override': allowEmergencyOverride,
        'active': active,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };
}

class PolicyViolation {
  const PolicyViolation({
    required this.id,
    required this.studentId,
    this.policyId,
    required this.deviceId,
    required this.packageName,
    required this.violationType,
    required this.occurredAt,
    this.synced = true,
  });

  factory PolicyViolation.fromJson(Map<String, dynamic> json) {
    return PolicyViolation(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      policyId: json['policy_id'] as String?,
      deviceId: json['device_id'] as String,
      packageName: json['package_name'] as String,
      violationType: json['violation_type'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      synced: json['synced'] as bool? ?? true,
    );
  }

  final String id;
  final String studentId;
  final String? policyId;
  final String deviceId;
  final String packageName;
  final String violationType;
  final DateTime occurredAt;
  final bool synced;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'student_id': studentId,
        'policy_id': policyId,
        'device_id': deviceId,
        'package_name': packageName,
        'violation_type': violationType,
        'occurred_at': occurredAt.toIso8601String(),
        'synced': synced,
      };

  PolicyViolation copyWith({bool? synced}) => PolicyViolation(
        id: id,
        studentId: studentId,
        policyId: policyId,
        deviceId: deviceId,
        packageName: packageName,
        violationType: violationType,
        occurredAt: occurredAt,
        synced: synced ?? this.synced,
      );
}

class PolicyOverride {
  const PolicyOverride({
    required this.id,
    required this.studentId,
    this.policyId,
    required this.reason,
    required this.durationMinutes,
    required this.createdAt,
  });

  factory PolicyOverride.fromJson(Map<String, dynamic> json) {
    return PolicyOverride(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      policyId: json['policy_id'] as String?,
      reason: json['reason'] as String,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 15,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String studentId;
  final String? policyId;
  final String reason;
  final int durationMinutes;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'student_id': studentId,
        'policy_id': policyId,
        'reason': reason,
        'duration_minutes': durationMinutes,
        'created_at': createdAt.toIso8601String(),
      };
}
