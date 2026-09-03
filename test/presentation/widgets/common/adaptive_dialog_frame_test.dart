import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/adaptive_dialog_frame.dart';

void main() {
  testWidgets('bounds dialog content for landscape, large text and keyboard', (
    tester,
  ) async {
    Future<void> pump({
      required Size size,
      required double textScale,
      required double keyboardHeight,
      required double reservedSpace,
      required bool scaleReserve,
    }) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              viewInsets: EdgeInsets.only(bottom: keyboardHeight),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: AdaptiveDialogFrame(
                maxWidth: 800,
                maxHeight: 600,
                reservedVerticalSpace: reservedSpace,
                scaleReservedVerticalSpace: scaleReserve,
                child: const ColoredBox(
                  key: ValueKey('dialog-content'),
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pump(
      size: const Size(600, 360),
      textScale: 2,
      keyboardHeight: 0,
      reservedSpace: 220,
      scaleReserve: true,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('dialog-content'))).height,
      100,
    );

    await pump(
      size: const Size(320, 640),
      textScale: 1,
      keyboardHeight: 300,
      reservedSpace: 48,
      scaleReserve: false,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('dialog-content'))).height,
      340,
    );
  });
}
