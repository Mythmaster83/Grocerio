import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/backend/supabase_config.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/result.dart';
import 'device_auth_store.dart';

/// Email authentication: password (primary) and magic link (fallback).
///
/// supabase_flutter persists the JWT session across app restarts. We also
/// mirror signed-in state into [DeviceAuthStore] so this install can answer
/// "is someone logged in here?" without waiting on a network round-trip.
class AuthService {
  final SupabaseClient? _client;

  AuthService(this._client);

  bool get isAvailable => _client != null;

  User? get currentUser => _client?.auth.currentUser;

  bool get hasSession => _client?.auth.currentSession != null;

  /// Emits on sign-in, sign-out, and token refresh. Single-value when there is
  /// no backend so widgets don't need a separate code path.
  Stream<User?> userChanges() {
    final client = _client;
    if (client == null) return Stream.value(null);
    return client.auth.onAuthStateChange.asyncMap((state) async {
      final user = state.session?.user;
      if (user != null) {
        await DeviceAuthStore.markSignedIn(user.email ?? '');
      } else if (state.event == AuthChangeEvent.signedOut) {
        await DeviceAuthStore.markSignedOut();
      }
      return user;
    });
  }

  /// Align the local device flag with the restored Supabase session (call once
  /// after [SupabaseConfig.initialize]).
  Future<void> syncDeviceLoginFlag() async {
    final user = currentUser;
    if (user != null) {
      await DeviceAuthStore.markSignedIn(user.email ?? '');
      return;
    }
    if (_client?.auth.currentSession == null) {
      await DeviceAuthStore.markSignedOut();
    }
  }

