import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../l10n/generated/app_localizations.dart';
import '../devices/device_repository.dart';
import '../profile/onboarding_screen.dart';
import '../profile/profile.dart';

/// Decides what a signed-in user sees: loading, an error with retry, onboarding (no profile yet), or the home screen.
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
    final text = Theme.of(context).textTheme;
    final profile = widget.profile;
    final minor = isPossibleMinor(profile.birthYear, DateTime.now().year);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l10n.welcomeUser(profile.displayName), style: text.headlineSmall),
                const SizedBox(height: Spacing.lg),
                AppCard(child: Text(l10n.homePlannerSoon, style: text.bodyMedium)),
                if (minor) ...<Widget>[
                  const SizedBox(height: Spacing.lg),
                  StatusBanner(kind: BannerKind.info, message: l10n.minorNotice),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
