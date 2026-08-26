import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/tokens.dart';
import '../../account/presentation/providers/account_di.dart';
import '../../account/presentation/screens/profile_screen.dart';
import '../../notifications/presentation/screens/notifications_screen.dart';
import '../../preferences/presentation/screens/settings_screen.dart';
import '../../pricing/presentation/screens/price_lookup_screen.dart';
import '../../stores/presentation/providers/stores_di.dart';
import '../../stores/presentation/screens/tracked_stores_screen.dart';

/// The app's only navigation surface.
///
/// Everything that isn't a list lives here. A drawer rather than a bottom bar
/// because these are all occasional destinations — putting Settings or Price
/// lookup permanently on screen would cost a tab's worth of space to something
/// used once a week.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _go(BuildContext context, Widget screen) {
    // Grab the scaffold navigator *before* closing the drawer. Popping first
    // disposes the drawer context; a follow-up push from that context can
    // open a blank route (Your stores was the heavy screen that showed it).
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackedCount = ref.watch(trackedStoresProvider).length;
    final email = ref.watch(currentUserProvider).valueOrNull?.email;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProfileBlock(
              email: email,
              onTap: () => _go(context, const ProfileScreen()),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => _go(context, const SettingsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Your stores'),
              subtitle: Text(
                trackedCount == 0
                    ? 'Pick nearby locations'
                    : trackedCount == 1
                        ? '1 store tracked'
                        : '$trackedCount stores tracked',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
              onTap: () => _go(context, const TrackedStoresScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.sell_outlined),
              title: const Text('Price lookup'),
              onTap: () => _go(context, const PriceLookupScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: const Text('Notifications'),
              onTap: () => _go(context, const NotificationsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBlock extends StatelessWidget {
  /// Null when signed out, which is a supported long-term state, not a
  /// pre-login placeholder.
  final String? email;
  final VoidCallback onTap;

  const _ProfileBlock({required this.email, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.surfaceElevated,
              child: Icon(email == null ? Icons.person_outline : Icons.person),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email ?? 'Grocerio',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email == null
                        ? 'Sign in to share lists'
                        : 'Signed in — lists sync',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
