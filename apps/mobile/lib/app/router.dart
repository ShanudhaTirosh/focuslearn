import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/update_password_screen.dart';
import '../features/auth/verify_email_screen.dart';
import '../features/enforcement/enforcement_rules_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notebooks/notebooks_hub_screen.dart';
import '../features/settings/settings_screen.dart';
import 'providers.dart';
import 'routes.dart';

/// Re-runs the router's redirect whenever the auth state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _AuthRefresh(auth.changes);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = auth.currentSession != null;
      final location = state.matchedLocation;
      final onAuthPage = Routes.authRoutes.contains(location);
      if (!signedIn && !onAuthPage) {
        return Routes.login;
      }
      if (signedIn && onAuthPage && location != Routes.updatePassword) {
        return Routes.home;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: Routes.home, builder: (context, state) => const HomeGate()),
      GoRoute(path: Routes.settings, builder: (context, state) => const SettingsScreen()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: Routes.signup, builder: (context, state) => const SignupScreen()),
      GoRoute(
        path: Routes.verify,
        builder: (context, state) => VerifyEmailScreen(email: state.extra is String ? state.extra! as String : ''),
      ),
      GoRoute(path: Routes.reset, builder: (context, state) => const ResetPasswordScreen()),
      GoRoute(path: Routes.updatePassword, builder: (context, state) => const UpdatePasswordScreen()),
      GoRoute(path: Routes.enforcement, builder: (context, state) => const EnforcementRulesScreen()),
      GoRoute(path: Routes.notebooks, builder: (context, state) => const NotebooksHubScreen()),
    ],
  );
});
