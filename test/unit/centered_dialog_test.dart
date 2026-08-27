import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/core/widgets/confirm_dialog.dart';

void main() {
  testWidgets(
      'confirm dialog stays in the middle of the screen when a keyboard inset is present',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding.only(bottom: 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showConfirmDialog(
                  context,
                  title: 'Delete item?',
                  message: 'Milk will be removed from this list.',
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    final dialogRect = tester.getRect(find.byType(AlertDialog));
    final screenRect = tester.getRect(find.byType(MaterialApp));
    expect(
      (dialogRect.center.dy - screenRect.center.dy).abs(),
      lessThan(80),
      reason:
          'dialog should sit in the middle of the screen, not the strip above the keyboard',
    );
  });
}
