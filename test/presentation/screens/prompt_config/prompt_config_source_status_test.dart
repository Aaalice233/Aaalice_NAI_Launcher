import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/prompt/algorithm_config.dart';
import 'package:nai_launcher/data/models/prompt/official_wordlist.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_prompt_result.dart';
import 'package:nai_launcher/data/models/prompt/tag_library.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:nai_launcher/data/services/wordlist_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/random_mode_provider.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_group_sync_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_provider.dart';
import 'package:nai_launcher/presentation/screens/prompt_config/prompt_config_screen.dart';

void main() {
  for (final width in [700.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      'shows real hybrid sources without overflow at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpPromptScreen(tester, RandomGenerationMode.hybrid);

        expect(find.text('混合 · Character Prompts + Catalog'), findsOneWidget);
        expect(find.text('2456 + 1'), findsOneWidget);
        expect(tester.takeException(), isNull);

        if (width == 1600) {
          await tester.tap(find.text('混合 · Character Prompts + Catalog'));
          await tester.pumpAndSettle();

          expect(find.text('1741-fixture.js'), findsOneWidget);
          expect(find.text('fixture-sha256'), findsOneWidget);
          expect(find.text('https://example.com/catalog.csv'), findsOneWidget);
          expect(find.text('Unlicense'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  for (final scenario in [
    (RandomGenerationMode.naiOfficial, '官网 · Character Prompts', '2456', false),
    (RandomGenerationMode.custom, '自定义 · Catalog 扩展', '1', true),
  ]) {
    testWidgets('${scenario.$1.name} reports only its active source', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1180, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpPromptScreen(tester, scenario.$1);

      expect(find.text(scenario.$2), findsOneWidget);
      expect(find.text(scenario.$3), findsOneWidget);
      await tester.tap(find.text(scenario.$2));
      await tester.pumpAndSettle();

      expect(
        find.text('https://example.com/catalog.csv'),
        scenario.$4 ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('1741-fixture.js'),
        scenario.$4 ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpPromptScreen(
  WidgetTester tester,
  RandomGenerationMode mode,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tagLibraryNotifierProvider.overrideWith(_FixedTagLibrary.new),
        randomPresetNotifierProvider.overrideWith(_FixedPresets.new),
        randomModeNotifierProvider.overrideWith(() => _FixedMode(mode)),
        generationParamsNotifierProvider.overrideWith(_V5Params.new),
        tagGroupSyncNotifierProvider.overrideWith(_FixedTagGroupSync.new),
        officialWordlistDataProvider.overrideWith((ref) async => _officialData),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PromptConfigScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _library = TagLibrary(
  id: 'catalog-fixture',
  name: 'Catalog fixture',
  lastUpdated: DateTime.utc(2026),
  source: TagLibrarySource.catalog,
  dataVersion: 'fixture',
  sourceUrl: 'https://example.com/catalog.csv',
  sourceCommit: 'abc123',
  sourceLicense: 'Unlicense',
  sourceVersionDate: DateTime.utc(2026),
  sourceCatalogTagCount: 221787,
  sourceCatalogAliasCount: 71504,
  categories: {
    'detail': [WeightedTag.simple('fixture tag', 1)],
  },
);

const _preset = RandomPreset(
  id: 'fixture',
  name: 'Fixture',
  isDefault: true,
  algorithmConfig: AlgorithmConfig(),
);

final _officialData = OfficialWordlistData(
  schemaVersion: officialWordlistSchemaVersion,
  dataVersion: 'fixture',
  sourceFileName: '1741-fixture.js',
  sourceSize: 1,
  sourceSha256: 'fixture-sha256',
  generators: const [],
);

class _FixedTagLibrary extends TagLibraryNotifier {
  @override
  TagLibraryState build() => TagLibraryState(library: _library);
}

class _FixedPresets extends RandomPresetNotifier {
  @override
  RandomPresetState build() =>
      const RandomPresetState(presets: [_preset], selectedPresetId: 'fixture');
}

class _FixedMode extends RandomModeNotifier {
  _FixedMode(this.mode);

  final RandomGenerationMode mode;

  @override
  RandomGenerationMode build() => mode;
}

class _FixedTagGroupSync extends TagGroupSyncNotifier {
  @override
  TagGroupSyncState build() => const TagGroupSyncState();
}

class _V5Params extends GenerationParamsNotifier {
  @override
  ImageParams build() =>
      const ImageParams(model: ImageModels.animeDiffusionV5Full);
}
