import 'dart:async';
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
import 'package:nai_launcher/presentation/screens/dlss/dlss_preset_editor.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/img2img_dlss_upscale_controls.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/generation_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/integrations_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/settings_card.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_context_menu.dart';

void main() {
  testWidgets(
    'recreating an expanded editor cannot restore bool as scroll offset',
    (tester) async {
      final controller = _Controller();
      final bucket = PageStorageBucket();
      Widget editor(int generation) => _app(
        controller,
        Scaffold(
          body: PageStorage(
            bucket: bucket,
            child: SingleChildScrollView(
              child: DlssOptionsEditor(
                key: ValueKey(generation),
                value: controller.options,
                onChanged: controller.setOptions,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(editor(1));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('高级参数'));
      await tester.tap(find.text('高级参数'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(editor(2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('group reflow and collapse preserve pending edits and help', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 380));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _Controller();
    final editor = Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: DlssOptionsEditor(
            value: controller.options,
            onChanged: controller.setOptions,
          ),
        ),
      ),
    );
    await tester.pumpWidget(_app(controller, editor));
    await tester.pumpAndSettle();
    final advancedTitle = find.text('高级参数');
    await tester.ensureVisible(advancedTitle);
    await tester.tap(advancedTitle);
    await tester.pumpAndSettle();
    final help = find.byKey(const ValueKey('dlss-help-细节混合'));
    await tester.ensureVisible(help);
    await tester.tap(help);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('dlss-value-细节混合'));
    final before = tester.widget<TextField>(field);
    await tester.ensureVisible(field);
    await tester.enterText(field, '1.');
    await tester.binding.setSurfaceSize(const Size(320, 380));
    await tester.pumpAndSettle();
    final after = tester.widget<TextField>(field);
    expect(after.controller, same(before.controller));
    expect(after.controller!.text, '1.');
    expect(after.focusNode, same(before.focusNode));
    expect(after.focusNode!.hasFocus, isTrue);
    await tester.enterText(field, 'NaN');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('请输入此参数支持的有效数值。'), findsOneWidget);
    await tester.ensureVisible(advancedTitle);
    await tester.tap(advancedTitle);
    await tester.pumpAndSettle();
    expect(field, findsNothing);
    expect(find.byKey(const Key('dlss-advanced-group')), findsOneWidget);
    await tester.tap(advancedTitle);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller, same(before.controller));
    expect(tester.widget<TextField>(field).controller!.text, 'NaN');
    expect(find.text('请输入此参数支持的有效数值。'), findsOneWidget);
    expect(tester.widget<IconButton>(help).isSelected, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets('all six presets remain selectable at $width and 3x text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _Controller();
      await tester.pumpWidget(
        _app(
          controller,
          const Scaffold(
            body: SingleChildScrollView(child: DlssPresetEditor()),
          ),
          scale: 3,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dlss-preset-selector')));
      await tester.pumpAndSettle();
      final preserveColor = find.text('默认').last;
      await tester.ensureVisible(preserveColor);
      await tester.tap(preserveColor);
      await tester.pumpAndSettle();
      expect(controller.presetState.selectedId, 'color-light');
      expect(controller.options.color, 0.25);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'preset selector restores saved definitions while edits remain portable',
    (tester) async {
      final controller = _Controller();
      await controller.createPreset('我的参数');
      final customId = controller.presetState.selectedId;
      await controller.setOptions(controller.options.copyWith(intensity: 2.3));
      await controller.savePreset(customId);
      await tester.pumpWidget(
        _app(
          controller,
          const Scaffold(
            body: SingleChildScrollView(child: DlssPresetEditor()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('我的参数'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dlss-preset-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('柔和').last);
      await tester.pumpAndSettle();
      expect(controller.options.intensity, 1.1);
      await tester.tap(find.byKey(const Key('dlss-preset-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的参数').last);
      await tester.pumpAndSettle();
      expect(controller.options.intensity, 2.3);
      final strength = find.byKey(const ValueKey('dlss-value-强度'));
      await tester.ensureVisible(strength);
      await tester.enterText(strength, '2.7');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(controller.options.intensity, 2.7);
      expect(controller.presetState.selected.options.intensity, 2.3);
      expect(find.text('已调整 · 当前参数已自动保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'numeric NR controls accept values beyond sliders and reject invalid input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var options = const DlssOptions();
      await tester.pumpWidget(
        _app(
          _Controller(),
          Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: DlssOptionsEditor(
                  value: options,
                  onChanged: (value) => setState(() => options = value),
                ),
              ),
            ),
          ),
        ),
      );
      Finder field(String label) => find.byKey(ValueKey('dlss-value-$label'));
      final strength = field('强度');
      await tester.ensureVisible(strength);
      await tester.enterText(strength, '3.25');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(options.intensity, 3.25);
      await tester.enterText(strength, 'NaN');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(options.intensity, 3.25);
      expect(find.text('请输入此参数支持的有效数值。'), findsOneWidget);
      final passes = find.byKey(const Key('dlss-passes'));
      await tester.ensureVisible(passes);
      final slider = tester.widget<Slider>(passes);
      expect(slider.min, 1);
      expect(slider.max, 3);
      expect(slider.divisions, 2);
      await tester.tapAt(
        tester.getCenter(passes) +
            Offset(tester.getSize(passes).width / 2 - 10, 0),
      );
      await tester.pump();
      expect(options.passes, 3);
      await tester.tap(passes);
      await tester.pump();
      expect(options.passes, 2);
      final passInput = field('NR 处理次数');
      expect(tester.widget<TextField>(passInput).controller!.text, '2');
      await tester.ensureVisible(passInput);
      await tester.enterText(passInput, '1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(options.passes, 1);
      expect(tester.widget<Slider>(passes).value, 1);
      for (final invalid in ['0', '4', '2.5', '']) {
        await tester.enterText(passInput, invalid);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(options.passes, 1);
        expect(tester.widget<Slider>(passes).value, 1);
      }
      await tester.enterText(passInput, '3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(options.passes, 3);
      expect(tester.widget<TextField>(passInput).controller!.text, '3');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('automatic enhancement failures remain in DLSS settings', (
    tester,
  ) async {
    final controller = _Controller()
      ..enhancementError = StateError('native enhancement failed');
    await tester.pumpWidget(
      _app(
        controller,
        const Scaffold(
          body: SingleChildScrollView(child: DlssSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DLSS 增强失败，原图已保留'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
    await tester.ensureVisible(find.text('高级参数'));
    await tester.tap(find.text('高级参数'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNWidgets(9));
    for (final input in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(input.textAlign, TextAlign.center);
      expect(input.textAlignVertical, TextAlignVertical.center);
    }
    expect(find.byType(Slider), findsNWidgets(9));
    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders.map((slider) => slider.max), [4, 3, 2, 2, 1, 2, 2, 2, 2]);
    expect(sliders.map((slider) => slider.min), [1, 1, 0, 0, 0, 0, 0, -1, -1]);
    expect(sliders.map((slider) => slider.divisions), [
      null,
      2,
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
      testWidgets('SR scale entry remains reachable at $width / $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _Controller();
        await tester.pumpWidget(
          _app(
            controller,
            const Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Img2ImgDlssUpscaleControls(),
                ),
              ),
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        final input = find.byType(TextField);
        await tester.ensureVisible(input);
        await tester.enterText(input, '2.5');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(controller.options.scale, 2.5);
        expect(find.textContaining('当前运行库仍会计算一次 NR'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
      testWidgets('advanced NR controls can be changed at $width / $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var options = const DlssOptions();
        await tester.pumpWidget(
          _app(
            _Controller(),
            Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => SingleChildScrollView(
                  child: DlssOptionsEditor(
                    value: options,
                    onChanged: (value) => setState(() => options = value),
                  ),
                ),
              ),
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('高级参数'));
        await tester.tap(find.text('高级参数'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('3'));
        await tester.tap(find.text('3'));
        await tester.pumpAndSettle();
        expect(options.preset, 3);
        final autoMask = find.descendant(
          of: find.byKey(const Key('dlss-auto-mask')),
          matching: find.byType(Switch),
        );
        await tester.ensureVisible(autoMask);
        await tester.tap(autoMask);
        await tester.pumpAndSettle();
        final uiCorrection = find.descendant(
          of: find.byKey(const Key('dlss-ui-correction')),
          matching: find.byType(Switch),
        );
        await tester.ensureVisible(uiCorrection);
        await tester.tap(uiCorrection);
        await tester.pumpAndSettle();
        expect(options.autoMask, !const DlssOptions().autoMask);
        expect(options.uiCorrection, !const DlssOptions().uiCorrection);
        final advanced = find.byKey(const Key('dlss-advanced-group'));
        final advancedBounds = tester.getRect(advanced);
        for (final label in [
          '细节与颜色',
          'NR 模型',
          '局部调整',
          '模型强度',
          '模型开关',
          '细节混合',
          '颜色混合',
          '局部结构',
          '局部色调',
          '皮肤结构',
          '全局色调',
          '自动遮罩',
          'UI 修正',
        ]) {
          final child = find.descendant(
            of: advanced,
            matching: find.text(label),
          );
          expect(child, findsOneWidget);
          final bounds = tester.getRect(child);
          expect(advancedBounds.contains(bounds.topLeft), isTrue);
          expect(advancedBounds.contains(bounds.bottomRight), isTrue);
        }
        expect(
          find.descendant(of: advanced, matching: find.byType(SettingsCard)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
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
          for (final key in [
            'dlss-preset-group',
            'dlss-processing-group',
            'dlss-appearance-group',
            'dlss-advanced-group',
          ]) {
            final group = find.byKey(Key(key));
            expect(group, findsOneWidget);
            expect(
              find.ancestor(of: group, matching: find.byType(SettingsCard)),
              findsNothing,
              reason: 'each parameter group must stand on its own surface',
            );
          }
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('dlss-enabled')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('dlss-enabled')),
    );
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNull);
    expect(controller.preferenceEnabled, isTrue);
    expect(controller.automatic, isFalse);
  });

  testWidgets(
    'NR completion keeps finalizing status until result bytes arrive',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _Controller()..pendingResult = Completer<Uint8List>();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final source = Uint8List.fromList(
        img.encodePng(img.Image(width: 16, height: 16)),
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
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('dlss-run')));
      await tester.tap(find.byKey(const Key('dlss-run')));
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DlssEnhancementPanel)),
      )!;
      expect(find.text(l10n.dlss_finalizing), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('dlss-save-copy')))
            .onPressed,
        isNull,
      );
      controller.pendingResult!.complete(source);
      await tester.pumpAndSettle();
      expect(find.text(l10n.dlss_finalizing), findsNothing);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('dlss-save-copy')))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

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
    final viewport = find.byKey(const ValueKey('generation-image-comparison'));
    final initialRect = tester.getRect(viewport);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final transform = viewer.transformationController!;
    expect(transform.value.getMaxScaleOnAxis(), 1);
    for (var index = 0; index < 2; index++) {
      await tester.ensureVisible(find.byKey(const Key('dlss-run')));
      await tester.tap(find.byKey(const Key('dlss-run')));
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport), initialRect);
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController,
        same(transform),
      );
      expect(transform.value.getMaxScaleOnAxis(), index == 0 ? 1 : 2);
      // Keep a user's zoom when a later result replaces the current image.
      transform.value = Matrix4.diagonal3Values(2, 2, 1);
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
  Completer<Uint8List>? pendingResult;
  @override
  Future<void> refresh({bool fetchReleases = true}) async {}
  @override
  Future<Uint8List> enhance(
    Uint8List bytes,
    DlssOptions options, {
    Future<void>? cancelled,
    void Function(int completed, int total)? onProgress,
  }) async {
    inputs.add(bytes);
    if (pendingResult != null) {
      onProgress?.call(options.passes, options.passes);
      return pendingResult!.future;
    }
    final source = img.decodePng(bytes)!;
    return Uint8List.fromList(
      img.encodePng(
        img.copyResize(
          source,
          width: (source.width * options.scale).round(),
          height: (source.height * options.scale).round(),
        ),
      ),
    );
  }
}
