import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store_provider.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/presentation/providers/dlss_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/image_save_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/services/generation_history_storage_service.dart';

import '../../../helpers/image_generation_test_environment.dart';
import '../../../helpers/memory_queue_blob_store.dart';
import '../../../helpers/queue_execution_harness.dart';

class _Api extends Mock implements NAIImageGenerationApiService {}

class _Dlss extends Mock implements DlssController {}

void main() {
  setUpImageGenerationTestEnvironment();
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
        when(dlss.automaticSnapshot).thenReturn((
          bytes,
          cancelled,
          onPhase,
        ) async {
          entered.complete();
          await cancelled;
          throw StateError('NR cancelled');
        });
        final container = ProviderContainer(
          overrides: [
            naiImageGenerationApiServiceProvider.overrideWithValue(api),
            dlssProvider.overrideWithBuild((_, _) => dlss),
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

  test('queue cancellation during NR keeps the original and stops before '
      'the next submission', () async {
    final api = _Api();
    final dlss = _Dlss();
    final postprocessStarted = Completer<void>();
    final original = img.encodePng(img.Image(width: 2, height: 2));
    final submitted = <String>[];
    when(
      () => api.generateImageStream(
        any(),
        focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
        minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
        focusedSelectionRect: any(named: 'focusedSelectionRect'),
        focusedContextCrop: any(named: 'focusedContextCrop'),
        cancellationLease: any(named: 'cancellationLease'),
      ),
    ).thenAnswer((call) {
      submitted.add((call.positionalArguments.single as ImageParams).prompt);
      return Stream.value(ImageStreamChunk.complete(original));
    });
    when(() => api.cancelGeneration(any())).thenReturn(null);
    when(dlss.automaticSnapshot).thenReturn((bytes, cancelled, onPhase) async {
      if (postprocessStarted.isCompleted) return bytes;
      postprocessStarted.complete();
      await cancelled;
      throw StateError('NR cancelled');
    });
    final tasks = [
      ReplicationTask.create(prompt: 'first'),
      ReplicationTask.create(prompt: 'next'),
    ];
    final generation = ImageGenerationNotifier();
    final container = buildControlledQueueContainer(
      tasks,
      generation,
      localStorage: NoRetryLocalStorageService(),
      extraOverrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(api),
        dlssProvider.overrideWithBuild((_, _) => dlss),
        replicationQueueBlobStoreProvider.overrideWithValue(
          memoryQueueBlobStore(),
        ),
        generationSessionPersistenceEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(imageSaveSettingsNotifierProvider.notifier)
        .setAutoSave(false);
    final queue = container.read(queueExecutionNotifierProvider.notifier);
    expect(await queue.startQueue(), QueueStartResult.started);
    await postprocessStarted.future;

    final settled = generation.waitUntilGenerationInvocationSettled();
    generation.cancel();
    expect(await settled, isA<GenerationRunCancelled>());
    await container.pump();

    final images = container.read(imageGenerationNotifierProvider);
    expect(images.status, GenerationStatus.cancelled);
    expect(images.displayImages.single.bytes, original);
    expect(container.read(queueExecutionNotifierProvider).isIdle, isTrue);
    expect(container.read(queueExecutionNotifierProvider).completedCount, 1);
    expect(container.read(replicationQueueNotifierProvider).tasks, [tasks[1]]);
    expect(submitted, ['first']);
  });
}
