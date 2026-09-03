import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/krita/krita_bridge_notifier.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_param_sections.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/parameter_panel.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/precise_reference_panel.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/reverse_prompt_panel.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/size_selector.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/vibe_transfer_content.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_section.dart';
import 'package:nai_launcher/presentation/widgets/common/editable_double_field.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_slider.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveTempDir;

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'parameter_panel_test_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
  });

  setUp(() {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
  });

  tearDown(() async {
    PlatformCapabilities.debugOverride = null;
    await Hive.box(StorageKeys.settingsBox).clear();
    await Hive.box(StorageKeys.historyBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  group('resolveManualSizeFieldSyncText', () {
    test('keeps focused field text untouched while user is typing', () {
      final result = resolveManualSizeFieldSyncText(
        currentText: '83',
        targetValue: 8,
        hasFocus: true,
      );

      expect(result, isNull);
    });

    test('syncs unfocused field to latest widget value', () {
      final result = resolveManualSizeFieldSyncText(
        currentText: '832',
        targetValue: 1216,
        hasFocus: false,
      );

      expect(result, equals('1216'));
    });
  });

  group('resolveSeedFieldSyncText', () {
    test('keeps focused seed text untouched while user is typing', () {
      final result = resolveSeedFieldSyncText(
        currentText: '',
        seed: 123456,
        hasFocus: true,
      );

      expect(result, isNull);
    });

    test('syncs unfocused field to external seed value', () {
      final result = resolveSeedFieldSyncText(
        currentText: '',
        seed: 123456,
        hasFocus: false,
      );

      expect(result, equals('123456'));
    });

    test('syncs random seed state to empty field text', () {
      final result = resolveSeedFieldSyncText(
        currentText: '123456',
        seed: -1,
        hasFocus: false,
      );

      expect(result, equals(''));
    });
  });

  group('ParameterPanel', () {
    testWidgets('parameter sliders keep their discrete behavior', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith(
              (ref) => _TestLocalStorageService(),
            ),
            vibeLibraryStorageServiceProvider.overrideWithValue(
              _TestVibeLibraryStorageService(),
            ),
            kritaBridgeNotifierProvider.overrideWith(
              (ref) => _TestKritaBridgeNotifier(),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SizedBox(width: 960, height: 1200, child: ParameterPanel()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final cfgSliders = tester
          .widgetList<ThemedSlider>(find.byType(ThemedSlider))
          .where(
            (slider) =>
                slider.min == 1 && slider.max == 20 && slider.value == 5.0,
          )
          .toList();

      final stepsSliders = tester
          .widgetList<ThemedSlider>(find.byType(ThemedSlider))
          .where(
            (slider) =>
                slider.min == 1 && slider.max == 50 && slider.divisions == 49,
          )
          .toList();

      expect(cfgSliders, hasLength(1));
      expect(cfgSliders.single.divisions, equals(190));
      expect(stepsSliders, hasLength(1));
      expect(stepsSliders.single.hideTickMarks, isTrue);
    });

    testWidgets('高级选项在侧栏色面内使用独立 Material', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith(
              (ref) => _TestLocalStorageService(),
            ),
            vibeLibraryStorageServiceProvider.overrideWithValue(
              _TestVibeLibraryStorageService(),
            ),
            kritaBridgeNotifierProvider.overrideWith(
              (ref) => _TestKritaBridgeNotifier(),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF1A1A1A)),
                child: SizedBox(
                  width: 320,
                  height: 1200,
                  child: ParameterPanel(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final advancedOptions = find.byWidgetPredicate(
        (widget) =>
            widget is ExpansionTile &&
            widget.title is Text &&
            (widget.title as Text).data == '高级选项',
      );
      await tester.scrollUntilVisible(
        advancedOptions,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final material = tester
          .element(advancedOptions)
          .findAncestorWidgetOfExactType<Material>();
      expect(material, isNotNull);
      expect(material!.type, MaterialType.transparency);

      await tester.tap(advancedOptions);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('经典侧栏显示角色编辑，移动参数面板不重复挂载', (tester) async {
      Widget buildSubject({required bool showCharacterEditor}) {
        return ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith(
              (ref) => _TestLocalStorageService(),
            ),
            vibeLibraryStorageServiceProvider.overrideWithValue(
              _TestVibeLibraryStorageService(),
            ),
            kritaBridgeNotifierProvider.overrideWith(
              (ref) => _TestKritaBridgeNotifier(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 1200,
                child: ParameterPanel(showCharacterEditor: showCharacterEditor),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildSubject(showCharacterEditor: true));
      await tester.pumpAndSettle();

      final parameterList = tester.widget<ListView>(
        find.byType(ListView).first,
      );
      final children =
          (parameterList.childrenDelegate as SliverChildListDelegate).children;
      final seedIndex = children.indexWhere((child) => child is SeedSection);
      final characterIndex = children.indexWhere(
        (child) => child is InlineCharacterSection,
      );
      final reversePromptIndex = children.indexWhere(
        (child) => child is ReversePromptPanel,
      );
      expect(seedIndex, lessThan(characterIndex));
      expect(characterIndex, lessThan(reversePromptIndex));

      await tester.scrollUntilVisible(
        find.byKey(const Key('character-secondary-menu')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('character-secondary-menu')), findsOneWidget);
      expect(
        find.byKey(const Key('character-secondary-menu')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const Key('character-add-female')), findsOneWidget);
      expect(
        find.byKey(const Key('character-add-from-library')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(buildSubject(showCharacterEditor: false));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('character-secondary-menu')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('VibeTransferContent', () {
    testWidgets('exposes a local file drop region for add-from-file', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SizedBox(
                width: 720,
                child: VibeTransferContent(
                  vibes: const [],
                  normalizeVibeStrength: true,
                  showBackground: false,
                  onAddVibe: () {},
                  onAddLibraryVibe: (_) {},
                  onRemoveVibe: (_) {},
                  onUpdateStrength: (_, __) {},
                  onUpdateInfoExtracted: (_, __) {},
                  onUpdateEnabled: (_, __) {},
                  onClearAll: () {},
                  onImportDroppedFile: (_, __) async => 0,
                  recentEntries: const [],
                  isRecentCollapsed: false,
                  onToggleRecentCollapsed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Add from File'), findsOneWidget);
      expect(find.byType(DropRegion), findsOneWidget);
    });
  });

  group('PreciseReferencePanel', () {
    testWidgets('数值输入不限制参考强度和保真度', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith(
              (ref) => _TestLocalStorageService(),
            ),
            vibeLibraryStorageServiceProvider.overrideWithValue(
              _TestVibeLibraryStorageService(),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(width: 720, child: PreciseReferencePanel()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PreciseReferencePanel)),
      );
      container
          .read(generationParamsNotifierProvider.notifier)
          .addPreciseReference(
            _validPngBytes(width: 4, height: 4),
            type: PreciseRefType.character,
            strength: 3.5,
            fidelity: -2.25,
            isNormalizedPng: true,
          );
      await tester.pump();

      await tester.tap(find.text('Precise Reference'));
      await tester.pumpAndSettle();

      final fields = tester
          .widgetList<EditableDoubleField>(find.byType(EditableDoubleField))
          .toList();
      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();

      expect(fields, hasLength(2));
      expect(fields[0].value, 3.5);
      expect(fields[0].min, isNull);
      expect(fields[0].max, isNull);
      expect(fields[1].value, -2.25);
      expect(fields[1].min, isNull);
      expect(fields[1].max, isNull);
      expect(sliders, hasLength(2));
      expect(sliders[0].value, 1.0);
      expect(sliders[1].value, 0.0);
      expect(sliders[0].divisions, 20);
      expect(sliders[1].divisions, 20);

      await tester.enterText(find.byType(TextField).at(0), '4.25');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(
        container
            .read(generationParamsNotifierProvider)
            .preciseReferences
            .single
            .strength,
        4.25,
      );
    });

    testWidgets('imports every image selected for precise reference', (
      tester,
    ) async {
      FilePicker? originalFilePicker;
      try {
        originalFilePicker = FilePicker.platform;
      } catch (_) {
        originalFilePicker = null;
      }

      final filePicker = _FakeFilePicker(
        FilePickerResult([
          PlatformFile(
            name: 'first.png',
            size: 1,
            bytes: _validPngBytes(width: 4, height: 4),
          ),
          PlatformFile(
            name: 'second.png',
            size: 1,
            bytes: _validPngBytes(width: 5, height: 3),
          ),
        ]),
      );
      FilePicker.platform = filePicker;
      addTearDown(() {
        if (originalFilePicker != null) {
          FilePicker.platform = originalFilePicker;
        }
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith(
              (ref) => _TestLocalStorageService(),
            ),
            vibeLibraryStorageServiceProvider.overrideWithValue(
              _TestVibeLibraryStorageService(),
            ),
            naiImageEnhancementApiServiceProvider.overrideWithValue(
              _FakeEnhancementApiService(),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(width: 720, child: PreciseReferencePanel()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Precise Reference'));
      await tester.pumpAndSettle();
      expect(find.byType(DropRegion), findsOneWidget);
      await tester.tap(find.text('Add Reference'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Character'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PreciseReferencePanel)),
      );
      final references = container
          .read(generationParamsNotifierProvider)
          .preciseReferences;

      expect(filePicker.lastType, FileType.image);
      expect(filePicker.lastAllowMultiple, isTrue);
      expect(references, hasLength(2));
    });
  });
}

Uint8List _validPngBytes({required int width, required int height}) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.result);

  final FilePickerResult? result;
  FileType? lastType;
  bool? lastAllowMultiple;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    lastType = type;
    lastAllowMultiple = allowMultiple;
    return result;
  }
}

class _TestLocalStorageService extends LocalStorageService {
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
  String getDefaultModel() => 'nai-diffusion-4-5-full';

  @override
  String getDefaultSampler() => 'k_euler_ancestral';

  @override
  int getDefaultSteps() => 28;

  @override
  double getDefaultScale() => 5.0;

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
  String getLastNoiseSchedule() => 'native';

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

class _FakeEnhancementApiService extends NAIImageEnhancementApiService {
  _FakeEnhancementApiService() : super(Dio());
}

class _TestKritaBridgeNotifier extends KritaBridgeNotifier {
  @override
  Future<void> disable({bool persist = true}) async {}

  @override
  Future<void> close() async {}
}
