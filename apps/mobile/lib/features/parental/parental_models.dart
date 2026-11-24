library parental_models;

/// Models for child device management and parental configuration.

class DeviceConfig {
  const DeviceConfig({
    required this.id,
    required this.deviceId,
    required this.parentId,
    this.dailyScreenTimeLimitMinutes = 480,
    this.bedtimeStart,
    this.bedtimeEnd,
    this.scheduleDays = const <int>[1, 2, 3, 4, 5],
    this.studyStart,
    this.studyEnd,
    this.blockedPackages = const <String>[],
    this.allowedPackages = const <String>[],
    this.websiteBlocklist = const <String>[],
    this.websiteAllowlist = const <String>[],
    this.focusModeEnabled = false,
    this.lastSyncedAt,
  });

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    return DeviceConfig(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      parentId: json['parent_id'] as String,
      dailyScreenTimeLimitMinutes: (json['daily_screen_time_limit_minutes'] as num?)?.toInt() ?? 480,
      bedtimeStart: json['bedtime_start'] as String?,
      bedtimeEnd: json['bedtime_end'] as String?,
      scheduleDays: (json['schedule_days'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ??
          const <int>[1, 2, 3, 4, 5],
      studyStart: json['study_start'] as String?,
      studyEnd: json['study_end'] as String?,
      blockedPackages: (json['blocked_packages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      allowedPackages: (json['allowed_packages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      websiteBlocklist: (json['website_blocklist'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      websiteAllowlist: (json['website_allowlist'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      focusModeEnabled: json['focus_mode_enabled'] as bool? ?? false,
      lastSyncedAt: json['last_synced_at'] != null ? DateTime.tryParse(json['last_synced_at'] as String) : null,
    );
  }

  final String id;
  final String deviceId;
  final String parentId;
  final int dailyScreenTimeLimitMinutes;
  final String? bedtimeStart;
  final String? bedtimeEnd;
  final List<int> scheduleDays;
  final String? studyStart;
  final String? studyEnd;
  final List<String> blockedPackages;
  final List<String> allowedPackages;
  final List<String> websiteBlocklist;
  final List<String> websiteAllowlist;
  final bool focusModeEnabled;
  final DateTime? lastSyncedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'device_id': deviceId,
        'parent_id': parentId,
        'daily_screen_time_limit_minutes': dailyScreenTimeLimitMinutes,
        'bedtime_start': bedtimeStart,
        'bedtime_end': bedtimeEnd,
        'schedule_days': scheduleDays,
        'study_start': studyStart,
        'study_end': studyEnd,
        'blocked_packages': blockedPackages,
        'allowed_packages': allowedPackages,
        'website_blocklist': websiteBlocklist,
        'website_allowlist': websiteAllowlist,
        'focus_mode_enabled': focusModeEnabled,
        if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt!.toIso8601String(),
      };
}

class RemoteCommand {
  const RemoteCommand({
    required this.id,
    required this.deviceId,
    required this.parentId,
    required this.commandType,
    required this.payload,
    required this.status,
    this.createdAt,
    this.expiresAt,
  });

  factory RemoteCommand.fromJson(Map<String, dynamic> json) {
    return RemoteCommand(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      parentId: json['parent_id'] as String,
      commandType: json['command_type'] as String,
      payload: (json['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
    );
  }

  final String id;
  final String deviceId;
  final String parentId;
  final String commandType;
  final Map<String, dynamic> payload;
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'device_id': deviceId,
        'parent_id': parentId,
        'command_type': commandType,
        'payload': payload,
        'status': status,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      };
}

class ParentLinkStatus {
  const ParentLinkStatus({
    required this.isLinked,
    this.linkId,
    this.familyId,
    this.parentId,
    this.childDisplayName,
    this.status = 'none',
  });

  final bool isLinked;
  final String? linkId;
  final String? familyId;
  final String? parentId;
  final String? childDisplayName;
  final String status;

  static const ParentLinkStatus unlinked = ParentLinkStatus(isLinked: false);
}
