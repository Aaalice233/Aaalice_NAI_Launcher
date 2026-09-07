import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_command.dart';
import 'package:nai_launcher/presentation/providers/generation/image_generation_coordinator.dart';

class _Api extends Mock implements NAIImageGenerationApiService {}

void main() {
  setUpAll(() => registerFallbackValue(const ImageParams()));
  for (final scenario in ['success', 'failure', 'cancel']) {
    test(
      'postprocessing $scenario keeps one paid request and the correct final image',
      () async {
        final api = _Api();
        final original = Uint8List.fromList([1, 2, 3]);
        final enhanced = Uint8List.fromList([4, 5, 6]);
        when(
          () => api.generateImage(
            any(),
            onProgress: any(named: 'onProgress'),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        ).thenAnswer((_) async => (<Uint8List>[original], <int, String>{}));
        late ImageGenerationCoordinator coordinator;
        late GenerationRunHandle handle;
        var processed = 0;
        final errors = <Object>[];
        coordinator = ImageGenerationCoordinator(
          apiService: api,
          postprocess: (bytes, cancelled, onPhase) async {
            processed++;
            expect(bytes, same(original));
            expect(coordinator.isPostprocessing, isTrue);
            if (scenario == 'cancel') {
              coordinator.cancel(handle);
              await cancelled;
            }
            if (scenario != 'success') throw StateError('NR $scenario');
            return enhanced;
          },
          onPostprocessError: errors.add,
        );
        final command = GenerationCommand(
          runId: 1,
          params: const ImageParams(),
          batchCount: 1,
          batchSize: 1,
          streamPreviewEnabled: false,
          prepareBatch: (_, params) async => params,
        );
        handle = coordinator.start(command);
        final events = await coordinator.execute(command, handle).toList();
        final result = events.whereType<GenerationRequestCompleted>().single;
        expect(
          result.images.single,
          same(scenario == 'success' ? enhanced : original),
        );
        expect(
          events.whereType<GenerationCompleted>().single.images.single,
          same(result.images.single),
        );
        expect(
          events.whereType<GenerationCancelled>().length,
          scenario == 'cancel' ? 1 : 0,
        );
        expect(processed, 1);
        expect(errors.length, scenario == 'success' ? 0 : 1);
        verify(
          () => api.generateImage(
            any(),
            onProgress: any(named: 'onProgress'),
            focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
            minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
            focusedSelectionRect: any(named: 'focusedSelectionRect'),
          ),
        ).called(1);
        expect(coordinator.isPostprocessing, isFalse);
      },
    );
  }
}
