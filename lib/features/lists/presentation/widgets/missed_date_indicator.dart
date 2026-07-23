import 'package:flutter/material.dart';

/// Shared "last date missed" control — used on Home tiles and list detail.
class MissedDateIndicator extends StatelessWidget {
  final VoidCallback onTap;

  const MissedDateIndicator({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Last date missed',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(Icons.error_outline, color: scheme.error, size: 22),
      onPressed: onTap,
    );
  }
}

/// Shows the miss notice, then clears the persisted flag when closed.
Future<void> showMissedDateDialog({
  required BuildContext context,
  required Future<void> Function() onAcknowledge,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Last date missed'),
      content: const Text(
        'This list\'s planned date has already passed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  await onAcknowledge();
}
