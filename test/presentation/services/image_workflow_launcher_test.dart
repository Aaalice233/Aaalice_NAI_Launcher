import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/services/image_workflow_launcher.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';

void main() {
  late Directory hiveTempDir;
  late ProviderContainer container;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'nai_launcher_workflow_launcher_hive_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  ImageWorkflowController workflow() =>
      container.read(imageWorkflowControllerProvider.notifier);

  group('applyInpaintEditorResult', () {
    final canvas = _png(width: 1216, height: 1216);
    final mask = _png(width: 1216, height: 1216);
    const crop = Rect.fromLTWH(384, 0, 832, 1216);
    final focusOutpaintResult = ImageEditorResult(
      maskImage: mask,
      hasMaskChanges: true,
      focusedInpaintEnabled: true,
      focusOutpaint: FocusOutpaintResult(
        sourceImage: canvas,
        width: 1216,
        height: 1216,
        crop: crop,
      ),
      outputWidth: 1216,
      outputHeight: 1216,
    );

    test('a focus outpaint result replaces the source and keeps the frame', () {
      ImageWorkflowLauncher.applyInpaintEditorResult(
        workflow(),
        focusOutpaintResult,
        mask,
      );

      final state = container.read(imageWorkflowControllerProvider);
      final params = container.read(generationParamsNotifierProvider);
      expect(state.mode, ImageWorkflowMode.inpaint);
      expect(state.focusedInpaintEnabled, isTrue);
      expect(state.focusedContextCrop, crop);
      expect(state.focusedSelectionRect, isNull);
      expect(state.isOutpaint, isFalse);
      expect(params.sourceImage, same(canvas));
      expect(params.maskImage, same(mask));
      expect(params.isOutpaint, isFalse);
    });

    test('without a usable mask only the canvas is taken over', () {
      ImageWorkflowLauncher.applyInpaintEditorResult(
        workflow(),
        focusOutpaintResult,
        null,
      );

      final state = container.read(imageWorkflowControllerProvider);
      final params = container.read(generationParamsNotifierProvider);
      expect(state.focusedInpaintEnabled, isFalse);
      expect(state.focusedContextCrop, isNull);
      expect(params.sourceImage, same(canvas));
      expect(params.maskImage, isNull);
    });

    test('a plain outpaint result still disables focus', () {
      final outpaintSource = _png(width: 1216, height: 1216);

      ImageWorkflowLauncher.applyInpaintEditorResult(
        workflow(),
        ImageEditorResult(
          maskImage: mask,
          hasMaskChanges: true,
          outpaintSourceImage: outpaintSource,
          outpaintSourceWidth: 1216,
          outpaintSourceHeight: 1216,
          hasOutpaintChanges: true,
        ),
        mask,
      );

      final state = container.read(imageWorkflowControllerProvider);
      expect(state.isOutpaint, isTrue);
      expect(state.focusedInpaintEnabled, isFalse);
      expect(state.focusedContextCrop, isNull);
      expect(
        container.read(generationParamsNotifierProvider).sourceImage,
        same(outpaintSource),
      );
    });
  });
}

Uint8List _png({required int width, required int height}) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}
