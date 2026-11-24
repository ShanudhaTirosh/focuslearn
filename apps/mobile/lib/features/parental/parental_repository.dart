import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../platform/platform_channel.dart';
import 'parental_models.dart';

final parentalRepositoryProvider = Provider<ParentalRepository>((ref) {
  return ParentalRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(nativePlatformServiceProvider),
  );
});

final parentLinkStatusProvider = FutureProvider.autoDispose<ParentLinkStatus>((ref) {
  return ref.watch(parentalRepositoryProvider).checkLinkStatus();
});

final deviceConfigProvider = FutureProvider.autoDispose<DeviceConfig?>((ref) async {
  return ref.watch(parentalRepositoryProvider).loadConfig();
});

class ParentalRepository {
  ParentalRepository(this._supabase, this._nativePlatform);

  final SupabaseClient _supabase;
  final NativePlatformService _nativePlatform;

  static const String _prefConfigKey = 'focuslearn_device_config';
  static const String _prefPairKey = 'focuslearn_parent_link';

  Future<ParentLinkStatus> checkLinkStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return ParentLinkStatus.unlinked;

    try {
      final res = await _supabase
          .from('parent_child_links')
          .select('id, family_id, parent_id, display_name, status')
          .eq('child_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      if (res != null) {
        final status = ParentLinkStatus(
          isLinked: true,
          linkId: res['id'] as String,
          familyId: res['family_id'] as String,
          parentId: res['parent_id'] as String,
          childDisplayName: res['display_name'] as String?,
          status: 'active',
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefPairKey, jsonEncode({
          'isLinked': true,
          'linkId': status.linkId,
          'familyId': status.familyId,
          'parentId': status.parentId,
          'childDisplayName': status.childDisplayName,
        }));
        return status;
      }
    } on Object {
      // Offline fallback
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefPairKey);
    if (cached != null) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        return ParentLinkStatus(
          isLinked: map['isLinked'] as bool? ?? false,
          linkId: map['linkId'] as String?,
          familyId: map['familyId'] as String?,
          parentId: map['parentId'] as String?,
          childDisplayName: map['childDisplayName'] as String?,
          status: 'active',
        );
      } on Object {
        return ParentLinkStatus.unlinked;
      }
    }

    return ParentLinkStatus.unlinked;
  }

  /// Pairs this device/account with a parent using a 6-digit code.
  Future<bool> pairWithCode(String code) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('User must be signed in to pair');

    final cleanCode = code.trim();
    if (cleanCode.length != 6) throw ArgumentError('Pairing code must be 6 digits');

    // Query parent_child_links matching this code
    final link = await _supabase
        .from('parent_child_links')
        .select('*')
        .eq('pairing_code', cleanCode)
        .eq('status', 'pending')
        .maybeSingle();

    if (link == null) {
      return false;
    }

    // Update child_id and activate link
    await _supabase
        .from('parent_child_links')
        .update({
          'child_id': user.id,
          'status': 'active',
          'pairing_code': null,
        })
        .eq('id', link['id'] as String);

    return true;
  }

  Future<DeviceConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefConfigKey);
    DeviceConfig? local;
    if (raw != null && raw.isNotEmpty) {
      try {
        local = DeviceConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } on Object {
        local = null;
      }
    }

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        // Find device for this user
        final dev = await _supabase
            .from('devices')
            .select('id')
            .eq('user_id', user.id)
            .filter('revoked_at', 'is', null)
            .maybeSingle();

        if (dev != null) {
          final res = await _supabase
              .from('device_configs')
              .select('*')
              .eq('device_id', dev['id'] as String)
              .maybeSingle();

          if (res != null) {
            final remote = DeviceConfig.fromJson(res);
            await prefs.setString(_prefConfigKey, jsonEncode(remote.toJson()));
            return remote;
          }
        }
      } on Object {
        // Return local if offline
      }
    }
    return local;
  }

  /// Synchronizes device configurations and commands via device-sync function.
  Future<List<RemoteCommand>> syncDevice(String deviceId) async {
    try {
      final res = await _supabase.functions.invoke('device-sync', body: {
        'deviceId': deviceId,
      });

      if (res.data != null && res.data['success'] == true) {
        final configJson = res.data['config'] as Map<String, dynamic>?;
        if (configJson != null) {
          final config = DeviceConfig.fromJson(configJson);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefConfigKey, jsonEncode(config.toJson()));
        }

        final rawCmds = res.data['commands'] as List<dynamic>?;
        if (rawCmds != null) {
          return rawCmds
              .map((c) => RemoteCommand.fromJson(c as Map<String, dynamic>))
              .toList();
        }
      }
    } on Object {
      // Sync failed, return empty
    }
    return const [];
  }

  /// Sends periodic device heartbeat to the backend.
  Future<bool> sendHeartbeat(String deviceId, {String? appVersion}) async {
    try {
      final battery = await _nativePlatform.getBatteryStatus();
      final network = await _nativePlatform.getNetworkType();

      final res = await _supabase.functions.invoke('device-heartbeat', body: {
        'deviceId': deviceId,
        'batteryLevel': battery['level'],
        'isCharging': battery['isCharging'],
        'networkType': network,
        'appVersion': appVersion ?? '0.1.0',
      });

      return res.data != null && res.data['success'] == true;
    } on Object {
      return false;
    }
  }

  /// Reports aggregated daily screen time and package usage to Supabase.
  Future<void> reportDailyUsage(String deviceId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final stats = await _nativePlatform.getAppUsageSummary();
      if (stats.isEmpty) return;

      int totalMinutes = 0;
      final breakdown = <String, int>{};
      final today = DateTime.now().toIso8601String().substring(0, 10);

      for (final item in stats) {
        final pkg = item['packageName']?.toString() ?? '';
        final mins = (item['minutes'] as num?)?.toInt() ?? 0;
        final label = item['appLabel']?.toString() ?? pkg;
        totalMinutes += mins;
        if (pkg.isNotEmpty) {
          breakdown[pkg] = mins;
          // Upsert into app_usage_records
          await _supabase.from('app_usage_records').upsert({
            'device_id': deviceId,
            'child_id': user.id,
            'package_name': pkg,
            'app_label': label,
            'usage_date': today,
            'total_minutes': mins,
            'session_count': 1,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'device_id, package_name, usage_date');
        }
      }

      // Upsert into screen_time_records
      await _supabase.from('screen_time_records').upsert({
        'device_id': deviceId,
        'child_id': user.id,
        'record_date': today,
        'total_minutes': totalMinutes,
        'app_breakdown': breakdown,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'device_id, record_date');
    } on Object {
      // Offline fallback: usage will sync on next cycle
    }
  }

  /// Acknowledges and updates remote command execution result.
  Future<void> acknowledgeCommand(String commandId, {required bool success, String? error}) async {
    try {
      await _supabase.from('remote_commands').update({
        'status': success ? 'executed' : 'failed',
        'executed_at': DateTime.now().toUtc().toIso8601String(),
        if (error != null) 'error_message': error,
      }).eq('id', commandId);
    } on Object {
      // Ignored
    }
  }
}
