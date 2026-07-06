import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/comfyui/comfyui_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/img2img_panel.dart';

void main() {
  group('Img2ImgPanel', () {
    testWidgets('点击导演工具会导航到独立页面而不抛异常', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(1400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = container.read(
        imageWorkflowControllerProvider.notifier,
      );
      controller.replaceSourceImage(_testImageBytes);
      controller.setPanelExpanded(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(body: Img2ImgPanel()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('导演工具'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('重绘模式下应显示聚焦重绘控件', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(1400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = container.read(
        imageWorkflowControllerProvider.notifier,
      );
      controller.replaceSourceImage(_testImageBytes);
      controller.enterInpaintMode();
      controller.setPanelExpanded(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(body: Img2ImgPanel()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Focused Inpainting（聚焦重绘）'), findsOneWidget);
      expect(find.textContaining('Minimum Context Area'), findsNothing);
      expect(find.textContaining('重绘编辑器左上角按钮'), findsOneWidget);
    });

    testWidgets('超分模型下拉项不重复显示当前模块前缀', (tester) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _MemoryLocalStorageService(),
          ),
          comfyUISettingsProvider.overrideWith(_EnabledComfyUISettings.new),
          comfyUISeedvr2ModelsProvider.overrideWith(
            _FixedComfyUIUpscaleModels.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(1400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = container.read(
        imageWorkflowControllerProvider.notifier,
      );
      controller.replaceSourceImage(_testImageBytes);
      controller.enterUpscaleMode();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(body: Img2ImgPanel()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('seedvr2_ema_7b_fp16'), findsOneWidget);
      expect(find.textContaining('SeedVR2 ·'), findsNothing);

      await tester.tap(find.text('普通模型'));
      await tester.pumpAndSettle();

      expect(find.text('4x-UltraSharpV2'), findsOneWidget);
      expect(find.textContaining('普通模型 ·'), findsNothing);
    });
  });
}

final Uint8List _testImageBytes = Uint8List.fromList(
  img.encodePng(img.Image(width: 8, height: 8)),
);

class _EnabledComfyUISettings extends ComfyUISettings {
  @override
  ComfyUISettingsState build() {
    return const ComfyUISettingsState(enabled: true);
  }
}

class _FixedComfyUIUpscaleModels extends ComfyUISeedvr2Models {
  @override
  List<String> build() {
    return const ['seedvr2_ema_7b_fp16.safetensors', '4x-UltraSharpV2.pth'];
  }

  @override
  Future<void> fetch({bool force = false}) async {}
}

class _MemoryLocalStorageService extends LocalStorageService {
  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = _values.containsKey(key) ? _values[key] : defaultValue;
    return value as T?;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _values.remove(key);
  }
}
