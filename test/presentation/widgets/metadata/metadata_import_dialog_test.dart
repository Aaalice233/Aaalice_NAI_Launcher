import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/metadata/metadata_import_options.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/utils/fixed_tag_import_resolution.dart';
import 'package:nai_launcher/presentation/widgets/common/translated_tag_text.dart';
import 'package:nai_launcher/presentation/widgets/metadata/metadata_import_dialog.dart';

void main() {
  Future<void> pumpAndOpenDialog(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    EdgeInsets padding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
    NaiImageMetadata metadata = const NaiImageMetadata(steps: 28, scale: 5),
    FixedTagImportResolution? fixedTagResolution,
    MetadataImportOptions? initialOptions,
    TagTranslationLookup? translationLookup,
    ValueChanged<MetadataImportOptions?>? onClosed,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: padding,
            viewPadding: padding,
            viewInsets: viewInsets,
            textScaler: TextScaler.linear(textScale),
          ),
          child: translationLookup == null
              ? child!
              : ProviderScope(
                  overrides: [
                    tagTranslationLookupProvider.overrideWithValue(
                      translationLookup,
                    ),
                  ],
                  child: child!,
                ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('open-metadata-import'),
              onPressed: () async {
                final result = await MetadataImportDialog.show(
                  context,
                  metadata: metadata,
                  fixedTagResolution: fixedTagResolution,
                  initialOptions: initialOptions,
                );
                onClosed?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-metadata-import')));
    await tester.pumpAndSettle();
  }

  testWidgets('compact form uses a bottom sheet and respects SafeArea', (
    tester,
  ) async {
    const size = Size(320, 640);
    const safePadding = EdgeInsets.fromLTRB(8, 24, 12, 20);
    await pumpAndOpenDialog(tester, size: size, padding: safePadding);

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOne);
    final rect = tester.getRect(
      find.byKey(const ValueKey('adaptive-bottom-sheet')),
    );
    expect(rect.left, greaterThanOrEqualTo(safePadding.left));
    expect(rect.top, greaterThanOrEqualTo(safePadding.top));
    expect(rect.right, lessThanOrEqualTo(size.width - safePadding.right));
    expect(rect.bottom, lessThanOrEqualTo(size.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large text and IME keep compact actions visible and scrollable',
    (tester) async {
      const size = Size(320, 700);
      const keyboardInset = 260.0;
      await pumpAndOpenDialog(
        tester,
        size: size,
        textScale: 3,
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
        viewInsets: const EdgeInsets.only(bottom: keyboardInset),
      );

      expect(find.byKey(const Key('metadata-import-options-list')), findsOne);
      expect(find.text('Confirm'), findsOne);
      final dialogRect = tester.getRect(
        find.byKey(const ValueKey('adaptive-bottom-sheet')),
      );
      expect(dialogRect.bottom, lessThanOrEqualTo(size.height - keyboardInset));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('medium and expanded presentations stay width-bounded', (
    tester,
  ) async {
    for (final size in [const Size(700, 800), const Size(1000, 800)]) {
      await pumpAndOpenDialog(tester, size: size);

      final surfaceFinder = size.width < 600
          ? find.byKey(const ValueKey('adaptive-bottom-sheet'))
          : find.byKey(const ValueKey('adaptive-centered-form'));
      expect(surfaceFinder, findsOneWidget);
      expect(
        tester.getSize(surfaceFinder).width,
        lessThanOrEqualTo(size.width),
      );
      expect(tester.takeException(), isNull, reason: '$size');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('system back dismisses without returning import options', (
    tester,
  ) async {
    Object? result = 'open';
    await pumpAndOpenDialog(
      tester,
      size: const Size(320, 640),
      onClosed: (value) => result = value,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsNothing);
    expect(find.byKey(const Key('open-metadata-import')), findsOneWidget);
  });

  testWidgets('generation-only preset preserves selective import result', (
    tester,
  ) async {
    MetadataImportOptions? result;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await MetadataImportDialog.show(
                  context,
                  metadata: const NaiImageMetadata(
                    prompt: 'main prompt',
                    steps: 28,
                    scale: 5,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Parameters Only'));
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.importPrompt, isFalse);
    expect(result!.importSteps, isTrue);
    expect(result!.importScale, isTrue);
  });

  testWidgets('generation option labels omit localized value separators', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MetadataImportDialog(
            metadata: NaiImageMetadata(steps: 28, scale: 5),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('步数'), findsOneWidget);
    expect(find.text('CFG 强度'), findsOneWidget);
    expect(find.text('CFG 强度：'), findsNothing);
  });

  testWidgets('unknown fixed tags require an explicit stacking policy', (
    tester,
  ) async {
    const metadata = NaiImageMetadata(prompt: 'shared prompt');
    await pumpAndOpenDialog(
      tester,
      size: const Size(700, 800),
      metadata: metadata,
      fixedTagResolution: const FixedTagImportResolution(
        metadata: metadata,
        source: FixedTagImportSource.unknown,
      ),
    );

    expect(find.text('Source: not recorded; cannot be determined'), findsOne);
    expect(find.text('Disable current fixed tags (recommended)'), findsOne);
    expect(find.text('Keep and stack with the image prompt'), findsOne);
  });

  testWidgets('negative preview matches what the import writes', (
    tester,
  ) async {
    const model = ImageModels.animeDiffusionV45Full;
    final heavy = UcPresets.getPresetContent(model, UcPresetType.heavy);
    final metadata = NaiImageMetadata(
      prompt: '1girl',
      negativePrompt: '$heavy, bad hands, watermark',
      model: model,
      ucPreset: UcPresets.heavyApiValue,
      fixedNegativePrefixTags: const ['bad hands'],
    );
    Iterable<String> previews() => tester
        .widgetList<TranslatedPromptText>(find.byType(TranslatedPromptText))
        .map((widget) => widget.prompt);

    await pumpAndOpenDialog(
      tester,
      size: const Size(900, 1000),
      metadata: metadata,
    );

    expect(previews(), contains('watermark'));
    expect(previews(), isNot(contains(metadata.negativePrompt)));

    await tester.tap(
      find.widgetWithText(FilterChip, 'Undesired Content Preset'),
    );
    await tester.pump();

    expect(previews(), contains('$heavy, watermark'));
  });

  Future<void> revealOption(WidgetTester tester, Finder option) async {
    final scrollable = find.descendant(
      of: find.byKey(const Key('metadata-import-options-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(option, 160, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(option.hitTestable(), findsOneWidget);
  }

  Future<void> tapOption(WidgetTester tester, String label) async {
    final option = find.text(label);
    await revealOption(tester, option);
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'legacy image shows a usable mode even with fixed tag resolution',
    (tester) async {
      const image = NaiImageMetadata(characterPrompts: ['A']);
      MetadataImportOptions? result;
      await pumpAndOpenDialog(
        tester,
        size: const Size(600, 800),
        metadata: image,
        fixedTagResolution: resolveFixedTagImport(metadata: image, entries: []),
        initialOptions: MetadataImportOptions.none().copyWith(
          importCharacterPrompts: true,
        ),
        onClosed: (value) => result = value,
      );
      final confirm = find.widgetWithText(FilledButton, 'Confirm');
      await tapOption(tester, 'Append to the end');
      await tapOption(tester, 'Character Prompts (1)');
      final appendTile = find.widgetWithText(
        RadioListTile<CharacterImportMode>,
        'Append to the end',
      );
      expect(
        tester.widget<RadioListTile<CharacterImportMode>>(appendTile).enabled,
        isFalse,
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tapOption(tester, 'Character Prompts (1)');
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result!.characterImportMode, CharacterImportMode.append);
      expect(result!.selectedCountFor(image), 1);
      expect(result!.selectedCharacterIndices, isEmpty);
    },
  );

  testWidgets(
    'mode alone cannot confirm after the final detailed row is unchecked',
    (tester) async {
      const image = NaiImageMetadata(
        characterInfos: [CharacterPromptInfo(prompt: 'A')],
      );
      await pumpAndOpenDialog(
        tester,
        size: const Size(600, 800),
        metadata: image,
        initialOptions: MetadataImportOptions.none().copyWith(
          importCharacterPrompts: true,
        ),
      );
      await tapOption(tester, 'Append to the end');
      await tapOption(tester, 'Character 1: A');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
            .onPressed,
        isNull,
      );
    },
  );

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      'character mode and last row are reachable at ${width}px with 3x text',
      (tester) async {
        final prompts = [for (var i = 1; i <= 6; i++) 'subject $i'];
        final image = NaiImageMetadata(
          characterPrompts: prompts,
          characterInfos: [
            for (final p in prompts) CharacterPromptInfo(prompt: p),
          ],
        );
        MetadataImportOptions? result;
        await pumpAndOpenDialog(
          tester,
          size: Size(width, 850),
          textScale: 3,
          metadata: image,
          fixedTagResolution: resolveFixedTagImport(
            metadata: image,
            entries: [],
          ),
          initialOptions: MetadataImportOptions.none().copyWith(
            importCharacterPrompts: true,
          ),
          onClosed: (value) => result = value,
        );
        expect(
          find.byKey(
            ValueKey(
              width < 600 ? 'adaptive-bottom-sheet' : 'adaptive-centered-form',
            ),
          ),
          findsOneWidget,
        );
        await tapOption(tester, 'Append to the end');
        expect(
          tester.getTopLeft(find.text('Character Prompts (6)')).dy,
          lessThan(tester.getTopLeft(find.text('Character import mode')).dy),
        );
        expect(
          tester.getTopLeft(find.text('Append to the end')).dy,
          lessThan(tester.getTopLeft(find.text('Character 1: subject 1')).dy),
        );
        await tapOption(tester, 'Character 6: subject 6');
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(result!.characterImportMode, CharacterImportMode.append);
        expect(result!.selectedCharacterIndices, [0, 1, 2, 3, 4]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'long character translations stay on one line at 320px with 3x text',
    (tester) async {
      const dictionary = {
        'long_hair': '长发',
        'blue_eyes': '蓝色眼睛',
        'black_dress': '黑色连衣裙',
        'white_gloves': '白色手套',
        'hair_ornament': '发饰',
        'looking_at_viewer': '望向观众',
      };
      final prompt = dictionary.keys.join(', ');
      final pending = Completer<Map<String, String>>();
      final lookup = TagTranslationLookup.fromResolver((_) => pending.future);
      addTearDown(lookup.dispose);
      MetadataImportOptions? result;
      await pumpAndOpenDialog(
        tester,
        size: const Size(320, 850),
        textScale: 3,
        metadata: NaiImageMetadata(
          characterInfos: [
            CharacterPromptInfo(prompt: prompt),
            const CharacterPromptInfo(prompt: 'B'),
          ],
        ),
        initialOptions: MetadataImportOptions.none().copyWith(
          importCharacterPrompts: true,
        ),
        translationLookup: lookup,
        onClosed: (value) => result = value,
      );
      await tapOption(tester, 'Append to the end');
      final nextRow = find.text('Character 2: B');
      final topBeforeTranslation = tester.getTopLeft(nextRow).dy;
      final translation = find.text(dictionary.values.join('，'));
      expect(translation, findsNothing);
      pending.complete(dictionary);
      await tester.pumpAndSettle();

      RenderParagraph paragraph(Finder text) =>
          tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
      final original = paragraph(
        find.text('Character 1: ${prompt.substring(0, 35)}...'),
      );
      final translated = paragraph(translation);
      expect(original.didExceedMaxLines, isFalse);
      expect(original.size.height, greaterThan(translated.size.height));
      expect(translated.maxLines, 1);
      expect(translated.didExceedMaxLines, isTrue);
      expect(translated.overflow, TextOverflow.ellipsis);
      expect(
        tester.getTopLeft(nextRow).dy - topBeforeTranslation,
        lessThan(2 * translated.size.height),
      );
      await tapOption(tester, 'Character 2: B');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result!.selectedCharacterIndices, [0]);
      expect(tester.takeException(), isNull);
    },
  );

  group('initial options', () {
    Future<MetadataImportOptions?> confirmFrom(
      WidgetTester tester, {
      required NaiImageMetadata metadata,
      required MetadataImportOptions initialOptions,
      Future<void> Function()? adjust,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      MetadataImportOptions? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await MetadataImportDialog.show(
                    context,
                    metadata: metadata,
                    initialOptions: initialOptions,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await adjust?.call();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      return result;
    }

    Future<bool> chipSelected(WidgetTester tester, String label) async {
      final chip = find.widgetWithText(FilterChip, label);
      await revealOption(tester, chip);
      return tester.widget<FilterChip>(chip).selected;
    }

    testWidgets('remembered categories preselect while image items stay all', (
      tester,
    ) async {
      final result = await confirmFrom(
        tester,
        metadata: const NaiImageMetadata(
          prompt: 'main prompt',
          seed: 42,
          steps: 28,
          characterInfos: [
            CharacterPromptInfo(prompt: 'girl a'),
            CharacterPromptInfo(prompt: 'girl b'),
          ],
        ),
        initialOptions: MetadataImportOptions.all().copyWith(importSeed: false),
        adjust: () async {
          expect(await chipSelected(tester, 'Seed'), isFalse);
          expect(await chipSelected(tester, 'Steps'), isTrue);
        },
      );

      expect(result!.importSeed, isFalse);
      expect(result.importSteps, isTrue);
      expect(result.importCharacterPrompts, isTrue);
      expect(result.selectedCharacterIndices, [0, 1]);
    });

    testWidgets('categories the image lacks keep their remembered value', (
      tester,
    ) async {
      final result = await confirmFrom(
        tester,
        metadata: const NaiImageMetadata(prompt: 'main prompt', steps: 28),
        initialOptions: MetadataImportOptions.all().copyWith(
          importSeed: false,
          importSampler: false,
        ),
        adjust: () async {
          expect(await chipSelected(tester, 'Steps'), isTrue);
          expect(find.widgetWithText(FilterChip, 'Seed'), findsNothing);
        },
      );

      expect(result!.importSeed, isFalse);
      expect(result.importSampler, isFalse);
      expect(result.importModel, isTrue);
    });

    testWidgets(
      'a new image resets every per-image selection and keeps the mode',
      (tester) async {
        final result = await confirmFrom(
          tester,
          metadata: const NaiImageMetadata(
            prompt: 'base',
            qualityTags: ['quality'],
            characterInfos: [CharacterPromptInfo(prompt: 'A')],
            vibeReferences: [
              VibeReference(displayName: 'style', vibeEncoding: 'encoding'),
            ],
            preciseReferenceImages: ['AQID'],
          ),
          initialOptions: MetadataImportOptions.all().copyWith(
            characterImportMode: CharacterImportMode.append,
            selectedQualityTags: ['old'],
            selectedCharacterIndices: [3],
            selectedVibeIndices: [4],
            selectedPreciseReferenceIndices: [5],
          ),
        );
        expect(result!.selectedQualityTags, ['quality']);
        expect(result.selectedCharacterIndices, [0]);
        expect(result.selectedVibeIndices, [0]);
        expect(result.selectedPreciseReferenceIndices, [0]);
        expect(result.characterImportMode, CharacterImportMode.append);
      },
    );

    testWidgets('select all restores defaults over remembered categories', (
      tester,
    ) async {
      final result = await confirmFrom(
        tester,
        metadata: const NaiImageMetadata(
          prompt: 'main prompt',
          seed: 42,
          steps: 28,
        ),
        initialOptions: MetadataImportOptions.none().copyWith(
          importPrompt: true,
          characterImportMode: CharacterImportMode.append,
        ),
        adjust: () async {
          await tester.tap(find.text('Select All'));
          await tester.pump();
        },
      );

      expect(result!.importSeed, isTrue);
      expect(result.characterImportMode, CharacterImportMode.replace);
      expect(result.importSteps, isTrue);
      expect(result.importNegativePrompt, isTrue);
    });

    testWidgets('quick filters preserve the mode until select all', (
      tester,
    ) async {
      final result = await confirmFrom(
        tester,
        metadata: const NaiImageMetadata(
          prompt: 'main',
          steps: 24,
          characterPrompts: ['A'],
        ),
        initialOptions: MetadataImportOptions.all().copyWith(
          characterImportMode: CharacterImportMode.append,
        ),
        adjust: () async {
          for (final label in ['Parameters Only', 'Clear', 'Prompts Only']) {
            await tapOption(tester, label);
            final group = tester.widget<RadioGroup<CharacterImportMode>>(
              find.byType(RadioGroup<CharacterImportMode>),
            );
            expect(group.groupValue, CharacterImportMode.append, reason: label);
          }
        },
      );
      expect(result!.characterImportMode, CharacterImportMode.append);
    });
  });
}
