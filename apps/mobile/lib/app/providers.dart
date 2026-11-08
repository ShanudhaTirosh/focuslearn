import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_repository.dart';
import '../features/devices/device_repository.dart';
import '../features/profile/profile.dart';
import '../features/profile/profile_repository.dart';

/// Version sent with the device record. Set with --dart-define=APP_VERSION=1.2.3 (verify in the release pipeline).
const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseClientProvider)));

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(supabaseClientProvider)));

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) => DeviceRepository(ref.watch(supabaseClientProvider)));

/// Replace with a Turnstile WebView implementation once that spike is done (see docs/LIMITATIONS.md).
final captchaProvider = Provider<CaptchaProvider>((ref) => const NoCaptcha());

/// The current session, updated whenever the user signs in or out.
final sessionProvider = StreamProvider<Session?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield repo.currentSession;
  await for (final change in repo.changes) {
    yield change.session;
  }
});

/// The signed-in user's profile, or null if they have not finished onboarding (or are signed out).
final myProfileProvider = FutureProvider.autoDispose<Profile?>((ref) async {
  final session = ref.watch(sessionProvider).valueOrNull;
  if (session == null) {
    return null;
  }
  return ref.watch(profileRepositoryProvider).fetchMine();
});

/// Language and theme choice. Errors fall back to the defaults (the app must still start offline).
final userPreferencesProvider = FutureProvider.autoDispose<UserPreferences?>((ref) async {
  final session = ref.watch(sessionProvider).valueOrNull;
  if (session == null) {
    return null;
  }
  try {
    return await ref.watch(profileRepositoryProvider).fetchPreferences();
  } on Object {
    return null;
  }
});

final devicesProvider = FutureProvider.autoDispose<List<DeviceInfo>>((ref) => ref.watch(deviceRepositoryProvider).listMine());

final installIdProvider = FutureProvider<String>((ref) => ref.watch(deviceRepositoryProvider).installId());

final pendingDeletionProvider = FutureProvider.autoDispose<DateTime?>((ref) => ref.watch(profileRepositoryProvider).fetchPendingDeletion());
