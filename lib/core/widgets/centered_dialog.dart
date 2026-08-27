import 'package:flutter/material.dart';

/// Shows a material dialog that stays in the middle of the screen.
///
/// Two things conspire to glue dialogs to the bottom after inline item edit:
/// the IME is often still up, and [Dialog] pads itself by
/// [MediaQuery.viewInsets] (the keyboard). The remaining overlay is a strip
/// above the keyboard, so a "centered" dialog looks parked at the bottom.
///
/// This helper dismisses focus, then (by default) zeros viewInsets for the
/// dialog route so [DialogTheme.alignment] is the real screen center.
Future<T?> showCenteredDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  /// Keep keyboard padding so a tall form (sign-up) can still rise above the
  /// IME. Confirm / picker dialogs should leave this true.
  bool ignoreViewInsets = true,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  // One frame is not enough for the IME to report a zero inset on Android.
  await Future<void>.delayed(const Duration(milliseconds: 80));
  if (!context.mounted) return null;

  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      Widget dialog = builder(ctx);
      if (ignoreViewInsets) {
        final media = MediaQuery.of(ctx);
        dialog = MediaQuery(
          data: media.copyWith(viewInsets: EdgeInsets.zero),
          child: dialog,
        );
      }
      // App-wide FilledButtons use an infinite min width so they fill forms.
      // Inside a dialog that forces the action bar to wrap and the sheet to
      // grow until it sits on the bottom edge.
      return Theme(
        data: Theme.of(ctx).copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        child: dialog,
      );
    },
  );
}
