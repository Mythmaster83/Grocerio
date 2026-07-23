import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/voice_input_controller.dart';

/// Mic button used inside the Add Item modal. Emits the raw transcript via
/// [onResult] into an editable field — never auto-commits it. See
/// VoiceInputController's doc comment for why.
class VoiceInputButton extends ConsumerWidget {
  final ValueChanged<String> onResult;
  const VoiceInputButton({super.key, required this.onResult});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceInputControllerProvider);
    final controller = ref.read(voiceInputControllerProvider.notifier);

    ref.listen(voiceInputControllerProvider, (previous, next) {
      if (previous?.status == VoiceInputStatus.listening &&
          next.status == VoiceInputStatus.idle &&
          next.transcript.isNotEmpty) {
        onResult(next.transcript);
      }
      if (next.status == VoiceInputStatus.unavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice input is not available on this device.')),
        );
      }
      if (next.status == VoiceInputStatus.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission was denied.')),
        );
      }
      if (next.status == VoiceInputStatus.blockedByOS) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
              'Microphone blocked. Open Windows Settings → Privacy & security → '
              'Microphone, and allow desktop apps to access your microphone.',
            ),
          ),
        );
      }
    });

    final listening = state.status == VoiceInputStatus.listening;

    return IconButton.filledTonal(
      icon: Icon(listening ? Icons.mic : Icons.mic_none_outlined),
      color: listening ? Theme.of(context).colorScheme.error : null,
      tooltip: listening ? 'Stop listening' : 'Add item by voice',
      onPressed: () => listening ? controller.stopListening() : controller.startListening(),
    );
  }
}
