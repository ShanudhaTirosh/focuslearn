// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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

  @override
  String get navPlanner => 'Planner';

  @override
  String get navFocus => 'Focus';

  @override
  String get navCalculators => 'Calculators';

  @override
  String get navNotes => 'Notes';

  @override
  String get navSettings => 'Settings';

  @override
  String get calculatorsTitle => 'Study Calculators';

  @override
  String get calcStandard => 'Standard & Fractions';

  @override
  String get calcStandardDesc =>
      'Arithmetic with exact rationals, powers, and step-by-step working';

  @override
  String get calcPercentage => 'Percentage';

  @override
  String get calcPercentageDesc =>
      'Percent of, what percent, percent change, increase and decrease';

  @override
  String get calcCommercial => 'Commercial & Business';

  @override
  String get calcCommercialDesc =>
      'Profit and loss, margin, markup, interest, and break-even';

  @override
  String get calcStatistics => 'Statistics';

  @override
  String get calcStatisticsDesc =>
      'Mean, median, mode, variance, and standard deviation';

  @override
  String get calcConverter => 'Unit Converter';

  @override
  String get calcConverterDesc =>
      'Length, mass, volume, area, time, speed, and temperature';

  @override
  String get calcFormulas => 'Formula Reference';

  @override
  String get calcFormulasDesc =>
      'Key formulas for G.C.E. Advanced Level syllabus streams';

  @override
  String get calcCalculate => 'Calculate';

  @override
  String get calcClear => 'Clear';

  @override
  String get calcResult => 'Result';

  @override
  String get calcSteps => 'Calculation Steps';

  @override
  String get calcHistory => 'Recent Calculations';

  @override
  String get calcExpressionHint => 'e.g. (1/3 + 2/5) * 15 or 100 + 10%';

  @override
  String get calcInputA => 'Value A';

  @override
  String get calcInputB => 'Value B';

  @override
  String get calcInputPercent => 'Percentage (%)';

  @override
  String get calcInputBase => 'Base Value';

  @override
  String get calcInputPart => 'Part';

  @override
  String get calcInputWhole => 'Whole';

  @override
  String get calcInputCost => 'Cost Price';

  @override
  String get calcInputSellingPrice => 'Selling Price';

  @override
  String get calcInputMarkup => 'Markup %';

  @override
  String get calcInputMargin => 'Margin %';

  @override
  String get calcInputPrincipal => 'Principal';

  @override
  String get calcInputRate => 'Annual Rate (%)';

  @override
  String get calcInputPeriods => 'Periods (e.g. Years)';

  @override
  String get calcInputFixedCost => 'Fixed Costs';

  @override
  String get calcInputUnitPrice => 'Price per Unit';

  @override
  String get calcInputVariableCost => 'Variable Cost per Unit';

  @override
  String get calcDataListHint => 'Enter numbers separated by spaces or commas';

  @override
  String get focusTitle => 'Focus Timer';

  @override
  String get focusForest => 'Study Forest';

  @override
  String get focusAchievements => 'Achievements';

  @override
  String get focusDuration => 'Session Duration';

  @override
  String focusMinutes(String count) {
    return '$count min';
  }

  @override
  String get focusStart => 'Start Focus';

  @override
  String get focusPause => 'Pause';

  @override
  String get focusResume => 'Resume';

  @override
  String get focusEndEarly => 'End Session';

  @override
  String get focusEmergencyExit => 'Emergency Exit';

  @override
  String get focusEmergencyExitConfirm =>
      'Stop focus session now? Time completed so far will still count if at least 5 minutes.';

  @override
  String get focusGentleRestDay =>
      'Gentle Rest Day: 1 missed day per week is forgiven and keeps your streak alive!';

  @override
  String get focusCurrentStreak => 'Current Streak';

  @override
  String focusDaysCount(String count) {
    return '$count days';
  }

  @override
  String focusLongestStreak(String count) {
    return 'Best Streak: $count days';
  }

  @override
  String focusTreeEarned(String tree) {
    return 'Tree Earned: $tree';
  }

  @override
  String focusValidatedMinutes(String minutes) {
    return '$minutes min validated';
  }

  @override
  String get focusTreeNone => 'No tree (under 5 min)';

  @override
  String get focusTreeSeedling => 'Seedling (5+ min)';

  @override
  String get focusTreeSapling => 'Sapling (15+ min)';

  @override
  String get focusTreeTree => 'Full Tree (25+ min)';

  @override
  String get focusTreeGrove => 'Grove (50+ min)';

  @override
  String get focusSubject => 'Study Subject';

  @override
  String get plannerTitle => 'Planner & Timetable';

  @override
  String get plannerAddEvent => 'Add Event';

  @override
  String get plannerEditEvent => 'Edit Event';

  @override
  String get plannerSubjects => 'Subjects';

  @override
  String get plannerAssignments => 'Assignments';

  @override
  String get plannerAgenda => 'Agenda';

  @override
  String get plannerDayView => 'Day';

  @override
  String get plannerWeekView => 'Week';

  @override
  String get plannerToday => 'Today';

  @override
  String get plannerConflictWarning =>
      'Time conflict detected with another event';

  @override
  String get plannerJoinClass => 'Join Class';

  @override
  String get plannerOpenLinkConfirm => 'External Class Link';

  @override
  String plannerOpenLinkWarning(String host) {
    return 'This link opens an external host ($host). Proceed?';
  }

  @override
  String get plannerOpen => 'Open';

  @override
  String get plannerRepeat => 'Recurrence';

  @override
  String get plannerRepeatNone => 'Does not repeat';

  @override
  String get plannerRepeatDaily => 'Daily';

  @override
  String get plannerRepeatWeekly => 'Weekly';

  @override
  String get plannerRepeatMonthly => 'Monthly';

  @override
  String get plannerSave => 'Save';

  @override
  String get plannerDelete => 'Delete';

  @override
  String plannerDue(String date) {
    return 'Due $date';
  }

  @override
  String get plannerAssignmentCompleted => 'Completed';

  @override
  String get plannerAssignmentPending => 'Pending';

  @override
  String get notesTitle => 'Study Notes';

  @override
  String get notesNew => 'New Note';

  @override
  String get notesSearch => 'Search notes';

  @override
  String get notesEmpty =>
      'No notes yet. Tap + to write your first study note.';

  @override
  String get notesShare => 'Share';

  @override
  String get notesDelete => 'Delete Note';

  @override
  String get socialTitle => 'Study Groups & Friends';

  @override
  String get socialFriends => 'Friends';

  @override
  String get socialGroups => 'Groups';

  @override
  String get socialCreateGroup => 'Create Study Group';

  @override
  String get socialJoinGroup => 'Join Group with Code';

  @override
  String get socialSendMessage => 'Send message';

  @override
  String get socialChatTitle => 'Discussion';

  @override
  String get updatePasswordTitle => 'Set new password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmPasswordLabel => 'Confirm new password';

  @override
  String get updatePasswordButton => 'Update password';

  @override
  String get passwordUpdatedSuccess =>
      'Your password has been updated. You can now sign in.';

  @override
  String get passwordMismatch => 'Passwords do not match.';

  @override
  String get enforcementTitle => 'Focus Enforcement & Rules';

  @override
  String get enforcementActiveRules => 'Active Rules';

  @override
  String get enforcementNoRules =>
      'No strict enforcement rules active. Focus mode is voluntary.';

  @override
  String get enforcementBlockedApps => 'Restricted Distractions';

  @override
  String get enforcementAllowedApps => 'Allowed Study Apps';

  @override
  String get enforcementScheduledWindows => 'Scheduled Study Hours';

  @override
  String get enforcementDailyLimit => 'Daily Entertainment Limit';

  @override
  String get enforcementViolationsHistory => 'Violations & Interceptions';

  @override
  String get enforcementNoViolations =>
      'No violations recorded. Keep up the great focus!';

  @override
  String get enforcementOverridesHistory => 'Emergency Overrides';

  @override
  String get enforcementOverlayTitle => 'Focus Mode Active';

  @override
  String get enforcementOverlayPrompt =>
      'This app is restricted during your scheduled study session.';

  @override
  String enforcementOverlayTimeRemaining(String time) {
    return 'Time remaining: $time';
  }

  @override
  String get enforcementEmergencyOverride => 'Emergency Override';

  @override
  String get enforcementOverrideReasonTitle => 'Enter Reason for Override';

  @override
  String get enforcementOverrideReasonHelp =>
      'Your reason will be recorded transparently in the session history.';

  @override
  String get enforcementOverrideConfirm => 'Unlock 15 Minutes';

  @override
  String get enforcementPermissionsTitle => 'Required Permissions';

  @override
  String get enforcementUsageAccessRequired =>
      'Usage Access is required to detect distracting apps during focus sessions.';

  @override
  String get enforcementOverlayRequired =>
      'Display Over Other Apps permission is required to show the study barrier.';

  @override
  String get enforcementGrantPermission => 'Grant Permission';

  @override
  String get enforcementPermissionGranted => 'Permission Granted';

  @override
  String get navEnforcement => 'Rules & Focus';

  @override
  String get calcScientific => 'Scientific & A/L Advanced';

  @override
  String get calcScientificDesc =>
      'Trigonometry, complex numbers, matrices, equations, calculus, and chemistry stoichiometry';

  @override
  String get calcCamera => 'AI Camera Calculator';

  @override
  String get calcCameraDesc =>
      'Scan math & science problems with step-by-step verified solutions';

  @override
  String get navNotebooks => 'AI Notebooks';

  @override
  String get notebooksTitle => 'Research Notebooks';

  @override
  String get notebooksDesc =>
      'NotebookLM-style grounded AI study notebooks from your own PDFs and notes';
}
