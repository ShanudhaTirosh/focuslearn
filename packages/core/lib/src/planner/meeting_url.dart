import '../validation.dart';

class MeetingUrlResult {
  const MeetingUrlResult(this.code, {this.provider, this.normalized});

  /// `ok`, or `blank`, `too_long`, `invalid_url`, `not_https`, `credentials`, `ip_host`, `invalid_host`.
  final String code;

  /// `zoom`, `meet`, `teams` or `other` (an unknown host is allowed but the UI should warn).
  final String? provider;

  /// The link to store: lower-case scheme and host. Matches the database pattern.
  final String? normalized;
}

final RegExp _forbiddenChars = RegExp(r'[\s\x00-\x1f\x7f-\x9f]');
final RegExp _schemePattern = RegExp(r'^([A-Za-z][A-Za-z0-9+.-]*):(.*)$', dotAll: true);
final RegExp _portPattern = RegExp(r'^[0-9]{1,5}$');
final RegExp _ipv4Pattern = RegExp(r'^[0-9]{1,3}(\.[0-9]{1,3}){3}$');
final RegExp _hostPattern = RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$');

/// Checks a class link: https only, no credentials, no IP addresses, no look-alike (non-ASCII) hosts, and the host is matched
/// by exact name or a dot-separated suffix, so `zoom.us.evil.com` and `evilzoom.us` are NOT Zoom.
MeetingUrlResult validateMeetingUrl(String url) {
  final u = trimUnicodeWhitespace(url);
  if (u.isEmpty) {
    return const MeetingUrlResult('blank');
  }
  if (u.runes.length > 500) {
    return const MeetingUrlResult('too_long');
  }
  if (_forbiddenChars.hasMatch(u)) {
    return const MeetingUrlResult('invalid_url');
  }
  final m = _schemePattern.firstMatch(u);
  if (m == null || m.group(1)!.toLowerCase() != 'https') {
    return const MeetingUrlResult('not_https');
  }
  var rest = m.group(2)!;
  if (!rest.startsWith('//')) {
    return const MeetingUrlResult('invalid_url');
  }
  rest = rest.substring(2);
  final slash = rest.indexOf('/');
  final authority = slash == -1 ? rest : rest.substring(0, slash);
  final path = slash == -1 ? '' : rest.substring(slash);
  if (authority.contains('?') || authority.contains('#')) {
    return const MeetingUrlResult('invalid_url');
  }
  if (authority.contains('@')) {
    return const MeetingUrlResult('credentials');
  }
  if (authority.startsWith('[')) {
    return const MeetingUrlResult('ip_host');
  }
  var host = authority;
  String? port;
  final colon = authority.lastIndexOf(':');
  if (colon != -1) {
    host = authority.substring(0, colon);
    port = authority.substring(colon + 1);
    final n = int.tryParse(port);
    if (!_portPattern.hasMatch(port) || n == null || n < 1 || n > 65535) {
      return const MeetingUrlResult('invalid_url');
    }
  }
  host = host.toLowerCase();
  if (host.runes.any((r) => r > 127)) {
    return const MeetingUrlResult('invalid_host');
  }
  if (_ipv4Pattern.hasMatch(host)) {
    return const MeetingUrlResult('ip_host');
  }
  if (!_hostPattern.hasMatch(host)) {
    return const MeetingUrlResult('invalid_host');
  }
  final String provider;
  if (host == 'zoom.us' || host.endsWith('.zoom.us')) {
    provider = 'zoom';
  } else if (host == 'meet.google.com') {
    provider = 'meet';
  } else if (host == 'teams.microsoft.com' || host == 'teams.live.com') {
    provider = 'teams';
  } else {
    provider = 'other';
  }
  return MeetingUrlResult('ok', provider: provider, normalized: 'https://$host${port != null ? ':$port' : ''}$path');
}
