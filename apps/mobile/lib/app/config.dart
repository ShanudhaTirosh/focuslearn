import 'package:focuslearn_core/focuslearn_core.dart';

/// Build-time settings, passed with `--dart-define` (or `--dart-define-from-file`), never hard-coded:
///   SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, TURNSTILE_SITE_KEY (optional).
/// Switching between the self-hosted backend and Supabase Cloud is a change of these values only.
class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.publishableKey, required this.captchaSiteKey});

  factory AppConfig.fromEnvironment() => const AppConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
        captchaSiteKey: String.fromEnvironment('TURNSTILE_SITE_KEY'),
      );

  final String supabaseUrl;
  final String publishableKey;
  final String captchaSiteKey;

  static const Set<String> _localHosts = <String>{'localhost', '127.0.0.1', '10.0.2.2'};

  /// Returns null when the configuration is usable, otherwise one of:
  /// `missing_url`, `insecure_url`, `missing_key`, `secret_key`.
  /// Plain http is accepted only for local development hosts, and only when [allowLocalHttp] is true (debug builds).
  String? problem({bool allowLocalHttp = false}) {
    final uri = Uri.tryParse(supabaseUrl.trim());
    if (uri == null || uri.host.isEmpty) {
      return 'missing_url';
    }
    final secure = uri.scheme == 'https';
    final localHttp = uri.scheme == 'http' && allowLocalHttp && _localHosts.contains(uri.host);
    if (!secure && !localHttp) {
      return 'insecure_url';
    }
    final key = validateClientKey(publishableKey);
    if (key == 'blank') {
      return 'missing_key';
    }
    if (key == 'secret_key') {
      return 'secret_key';
    }
    return null;
  }

  bool get captchaConfigured => captchaSiteKey.isNotEmpty;
}
