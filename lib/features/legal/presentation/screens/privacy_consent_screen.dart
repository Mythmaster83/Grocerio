import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/legal_config.dart';
import '../../../../core/theme/tokens.dart';
import '../providers/consent_controller.dart';

/// First-run gate. Shown before the home screen until the user accepts the
/// privacy policy and terms; acceptance is persisted per install by
/// [ConsentController] so it appears only once (until the policy version bumps).
class PrivacyConsentScreen extends ConsumerStatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  ConsumerState<PrivacyConsentScreen> createState() =>
      _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends ConsumerState<PrivacyConsentScreen> {
  bool _busy = false;

  /// Gates the Continue button: the user must tick the acknowledgement box
  /// before they can proceed, so acceptance is an explicit action rather than
  /// an implicit consequence of tapping through.
  bool _agreed = false;

  Future<void> _openPolicy() async {
    final uri = Uri.tryParse(LegalConfig.privacyPolicyUrl);
    var opened = false;
    if (uri != null) {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the privacy policy. Try again later.'),
        ),
      );
    }
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    await ref.read(consentControllerProvider.notifier).accept();
    // On success GrocerApp rebuilds into HomeScreen and disposes this screen,
    // so there is nothing more to do here; the mounted guard covers the rare
    // case where the write fails and we stay put.
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.accentTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_basket_outlined,
                        size: 38,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Welcome to Grocerio',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Before you start, please review how Grocerio works and '
                    'agree to our privacy policy and terms.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _DisclaimerCard(
                    icon: Icons.groups_outlined,
                    title: 'Data is crowdsourced',
                    body:
                        'All prices and details are submitted by shoppers like '
                        'you — not from any retailer feed. They may be '
                        'incomplete or wrong and come with no warranty.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _DisclaimerCard(
                    icon: Icons.sell_outlined,
                    title: 'Prices are informational only',
                    body:
                        'Prices are estimates, not quotes. Retailers can change '
                        'them at any time, so always confirm the current price '
                        'in the store.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _DisclaimerCard(
                    icon: Icons.store_mall_directory_outlined,
                    title: 'Independent and unaffiliated',
                    body:
                        'Grocerio is not affiliated with, endorsed by, or '
                        'sponsored by any supermarket or chain named in the app. '
                        'All trademarks belong to their owners.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _DisclaimerCard(
                    icon: Icons.gavel_outlined,
                    title: "Follow each store's rules",
                    body:
                        'Some stores do not allow collecting price or product '
                        "data on their premises. Follow the store's own terms "
                        'of service — only report a price where it is allowed.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: TextButton.icon(
                      onPressed: _openPolicy,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Read the full Privacy Policy & Terms'),
                    ),
                  ),
                ],
              ),
            ),
            _ConsentFooter(
              busy: _busy,
              agreed: _agreed,
              onAgreedChanged: (value) => setState(() => _agreed = value),
              onContinue: _accept,
            ),
          ],
        ),
      ),
    );
  }
}

/// One key disclaimer, rendered as an icon + title + explanation card so the
/// three launch-critical points read as distinct, scannable items.
class _DisclaimerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _DisclaimerCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: AppBorders.hairline,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky footer with the acknowledgement checkbox and the Continue button,
/// kept out of the scroll area so the primary action is always reachable.
/// Continue stays disabled until the box is ticked.
class _ConsentFooter extends StatelessWidget {
  final bool busy;
  final bool agreed;
  final ValueChanged<bool> onAgreedChanged;
  final VoidCallback onContinue;

  const _ConsentFooter({
    required this.busy,
    required this.agreed,
    required this.onAgreedChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: AppBorders.hairlineSide),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Whole row is tappable, not just the box, so the label is a target.
          InkWell(
            onTap: busy ? null : () => onAgreedChanged(!agreed),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Checkbox(
                    value: agreed,
                    onChanged:
                        busy ? null : (value) => onAgreedChanged(value ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'I have read the Privacy Policy and agree.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (busy || !agreed) ? null : onContinue,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
