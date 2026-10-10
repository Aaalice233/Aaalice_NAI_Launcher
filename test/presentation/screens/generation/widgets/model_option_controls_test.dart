import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/enums/image_model_mode.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_param_sections.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_toggle_button.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_dropdown.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_slider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveTempDir;

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'model_option_controls_test_',
    );
    Hive.init(hiveTempDir.path);
    // 内存后端：widget test 的 FakeAsync 时钟里发起的落盘写不会完成。
    await Hive.openBox(StorageKeys.settingsBox, bytes: Uint8List(0));
  });

  tearDown(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  Future<ProviderContainer> pumpSections(
    WidgetTester tester, {
    required String model,
    double width = 600,
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _TestLocalStorageService(model),
          ),
          vibeLibraryStorageServiceProvider.overrideWithValue(
            _TestVibeLibraryStorageService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ModelSection(),
                  StepsSection(),
                  SamplerSection(),
                  NoiseScheduleSection(),
                  CfgScaleSection(),
                  AdvancedSamplingOptions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(ModelSection)));
  }

  final modeToggle = find.byKey(const ValueKey('generation-model-mode'));
  final effortToggle = find.byKey(const ValueKey('generation-effort'));

  double titleCenter(WidgetTester tester) =>
      tester.getCenter(find.text('模型')).dy;

  ThemedSlider stepsSlider(WidgetTester tester) => tester
      .widgetList<ThemedSlider>(find.byType(ThemedSlider))
      .singleWhere((slider) => slider.max == 50);

  ThemedSlider cfgRescaleSlider(WidgetTester tester) => tester
      .widgetList<ThemedSlider>(find.byType(ThemedSlider))
      .singleWhere((slider) => slider.max == 1);

  testWidgets('V5 Full shows mode and effort, starting on the full model', (
    tester,
  ) async {
    await pumpSections(tester, model: ImageModels.animeDiffusionV5Full);

    expect(modeToggle, findsOneWidget);
    expect(effortToggle, findsOneWidget);
    for (final label in ['动漫', '兽人', '节约', '标准']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('模式'), findsNothing);
    expect(find.text('生成档位'), findsNothing);
    expect(stepsSlider(tester).onChanged, isNotNull);
  });

  testWidgets('switching to Medium locks the controls it takes over', (
    tester,
  ) async {
    final container = await pumpSections(
      tester,
      model: ImageModels.animeDiffusionV5Full,
    );

    await tester.tap(find.text('节约'));
    await tester.pump();

    expect(
      container.read(generationParamsNotifierProvider).model,
      ImageModels.animeDiffusionV5FullMedium,
    );
    final modelDropdown = tester.widget<ThemedDropdown<String>>(
      find.byType(ThemedDropdown<String>).first,
    );
    expect(modelDropdown.value, ImageModels.animeDiffusionV5Full);

    expect(find.text('步数: 14'), findsOneWidget);
    expect(stepsSlider(tester).onChanged, isNull);
    final dropdowns = tester
        .widgetList<ThemedDropdown<String>>(find.byType(ThemedDropdown<String>))
        .skip(1);
    expect(dropdowns.every((dropdown) => dropdown.onChanged == null), isTrue);
    expect(
      dropdowns.map((dropdown) => dropdown.value),
      containsAll([Samplers.kEulerAncestral, NoiseSchedules.karras]),
    );
    expect(cfgRescaleSlider(tester).onChanged, isNull);
    expect(find.textContaining('节约档'), findsNothing);
    final varietyPlus = tester.widget<GenerationToggleButton>(
      find.widgetWithText(GenerationToggleButton, 'Variety+'),
    );
    expect(varietyPlus.onChanged, isNull);
    expect(varietyPlus.isEnabled, isFalse);

    await tester.tap(find.text('标准'));
    await tester.pump();
    expect(
      container.read(generationParamsNotifierProvider).model,
      ImageModels.animeDiffusionV5Full,
    );
    expect(stepsSlider(tester).onChanged, isNotNull);
    expect(cfgRescaleSlider(tester).onChanged, isNotNull);
  });

  testWidgets('re-selecting V5 Full in the dropdown keeps Medium', (
    tester,
  ) async {
    final container = await pumpSections(
      tester,
      model: ImageModels.animeDiffusionV5FullMedium,
    );

    tester
        .widget<ThemedDropdown<String>>(
          find.byType(ThemedDropdown<String>).first,
        )
        .onChanged!(ImageModels.animeDiffusionV5Full);
    await tester.pump();

    expect(
      container.read(generationParamsNotifierProvider).model,
      ImageModels.animeDiffusionV5FullMedium,
    );
  });

  testWidgets('furry mode toggles without an inline explanation', (
    tester,
  ) async {
    final container = await pumpSections(
      tester,
      model: ImageModels.animeDiffusionV45Full,
    );

    expect(effortToggle, findsNothing);
    await tester.tap(find.text('兽人'));
    await tester.pump();

    expect(
      container.read(generationParamsNotifierProvider).modelMode,
      ImageModelMode.furry,
    );
    expect(find.textContaining('fur dataset'), findsNothing);
  });

  testWidgets('mode and effort sit right-aligned in the model title row', (
    tester,
  ) async {
    await pumpSections(tester, model: ImageModels.animeDiffusionV5Full);

    for (final toggle in [modeToggle, effortToggle]) {
      expect(
        tester.getCenter(toggle).dy,
        moreOrLessEquals(titleCenter(tester), epsilon: 1),
      );
    }
    final dropdown = tester.getRect(find.byType(ThemedDropdown<String>).first);
    final mode = tester.getRect(modeToggle);
    final effort = tester.getRect(effortToggle);
    expect(mode.right, lessThan(effort.left));
    expect(effort.right, moreOrLessEquals(dropdown.right, epsilon: 1));
    expect(effort.bottom, lessThanOrEqualTo(dropdown.top));
  });

  testWidgets('models without furry mode or effort show neither control', (
    tester,
  ) async {
    await pumpSections(tester, model: ImageModels.animeDiffusionV3);

    expect(modeToggle, findsNothing);
    expect(effortToggle, findsNothing);
  });

  for (final width in [320.0, 600.0, 840.0]) {
    testWidgets('Medium stays fully reachable at ${width.toInt()}px, 3x text', (
      tester,
    ) async {
      final container = await pumpSections(
        tester,
        model: ImageModels.animeDiffusionV5FullMedium,
        width: width,
        textScale: 3,
      );

      expect(tester.takeException(), isNull);
      for (final label in ['动漫', '兽人', '节约', '标准']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(stepsSlider(tester).onChanged, isNull);
      expect(find.textContaining('节约档'), findsNothing);
      expect(
        tester.getCenter(effortToggle).dy,
        moreOrLessEquals(titleCenter(tester), epsilon: 1),
      );

      await tester.ensureVisible(find.text('标准'));
      await tester.pump();
      await tester.tap(find.text('标准'));
      await tester.pump();
      expect(
        container.read(generationParamsNotifierProvider).model,
        ImageModels.animeDiffusionV5Full,
      );
    });
  }
}

