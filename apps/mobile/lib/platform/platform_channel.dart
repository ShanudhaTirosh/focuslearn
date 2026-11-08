import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class NativePlatformService {
  const NativePlatformService();

  static const MethodChannel _channel = MethodChannel('com.shanutechx.focuslearn/platform');

  Future<bool> scheduleAlarm({
    required int id,
    required DateTime fireTime,
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final success = await _channel.invokeMethod<bool>('scheduleAlarm', {
        'id': id,
        'timestampUtc': fireTime.toUtc().millisecondsSinceEpoch,
        'title': title,
        'body': body,
      });
      return success ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> cancelAlarm(int id) async {
    if (!Platform.isAndroid) return false;
    try {
      final success = await _channel.invokeMethod<bool>('cancelAlarm', {
        'id': id,
      });
      return success ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> checkUsagePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('checkUsagePermission');
      return granted ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> openUsageSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final success = await _channel.invokeMethod<bool>('openUsageSettings');
      return success ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<List<Map<String, String>>> getInstalledApps() async {
    if (!Platform.isAndroid) return const [];
    try {
      final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>('getInstalledApps');
      if (result == null) return const [];
      return result.map((item) => {
        'name': item['name']?.toString() ?? '',
        'packageName': item['packageName']?.toString() ?? '',
      }).toList();
    } on PlatformException {
      return const [];
    }
  }

  Future<bool> setAlwaysOnTop(bool enabled) async {
    if (!Platform.isWindows) return false;
    try {
      final result = await _channel.invokeMethod<bool>('setAlwaysOnTop', {'enabled': enabled});
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}

