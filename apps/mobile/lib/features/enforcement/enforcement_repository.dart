import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import 'enforcement_models.dart';

final enforcementRepositoryProvider = Provider<EnforcementRepository>((ref) {
  return EnforcementRepository(ref.watch(supabaseClientProvider));
});

final activePoliciesProvider = FutureProvider.autoDispose<List<EnforcementPolicy>>((ref) {
  return ref.watch(enforcementRepositoryProvider).loadPolicies();
});

final violationsHistoryProvider = FutureProvider.autoDispose<List<PolicyViolation>>((ref) {
  return ref.watch(enforcementRepositoryProvider).loadViolations();
});

final overridesHistoryProvider = FutureProvider.autoDispose<List<PolicyOverride>>((ref) {
  return ref.watch(enforcementRepositoryProvider).loadOverrides();
});

class EnforcementRepository {
  EnforcementRepository(this._supabase);

  final SupabaseClient _supabase;
  static const String _prefPoliciesKey = 'focuslearn_enforcement_policies';
  static const String _prefViolationsKey = 'focuslearn_policy_violations';
  static const String _prefOverridesKey = 'focuslearn_policy_overrides';

  Future<List<EnforcementPolicy>> loadCachedPolicies() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefPoliciesKey);
    if (raw == null || raw.isEmpty) return <EnforcementPolicy>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => EnforcementPolicy.fromJson(item as Map<String, dynamic>)).toList();
    } on Object {
      return <EnforcementPolicy>[];
    }
  }

  Future<void> saveCachedPolicies(List<EnforcementPolicy> policies) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(policies.map((p) => p.toJson()).toList());
    await prefs.setString(_prefPoliciesKey, raw);
  }

  Future<List<EnforcementPolicy>> loadPolicies() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase
            .from('enforcement_policies')
            .select('*')
            .eq('student_id', user.id)
            .eq('active', true);
        final remote = (data as List<dynamic>)
            .map((item) => EnforcementPolicy.fromJson(item as Map<String, dynamic>))
            .toList();
        await saveCachedPolicies(remote);
        return remote;
      } on Object {
        // Fall back to offline cache
      }
    }
    return loadCachedPolicies();
  }

  Future<EnforcementPolicy> createPolicy({
    required String title,
    required String mode,
    required List<String> blockedPackages,
    List<String> allowedPackages = const [],
    List<int> scheduleDays = const [],
    String? startTime,
    String? endTime,
    int dailyLimitMinutes = 0,
    bool allowEmergencyOverride = true,
  }) async {
    final user = _supabase.auth.currentUser;
    final policy = EnforcementPolicy(
      id: 'loc-${DateTime.now().millisecondsSinceEpoch}',
      studentId: user?.id ?? 'offline',
      creatorId: user?.id ?? 'offline',
      title: title,
      mode: mode,
      blockedPackages: blockedPackages,
      allowedPackages: allowedPackages,
      scheduleDays: scheduleDays,
      startTime: startTime,
      endTime: endTime,
      dailyLimitMinutes: dailyLimitMinutes,
      allowEmergencyOverride: allowEmergencyOverride,
      active: true,
      createdAt: DateTime.now(),
    );

    if (user != null) {
      try {
        final res = await _supabase.from('enforcement_policies').insert(<String, dynamic>{
          'student_id': user.id,
          'creator_id': user.id,
          'title': title,
          'mode': mode,
          'blocked_packages': blockedPackages,
          'allowed_packages': allowedPackages,
          'schedule_days': scheduleDays,
          'start_time': startTime,
          'end_time': endTime,
          'daily_limit_minutes': dailyLimitMinutes,
          'allow_emergency_override': allowEmergencyOverride,
          'active': true,
        }).select('*').single();

        final remotePolicy = EnforcementPolicy.fromJson(res);
        final cached = await loadCachedPolicies();
        cached.add(remotePolicy);
        await saveCachedPolicies(cached);
        return remotePolicy;
      } on Object {
        // Cached locally
      }
    }

    final cached = await loadCachedPolicies();
    cached.add(policy);
    await saveCachedPolicies(cached);
    return policy;
  }

  Future<List<PolicyViolation>> loadViolations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefViolationsKey);
    List<PolicyViolation> local = <PolicyViolation>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        local = list.map((item) => PolicyViolation.fromJson(item as Map<String, dynamic>)).toList();
      } on Object {
        local = <PolicyViolation>[];
      }
    }

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase
            .from('policy_violations')
            .select('*')
            .eq('student_id', user.id)
            .order('occurred_at', ascending: false)
            .limit(50);
        final remote = (data as List<dynamic>)
            .map((item) => PolicyViolation.fromJson(item as Map<String, dynamic>))
            .toList();
        return remote;
      } on Object {
        // Return local if offline
      }
    }
    return local;
  }

  Future<void> recordViolation({
    String? policyId,
    required String deviceId,
    required String packageName,
    required String violationType,
  }) async {
    final user = _supabase.auth.currentUser;
    final violation = PolicyViolation(
      id: 'viol-${DateTime.now().millisecondsSinceEpoch}',
      studentId: user?.id ?? 'offline',
      policyId: policyId,
      deviceId: deviceId,
      packageName: packageName,
      violationType: violationType,
      occurredAt: DateTime.now().toUtc(),
      synced: false,
    );

    // Save to local queue
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefViolationsKey);
    final list = raw != null && raw.isNotEmpty
        ? (jsonDecode(raw) as List<dynamic>).map((e) => PolicyViolation.fromJson(e as Map<String, dynamic>)).toList()
        : <PolicyViolation>[];
    list.insert(0, violation);
    await prefs.setString(_prefViolationsKey, jsonEncode(list.map((v) => v.toJson()).toList()));

    // Attempt remote sync if authenticated
    if (user != null) {
      try {
        await _supabase.from('policy_violations').insert(<String, dynamic>{
          'student_id': user.id,
          'policy_id': policyId,
          'device_id': deviceId,
          'package_name': packageName,
          'violation_type': violationType,
          'occurred_at': violation.occurredAt.toIso8601String(),
        });
        // Mark as synced
        list[0] = list[0].copyWith(synced: true);
        await prefs.setString(_prefViolationsKey, jsonEncode(list.map((v) => v.toJson()).toList()));
      } on Object {
        // Stored locally in queue
      }
    }
  }

  Future<List<PolicyOverride>> loadOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefOverridesKey);
    List<PolicyOverride> local = <PolicyOverride>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        local = list.map((item) => PolicyOverride.fromJson(item as Map<String, dynamic>)).toList();
      } on Object {
        local = <PolicyOverride>[];
      }
    }

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase
            .from('policy_overrides')
            .select('*')
            .eq('student_id', user.id)
            .order('created_at', ascending: false)
            .limit(50);
        final remote = (data as List<dynamic>)
            .map((item) => PolicyOverride.fromJson(item as Map<String, dynamic>))
            .toList();
        return remote;
      } on Object {
        // Return local if offline
      }
    }
    return local;
  }

  Future<void> recordOverride({
    String? policyId,
    required String reason,
    int durationMinutes = 15,
  }) async {
    final user = _supabase.auth.currentUser;
    final override = PolicyOverride(
      id: 'ovr-${DateTime.now().millisecondsSinceEpoch}',
      studentId: user?.id ?? 'offline',
      policyId: policyId,
      reason: reason,
      durationMinutes: durationMinutes,
      createdAt: DateTime.now().toUtc(),
    );

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefOverridesKey);
    final list = raw != null && raw.isNotEmpty
        ? (jsonDecode(raw) as List<dynamic>).map((e) => PolicyOverride.fromJson(e as Map<String, dynamic>)).toList()
        : <PolicyOverride>[];
    list.insert(0, override);
    await prefs.setString(_prefOverridesKey, jsonEncode(list.map((o) => o.toJson()).toList()));

    if (user != null) {
      try {
        await _supabase.from('policy_overrides').insert(<String, dynamic>{
          'student_id': user.id,
          'policy_id': policyId,
          'reason': reason,
          'duration_minutes': durationMinutes,
          'created_at': override.createdAt.toIso8601String(),
        });
      } on Object {
        // Stored locally
      }
    }
  }

  /// Checks whether a given package is blocked under active policies.
  bool isPackageRestricted(String packageName, List<EnforcementPolicy> policies) {
    if (packageName.isEmpty || packageName == 'com.shanutechx.focuslearn') return false;

    final now = DateTime.now();
    for (final policy in policies) {
      if (!policy.active) continue;

      // Check schedule if configured
      if (policy.scheduleDays.isNotEmpty && !policy.scheduleDays.contains(now.weekday)) {
        continue;
      }

      // Check blocked packages
      if (policy.blockedPackages.contains(packageName)) {
        return true;
      }
    }
    return false;
  }
}
