import '../l10n/generated/app_localizations.dart';

/// Maps a validation code from the core package to a message. Unknown codes get a generic message.
String validationMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    'blank' => l10n.errorBlank,
    'too_short' => l10n.errorTooShort,
    'too_long' => l10n.errorTooLong,
    'invalid_format' => l10n.errorInvalidFormat,
    'control_char' => l10n.errorControlChar,
    'out_of_range' => l10n.errorOutOfRange,
    'too_young' => l10n.errorTooYoung,
    'unknown_value' => l10n.errorUnknownValue,
    'too_many' => l10n.errorTooMany,
    'common_password' => l10n.errorCommonPassword,
    'contains_email' => l10n.errorContainsEmail,
    _ => l10n.errorGeneric,
  };
}

/// Maps an auth failure kind to a message. None of these reveals whether an account exists.
String authMessage(AppLocalizations l10n, String kind) {
  return switch (kind) {
    'invalid_credentials' => l10n.authInvalidCredentials,
    'email_not_confirmed' => l10n.authEmailNotConfirmed,
    'rate_limited' => l10n.authRateLimited,
    'captcha_failed' => l10n.authCaptchaFailed,
    'weak_password' => l10n.authWeakPassword,
    'same_password' => l10n.authSamePassword,
    'network' => l10n.authNetwork,
    'server' => l10n.authServer,
    _ => l10n.authUnknown,
  };
}

String streamName(AppLocalizations l10n, String stream) {
  return switch (stream) {
    'technology' => l10n.streamTechnology,
    'commerce' => l10n.streamCommerce,
    'science' => l10n.streamScience,
    'mathematics' => l10n.streamMathematics,
    'arts' => l10n.streamArts,
    _ => l10n.streamOther,
  };
}

String configMessage(AppLocalizations l10n, String problem) {
  return switch (problem) {
    'missing_url' => l10n.configMissingUrl,
    'insecure_url' => l10n.configInsecureUrl,
    'missing_key' => l10n.configMissingKey,
    'secret_key' => l10n.configSecretKey,
    _ => l10n.errorGeneric,
  };
}
