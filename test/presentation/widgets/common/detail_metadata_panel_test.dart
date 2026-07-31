import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/shortcuts/shortcuts.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_metadata_panel.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcuts.dart';

void main() {
  testWidgets(
    'resolution uses encoded image size instead of request metadata',
    (tester) async {
      final image = img.Image(width: 640, height: 960);
      final detail = GeneratedImageDetailData(
        imageBytes: Uint8List.fromList(img.encodePng(image)),
        metadata: const NaiImageMetadata(seed: 123, width: 1792, height: 896),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DetailMetadataPanel(
                currentImage: detail,
                expandedWidth: 600,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var attempt = 0; attempt < 20; attempt++) {
        if (find.text('640 × 960').evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('640 × 960'), findsOneWidget);
      expect(find.text('1792 × 896'), findsNothing);
    },
  );

  testWidgets(
    'Ctrl+C copies selected metadata text before the viewer shortcut',
    (tester) async {
      const selectedText = 'nai-diffusion-4-5-full';
      var copiedPrompt = false;
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final image = img.Image(width: 1, height: 1);
      final detail = GeneratedImageDetailData(
        imageBytes: Uint8List.fromList(img.encodePng(image)),
        metadata: const NaiImageMetadata(model: selectedText, seed: 123),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shortcutConfigNotifierProvider.overrideWith(
              _FakeShortcutConfigNotifier.new,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PageShortcuts(
                contextType: ShortcutContext.viewer,
                shortcuts: {
                  ShortcutIds.copyPrompt: () {
                    copiedPrompt = true;
                  },
                },
                child: DetailMetadataPanel(
                  currentImage: detail,
                  expandedWidth: 600,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editable = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .singleWhere((widget) => widget.controller.text == selectedText);
      editable.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: selectedText.length,
      );
      editable.focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(clipboardText, selectedText);
      expect(copiedPrompt, isFalse);
    },
  );
}

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}
