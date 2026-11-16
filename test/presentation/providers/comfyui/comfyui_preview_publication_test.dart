import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/comfyui/comfyui.dart';
import 'package:nai_launcher/presentation/providers/comfyui/comfyui_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_preview_decode.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_preview_publication.dart';

import '../../../helpers/controlled_preview_images.dart';

class _Api extends Mock implements ComfyUIApiService {}

class _Socket extends Mock implements ComfyUIWebSocketService {}

class _Manager extends Mock implements ComfyUIConnectionManager {}

class _Templates extends Mock implements WorkflowTemplateManager {}

class _Connection extends ComfyUIConnection {
  _Connection(this.connection);
  final ComfyUIConnectionManager connection;
  @override
  ComfyUIConnectionStatus build() => ComfyUIConnectionStatus.connected;
  @override
  ComfyUIConnectionManager get manager => connection;
}

class _Workflows extends ComfyUIWorkflows {
  _Workflows(this.templates);
  final WorkflowTemplateManager templates;
  @override
  List<WorkflowTemplate> build() => const [];
  @override
  WorkflowTemplateManager get manager => templates;
}

class _Harness {
  _Harness(this.wsOutput, {StreamPreviewImageResolver? resolve}) {
    final template = WorkflowTemplate(
      id: 'test',
      name: 'test',
      description: '',
      workflowJson: const {},
      slots: [
        WorkflowSlot(
          id: 'output',
          direction: SlotDirection.output,
          dataType: SlotDataType.image,
          nodeId: '1',
          label: 'output',
          outputMethod: wsOutput
              ? OutputMethod.websocket
              : OutputMethod.httpHistory,
        ),
      ],
    );
    when(() => manager.api).thenReturn(api);
    when(() => manager.ws).thenReturn(socket);
    when(() => manager.clientId).thenReturn('client');
    when(() => socket.imageStream).thenAnswer((_) => frames.stream);
    when(() => socket.progressStream).thenAnswer((_) => progress.stream);
    when(() => templates.getById('test')).thenReturn(template);
    when(
      () => templates.uploadInputImages(
        api: api,
        template: template,
        imageData: const {},
      ),
    ).thenAnswer((_) async => <String, String>{});
    when(
      () => templates.buildExecutableWorkflow(
        template: template,
        paramValues: const {},
        uploadedFiles: const {},
      ),
    ).thenReturn(const {});
    when(
      () => templates.validateWorkflowNodeTypes(api: api, workflow: const {}),
    ).thenAnswer((_) async {});
    when(
      () => api.queuePrompt(workflow: const {}, clientId: 'client'),
    ).thenAnswer(
      (_) async => ComfyUIPromptResult(promptId: 'prompt-${++requests}'),
    );
    when(() => api.getOutputImages(any(), allowedNodeIds: {'1'})).thenAnswer(
      (_) async => [
        Uint8List.fromList([9]),
      ],
    );
    when(() => api.interrupt()).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        comfyUIConnectionProvider.overrideWith(() => _Connection(manager)),
        comfyUIWorkflowsProvider.overrideWith(() => _Workflows(templates)),
        streamPreviewImageResolverProvider.overrideWithValue(
          resolve ?? images.resolve,
        ),
        streamPreviewLifecycleReaderProvider.overrideWithValue(() => lifecycle),
      ],
    );
    container.listen(comfyUITaskProvider, (_, _) {});
  }

  final bool wsOutput;
  final api = _Api();
  final socket = _Socket();
  final manager = _Manager();
  final templates = _Templates();
  final frames = StreamController<ComfyUIImageFrame>.broadcast();
  final progress = StreamController<ComfyUIProgress>.broadcast();
  final images = ControlledPreviewImages();
  late final ProviderContainer container;
  var requests = 0;
  AppLifecycleState? lifecycle = AppLifecycleState.resumed;

  ComfyUITask get notifier => container.read(comfyUITaskProvider.notifier);
  ComfyUITaskState get state => container.read(comfyUITaskProvider);
  Future<List<Uint8List>?> start() => notifier.execute(templateId: 'test');

  void preview(int value) => frames.add(
    ComfyUIImageFrame(data: Uint8List.fromList([value]), isPreview: true),
  );

  void finish() {
    if (wsOutput) frames.add(ComfyUIImageFrame(data: Uint8List.fromList([9])));
    progress.add(
      ComfyUIProgress(
        promptId: state.promptId!,
        status: ComfyUITaskStatus.completed,
      ),
    );
  }

  Future<void> dispose() async {
    container.dispose();
    images.dispose();
    await frames.close();
    await progress.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages(),
  );

  for (final wsOutput in [false, true]) {
    final mode = wsOutput ? 'WS' : 'HTTP';
    test('$mode publishes a synchronously cached preview', () async {
      final harness = _Harness(wsOutput);
      addTearDown(harness.dispose);
      final execution = harness.start();
      await pumpEventQueue();
      final before = harness.state;
      harness.preview(1);
      await pumpEventQueue();
      expect(harness.state, same(before));
      final image = harness.images.complete(0);
      await pumpEventQueue();
      expect(harness.state.previewImage, same(harness.images.requests[0]));
      var synchronous = false;
      final resolved = MemoryImage(
        harness.state.previewImage!,
      ).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((info, sync) {
        synchronous = sync;
        expect(info.image.isCloneOf(image), isTrue);
        info.dispose();
      });
      resolved.addListener(listener);
      expect(synchronous, isTrue);
      resolved.removeListener(listener);
      harness.finish();
      expect(await execution, hasLength(1));
    });

    test('$mode out of order decode cannot replace B with A', () async {
      final harness = _Harness(wsOutput);
      addTearDown(harness.dispose);
      final execution = harness.start();
      await pumpEventQueue();
      harness
        ..preview(1)
        ..preview(2);
      await pumpEventQueue();
      harness.images.complete(1);
      await pumpEventQueue();
      final before = harness.state;
      harness.images.complete(0);
      await pumpEventQueue();
      expect(harness.state, same(before));
      expect(harness.state.previewImage, same(harness.images.requests[1]));
      harness.finish();
      await execution;
    });

    test(
      '$mode slow decodes keep publishing before later arrivals finish',
      () async {
        final harness = _Harness(wsOutput);
        addTearDown(harness.dispose);
        final execution = harness.start();
        await pumpEventQueue();
        harness
          ..preview(1)
          ..preview(2)
          ..preview(3);
        await pumpEventQueue();
        expect(harness.images.requests, hasLength(2));
        for (var index = 0; index < 4; index++) {
          harness.images.complete(index);
          await pumpEventQueue();
          expect(
            harness.state.previewImage,
            same(harness.images.requests[index]),
          );
          expect(harness.state.previewImage!.single, index + 1);
          if (index == 0) {
            harness.preview(4);
            await pumpEventQueue();
          }
        }
        harness.finish();
        await execution;
      },
    );

    test(
      '$mode publishes previews after an output frame until workflow completion',
      () async {
        final harness = _Harness(wsOutput, resolve: resolvedPreviewImage);
        addTearDown(harness.dispose);
        final httpImages = Completer<List<Uint8List>>();
        when(
          () => harness.api.getOutputImages(any(), allowedNodeIds: {'1'}),
        ).thenAnswer((_) => httpImages.future);
        final timers = FakeAsync();
        final execution = runZoned(
          harness.start,
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) =>
                timers.run((_) => Timer(duration, callback)),
          ),
        );
        await pumpEventQueue();

        harness.frames.add(ComfyUIImageFrame(data: Uint8List.fromList([8])));
        harness.preview(1);
        await pumpEventQueue();
        final previewAfterOutput = harness.state.previewImage;

        harness.finish();
        await pumpEventQueue();
        final statusBeforeResult = harness.state.status;
        harness.preview(2);
        await pumpEventQueue();
        final previewAfterCompletion = harness.state.previewImage;

        httpImages.complete([
          Uint8List.fromList([9]),
        ]);
        timers.elapse(const Duration(milliseconds: 500));
        final result = await execution;

        expect(previewAfterOutput, [1]);
        expect(statusBeforeResult, ComfyUITaskStatus.running);
        expect(previewAfterCompletion, same(previewAfterOutput));
        expect(result, [
          if (wsOutput) [8],
          [9],
        ]);
      },
    );

    for (final ending in ['final', 'cancel']) {
      test('$mode thirty chunks without frames release on $ending', () async {
        final harness = _Harness(wsOutput);
        addTearDown(harness.dispose);
        final execution = harness.start();
        await pumpEventQueue();
        for (var index = 0; index < 30; index++) {
          harness.preview(index + 1);
          await pumpEventQueue();
          harness.images.complete(index);
          await pumpEventQueue();
          expect(harness.images.listeners, 1);
        }
        if (ending == 'final') {
          harness.finish();
          await pumpEventQueue();
        } else {
          harness.notifier.cancel();
        }
        expect(harness.images.listeners, 0);
        if (ending == 'cancel') harness.finish();
        await execution;
        expect(harness.images.listeners, 0);
      });
    }

    for (final lifecycle in [
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      test(
        '$mode $lifecycle bypasses decoding and resumes when visible',
        () async {
          final harness = _Harness(wsOutput);
          addTearDown(harness.dispose);
          harness.lifecycle = lifecycle;
          final execution = harness.start();
          await pumpEventQueue();
          harness.preview(1);
          await pumpEventQueue();
          expect(harness.images.requests, isEmpty);
          expect(harness.state.previewImage!.single, 1);
          harness.lifecycle = AppLifecycleState.resumed;
          harness.preview(2);
          await pumpEventQueue();
          expect(harness.state.previewImage!.single, 1);
          harness.images.complete(0);
          await pumpEventQueue();
          expect(
            harness.state.previewImage,
            same(harness.images.requests.single),
          );
          harness.finish();
          await execution;
        },
      );
    }

    test('$mode invalidates pending preview on completion', () async {
      final harness = _Harness(wsOutput);
      addTearDown(harness.dispose);
      final execution = harness.start();
      await pumpEventQueue();
      harness.preview(1);
      await pumpEventQueue();
      harness.finish();
      await pumpEventQueue();
      final before = harness.state;
      harness.images.complete(0);
      await pumpEventQueue();
      expect(harness.state, same(before));
      expect(harness.state.previewImage, isNull);
      await execution;
    });

    test(
      '$mode old prompt decode cannot publish into a running prompt',
      () async {
        final harness = _Harness(wsOutput);
        addTearDown(harness.dispose);
        final previous = harness.start();
        await pumpEventQueue();
        final oldPromptId = harness.state.promptId!;
        harness.preview(1);
        await pumpEventQueue();
        final current = harness.start();
        await pumpEventQueue();
        final before = harness.state;
        harness.images.complete(0);
        await pumpEventQueue();
        expect(harness.state, same(before));
        expect(harness.state.previewImage, isNull);
        harness.preview(2);
        await pumpEventQueue();
        expect(harness.images.requests, hasLength(2));
        harness.images.complete(1);
        await pumpEventQueue();
        expect(harness.state.previewImage!.single, 2);
        if (wsOutput) {
          harness.frames.add(ComfyUIImageFrame(data: Uint8List.fromList([9])));
        }
        harness.progress.add(
          ComfyUIProgress(
            promptId: oldPromptId,
            status: ComfyUITaskStatus.completed,
          ),
        );
        await previous;
        harness.finish();
        await current;
      },
    );

    test('$mode still publishes original bytes when decoding fails', () async {
      final harness = _Harness(wsOutput);
      addTearDown(harness.dispose);
      final execution = harness.start();
      await pumpEventQueue();
      harness.preview(1);
      await pumpEventQueue();
      harness.images.fail(0);
      await pumpEventQueue();
      expect(harness.state.previewImage, same(harness.images.requests[0]));
      harness.finish();
      await execution;
    });

    for (final ending in ['final', 'cancel', 'failure', 'restart', 'dispose']) {
      test('$mode drops pending preview after $ending', () async {
        final harness = _Harness(wsOutput);
        addTearDown(harness.dispose);
        final execution = harness.start();
        await pumpEventQueue();
        harness.preview(1);
        await pumpEventQueue();
        Future<List<Uint8List>?>? next;
        if (ending == 'cancel') {
          harness.notifier.cancel();
        } else if (ending == 'failure') {
          harness.progress.add(
            ComfyUIProgress(
              promptId: harness.state.promptId!,
              status: ComfyUITaskStatus.failed,
            ),
          );
          await execution;
          expect(harness.state.status, ComfyUITaskStatus.failed);
        } else {
          harness.finish();
          await execution;
          if (ending == 'restart') {
            next = harness.start();
            await pumpEventQueue();
          } else if (ending == 'dispose') {
            harness.container.dispose();
          }
        }
        final before = ending == 'dispose' ? null : harness.state;
        expect(harness.images.listeners, 0);
        harness.images.complete(0);
        await pumpEventQueue();
        if (ending != 'dispose') expect(harness.state, same(before));
        if (ending == 'cancel') {
          harness.finish();
          await execution;
        }
        if (ending == 'restart') {
          harness.finish();
          await next;
        }
      });
    }
  }
}
