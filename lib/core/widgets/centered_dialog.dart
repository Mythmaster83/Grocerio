import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a material dialog in the visual middle of the screen.
///
/// [Dialog] centers itself in the area *above* [MediaQuery.viewInsets] (the
/// keyboard). After inline item edit the IME is still up, so that area is a
/// thin strip and the dialog looks glued to the bottom. Zeroing viewInsets
/// instead centers on the full window — which is behind the OS keyboard, so
/// the same dialog still looks bottom-stuck.
///
/// The reliable sequence is: hide the IME, wait until the engine reports a
/// closed inset, then show the dialog on a route that no longer pads for
/// the keyboard.
Future<T?> showCenteredDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  /// When false, the scaffold resizes for the IME so a tall form (sign-up)
  /// can still rise above the keyboard after its own fields take focus.
  bool ignoreViewInsets = true,
}) async {
  await _dismissKeyboard(context);
  if (!context.mounted) return null;

  final capturedTheme = Theme.of(context);

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      Widget dialog = builder(ctx);
      // App-wide FilledButtons use an infinite min width so they fill forms.
      // Inside a dialog that forces the action bar to wrap and the sheet to
      // grow until it sits on the bottom edge.
      dialog = Theme(
        data: capturedTheme.copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        child: dialog,
      );

      if (ignoreViewInsets) {
        dialog = MediaQuery.removeViewInsets(
          context: ctx,
          removeLeft: true,
          removeTop: true,
          removeRight: true,
          removeBottom: true,
          child: dialog,
        );
      }

      // Scaffold absorbs hits, which would block the modal barrier. Only use
      // one when a tall form must resize for its own keyboard.
      if (!ignoreViewInsets) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: Align(
            alignment: Alignment.center,
            child: dialog,
          ),
        );
      }

      return Align(
        alignment: Alignment.center,
        child: dialog,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

Future<void> _dismissKeyboard(BuildContext context) async {
  FocusManager.instance.primaryFocus?.unfocus();
  try {
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
  } catch (_) {
    // Tests and desktop have no IME channel; hiding is best-effort.
  }
  if (!context.mounted) return;

  double bottomInset() {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  if (bottomInset() < 1) return;

  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!context.mounted) return;
    if (bottomInset() < 1) return;
  }
}
