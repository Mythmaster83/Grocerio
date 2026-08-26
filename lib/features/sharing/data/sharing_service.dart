import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/list_member.dart';

/// Invitations and membership reads.
///
/// Every method is a thin wrapper over an RPC or a policy-guarded table: the
/// rules about who may invite whom live in the database, not here, so a bug in
/// this class cannot widen access.
class SharingService {
  final SupabaseClient? _client;

  SharingService(this._client);

  String? get currentUserId => _client?.auth.currentUser?.id;

  Future<Result<void>> inviteByEmail({
    required String listId,
    required String email,
  }) async {
    final client = _client;
    if (client == null) {
      return const Result.err(ValidationFailure('Sharing is unavailable.'));
    }
    final trimmed = email.trim();
    if (!trimmed.contains('@')) {
      return const Result.err(ValidationFailure('Enter a valid email address.'));
    }

    try {
      await client.rpc(
        'invite_member_by_email',
        params: {'p_list_id': listId, 'p_email': trimmed},
      );
      return const Result.ok(null);
    } on PostgrestException catch (e, st) {
      logger.error('Invite failed', e, st);
      return Result.err(_inviteFailure(e));
    } catch (e, st) {
      logger.error('Invite failed', e, st);
      return Result.err(
        NetworkFailure('Could not send the invite. Check your connection.',
            cause: e),
      );
    }
  }

  /// The server raises named exceptions so the app can say something specific;
  /// "user_not_found" in particular is the common case and needs its own copy,
  /// since the person almost certainly just hasn't installed the app yet.
  AppFailure _inviteFailure(PostgrestException e) {
    final message = e.message;
    if (message.contains('user_not_found')) {
      return const NotFoundFailure(
        'No Grocerio account uses that email yet. Ask them to sign in once, '
        'then invite them again.',
      );
    }
    if (message.contains('not_list_owner')) {
      return const UnauthorizedFailure('Only the list owner can invite people.');
    }
    return NetworkFailure('Could not send the invite.', cause: e);
  }

  Future<Result<List<ListMember>>> members(String listId) async {
    final client = _client;
    if (client == null) return const Result.ok([]);

    try {
      final rows = await client.rpc(
        'list_members_view',
        params: {'p_list_id': listId},
      ) as List<dynamic>;

      return Result.ok([
        for (final row in rows.cast<Map<String, dynamic>>())
          ListMember(
            userId: row['user_id'] as String,
            email: row['email'] as String?,
            role: (row['role'] as String?) ?? 'editor',
            isOwner: (row['is_owner'] as bool?) ?? false,
          ),
      ]);
    } catch (e, st) {
      logger.error('Could not load list members', e, st);
      return Result.err(
        NetworkFailure('Could not load who this list is shared with.', cause: e),
      );
    }
  }

  Future<Result<void>> removeMember({
    required String listId,
    required String userId,
  }) async {
    final client = _client;
    if (client == null) {
      return const Result.err(ValidationFailure('Sharing is unavailable.'));
    }
    try {
      await client
          .from('list_members')
          .delete()
          .eq('list_id', listId)
          .eq('user_id', userId);
      return const Result.ok(null);
    } catch (e, st) {
      logger.error('Could not remove member', e, st);
      return Result.err(NetworkFailure('Could not remove that person.', cause: e));
    }
  }

  /// Ids of every list that has at least one membership row visible to this
  /// user: lists they were invited to, and their own lists they've shared.
  Future<Set<String>> sharedListIds() async {
    final client = _client;
    if (client == null) return const {};
    try {
      final rows = await client.from('list_members').select('list_id');
      return {for (final row in rows) row['list_id'] as String};
    } catch (e, st) {
      // Sharing state is decoration on the home screen; failing to load it must
      // not stop lists from rendering.
      logger.warning('Could not load shared list ids: $e');
      logger.debug(st.toString());
      return const {};
    }
  }
}
