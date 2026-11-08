import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../calculators/calculators_screen.dart';
import '../devices/device_repository.dart';
import '../focus/focus_timer_screen.dart';
import '../notes/notes_screen.dart';
import '../planner/timetable_screen.dart';
import '../profile/onboarding_screen.dart';
import '../profile/profile.dart';
import '../social/social_screen.dart';

/// Decides what a signed-in user sees: loading, an error with retry, onboarding (no profile yet), or the home shell.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(myProfileProvider);
    return profile.when(
      loading: () => Scaffold(body: LoadingView(label: l10n.loadingProfile)),
      error: (error, stack) => Scaffold(
        body: ErrorView(
          message: l10n.errorLoadProfile,
          retryLabel: l10n.retry,
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
      ),
      data: (p) => p == null ? const OnboardingScreen() : HomeScreen(profile: p),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  static const List<Widget> _screens = <Widget>[
    TimetableScreen(),
    FocusTimerScreen(),
    CalculatorsScreen(),
    NotesScreen(),
    SocialScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerDevice());
  }

  Future<void> _registerDevice() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(deviceRepositoryProvider).registerThisDevice(appVersion: appVersion);
      if (result == DeviceRegistration.revoked) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.deviceRevokedSignedOut)));
        await ref.read(authRepositoryProvider).signOut();
      }
    } on Object {
      // Offline or the table is unavailable: the device is registered again at the next start.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: l10n.navPlanner,
          ),
          NavigationDestination(
            icon: const Icon(Icons.timer_outlined),
            selectedIcon: const Icon(Icons.timer),
            label: l10n.navFocus,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calculate_outlined),
            selectedIcon: const Icon(Icons.calculate),
            label: l10n.navCalculators,
          ),
          NavigationDestination(
            icon: const Icon(Icons.edit_note_outlined),
            selectedIcon: const Icon(Icons.edit_note),
            label: l10n.navNotes,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: l10n.socialTitle,
          ),
        ],
      ),
    );
  }
}
