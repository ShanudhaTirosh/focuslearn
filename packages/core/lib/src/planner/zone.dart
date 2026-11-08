/// Wall-clock fields of an instant in some time zone.
class LocalTime {
  const LocalTime(this.year, this.month, this.day, this.hour, this.minute);

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;

  int get minutesOfDay => hour * 60 + minute;

  /// The calendar date as a UTC midnight [DateTime] (used only for date arithmetic).
  DateTime get date => DateTime.utc(year, month, day);
}

/// Converts between wall-clock time in one IANA zone and UTC.
abstract class ZoneResolver {
  /// A wall-clock time that does not exist (spring-forward gap) moves forward by the gap; one that happens twice
  /// (fall-back overlap) means the FIRST occurrence. This is the rule the Python reference and the vectors use.
  DateTime localToUtc(int year, int month, int day, int hour, int minute);

  LocalTime utcToLocal(DateTime utc);
}

/// Builds a [ZoneResolver] from one primitive: the UTC offset (in minutes) in force at an instant (milliseconds since epoch).
/// The gap and overlap rules are written here once, so they do not depend on how a time-zone package resolves ambiguity.
class OffsetZoneResolver implements ZoneResolver {
  OffsetZoneResolver(this.offsetMinutesAt);

  final int Function(int utcMillis) offsetMinutesAt;

  static const int _minute = 60000;
  static const int _day = 86400000;

  @override
  DateTime localToUtc(int year, int month, int day, int hour, int minute) {
    final asUtc = DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;
    final before = offsetMinutesAt(asUtc - _day);
    final after = offsetMinutesAt(asUtc + _day);
    final valid = <int>[];
    for (final offset in <int>{before, after}) {
      final utc = asUtc - offset * _minute;
      if (offsetMinutesAt(utc) == offset) {
        valid.add(utc);
      }
    }
    if (valid.isEmpty) {
      // In the gap: keep the offset from before the change, which lands after the gap.
      return DateTime.fromMillisecondsSinceEpoch(asUtc - before * _minute, isUtc: true);
    }
    valid.sort();
    return DateTime.fromMillisecondsSinceEpoch(valid.first, isUtc: true); // overlap: the earlier instant is the first occurrence
  }

  @override
  LocalTime utcToLocal(DateTime utc) {
    final ms = utc.millisecondsSinceEpoch;
    final local = DateTime.fromMillisecondsSinceEpoch(ms + offsetMinutesAt(ms) * _minute, isUtc: true);
    return LocalTime(local.year, local.month, local.day, local.hour, local.minute);
  }
}

/// A zone with a constant offset (UTC, or a zone without daylight saving such as Asia/Colombo at +05:30).
class FixedOffsetResolver extends OffsetZoneResolver {
  FixedOffsetResolver(int minutes) : super((_) => minutes);
}
