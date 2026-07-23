import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../../core/utils/app_logger.dart';

enum VoiceInputStatus { idle, listening, unavailable, denied, blockedByOS, error }

class VoiceInputState {
  final VoiceInputStatus status;
  final String transcript;
  const VoiceInputState({required this.status, this.transcript = ''});

  VoiceInputState copyWith({VoiceInputStatus? status, String? transcript}) => VoiceInputState(
        status: status ?? this.status,
        transcript: transcript ?? this.transcript,
      );
}

/// Wraps `speech_to_text`. KNOWN LIMITATION (carried over intentionally,
/// tracked in goals.md): on-device speech recognition quality varies by
/// platform/locale and can mis-transcribe short grocery-item names or
/// plural/singular forms ("egg" vs "eggs"). This controller surfaces the
/// raw transcript and lets the caller (add_item_modal) put it in an
/// editable text field rather than auto-submitting it — that one decision
/// converts "voice input occasionally wrong" from a data-integrity bug
/// into a normal, correctable text field, which is the pragmatic MVP fix
/// until a grocery-domain-tuned recognizer is worth the investment.
class VoiceInputController extends Notifier<VoiceInputState> {
  final SpeechToText _speech = SpeechToText();

  bool get _isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  VoiceInputState build() => const VoiceInputState(status: VoiceInputStatus.idle);

  Future<void> startListening() async {
    final available = await _speech.initialize(
      onError: (err) {
        logger.warning('Speech error: ${err.errorMsg}');
        if (_isWindows) {
          state = state.copyWith(status: VoiceInputStatus.blockedByOS);
          return;
        }
        if (err.errorMsg == 'error_permission') {
          state = state.copyWith(status: VoiceInputStatus.denied);
          return;
        }
        state = state.copyWith(status: VoiceInputStatus.error);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          state = state.copyWith(status: VoiceInputStatus.idle);
        }
      },
    );

    // hasPermission is meaningful on mobile; on Windows the plugin always
    // returns true without checking OS privacy settings.
    if (!_isWindows) {
      final hasPerm = await _speech.hasPermission;
      if (!hasPerm) {
        state = state.copyWith(status: VoiceInputStatus.denied);
        return;
      }
    }

    if (!available) {
      state = state.copyWith(
        status: _isWindows ? VoiceInputStatus.blockedByOS : VoiceInputStatus.unavailable,
      );
      return;
    }

    state = state.copyWith(status: VoiceInputStatus.listening, transcript: '');
    try {
      await _speech.listen(
        onResult: (result) {
          state = state.copyWith(transcript: result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (e, st) {
      logger.error('Failed to start speech recognition', e, st);
      state = state.copyWith(
        status: _isWindows ? VoiceInputStatus.blockedByOS : VoiceInputStatus.error,
      );
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
    state = state.copyWith(status: VoiceInputStatus.idle);
  }
}

final voiceInputControllerProvider =
    NotifierProvider<VoiceInputController, VoiceInputState>(VoiceInputController.new);
