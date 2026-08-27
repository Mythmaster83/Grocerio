import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/core/widgets/confirm_dialog.dart';

void main() {
  testWidgets(
      'confirm dialog stays in the middle of the screen when a keyboard inset is present',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 640);
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
    // _dismissKeyboard polls the engine inset for up to ~480ms in tests
    // because FakeViewPadding never drops to zero.
    await tester.pump(const Duration(milliseconds: 520));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    // AlertDialog itself expands to the overlay; measure the card chrome
    // (title through actions) so a full-screen widget cannot fake a pass.
    final top = tester.getRect(find.text('Delete item?')).top;
    final bottom = tester.getRect(find.text('Cancel')).bottom;
    final cardMid = (top + bottom) / 2;
    final screenMid = tester.getRect(find.byType(MaterialApp)).center.dy;
    expect(
      (cardMid - screenMid).abs(),
      lessThan(80),
      reason:
          'dialog card should sit in the middle of the screen, not the strip above the keyboard',
    );
  });
}
