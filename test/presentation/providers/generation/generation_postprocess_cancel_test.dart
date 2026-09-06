import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/dlss_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/batch_generation_notifier.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_generation_notifier.dart';

class _Api extends Mock implements NAIImageGenerationApiService {}

class _Dlss extends Mock implements DlssController {}

void main() {
  setUpAll(() => registerFallbackValue(const ImageParams()));
  for (final batch in [true, false]) {
    test(
      '${batch ? 'batch' : 'stream'} cancellation during NR retains arrived image',
      () async {
        final api = _Api();
        final dlss = _Dlss();
        final entered = Completer<void>();
        final original = Uint8List.fromList([1, 2, 3]);
        when(
          () => api.generateImageStream(any()),
        ).thenAnswer((_) => Stream.value(ImageStreamChunk.complete(original)));
        when(dlss.automaticSnapshot).thenReturn((bytes, cancelled) async {
          entered.complete();
          await cancelled;
          throw StateError('NR cancelled');
        });
        final container = ProviderContainer(
          overrides: [
            naiImageGenerationApiServiceProvider.overrideWithValue(api),
            dlssProvider.overrideWith((_) => dlss),
          ],
        );
        addTearDown(container.dispose);
        if (batch) {
          final notifier = container.read(
            batchGenerationNotifierProvider.notifier,
          );
          final run = notifier.generateBatch(const ImageParams(), count: 2);
          await entered.future;
          notifier.cancel();
          await run;
          expect(notifier.state.items.first.image, original);
          expect(notifier.state.items.first.isCompleted, isTrue);
          expect(notifier.state.status, BatchGenerationStatus.cancelled);
        } else {
          final notifier = container.read(
            streamGenerationNotifierProvider.notifier,
          );
          final run = notifier.generate(const ImageParams());
          await entered.future;
          notifier.cancel();
          await run;
          expect(notifier.state.result?.bytes, original);
          expect(notifier.state.status, StreamGenerationStatus.cancelled);
        }
        verify(dlss.automaticSnapshot).called(1);
        verify(() => api.generateImageStream(any())).called(1);
      },
    );
  }
}
