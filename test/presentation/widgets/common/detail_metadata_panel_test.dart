import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/shortcuts/shortcuts.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_metadata_panel.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/prompt_copy_dialog.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/prompt_section.dart';
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
    'legacy metadata matches current fixed library and opens copy categories',
    (tester) async {
      final image = img.Image(width: 1, height: 1);
      final detail = GeneratedImageDetailData(
        imageBytes: Uint8List.fromList(img.encodePng(image)),
        metadata: const NaiImageMetadata(
          prompt: 'private prefix, 1girl, blue hair',
          negativePrompt: 'bad hands',
          characterInfos: [CharacterPromptInfo(prompt: 'rabbit girl')],
        ),
      );
      final fixedEntry = FixedTagEntry.create(
        name: 'private',
        content: 'private prefix',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fixedTagsNotifierProvider.overrideWith(
              () => _FakeFixedTagsNotifier(fixedEntry),
            ),
          ],
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
      await tester.pumpAndSettle();

      final sections = tester
          .widgetList<PromptSection>(find.byType(PromptSection))
          .toList();
      expect(sections, hasLength(2));
      final mainSection = sections.first;
      expect(mainSection.fixedTags, contains('private prefix'));
      expect(mainSection.characterTags, contains('rabbit girl'));
      expect(mainSection.onCopy, isNotNull);
      expect(sections.last.isNegative, isTrue);
      expect(find.byIcon(Icons.library_add), findsNWidgets(2));
      expect(find.byType(AnimatedCrossFade), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PromptSection),
          matching: find.byType(AnimatedSize),
        ),
        findsNWidgets(2),
      );

      final copyFuture = mainSection.onCopy!();
      await tester.pumpAndSettle();

      expect(find.byType(PromptCopyDialog), findsOneWidget);
      final categoryTiles = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(categoryTiles, hasLength(4));
      expect(categoryTiles.last.onChanged, isNotNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await copyFuture;
    },
  );

  testWidgets('copy all TAGs writes the complete local prompt export', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String?;
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
      metadata: const NaiImageMetadata(
        prompt: '{{1girl}}, blue hair',
        negativePrompt: '[lowres]',
        characterInfos: [
          CharacterPromptInfo(prompt: 'red hair', negativePrompt: 'bad hands'),
        ],
      ),
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
              expandedWidth: 360,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final copyAll = find.text('复制全部 TAG');
    await tester.ensureVisible(copyAll);
    await tester.tap(copyAll);
    await tester.pump();

    expect(
      clipboardText,
      startsWith(
        'positive: {{1girl}}, blue hair | red hair\n'
        'negative: [lowres] | bad hands',
      ),
    );
    expect(clipboardText, isNot('{}'));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('keeps a comma inside nested weights as one detail chip', (
    tester,
  ) async {
    const fragment = '{{{blue_eyes, long_hair}}}';
    final image = img.Image(width: 1, height: 1);
    final detail = GeneratedImageDetailData(
      imageBytes: Uint8List.fromList(img.encodePng(image)),
      metadata: const NaiImageMetadata(prompt: '$fragment, city'),
    );
    final fixedEntry = FixedTagEntry.create(
      name: 'weighted group',
      content: fragment,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fixedTagsNotifierProvider.overrideWith(
            () => _FakeFixedTagsNotifier(fixedEntry),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DetailMetadataPanel(currentImage: detail, expandedWidth: 600),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final section = tester.widget<PromptSection>(find.byType(PromptSection));
    expect(section.tags, const [fragment, 'city']);
    expect(section.fixedTags, contains(fragment));
    expect(find.textContaining(fragment), findsOneWidget);
    expect(find.text('{{{blue_eyes'), findsNothing);
    expect(find.text('long_hair}}}'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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

class _FakeFixedTagsNotifier extends FixedTagsNotifier {
  _FakeFixedTagsNotifier(this.entry);

  final FixedTagEntry entry;

  @override
  FixedTagsState build() => FixedTagsState(entries: [entry]);
}

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}