  Future<Result<void>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      return const Result.err(
        ValidationFailure('Sign-in is unavailable in this build.'),
      );
    }
    final trimmed = email.trim();
    final validation = _validateEmailPassword(trimmed, password);
    if (validation != null) return Result.err(validation);

    try {
      final response = await client.auth.signInWithPassword(
        email: trimmed,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return const Result.err(
          UnauthorizedFailure('Sign-in failed. Check email and password.'),
        );
      }
      await DeviceAuthStore.markSignedIn(user.email ?? trimmed);
      return const Result.ok(null);
    } on AuthException catch (e, st) {
      logger.error('Password sign-in failed', e, st);
      return Result.err(UnauthorizedFailure(_friendlyAuthMessage(e), cause: e));
    } catch (e, st) {
      logger.error('Password sign-in failed', e, st);
      return Result.err(
        NetworkFailure('Could not sign in. Try again.', cause: e),
      );
    }
  }

  /// Creates an account. If email confirmation is required, returns
  /// [SignUpResult.needsEmailConfirmation] and there is no session yet.
  ///
  /// Uses [SupabaseConfig.authEmailRedirectUrl] (HTTPS “verified” page) when
  /// set — never the custom-scheme deep link, which triggers “Invalid path…”
  /// if Site URL / Redirect URLs are wrong. If the HTTPS URL is unset, confirm
  /// emails use Supabase Site URL (must not be localhost).
  Future<Result<SignUpResult>> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      return const Result.err(
        ValidationFailure('Sign-up is unavailable in this build.'),
      );
    }
    final trimmed = email.trim();
    final validation = _validateEmailPassword(trimmed, password);
    if (validation != null) return Result.err(validation);

    try {
      final confirmRedirect = SupabaseConfig.authEmailRedirectUrl.trim();
      final response = await client.auth.signUp(
        email: trimmed,
        password: password,
        emailRedirectTo: confirmRedirect.isEmpty ? null : confirmRedirect,
      );

      // Supabase returns a user with empty identities when the email is already
      // registered (anti-enumeration). Treat that as "sign in instead".
      final identities = response.user?.identities;
      if (response.user != null &&
          (identities == null || identities.isEmpty) &&
          response.session == null) {
        return const Result.err(
          UnauthorizedFailure(
            'That email already has an account. Sign in instead.',
          ),
        );
      }

      if (response.session != null && response.user != null) {
        await DeviceAuthStore.markSignedIn(response.user!.email ?? trimmed);
        return const Result.ok(SignUpResult.signedIn);
      }
      if (response.user != null) {
        return const Result.ok(SignUpResult.needsEmailConfirmation);
      }
      return const Result.err(
        NetworkFailure('Could not create the account. Try again.'),
      );
    } on AuthException catch (e, st) {
      logger.error('Sign-up failed', e, st);
      return Result.err(UnauthorizedFailure(_friendlyAuthMessage(e), cause: e));
    } catch (e, st) {
      logger.error('Sign-up failed', e, st);
      return Result.err(
        NetworkFailure('Could not create the account. Try again.', cause: e),
      );
    }
  }

  Future<Result<void>> sendPasswordResetEmail(String email) async {
    final client = _client;
    if (client == null) {
      return const Result.err(
        ValidationFailure('Password reset is unavailable in this build.'),
      );
    }
    final trimmed = email.trim();
    if (!trimmed.contains('@') || trimmed.length < 5) {
      return const Result.err(ValidationFailure('Enter a valid email address.'));
    }
    try {
      await client.auth.resetPasswordForEmail(
        trimmed,
        redirectTo: SupabaseConfig.authRedirectUrl,
      );
      return const Result.ok(null);
    } on AuthException catch (e, st) {
      logger.error('Password reset failed', e, st);
      return Result.err(UnauthorizedFailure(_friendlyAuthMessage(e), cause: e));
    } catch (e, st) {
      logger.error('Password reset failed', e, st);
      return Result.err(
        NetworkFailure('Could not send the reset email.', cause: e),
      );
    }
  }

  Future<Result<void>> sendSignInLink(String email) async {
    final client = _client;
    if (client == null) {
      return const Result.err(
        ValidationFailure('Sign-in is unavailable in this build.'),
      );
    }
    final trimmed = email.trim();
    if (!trimmed.contains('@') || trimmed.length < 5) {
      return const Result.err(ValidationFailure('Enter a valid email address.'));
    }

    try {
      await client.auth.signInWithOtp(
        email: trimmed,
        emailRedirectTo: SupabaseConfig.authRedirectUrl,
      );
      return const Result.ok(null);
    } on AuthException catch (e, st) {
      logger.error('Sign-in link failed', e, st);
      return Result.err(UnauthorizedFailure(_friendlyAuthMessage(e), cause: e));
    } catch (e, st) {
      logger.error('Sign-in link failed', e, st);
      return Result.err(
        NetworkFailure('Could not send the sign-in link.', cause: e),
      );
    }
  }

  static ValidationFailure? _validateEmailPassword(
    String email,
    String password,
  ) {
    if (!email.contains('@') || email.length < 5) {
      return const ValidationFailure('Enter a valid email address.');
    }
    if (password.length < 6) {
      return const ValidationFailure('Password must be at least 6 characters.');
    }
    return null;
  }

  static String _friendlyAuthMessage(AuthException e) {
    final raw = e.message;
    final lower = raw.toLowerCase();
    if (lower.contains('invalid path') || lower.contains('redirect')) {
      return 'Auth link failed: check Supabase Site URL '
          '(must be http/https) and that Redirect URLs includes '
          '${SupabaseConfig.authRedirectUrl}';
    }
    if (lower.contains('invalid login') ||
        lower.contains('invalid credentials')) {
      return 'Wrong email or password.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already been registered')) {
      return 'That email already has an account. Sign in instead.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Confirm your email from the message we sent, then sign in.';
    }
    if (lower.contains('signup is disabled') ||
        lower.contains('signups not allowed')) {
      return 'New accounts are disabled in Supabase. Enable Email sign-ups '
          'under Authentication → Providers → Email.';
    }
    return raw;
  }

  Future<Result<void>> signOut() async {
    final client = _client;
    if (client == null) {
      await DeviceAuthStore.markSignedOut();
      return const Result.ok(null);
    }
    try {
      await client.auth.signOut();
      await DeviceAuthStore.markSignedOut();
      return const Result.ok(null);
    } catch (e, st) {
      logger.error('Sign-out failed', e, st);
      return Result.err(NetworkFailure('Could not sign out.', cause: e));
    }
  }

  Future<Result<void>> deleteAccount() async {
    final client = _client;
    if (client == null) {
      return const Result.err(
        ValidationFailure('Account deletion is unavailable in this build.'),
      );
    }
    try {
      await client.rpc('delete_own_account');
      await client.auth.signOut();
      await DeviceAuthStore.markSignedOut();
      return const Result.ok(null);
    } on PostgrestException catch (e, st) {
      logger.error('Account deletion failed', e, st);
      return Result.err(
        NetworkFailure('Could not delete the account.', cause: e),
      );
    } catch (e, st) {
      logger.error('Account deletion failed', e, st);
      return Result.err(
        NetworkFailure('Could not delete the account.', cause: e),
      );
    }
  }
}

enum SignUpResult {
  signedIn,
  needsEmailConfirmation,
}