class _TestLocalStorageService extends LocalStorageService {
  _TestLocalStorageService(this._model);

  final String _model;
  final Map<String, Object?> _settings = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = _settings[key];
    return value is T ? value : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _settings[key] = value;
  }

  @override
  String getLastPrompt() => '';

  @override
  String getLastNegativePrompt() => '';

  @override
  String getDefaultModel() => _model;

  @override
  String getDefaultSampler() => Samplers.kDpmpp2m;

  @override
  int getDefaultSteps() => 28;

  @override
  double getDefaultScale() => 4.0;

  @override
  int getDefaultWidth() => 832;

  @override
  int getDefaultHeight() => 1216;

  @override
  bool getLastSmea() => false;

  @override
  bool getLastSmeaDyn() => false;

  @override
  double getLastCfgRescale() => 0.0;

  @override
  String getLastNoiseSchedule() => NoiseSchedules.exponential;

  @override
  bool getLastVarietyPlus() => false;

  @override
  bool getSeedLocked() => false;

  @override
  int? getLockedSeedValue() => null;
}

class _TestVibeLibraryStorageService extends VibeLibraryStorageService {
  @override
  Future<List<VibeLibraryEntry>> getRecentDisplayEntries({
    int limit = 20,
  }) async {
    return const [];
  }

  @override
  Future<void> saveGenerationStateJson(String stateJson) async {}
}
