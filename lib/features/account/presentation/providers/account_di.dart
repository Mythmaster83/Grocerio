import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/backend/supabase_config.dart';
import '../../data/auth_service.dart';
import '../../data/device_auth_store.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(SupabaseConfig.clientOrNull);
});

/// The signed-in user, or null. Watch this rather than reading
/// `currentUser` directly so widgets rebuild when auth completes.
final currentUserProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.userChanges();
});

/// True when this build can talk to a backend at all.
final backendAvailableProvider = Provider<bool>((ref) {
  return ref.watch(authServiceProvider).isAvailable;
});

/// Local mirror: this install believes someone is signed in (SharedPreferences).
/// Useful while a session is restoring, and for Play / offline checks.
final deviceLoggedInProvider = FutureProvider<bool>((ref) {
  // Rebuild when auth user changes so the flag stays honest after sign-out.
  ref.watch(currentUserProvider);
  return DeviceAuthStore.isLoggedIn();
});
