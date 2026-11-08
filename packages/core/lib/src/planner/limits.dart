/// Limits shared with the database (backend/supabase/migrations/20261018000000_planner.sql). Checked against it by a test.
abstract final class PlannerRules {
  static const int titleMax = 80;
  static const int locationMax = 120;
  static const int notesMax = 2000;
  static const int reminderOffsetMax = 10080;
  static const int reminderCountMax = 5;
  static const int meetingUrlMax = 500;
  static const int eventMaxHours = 24;
  static const List<String> categories = <String>['study', 'revision', 'homework', 'break', 'online_class'];

  /// Soft planning range for a study or class block (2.5 to 4 hours). A preference, never a rule.
  static const int preferredBlockMinMinutes = 150;
  static const int preferredBlockMaxMinutes = 240;
}
