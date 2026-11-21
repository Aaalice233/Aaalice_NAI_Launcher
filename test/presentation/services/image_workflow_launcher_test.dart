import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_request_resolution.dart';
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

  test(
    'ordinary editing honors compression and reuses the live page size for a smaller source',
    () {
      final settings = container.read(
        generationParamsNotifierProvider.notifier,
      );
      for (final (compressed, width, height, pageWidth, pageHeight, expected)
          in [
            (true, 768, 768, 1024, 1024, (768, 768)),
            (true, 1664, 2432, 1024, 1024, (1472, 2112)),
            (false, 416, 608, 832, 1216, (832, 1216)),
            (false, 960, 640, 1152, 768, (1152, 768)),
          ]) {
        settings.updateSize(pageWidth, pageHeight, persist: false);
        final bytes = _png(width: width, height: height);
        expect(
          ImageWorkflowLauncher.applyEditResult(
            workflow(),
            ImageEditorResult(
              modifiedImage: bytes,
              outputWidth: width,
              outputHeight: height,
              compressionApplied: compressed,
            ),
          ),
          isTrue,
        );
        final params = container.read(generationParamsNotifierProvider);
        final state = container.read(imageWorkflowControllerProvider);
        expect(params.sourceImage, same(bytes));
        expect(
          (state.sourceImageWidth, state.sourceImageHeight),
          (width, height),
        );
        expect((params.width, params.height), expected);
      }
    },
  );

  test(
    'edited full canvas, mask and selection survive inpainting and a preset change',
    () async {
      final source = _png(width: 1664, height: 2432);
      final maskImage = img.Image(width: 1664, height: 2432, numChannels: 1);
      img.fillRect(
        maskImage,
        x1: 400,
        y1: 950,
        x2: 450,
        y2: 1000,
        color: img.ColorRgb8(255, 255, 255),
      );
      final mask = img.encodePng(maskImage, level: 1);
      const selection = Rect.fromLTWH(288, 900, 1088, 576);
      ImageWorkflowLauncher.applyEditResult(
        workflow(),
        ImageEditorResult(
          modifiedImage: source,
          outputWidth: 1664,
          outputHeight: 2432,
        ),
      );
      ImageWorkflowLauncher.applyInpaintEditorResult(
        workflow(),
        ImageEditorResult(
          maskImage: mask,
          hasMaskChanges: true,
          focusedInpaintEnabled: true,
          focusAreaRect: selection,
          minimumContextMegaPixels: 96,
        ),
        mask,
      );
      final settings = container.read(generationParamsNotifierProvider);
      expect((settings.width, settings.height), (1472, 2112));
      container
          .read(generationParamsNotifierProvider.notifier)
          .updateSize(1024, 1024, persist: false);
      final params = container.read(generationParamsNotifierProvider);
      final state = container.read(imageWorkflowControllerProvider);
      expect((state.sourceImageWidth, state.sourceImageHeight), (1664, 2432));
      expect(params.sourceImage, same(source));
      expect(params.maskImage, same(mask));
      expect(state.focusedSelectionRect, selection);
      expect(state.focusedInpaintEnabled, isTrue);
      expect(params.isOutpaint, isFalse);
      expect(state.isOutpaint, isFalse);
      final subscription = container.listen(
        generationPageRequestGeometryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final geometry = await container.read(
        generationPageRequestGeometryProvider.future,
      );
      expect((geometry?.requestWidth, geometry?.requestHeight), (1280, 768));
    },
  );

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

    test('an empty exported mask retains the fixed frame for validation', () {
      ImageWorkflowLauncher.applyInpaintEditorResult(
        workflow(),
        focusOutpaintResult,
        null,
      );

      final state = container.read(imageWorkflowControllerProvider);
      final params = container.read(generationParamsNotifierProvider);
      expect(state.focusedInpaintEnabled, isTrue);
      expect(state.focusedContextCrop, crop);
      expect(params.sourceImage, same(canvas));
      expect(params.maskImage, same(mask));
      expect(params.isInpainting, isTrue);
    });

    test('an edited source without a mask stays in inpaint mode', () {
      final edited = _png(width: 832, height: 1216);

      ImageWorkflowLauncher.applyInpaintEditorResult(
        workflow(),
        ImageEditorResult(
          hasSourceImageChanges: true,
          inpaintSourceImage: edited,
          inpaintSourceWidth: 832,
          inpaintSourceHeight: 1216,
          outputWidth: 832,
          outputHeight: 1216,
        ),
        null,
      );

      final state = container.read(imageWorkflowControllerProvider);
      final params = container.read(generationParamsNotifierProvider);
      expect(state.mode, ImageWorkflowMode.inpaint);
      expect(state.isOutpaint, isFalse);
      expect(params.sourceImage, same(edited));
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
