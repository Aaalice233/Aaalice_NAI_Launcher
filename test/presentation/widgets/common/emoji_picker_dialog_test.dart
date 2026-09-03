import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/emoji_picker_dialog.dart';

void main() {
  testWidgets('emoji picker adapts from 320 to 1600 logical pixels', (
    tester,
  ) async {
    final view = tester.view;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    for (final size in const [Size(320, 568), Size(1600, 900)]) {
      view.devicePixelRatio = 3;
      view.physicalSize = size * 3;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 16),
              viewInsets: EdgeInsets.only(bottom: size.width == 320 ? 240 : 0),
              textScaler: const TextScaler.linear(3),
            ),
            child: const Scaffold(body: EmojiPickerDialog()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(EmojiPicker), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'size: $size');
    }
  });
}
