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

  /// No description provided for @navPlanner.
  ///
  /// In en, this message translates to:
  /// **'Planner'**
  String get navPlanner;

  /// No description provided for @navFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get navFocus;

  /// No description provided for @navCalculators.
  ///
  /// In en, this message translates to:
  /// **'Calculators'**
  String get navCalculators;

  /// No description provided for @navNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get navNotes;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @calculatorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Study Calculators'**
  String get calculatorsTitle;

  /// No description provided for @calcStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard & Fractions'**
  String get calcStandard;

  /// No description provided for @calcStandardDesc.
  ///
  /// In en, this message translates to:
  /// **'Arithmetic with exact rationals, powers, and step-by-step working'**
  String get calcStandardDesc;

  /// No description provided for @calcPercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get calcPercentage;

  /// No description provided for @calcPercentageDesc.
  ///
  /// In en, this message translates to:
  /// **'Percent of, what percent, percent change, increase and decrease'**
  String get calcPercentageDesc;

  /// No description provided for @calcCommercial.
  ///
  /// In en, this message translates to:
  /// **'Commercial & Business'**
  String get calcCommercial;

  /// No description provided for @calcCommercialDesc.
  ///
  /// In en, this message translates to:
  /// **'Profit and loss, margin, markup, interest, and break-even'**
  String get calcCommercialDesc;

  /// No description provided for @calcStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get calcStatistics;

  /// No description provided for @calcStatisticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Mean, median, mode, variance, and standard deviation'**
  String get calcStatisticsDesc;

  /// No description provided for @calcConverter.
  ///
  /// In en, this message translates to:
  /// **'Unit Converter'**
  String get calcConverter;

  /// No description provided for @calcConverterDesc.
  ///
  /// In en, this message translates to:
  /// **'Length, mass, volume, area, time, speed, and temperature'**
  String get calcConverterDesc;

  /// No description provided for @calcFormulas.
  ///
  /// In en, this message translates to:
  /// **'Formula Reference'**
  String get calcFormulas;

  /// No description provided for @calcFormulasDesc.
  ///
  /// In en, this message translates to:
  /// **'Key formulas for G.C.E. Advanced Level syllabus streams'**
  String get calcFormulasDesc;

  /// No description provided for @calcCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get calcCalculate;

  /// No description provided for @calcClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get calcClear;

  /// No description provided for @calcResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get calcResult;

  /// No description provided for @calcSteps.
  ///
  /// In en, this message translates to:
  /// **'Calculation Steps'**
  String get calcSteps;

  /// No description provided for @calcHistory.
  ///
  /// In en, this message translates to:
  /// **'Recent Calculations'**
  String get calcHistory;

  /// No description provided for @calcExpressionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. (1/3 + 2/5) * 15 or 100 + 10%'**
  String get calcExpressionHint;

  /// No description provided for @calcInputA.
  ///
  /// In en, this message translates to:
  /// **'Value A'**
  String get calcInputA;

  /// No description provided for @calcInputB.
  ///
  /// In en, this message translates to:
  /// **'Value B'**
  String get calcInputB;

  /// No description provided for @calcInputPercent.
  ///
  /// In en, this message translates to:
  /// **'Percentage (%)'**
  String get calcInputPercent;

  /// No description provided for @calcInputBase.
  ///
  /// In en, this message translates to:
  /// **'Base Value'**
  String get calcInputBase;

  /// No description provided for @calcInputPart.
  ///
  /// In en, this message translates to:
  /// **'Part'**
  String get calcInputPart;

  /// No description provided for @calcInputWhole.
  ///
  /// In en, this message translates to:
  /// **'Whole'**
  String get calcInputWhole;

  /// No description provided for @calcInputCost.
  ///
  /// In en, this message translates to:
  /// **'Cost Price'**
  String get calcInputCost;

  /// No description provided for @calcInputSellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling Price'**
  String get calcInputSellingPrice;

  /// No description provided for @calcInputMarkup.
  ///
  /// In en, this message translates to:
  /// **'Markup %'**
  String get calcInputMarkup;

  /// No description provided for @calcInputMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin %'**
  String get calcInputMargin;

  /// No description provided for @calcInputPrincipal.
  ///
  /// In en, this message translates to:
  /// **'Principal'**
  String get calcInputPrincipal;

  /// No description provided for @calcInputRate.
  ///
  /// In en, this message translates to:
  /// **'Annual Rate (%)'**
  String get calcInputRate;

  /// No description provided for @calcInputPeriods.
  ///
  /// In en, this message translates to:
  /// **'Periods (e.g. Years)'**
  String get calcInputPeriods;

  /// No description provided for @calcInputFixedCost.
  ///
  /// In en, this message translates to:
  /// **'Fixed Costs'**
  String get calcInputFixedCost;

  /// No description provided for @calcInputUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Price per Unit'**
  String get calcInputUnitPrice;

  /// No description provided for @calcInputVariableCost.
  ///
  /// In en, this message translates to:
  /// **'Variable Cost per Unit'**
  String get calcInputVariableCost;

  /// No description provided for @calcDataListHint.
  ///
  /// In en, this message translates to:
  /// **'Enter numbers separated by spaces or commas'**
  String get calcDataListHint;

  /// No description provided for @focusTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus Timer'**
  String get focusTitle;

  /// No description provided for @focusForest.
  ///
  /// In en, this message translates to:
  /// **'Study Forest'**
  String get focusForest;

  /// No description provided for @focusAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get focusAchievements;

  /// No description provided for @focusDuration.
  ///
  /// In en, this message translates to:
  /// **'Session Duration'**
  String get focusDuration;

  /// No description provided for @focusMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String focusMinutes(String count);

  /// No description provided for @focusStart.
  ///
  /// In en, this message translates to:
  /// **'Start Focus'**
  String get focusStart;

  /// No description provided for @focusPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get focusPause;

  /// No description provided for @focusResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get focusResume;

  /// No description provided for @focusEndEarly.
  ///
  /// In en, this message translates to:
  /// **'End Session'**
  String get focusEndEarly;

  /// No description provided for @focusEmergencyExit.
  ///
  /// In en, this message translates to:
  /// **'Emergency Exit'**
  String get focusEmergencyExit;

  /// No description provided for @focusEmergencyExitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop focus session now? Time completed so far will still count if at least 5 minutes.'**
  String get focusEmergencyExitConfirm;

  /// No description provided for @focusGentleRestDay.
  ///
  /// In en, this message translates to:
  /// **'Gentle Rest Day: 1 missed day per week is forgiven and keeps your streak alive!'**
  String get focusGentleRestDay;

  /// No description provided for @focusCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get focusCurrentStreak;

  /// No description provided for @focusDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String focusDaysCount(String count);

  /// No description provided for @focusLongestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best Streak: {count} days'**
  String focusLongestStreak(String count);

  /// No description provided for @focusTreeEarned.
  ///
  /// In en, this message translates to:
  /// **'Tree Earned: {tree}'**
  String focusTreeEarned(String tree);

  /// No description provided for @focusValidatedMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min validated'**
  String focusValidatedMinutes(String minutes);

  /// No description provided for @focusTreeNone.
  ///
  /// In en, this message translates to:
  /// **'No tree (under 5 min)'**
  String get focusTreeNone;

  /// No description provided for @focusTreeSeedling.
  ///
  /// In en, this message translates to:
  /// **'Seedling (5+ min)'**
  String get focusTreeSeedling;

  /// No description provided for @focusTreeSapling.
  ///
  /// In en, this message translates to:
  /// **'Sapling (15+ min)'**
  String get focusTreeSapling;

  /// No description provided for @focusTreeTree.
  ///
  /// In en, this message translates to:
  /// **'Full Tree (25+ min)'**
  String get focusTreeTree;

  /// No description provided for @focusTreeGrove.
  ///
  /// In en, this message translates to:
  /// **'Grove (50+ min)'**
  String get focusTreeGrove;

  /// No description provided for @focusSubject.
  ///
  /// In en, this message translates to:
  /// **'Study Subject'**
  String get focusSubject;

  /// No description provided for @plannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Planner & Timetable'**
  String get plannerTitle;

  /// No description provided for @plannerAddEvent.
  ///
  /// In en, this message translates to:
  /// **'Add Event'**
  String get plannerAddEvent;

  /// No description provided for @plannerEditEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get plannerEditEvent;

  /// No description provided for @plannerSubjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get plannerSubjects;

  /// No description provided for @plannerAssignments.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get plannerAssignments;

  /// No description provided for @plannerAgenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get plannerAgenda;

  /// No description provided for @plannerDayView.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get plannerDayView;

  /// No description provided for @plannerWeekView.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get plannerWeekView;

  /// No description provided for @plannerToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get plannerToday;

  /// No description provided for @plannerConflictWarning.
  ///
  /// In en, this message translates to:
  /// **'Time conflict detected with another event'**
  String get plannerConflictWarning;

  /// No description provided for @plannerJoinClass.
  ///
  /// In en, this message translates to:
  /// **'Join Class'**
  String get plannerJoinClass;

  /// No description provided for @plannerOpenLinkConfirm.
  ///
  /// In en, this message translates to:
  /// **'External Class Link'**
  String get plannerOpenLinkConfirm;

  /// No description provided for @plannerOpenLinkWarning.
  ///
  /// In en, this message translates to:
  /// **'This link opens an external host ({host}). Proceed?'**
  String plannerOpenLinkWarning(String host);

  /// No description provided for @plannerOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get plannerOpen;

  /// No description provided for @plannerRepeat.
  ///
  /// In en, this message translates to:
  /// **'Recurrence'**
  String get plannerRepeat;

  /// No description provided for @plannerRepeatNone.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get plannerRepeatNone;

  /// No description provided for @plannerRepeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get plannerRepeatDaily;

  /// No description provided for @plannerRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get plannerRepeatWeekly;

  /// No description provided for @plannerRepeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get plannerRepeatMonthly;

  /// No description provided for @plannerSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get plannerSave;

  /// No description provided for @plannerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get plannerDelete;

  /// No description provided for @plannerDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String plannerDue(String date);

  /// No description provided for @plannerAssignmentCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get plannerAssignmentCompleted;

  /// No description provided for @plannerAssignmentPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get plannerAssignmentPending;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Study Notes'**
  String get notesTitle;

  /// No description provided for @notesNew.
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get notesNew;

  /// No description provided for @notesSearch.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get notesSearch;

  /// No description provided for @notesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes yet. Tap + to write your first study note.'**
  String get notesEmpty;

  /// No description provided for @notesShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get notesShare;

  /// No description provided for @notesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get notesDelete;

  /// No description provided for @socialTitle.
  ///
  /// In en, this message translates to:
  /// **'Study Groups & Friends'**
  String get socialTitle;

  /// No description provided for @socialFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get socialFriends;

  /// No description provided for @socialGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get socialGroups;

  /// No description provided for @socialCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Study Group'**
  String get socialCreateGroup;

  /// No description provided for @socialJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join Group with Code'**
  String get socialJoinGroup;

  /// No description provided for @socialSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get socialSendMessage;

  /// No description provided for @socialChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Discussion'**
  String get socialChatTitle;

  /// No description provided for @updatePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get updatePasswordTitle;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmPasswordLabel;

  /// No description provided for @updatePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePasswordButton;

  /// No description provided for @passwordUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated. You can now sign in.'**
  String get passwordUpdatedSuccess;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordMismatch;

  /// No description provided for @enforcementTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus Enforcement & Rules'**
  String get enforcementTitle;

  /// No description provided for @enforcementActiveRules.
  ///
  /// In en, this message translates to:
  /// **'Active Rules'**
  String get enforcementActiveRules;

  /// No description provided for @enforcementNoRules.
  ///
  /// In en, this message translates to:
  /// **'No strict enforcement rules active. Focus mode is voluntary.'**
  String get enforcementNoRules;

  /// No description provided for @enforcementBlockedApps.
  ///
  /// In en, this message translates to:
  /// **'Restricted Distractions'**
  String get enforcementBlockedApps;

  /// No description provided for @enforcementAllowedApps.
  ///
  /// In en, this message translates to:
  /// **'Allowed Study Apps'**
  String get enforcementAllowedApps;

  /// No description provided for @enforcementScheduledWindows.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Study Hours'**
  String get enforcementScheduledWindows;

  /// No description provided for @enforcementDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Daily Entertainment Limit'**
  String get enforcementDailyLimit;

  /// No description provided for @enforcementViolationsHistory.
  ///
  /// In en, this message translates to:
  /// **'Violations & Interceptions'**
  String get enforcementViolationsHistory;

  /// No description provided for @enforcementNoViolations.
  ///
  /// In en, this message translates to:
  /// **'No violations recorded. Keep up the great focus!'**
  String get enforcementNoViolations;

  /// No description provided for @enforcementOverridesHistory.
  ///
  /// In en, this message translates to:
  /// **'Emergency Overrides'**
  String get enforcementOverridesHistory;

  /// No description provided for @enforcementOverlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus Mode Active'**
  String get enforcementOverlayTitle;

  /// No description provided for @enforcementOverlayPrompt.
  ///
  /// In en, this message translates to:
  /// **'This app is restricted during your scheduled study session.'**
  String get enforcementOverlayPrompt;

  /// No description provided for @enforcementOverlayTimeRemaining.
  ///
  /// In en, this message translates to:
  /// **'Time remaining: {time}'**
  String enforcementOverlayTimeRemaining(String time);

  /// No description provided for @enforcementEmergencyOverride.
  ///
  /// In en, this message translates to:
  /// **'Emergency Override'**
  String get enforcementEmergencyOverride;

  /// No description provided for @enforcementOverrideReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Reason for Override'**
  String get enforcementOverrideReasonTitle;

  /// No description provided for @enforcementOverrideReasonHelp.
  ///
  /// In en, this message translates to:
  /// **'Your reason will be recorded transparently in the session history.'**
  String get enforcementOverrideReasonHelp;

  /// No description provided for @enforcementOverrideConfirm.
  ///
  /// In en, this message translates to:
  /// **'Unlock 15 Minutes'**
  String get enforcementOverrideConfirm;

  /// No description provided for @enforcementPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Required Permissions'**
  String get enforcementPermissionsTitle;

  /// No description provided for @enforcementUsageAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'Usage Access is required to detect distracting apps during focus sessions.'**
  String get enforcementUsageAccessRequired;

  /// No description provided for @enforcementOverlayRequired.
  ///
  /// In en, this message translates to:
  /// **'Display Over Other Apps permission is required to show the study barrier.'**
  String get enforcementOverlayRequired;

  /// No description provided for @enforcementGrantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get enforcementGrantPermission;

  /// No description provided for @enforcementPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Permission Granted'**
  String get enforcementPermissionGranted;

  /// No description provided for @navEnforcement.
  ///
  /// In en, this message translates to:
  /// **'Rules & Focus'**
  String get navEnforcement;

  /// No description provided for @calcScientific.
  ///
  /// In en, this message translates to:
  /// **'Scientific & A/L Advanced'**
  String get calcScientific;

  /// No description provided for @calcScientificDesc.
  ///
  /// In en, this message translates to:
  /// **'Trigonometry, complex numbers, matrices, equations, calculus, and chemistry stoichiometry'**
  String get calcScientificDesc;

  /// No description provided for @calcCamera.
  ///
  /// In en, this message translates to:
  /// **'AI Camera Calculator'**
  String get calcCamera;

  /// No description provided for @calcCameraDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan math & science problems with step-by-step verified solutions'**
  String get calcCameraDesc;

  /// No description provided for @navNotebooks.
  ///
  /// In en, this message translates to:
  /// **'AI Notebooks'**
  String get navNotebooks;

  /// No description provided for @notebooksTitle.
  ///
  /// In en, this message translates to:
  /// **'Research Notebooks'**
  String get notebooksTitle;

  /// No description provided for @notebooksDesc.
  ///
  /// In en, this message translates to:
  /// **'NotebookLM-style grounded AI study notebooks from your own PDFs and notes'**
  String get notebooksDesc;
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
