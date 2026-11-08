import 'package:timezone/timezone.dart' as tz;

import 'zone.dart';

/// A [ZoneResolver] for an IANA zone name such as `Asia/Colombo`. Call `initializeTimeZones()` from
/// `package:timezone/data/latest.dart` once at start-up first (the app does this; so does the test).
ZoneResolver zoneResolverFor(String name) {
  final location = tz.getLocation(name);
  // TimeZone.offset is in milliseconds (verify against the package version in use).
  return OffsetZoneResolver((ms) => location.timeZone(ms).offset ~/ 60000);
}
