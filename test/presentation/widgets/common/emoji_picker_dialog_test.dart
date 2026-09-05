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

    for (final size in const [
      Size(320, 568),
      Size(600, 720),
      Size(840, 760),
      Size(1180, 800),
      Size(1600, 900),
    ]) {
      view.devicePixelRatio = 3;
      view.physicalSize = size * 3;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: size,
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 16),
              viewInsets: EdgeInsets.only(bottom: size.width == 320 ? 240 : 0),
              textScaler: const TextScaler.linear(3),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => EmojiPickerDialog.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(EmojiPicker), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'size: $size');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPicker), findsNothing);
    }
  });
}
