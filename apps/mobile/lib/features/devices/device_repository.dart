import 'dart:io' show Platform;
import 'dart:math';

import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.installId,
    required this.platform,
    required this.name,
    required this.lastSeenAt,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        id: json['id'] as String,
        installId: json['install_id'] as String,
        platform: json['platform'] as String,
        name: json['name'] as String,
        lastSeenAt: DateTime.parse(json['last_seen_at'] as String).toLocal(),
      );

  final String id;
  final String installId;
  final String platform;
  final String name;
  final DateTime lastSeenAt;
}

enum DeviceRegistration { registered, revoked, unsupported }

/// The user-facing "my devices" list. It is NOT the list of real sessions (those live in the Auth service).
class DeviceRepository {
  DeviceRepository(this._client);

  static const String _installKey = 'focuslearn_install_id';

  final SupabaseClient _client;

  /// A random id created once per installation. It is not a hardware identifier.
  Future<String> installId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_installKey);
    if (existing != null) {
      return existing;
    }
    final id = generateUuidV4(Random.secure());
    await prefs.setString(_installKey, id);
    return id;
  }

  Future<void> _clearInstallId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_installKey);
  }

  String? get _platform {
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isWindows) {
      return 'windows';
    }
    return null;
  }

  String get _defaultName => Platform.isAndroid ? 'Android phone' : 'Windows PC';

  /// Registers or refreshes this installation. Returns [DeviceRegistration.revoked] if the user removed this device
  /// from another one: the caller should sign out. The install id is reset so a later sign-in creates a fresh entry.
  Future<DeviceRegistration> registerThisDevice({required String appVersion}) async {
    final platform = _platform;
    if (platform == null) {
      return DeviceRegistration.unsupported;
    }
    final id = await installId();
    final row = await _client.from('devices').select('id, revoked_at').eq('install_id', id).maybeSingle();
    if (row == null) {
      await _client.from('devices').insert(<String, dynamic>{
        'install_id': id,
        'platform': platform,
        'name': _defaultName,
        'app_version': appVersion,
      });
      return DeviceRegistration.registered;
    }
    if (row['revoked_at'] != null) {
      await _clearInstallId();
      return DeviceRegistration.revoked;
    }
    await _client.from('devices').update(<String, dynamic>{
      'app_version': appVersion,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', row['id'] as String);
    return DeviceRegistration.registered;
  }

  Future<List<DeviceInfo>> listMine() async {
    final rows = await _client.from('devices').select().filter('revoked_at', 'is', null).order('last_seen_at', ascending: false);
    return rows.map(DeviceInfo.fromJson).toList();
  }

  Future<void> remove(String deviceId) async {
    await _client.from('devices').update(<String, dynamic>{'revoked_at': DateTime.now().toUtc().toIso8601String()}).eq('id', deviceId);
  }
}
