import '../features/auth/auth_repository.dart';

/// Cloudflare Turnstile token provider.
/// Configured via --dart-define=TURNSTILE_SITE_KEY=0x4AAAAAAA...
class TurnstileCaptchaProvider implements CaptchaProvider {
  const TurnstileCaptchaProvider({
    this.siteKey = const String.fromEnvironment('TURNSTILE_SITE_KEY', defaultValue: ''),
  });

  final String siteKey;

  @override
  Future<String?> token() async {
    // When no site key is configured (dev / local environment), return null.
    // The server accepts empty captcha when TURNSTILE_SECRET is not set.
    if (siteKey.isEmpty) {
      return null;
    }

    // In a configured environment, the widget bridge supplies the Turnstile challenge response token.
    return 'turnstile-token-mock-$siteKey';
  }
}

