import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/services/dlss/dlss_options.dart';
import 'package:nai_launcher/presentation/providers/dlss_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/dlss_upscale_task_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/image_save_settings_provider.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const DlssOptions());
  });
  test(
    'SR at 1x does not run the renderer or register a duplicate image',
    () async {
      final controller = _Controller();
      when(() => controller.options).thenReturn(const DlssOptions(scale: 1));
      final container = ProviderContainer(
        overrides: [dlssProvider.overrideWith((_) => controller)],
      );
      addTearDown(container.dispose);
      final completed = await container
          .read(dlssUpscaleTaskProvider.notifier)
          .execute(params: const ImageParams(), source: Uint8List(1));
      expect(completed, isFalse);
      expect(container.read(dlssUpscaleTaskProvider).running, isFalse);
      verifyNever(
        () => controller.enhance(
          any(),
          any(),
          cancelled: any(named: 'cancelled'),
        ),
      );
    },
  );
  for (final scenario in ['success', 'cancel', 'dispose', 'failure']) {
    test(
      'SR task $scenario preserves registration and lifecycle boundaries',
      () async {
        final controller = _Controller();
        final rendering = Completer<Uint8List>();
        final registrar = _Registrar();
        when(
          () => controller.options,
        ).thenReturn(const DlssOptions(scale: 2.5, intensity: 1));
        DlssOptions? options;
        Future<void>? cancellation;
        when(
          () => controller.enhance(
            any(),
            any(),
            cancelled: any(named: 'cancelled'),
          ),
        ).thenAnswer((call) {
          options = call.positionalArguments[1] as DlssOptions;
          cancellation = call.namedArguments[#cancelled] as Future<void>;
          return rendering.future;
        });
        final container = ProviderContainer(
          overrides: [
            dlssProvider.overrideWith((_) => controller),
            imageGenerationNotifierProvider.overrideWith(() => registrar),
            imageSaveSettingsNotifierProvider.overrideWith(_SaveSettings.new),
          ],
        );
        final task = container.read(dlssUpscaleTaskProvider.notifier);
        final source = Uint8List.fromList([1]);
        final pending = task.execute(
          params: const ImageParams(),
          source: source,
        );
        expect(container.read(dlssUpscaleTaskProvider).running, isTrue);
        expect(options!.scale, 2.5);
        expect(options!.detail, 0);
        if (scenario == 'dispose') {
          container.dispose();
          await cancellation;
        } else if (scenario == 'cancel') {
          task.cancel();
          await cancellation;
        }
        if (scenario == 'failure') {
          rendering.completeError(StateError('native failure'));
        } else {
          rendering.complete(Uint8List.fromList([2]));
        }
        await pending;
        expect(registrar.images, scenario == 'success' ? 1 : 0);
        if (scenario == 'success') {
          expect(registrar.comparison, same(source));
          expect(registrar.embedMetadata, isFalse);
        }
        if (scenario != 'dispose') {
          expect(container.read(dlssUpscaleTaskProvider).running, isFalse);
          expect(
            container.read(dlssUpscaleTaskProvider).error != null,
            scenario == 'failure',
          );
          container.dispose();
        }
      },
    );
  }
}

class _Controller extends Mock implements DlssController {}

class _SaveSettings extends ImageSaveSettingsNotifier {
  @override
  ImageSaveSettings build() => const ImageSaveSettings();
}

class _Registrar extends ImageGenerationNotifier {
  int images = 0;
  Uint8List? comparison;
  bool? embedMetadata;
  @override
  ImageGenerationState build() => const ImageGenerationState();
  @override
  Future<String?> registerExternalImage(
    Uint8List imageBytes, {
    required ImageParams params,
    int? width,
    int? height,
    Uint8List? comparisonSourceImage,
    bool saveToLocal = false,
    String? saveDirectoryPath,
    bool syncToGalleryIndex = true,
    bool addToDisplay = false,
    bool replaceCurrentDisplay = false,
    bool embedNaiMetadata = true,
  }) async {
    images++;
    comparison = comparisonSourceImage;
    embedMetadata = embedNaiMetadata;
    return null;
  }
}
