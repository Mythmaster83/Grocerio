import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/backend/supabase_config.dart';
import '../../../account/presentation/providers/account_di.dart';
import '../../data/sharing_service.dart';
import '../../domain/entities/list_member.dart';

final sharingServiceProvider = Provider<SharingService>((ref) {
  return SharingService(SupabaseConfig.clientOrNull);
});

/// Who a single list is shared with. Invalidated after an invite or removal.
final listMembersProvider =
    FutureProvider.family<List<ListMember>, String>((ref, listId) async {
  // Rebuild on sign-in/out: membership is meaningless without a session.
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return const [];

  final result = await ref.watch(sharingServiceProvider).members(listId);
  return result.when(ok: (members) => members, err: (failure) => throw failure);
});

/// Lists that involve someone else, used by the home screen filter chips.
///
/// Derived from the server rather than stored locally: membership is not
/// something the device can know on its own, and a stale local copy would make
/// the Shared chip lie.
final sharedListIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return const {};
  return ref.watch(sharingServiceProvider).sharedListIds();
});
