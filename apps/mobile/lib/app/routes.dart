abstract final class Routes {
  static const String home = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verify = '/verify';
  static const String reset = '/reset';
  static const String settings = '/settings';

  /// Pages a signed-out user may see.
  static const Set<String> authRoutes = <String>{login, signup, verify, reset};
}
