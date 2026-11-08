import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_si.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('si'),
    Locale('ta')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'FocusLearn'**
  String get appName;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPassword;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get resetPasswordTitle;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset email'**
  String get sendResetLink;

  /// No description provided for @resetEmailSentGeneric.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that address, we have sent an email with the next steps.'**
  String get resetEmailSentGeneric;

  /// No description provided for @checkInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkInboxTitle;

  /// No description provided for @checkInboxBody.
  ///
  /// In en, this message translates to:
  /// **'If this address can be used, we sent a message with a confirmation link. Open it, then come back here and sign in.'**
  String get checkInboxBody;

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Send the email again'**
  String get resendEmail;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Send again in {seconds} s'**
  String resendIn(String seconds);

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @noAccountYet.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get noAccountYet;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccount;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @signupTermsNote.
  ///
  /// In en, this message translates to:
  /// **'You will review the terms of use and the privacy notice before you start.'**
  String get signupTermsNote;

  /// No description provided for @passwordHelp.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters. A few words together work well.'**
  String get passwordHelp;

  /// No description provided for @errorBlank.
  ///
  /// In en, this message translates to:
  /// **'This field cannot be empty.'**
  String get errorBlank;

  /// No description provided for @errorTooShort.
  ///
  /// In en, this message translates to:
  /// **'This is too short.'**
  String get errorTooShort;

  /// No description provided for @errorTooLong.
  ///
  /// In en, this message translates to:
  /// **'This is too long.'**
  String get errorTooLong;

  /// No description provided for @errorInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'This does not look right.'**
  String get errorInvalidFormat;

  /// No description provided for @errorControlChar.
  ///
  /// In en, this message translates to:
  /// **'Remove special control characters.'**
  String get errorControlChar;

  /// No description provided for @errorOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'This value is out of range.'**
  String get errorOutOfRange;

  /// No description provided for @errorTooYoung.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 13 to use FocusLearn.'**
  String get errorTooYoung;

  /// No description provided for @errorUnknownValue.
  ///
  /// In en, this message translates to:
  /// **'Choose one of the options.'**
  String get errorUnknownValue;

  /// No description provided for @errorTooMany.
  ///
  /// In en, this message translates to:
  /// **'There are too many items.'**
  String get errorTooMany;

  /// No description provided for @errorCommonPassword.
  ///
  /// In en, this message translates to:
  /// **'This password is too common. Choose another.'**
  String get errorCommonPassword;

  /// No description provided for @errorContainsEmail.
  ///
  /// In en, this message translates to:
  /// **'Do not use your email name in your password.'**
  String get errorContainsEmail;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something is not right. Check this field.'**
  String get errorGeneric;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'The email or password is not correct.'**
  String get authInvalidCredentials;

  /// No description provided for @authEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email first. Open the link we sent you.'**
  String get authEmailNotConfirmed;

  /// No description provided for @authRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get authRateLimited;

  /// No description provided for @authCaptchaFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not check that you are not a robot. Try again.'**
  String get authCaptchaFailed;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password.'**
  String get authWeakPassword;

  /// No description provided for @authSamePassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a password you have not used before.'**
  String get authSamePassword;

  /// No description provided for @authNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get authNetwork;

  /// No description provided for @authServer.
  ///
  /// In en, this message translates to:
  /// **'The service is having trouble. Try again later.'**
  String get authServer;

  /// No description provided for @authUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get authUnknown;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get onboardingTitle;

  /// No description provided for @onboardingIntro.
  ///
  /// In en, this message translates to:
  /// **'A few details so FocusLearn fits your studies. You can change most of them later.'**
  String get onboardingIntro;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameLabel;

  /// No description provided for @birthYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year of birth'**
  String get birthYearLabel;

  /// No description provided for @streamLabel.
  ///
  /// In en, this message translates to:
  /// **'A/L stream'**
  String get streamLabel;

  /// No description provided for @subjectsLabel.
  ///
  /// In en, this message translates to:
  /// **'Subjects (optional)'**
  String get subjectsLabel;

  /// No description provided for @subjectsHelp.
  ///
  /// In en, this message translates to:
  /// **'Separate subjects with commas.'**
  String get subjectsHelp;

  /// No description provided for @timeZoneNote.
  ///
  /// In en, this message translates to:
  /// **'Time zone: {zone}'**
  String timeZoneNote(String zone);

  /// No description provided for @minorNotice.
  ///
  /// In en, this message translates to:
  /// **'Your profile will be private and other people cannot find you by searching.'**
  String get minorNotice;

  /// No description provided for @acceptTermsLabel.
  ///
  /// In en, this message translates to:
  /// **'I have read the terms of use and the privacy notice (draft versions).'**
  String get acceptTermsLabel;

  /// No description provided for @mustAcceptTerms.
  ///
  /// In en, this message translates to:
  /// **'You need to accept to continue.'**
  String get mustAcceptTerms;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @streamTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get streamTechnology;

  /// No description provided for @streamCommerce.
  ///
  /// In en, this message translates to:
  /// **'Commerce'**
  String get streamCommerce;

  /// No description provided for @streamScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get streamScience;

  /// No description provided for @streamMathematics.
  ///
  /// In en, this message translates to:
  /// **'Mathematics'**
  String get streamMathematics;

  /// No description provided for @streamArts.
  ///
  /// In en, this message translates to:
  /// **'Arts'**
  String get streamArts;

  /// No description provided for @streamOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get streamOther;

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcomeUser(String name);

  /// No description provided for @homePlannerSoon.
  ///
  /// In en, this message translates to:
  /// **'Your timetable and study planner will appear here in a coming release.'**
  String get homePlannerSoon;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @loadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading your profile'**
  String get loadingProfile;

  /// No description provided for @errorLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'We could not load your profile.'**
  String get errorLoadProfile;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String signedInAs(String email);

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutOthers.
  ///
  /// In en, this message translates to:
  /// **'Sign out of other devices'**
  String get signOutOthers;

  /// No description provided for @signOutOthersBody.
  ///
  /// In en, this message translates to:
  /// **'Every other device where you are signed in will have to sign in again. This device stays signed in.'**
  String get signOutOthersBody;

  /// No description provided for @signOutOthersConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out others'**
  String get signOutOthersConfirm;

  /// No description provided for @preferencesSection.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesSection;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSinhala.
  ///
  /// In en, this message translates to:
  /// **'Sinhala'**
  String get languageSinhala;

  /// No description provided for @languageTamil.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get languageTamil;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Same as device'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @devicesSection.
  ///
  /// In en, this message translates to:
  /// **'Your devices'**
  String get devicesSection;

  /// No description provided for @devicesNone.
  ///
  /// In en, this message translates to:
  /// **'No devices yet.'**
  String get devicesNone;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @removeDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeDevice;

  /// No description provided for @removeDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'Remove this device from your list?'**
  String get removeDeviceBody;

  /// No description provided for @devicesNote.
  ///
  /// In en, this message translates to:
  /// **'Removing a device does not end its session by itself. Use “Sign out of other devices” as well.'**
  String get devicesNote;

  /// No description provided for @privacySection.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacySection;

  /// No description provided for @deletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deletionTitle;

  /// No description provided for @deletionBody.
  ///
  /// In en, this message translates to:
  /// **'We will delete your account and your data after 7 days. You can cancel before then.'**
  String get deletionBody;

  /// No description provided for @requestDeletion.
  ///
  /// In en, this message translates to:
  /// **'Request deletion'**
  String get requestDeletion;

  /// No description provided for @deletionPending.
  ///
  /// In en, this message translates to:
  /// **'Deletion is scheduled for {date}.'**
  String deletionPending(String date);

  /// No description provided for @cancelDeletion.
  ///
  /// In en, this message translates to:
  /// **'Cancel deletion'**
  String get cancelDeletion;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deviceRevokedSignedOut.
  ///
  /// In en, this message translates to:
  /// **'This device was removed from your account. Sign in again to continue.'**
  String get deviceRevokedSignedOut;

  /// No description provided for @configMissingUrl.
  ///
  /// In en, this message translates to:
  /// **'The server address is missing from this build.'**
  String get configMissingUrl;

  /// No description provided for @configMissingKey.
  ///
  /// In en, this message translates to:
  /// **'The public key is missing from this build.'**
  String get configMissingKey;

  /// No description provided for @configSecretKey.
  ///
  /// In en, this message translates to:
  /// **'This build contains a secret key. It must never ship in an app: rebuild with the publishable key.'**
  String get configSecretKey;

  /// No description provided for @configInsecureUrl.
  ///
  /// In en, this message translates to:
  /// **'The server address must use https.'**
  String get configInsecureUrl;

  /// No description provided for @doneMessage.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get doneMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'si', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'si':
      return AppLocalizationsSi();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
