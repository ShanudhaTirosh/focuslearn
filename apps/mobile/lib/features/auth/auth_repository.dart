import 'dart:async';
import 'dart:io' show SocketException;

import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An authentication failure reduced to a coarse [kind] (see `authErrorKind` in the core package).
/// The UI maps the kind to a message and never shows server text, so it cannot leak whether an account exists.
class AuthFailure implements Exception {
  const AuthFailure(this.kind);

  final String kind;

  @override
  String toString() => 'AuthFailure($kind)';
}

/// Supplies a bot-check token (Cloudflare Turnstile). Until the WebView implementation exists, [NoCaptcha] returns null,
/// which only works while captcha is DISABLED on the server (TURNSTILE_SECRET empty).
abstract class CaptchaProvider {
  Future<String?> token();
}

class NoCaptcha implements CaptchaProvider {
  const NoCaptcha();

  @override
  Future<String?> token() async => null;
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get changes => _client.auth.onAuthStateChange;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw AuthFailure(authErrorKind(code: e.code, statusCode: int.tryParse(e.statusCode ?? '')));
    } on SocketException {
      throw const AuthFailure('network');
    } on TimeoutException {
      throw const AuthFailure('network');
    }
  }

  Future<void> signUp({required String email, required String password, String? captchaToken}) =>
      _guard(() => _client.auth.signUp(email: email, password: password, captchaToken: captchaToken));

  Future<void> signIn({required String email, required String password, String? captchaToken}) =>
      _guard(() => _client.auth.signInWithPassword(email: email, password: password, captchaToken: captchaToken));

  Future<void> signOut() => _guard(() => _client.auth.signOut());

  /// Ends every session except this one. Supabase offers no per-session revoke in its public API.
  Future<void> signOutOthers() => _guard(() => _client.auth.signOut(scope: SignOutScope.others));

  Future<void> requestPasswordReset(String email, {String? captchaToken}) =>
      _guard(() => _client.auth.resetPasswordForEmail(email, captchaToken: captchaToken));

  Future<void> resendConfirmation(String email, {String? captchaToken}) =>
      _guard(() => _client.auth.resend(type: OtpType.signup, email: email, captchaToken: captchaToken));

  /// Sets a new password for the current user (used after following a reset link).
  Future<void> updatePassword(String newPassword) =>
      _guard(() => _client.auth.updateUser(UserAttributes(password: newPassword)));
}
