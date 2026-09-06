import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/services/dlss/dlss_device_probe.dart';
import 'package:nai_launcher/data/services/dlss/dlss_environment_service.dart';
import 'package:nai_launcher/data/services/dlss/dlss_options.dart';
import 'package:nai_launcher/data/services/dlss/dlss_release.dart';
import 'package:nai_launcher/data/services/dlss/dlss_runtime_manager.dart';
import 'package:nai_launcher/data/services/dlss/dlss_worker.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/dlss_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/image_comparison_view.dart';
import 'package:nai_launcher/presentation/screens/dlss/dlss_enhancement_panel.dart';
import 'package:nai_launcher/presentation/screens/dlss/dlss_settings_section.dart';
import 'package:nai_launcher/presentation/screens/dlss/dlss_options_editor.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/generation_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/integrations_settings_section.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_context_menu.dart';

void main() {
  testWidgets('advanced options render over a decorated sidebar surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _Controller(),
        Scaffold(
          body: Container(
            color: Colors.grey,
            child: SingleChildScrollView(
              child: DlssOptionsEditor(
                value: const DlssOptions(),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('高级参数'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Slider), findsNWidgets(7));
    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders.map((slider) => slider.max), [2, 2, 1, 2, 2, 2, 2]);
    expect(sliders.map((slider) => slider.min), [0, 0, 0, 0, 0, -1, -1]);
    expect(sliders.map((slider) => slider.divisions), [
      40,
      40,
      20,
      40,
      40,
      60,
      60,
    ]);
  });
  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'DLSS settings controls are reachable at $width / ${scale}x',
        (tester) async {
          tester.view.reset();
          await tester.binding.setSurfaceSize(Size(width, 700));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = _Controller();
          await tester.pumpWidget(
            _app(
              controller,
              const Scaffold(
                body: SingleChildScrollView(child: DlssSettingsSection()),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          final list = find.byType(Scrollable).first;
          await tester.scrollUntilVisible(
            find.byKey(const Key('dlss-install')),
            350,
            scrollable: list,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('v1.3'), findsWidgets);
          await tester.scrollUntilVisible(
            find.text('选择本地图片试用'),
            350,
            scrollable: list,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('选择本地图片试用'), findsOneWidget);
        },
      );
    }
  }

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('manual comparison is reachable at $width / $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _Controller();
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final source = Uint8List.fromList(
          img.encodePng(img.Image(width: 20, height: 30)),
        );
        await tester.pumpWidget(
          _app(
            controller,
            Scaffold(
              body: DlssEnhancementPanel(
                source: source,
                scrollController: scroll,
              ),
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('dlss-run')));
        await tester.tap(find.byKey(const Key('dlss-run')));
        await tester.pumpAndSettle();
        expect(find.byType(ImageComparisonView), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('generation-comparison-divider-handle')),
        );
        final line = find.byKey(
          const Key('generation-comparison-divider-line'),
        );
        final before = tester.getCenter(line).dx;
        await tester.drag(
          find.byKey(const Key('generation-comparison-divider-handle')),
          const Offset(40, 0),
        );
        await tester.pumpAndSettle();
        expect(tester.getCenter(line).dx, greaterThan(before));
        await tester.ensureVisible(find.byKey(const Key('dlss-save-copy')));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('unavailable runtime cannot enable the feature', (tester) async {
    final controller = _Controller()
      ..environment = const DlssEnvironment(
        availability: DlssAvailability.missingRuntime,
      );
    await tester.pumpWidget(
      _app(
        controller,
        const Scaffold(
          body: SingleChildScrollView(child: DlssSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('dlss-enabled')), 200);
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('dlss-enabled')),
    );
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNull);
    expect(controller.preferenceEnabled, isTrue);
    expect(controller.automatic, isFalse);
  });

  testWidgets('repeated manual previews always use the original input', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _Controller();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final source = Uint8List.fromList(
      img.encodePng(img.Image(width: 16, height: 16)),
    );
    await tester.pumpWidget(
      _app(
        controller,
        Scaffold(
          body: DlssEnhancementPanel(source: source, scrollController: scroll),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var index = 0; index < 2; index++) {
      await tester.ensureVisible(find.byKey(const Key('dlss-run')));
      await tester.tap(find.byKey(const Key('dlss-run')));
      await tester.pumpAndSettle();
    }
    expect(controller.inputs, hasLength(2));
    expect(
      controller.inputs.every((input) => identical(input, source)),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('dlss-save-copy')))
          .onPressed,
      isNotNull,
    );
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    testWidgets(
      'DLSS entry and local image menu respect $platform capabilities',
      (tester) async {
        PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
          platform,
        );
        addTearDown(() => PlatformCapabilities.debugOverride = null);
        final controller = _Controller();
        await tester.pumpWidget(
          _app(
            controller,
            const Scaffold(
              body: SingleChildScrollView(child: GenerationSettingsSection()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('dlss-settings-entry')), findsNothing);
        final context = tester.element(find.byType(GenerationSettingsSection));
        final menu = LocalImageContextMenu.buildSendEntries(
          context,
          isKritaConnected: false,
        );
        final values = menu
            .whereType<PopupMenuItem<LocalImageContextAction>>()
            .map((item) => item.value);
        expect(
          values.contains(LocalImageContextAction.dlssEnhance),
          platform == TargetPlatform.windows,
        );
        await tester.pumpWidget(
          _app(
            controller,
            const Scaffold(
              body: SingleChildScrollView(
                child: IntegrationsSettingsSection(initiallyShowDlss: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('DLSSNR'),
          platform == TargetPlatform.windows ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(DlssSettingsSection),
          platform == TargetPlatform.windows ? findsOneWidget : findsNothing,
        );
      },
    );
  }
}

Widget _app(_Controller controller, Widget home, {double scale = 1}) =>
    ProviderScope(
      overrides: [
        dlssProvider.overrideWith((ref) => controller),
        localStorageServiceProvider.overrideWith((ref) => controller.storage),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    );

class _Storage extends LocalStorageService {
  final values = <String, Object?>{};
  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      values.containsKey(key) ? values[key] as T? : defaultValue;
  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    values.remove(key);
  }
}

class _Controller extends DlssController {
  _Controller()
    : super(
        _Storage(),
        DlssRuntimeManager(dio: Dio()),
        DlssReleaseSource(Dio()),
        DlssWorker(),
      ) {
    const device = DlssDevice(
      index: 0,
      name: 'NVIDIA GeForce RTX 4060 Laptop GPU',
      luid: 'device',
      vendorId: 0x10de,
      deviceId: 1,
      memoryBytes: 8589934592,
      d3d12: true,
      driver: '32.0.16.1047',
    );
    environment = const DlssEnvironment(
      availability: DlssAvailability.ready,
      devices: [device],
      selected: device,
    );
    releases = [
      for (final id in [3, 2])
        DlssRelease(
          id: id,
          tag: 'v1.$id',
          prerelease: false,
          publishedAt: DateTime(2026, 9, id),
          assetId: id,
          bytes: 247420277,
          url: 'unused',
          digest: 'unused',
        ),
    ];
    active = DlssInstallation(
      releases.first,
      Directory('unused'),
      const {},
      installedBytes: 225251552,
    );
    installations = [active!];
  }
  final inputs = <Uint8List>[];
  @override
  Future<void> refresh({bool fetchReleases = true}) async {}
  @override
  Future<Uint8List> enhance(
    Uint8List bytes,
    DlssOptions options, {
    Future<void>? cancelled,
  }) async {
    inputs.add(bytes);
    return Uint8List.fromList(bytes);
  }
}
