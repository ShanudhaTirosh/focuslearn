// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Sinhala Sinhalese (`si`).
class AppLocalizationsSi extends AppLocalizations {
  AppLocalizationsSi([String locale = 'si']) : super(locale);

  @override
  String get appName => 'FocusLearn';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Sign up';

  @override
  String get createAccount => 'Create account';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get resetPasswordTitle => 'Reset your password';

  @override
  String get sendResetLink => 'Send reset email';

  @override
  String get resetEmailSentGeneric =>
      'If an account exists for that address, we have sent an email with the next steps.';

  @override
  String get checkInboxTitle => 'Check your email';

  @override
  String get checkInboxBody =>
      'If this address can be used, we sent a message with a confirmation link. Open it, then come back here and sign in.';

  @override
  String get resendEmail => 'Send the email again';

  @override
  String resendIn(String seconds) {
    return 'Send again in $seconds s';
  }

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get noAccountYet => 'New here? Create an account';

  @override
  String get haveAccount => 'Already have an account? Sign in';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signupTermsNote =>
      'You will review the terms of use and the privacy notice before you start.';

  @override
  String get passwordHelp =>
      'At least 10 characters. A few words together work well.';

  @override
  String get errorBlank => 'This field cannot be empty.';

  @override
  String get errorTooShort => 'This is too short.';

  @override
  String get errorTooLong => 'This is too long.';

  @override
  String get errorInvalidFormat => 'This does not look right.';

  @override
  String get errorControlChar => 'Remove special control characters.';

  @override
  String get errorOutOfRange => 'This value is out of range.';

  @override
  String get errorTooYoung => 'You must be at least 13 to use FocusLearn.';

  @override
  String get errorUnknownValue => 'Choose one of the options.';

  @override
  String get errorTooMany => 'There are too many items.';

  @override
  String get errorCommonPassword =>
      'This password is too common. Choose another.';

  @override
  String get errorContainsEmail =>
      'Do not use your email name in your password.';

  @override
  String get errorGeneric => 'Something is not right. Check this field.';

  @override
  String get authInvalidCredentials => 'The email or password is not correct.';

  @override
  String get authEmailNotConfirmed =>
      'Confirm your email first. Open the link we sent you.';

  @override
  String get authRateLimited =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get authCaptchaFailed =>
      'We could not check that you are not a robot. Try again.';

  @override
  String get authWeakPassword => 'Choose a stronger password.';

  @override
  String get authSamePassword => 'Choose a password you have not used before.';

  @override
  String get authNetwork => 'No connection. Check your internet and try again.';

  @override
  String get authServer => 'The service is having trouble. Try again later.';

  @override
  String get authUnknown => 'Something went wrong. Try again.';

  @override
  String get onboardingTitle => 'Set up your profile';

  @override
  String get onboardingIntro =>
      'A few details so FocusLearn fits your studies. You can change most of them later.';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get birthYearLabel => 'Year of birth';

  @override
  String get streamLabel => 'A/L stream';

  @override
  String get subjectsLabel => 'Subjects (optional)';

  @override
  String get subjectsHelp => 'Separate subjects with commas.';

  @override
  String timeZoneNote(String zone) {
    return 'Time zone: $zone';
  }

  @override
  String get minorNotice =>
      'Your profile will be private and other people cannot find you by searching.';

  @override
  String get acceptTermsLabel =>
      'I have read the terms of use and the privacy notice (draft versions).';

  @override
  String get mustAcceptTerms => 'You need to accept to continue.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get streamTechnology => 'Technology';

  @override
  String get streamCommerce => 'Commerce';

  @override
  String get streamScience => 'Science';

  @override
  String get streamMathematics => 'Mathematics';

  @override
  String get streamArts => 'Arts';

  @override
  String get streamOther => 'Other';

  @override
  String welcomeUser(String name) {
    return 'Welcome, $name';
  }

  @override
  String get homePlannerSoon =>
      'Your timetable and study planner will appear here in a coming release.';

  @override
  String get settings => 'Settings';

  @override
  String get loadingProfile => 'Loading your profile';

  @override
  String get errorLoadProfile => 'We could not load your profile.';

  @override
  String get retry => 'Try again';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get accountSection => 'Account';

  @override
  String signedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutOthers => 'Sign out of other devices';

  @override
  String get signOutOthersBody =>
      'Every other device where you are signed in will have to sign in again. This device stays signed in.';

  @override
  String get signOutOthersConfirm => 'Sign out others';

  @override
  String get preferencesSection => 'Preferences';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSinhala => 'Sinhala';

  @override
  String get languageTamil => 'Tamil';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSystem => 'Same as device';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get devicesSection => 'Your devices';

  @override
  String get devicesNone => 'No devices yet.';

  @override
  String get thisDevice => 'This device';

  @override
  String get removeDevice => 'Remove';

  @override
  String get removeDeviceBody => 'Remove this device from your list?';

  @override
  String get devicesNote =>
      'Removing a device does not end its session by itself. Use “Sign out of other devices” as well.';

  @override
  String get privacySection => 'Privacy';

  @override
  String get deletionTitle => 'Delete my account';

  @override
  String get deletionBody =>
      'We will delete your account and your data after 7 days. You can cancel before then.';

  @override
  String get requestDeletion => 'Request deletion';

  @override
  String deletionPending(String date) {
    return 'Deletion is scheduled for $date.';
  }

  @override
  String get cancelDeletion => 'Cancel deletion';

  @override
  String get cancel => 'Cancel';

  @override
  String get deviceRevokedSignedOut =>
      'This device was removed from your account. Sign in again to continue.';

  @override
  String get configMissingUrl =>
      'The server address is missing from this build.';

  @override
  String get configMissingKey => 'The public key is missing from this build.';

  @override
  String get configSecretKey =>
      'This build contains a secret key. It must never ship in an app: rebuild with the publishable key.';

  @override
  String get configInsecureUrl => 'The server address must use https.';

  @override
  String get doneMessage => 'Done.';
}
