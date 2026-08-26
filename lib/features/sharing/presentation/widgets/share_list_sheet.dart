import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/tokens.dart';
import '../../../account/presentation/providers/account_di.dart';
import '../../../account/presentation/screens/profile_screen.dart';
import '../../../sync/presentation/providers/sync_di.dart';
import '../../domain/entities/list_member.dart';
import '../providers/sharing_di.dart';

/// Invite people to a list and see who already has it.
///
/// Distinct from "Share as text", which copies a snapshot: this one gives
/// someone live edit access, so it needs an account on both ends and is worth a
/// separate, more explicit entry point.
Future<void> showShareListSheet(
  BuildContext context, {
  required String listId,
  required String listName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ShareListSheet(listId: listId, listName: listName),
  );
}

class _ShareListSheet extends ConsumerStatefulWidget {
  final String listId;
  final String listName;

  const _ShareListSheet({required this.listId, required this.listName});

  @override
  ConsumerState<_ShareListSheet> createState() => _ShareListSheetState();
}

class _ShareListSheetState extends ConsumerState<_ShareListSheet> {
  final _emailController = TextEditingController();
  bool _inviting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    if (_inviting) return;
    setState(() => _inviting = true);

    final result = await ref.read(sharingServiceProvider).inviteByEmail(
          listId: widget.listId,
          email: _emailController.text,
        );
    if (!mounted) return;
    setState(() => _inviting = false);

    result.when(
      ok: (_) {
        _emailController.clear();
        ref.invalidate(listMembersProvider(widget.listId));
        ref.invalidate(sharedListIdsProvider);
        // The invitee can only see the list once its rows exist server-side.
        ref.read(syncStatusProvider.notifier).syncNow();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invited — they can edit this list now')),
        );
      },
      err: (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  Future<void> _remove(ListMember member) async {
    final result = await ref.read(sharingServiceProvider).removeMember(
          listId: widget.listId,
          userId: member.userId,
        );
    if (!mounted) return;
    result.when(
      ok: (_) {
        ref.invalidate(listMembersProvider(widget.listId));
        ref.invalidate(sharedListIdsProvider);
      },
      err: (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final signedIn = ref.watch(currentUserProvider).valueOrNull != null;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share this list', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.listName,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!signedIn)
              _SignInPrompt(
                onSignIn: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              )
            else ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _invite(),
                decoration: const InputDecoration(
                  labelText: 'Invite by email',
                  hintText: 'them@example.com',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _inviting ? null : _invite,
                child: _inviting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send invite'),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Has access', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              _MemberList(listId: widget.listId, onRemove: _remove),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  final VoidCallback onSignIn;
  const _SignInPrompt({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sharing needs an account so the other person\'s edits can reach you. '
          'You can still copy the list as text without one.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: onSignIn, child: const Text('Sign in')),
      ],
    );
  }
}

class _MemberList extends ConsumerWidget {
  final String listId;
  final ValueChanged<ListMember> onRemove;

  const _MemberList({required this.listId, required this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final membersAsync = ref.watch(listMembersProvider(listId));
    final currentUserId = ref.watch(sharingServiceProvider).currentUserId;

    return membersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text(
        'Could not load who has access.',
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
      ),
      data: (members) {
        if (members.isEmpty) {
          return Text(
            'Only you.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
          );
        }
        final isOwner = members.any(
          (m) => m.isOwner && m.userId == currentUserId,
        );
        return Column(
          children: [
            for (final member in members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.person_outline),
                title: Text(member.label),
                subtitle: Text(member.isOwner ? 'Owner' : 'Can edit'),
                // The owner can remove anyone; a member can only remove
                // themselves, which is how leaving a shared list works.
                trailing: member.isOwner
                    ? null
                    : (isOwner || member.userId == currentUserId)
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: member.userId == currentUserId
                                ? 'Leave list'
                                : 'Remove',
                            onPressed: () => onRemove(member),
                          )
                        : null,
              ),
          ],
        );
      },
    );
  }
}
