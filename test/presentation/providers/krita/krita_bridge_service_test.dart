import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/krita/krita_bridge_models.dart';
import 'package:nai_launcher/core/models/image_generation_artifact.dart';
import 'package:nai_launcher/core/utils/focused_inpaint_utils.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/krita/krita_bridge_service.dart';

void main() {
  group('KritaBridgeService', () {
    test('responds to get_params with current generation snapshot', () async {
      final sent = <Map<String, dynamic>>[];
      final service = KritaBridgeService(
        readBaseParams: () => const ImageParams(
          prompt: '1girl',
          negativePrompt: 'bad hands',
          model: 'nai-diffusion-4-curated-preview',
          sampler: 'k_euler',
          steps: 30,
          scale: 5.5,
          seed: 123,
          width: 1024,
          height: 1024,
          strength: 0.45,
          noise: 0.1,
          inpaintStrength: 0.8,
        ),
        readMinimumContextPixels: () => 64,
        send: sent.add,
        isUiGenerating: () => false,
        generateStream: (_) => const Stream.empty(),
        generateFallback: (_) async => const [],
        registerExternalImage: (_, {required params, addToDisplay}) async =>
            null,
        cancelGeneration: () {},
      );

      await service.handle(const KritaGetParamsMessage(id: 'params-1'));

      expect(sent, hasLength(1));
      expect(sent.single, containsPair('type', 'params'));
      expect(sent.single['id'], 'params-1');
      expect(sent.single['prompt'], '1girl');
      expect(sent.single['negative_prompt'], 'bad hands');
      expect(sent.single['model'], 'nai-diffusion-4-curated-preview');
      expect(sent.single['sampler'], 'k_euler');
      expect(sent.single['steps'], 30);
      expect(sent.single['cfg_scale'], 5.5);
      expect(sent.single['seed'], 123);
      expect(sent.single['width'], 1024);
      expect(sent.single['height'], 1024);
      expect(sent.single['strength'], 0.45);
      expect(sent.single['noise'], 0.1);
      expect(sent.single['inpaint_strength'], 0.8);
      expect(sent.single['minimum_context_pixels'], 64);
      expectNoSensitiveBridgeData(sent.single);
    });

    test('responds to get_params with composed launcher prompts', () async {
      final sent = <Map<String, dynamic>>[];
      final service = KritaBridgeService(
        readBaseParams: () => const ImageParams(
          prompt: 'base prompt',
          negativePrompt: 'base negative',
        ),
        readPromptSnapshot: (params) => (
          prompt: 'fixed prefix, ${params.prompt}, fixed suffix',
          negativePrompt: 'negative fixed prefix, ${params.negativePrompt}',
        ),
        send: sent.add,
        isUiGenerating: () => false,
        generateStream: (_) => const Stream.empty(),
        generateFallback: (_) async => const [],
        registerExternalImage: (_, {required params, addToDisplay}) async =>
            null,
        cancelGeneration: () {},
      );

      await service.handle(const KritaGetParamsMessage(id: 'params-fixed'));

      expect(sent, hasLength(1));
      expect(sent.single['prompt'], 'fixed prefix, base prompt, fixed suffix');
      expect(
        sent.single['negative_prompt'],
        'negative fixed prefix, base negative',
      );
    });

    test('rejects generation while launcher UI is generating', () async {
      final sent = <Map<String, dynamic>>[];
      var streamCalled = false;
      final service = KritaBridgeService(
        readBaseParams: () => const ImageParams(),
        send: sent.add,
        isUiGenerating: () => true,
        generateStream: (_) {
          streamCalled = true;
          return const Stream.empty();
        },
        generateFallback: (_) async => const [],
        registerExternalImage: (_, {required params, addToDisplay}) async =>
            null,
        cancelGeneration: () {},
      );

      await service.handle(
        KritaImg2ImgMessage(
          id: 'img-1',
          image: Uint8List.fromList([1]),
          prompt: 'cat',
          negativePrompt: '',
          strength: 0.5,
          noise: 0.0,
        ),
      );

      expect(streamCalled, isFalse);
      expect(sent, hasLength(1));
      expect(sent.single['type'], 'error');
      expect(sent.single['id'], 'img-1');
      expect(sent.single['code'], KritaBridgeErrorCode.busy.value);
    });

    test('rate limits immediate retry after failed Krita request', () async {
      final sent = <Map<String, dynamic>>[];
      var streamCalls = 0;
      var now = DateTime.utc(2026, 5, 10, 12);
      final service = KritaBridgeService(
        readBaseParams: () => const ImageParams(),
        send: sent.add,
        isUiGenerating: () => false,
        generateStream: (_) {
          streamCalls++;
          throw Exception('500 server error');
        },
        generateFallback: (_) async => const [],
        registerExternalImage: (_, {required params, addToDisplay}) async =>
            null,
        cancelGeneration: () {},
        clock: () => now,
        failureCooldown: const Duration(seconds: 5),
      );

      Future<void> sendRequest(String id) {
        return service.handle(
          KritaImg2ImgMessage(
            id: id,
            image: Uint8List.fromList([1]),
            prompt: '',
            negativePrompt: '',
            strength: 0.5,
            noise: 0.0,
          ),
        );
      }

      await sendRequest('img-fail-1');
      await sendRequest('img-fail-2');

      expect(streamCalls, 1);
      expect(sent, hasLength(2));
      expect(sent.first['code'], KritaBridgeErrorCode.serverError.value);
      expect(sent.last['id'], 'img-fail-2');
      expect(sent.last['code'], KritaBridgeErrorCode.rateLimited.value);

      now = now.add(const Duration(seconds: 6));
      await sendRequest('img-fail-3');

      expect(streamCalls, 2);
      expect(sent.last['id'], 'img-fail-3');
      expect(sent.last['code'], KritaBridgeErrorCode.serverError.value);
    });

    test(
      'returns stream_interrupted when generation ends without final image',
      () async {
        final sent = <Map<String, dynamic>>[];
        var registered = false;
        final service = KritaBridgeService(
          readBaseParams: () => const ImageParams(),
          send: sent.add,
          isUiGenerating: () => false,
          generateStream: (_) => Stream.fromIterable([
            ImageStreamChunk.progress(
              progress: 0.25,
              currentStep: 1,
              totalSteps: 4,
              previewImage: Uint8List.fromList([1, 2, 3]),
            ),
          ]),
          generateFallback: (_) async => const [],
          registerExternalImage: (_, {required params, addToDisplay}) async {
            registered = true;
            return null;
          },
          cancelGeneration: () {},
        );

        await service.handle(
          KritaImg2ImgMessage(
            id: 'img-interrupted',
            image: Uint8List.fromList([1]),
            prompt: '',
            negativePrompt: '',
            strength: 0.5,
            noise: 0.0,
          ),
        );

        expect(registered, isFalse);
        expect(sent, hasLength(2));
        expect(sent.first['type'], 'progress');
        expect(sent.last['type'], 'error');
        expect(sent.last['id'], 'img-interrupted');
        expect(sent.last['code'], KritaBridgeErrorCode.streamInterrupted.value);
      },
    );

    test(
      'returns streaming_unsupported when streaming and fallback both fail',
      () async {
        final sent = <Map<String, dynamic>>[];
        final service = KritaBridgeService(
          readBaseParams: () => const ImageParams(),
          send: sent.add,
          isUiGenerating: () => false,
          generateStream: (_) => throw Exception('streaming is not allowed'),
          generateFallback: (_) async => const [],
          registerExternalImage: (_, {required params, addToDisplay}) async =>
              null,
          cancelGeneration: () {},
        );

        await service.handle(
          KritaImg2ImgMessage(
            id: 'img-no-stream',
            image: Uint8List.fromList([1]),
            prompt: '',
            negativePrompt: '',
            strength: 0.5,
            noise: 0.0,
          ),
        );

        expect(sent, hasLength(1));
        expect(sent.single['type'], 'error');
        expect(sent.single['id'], 'img-no-stream');
        expect(
          sent.single['code'],
          KritaBridgeErrorCode.streamingUnsupported.value,
        );
      },
    );

    test('maps empty inpaint mask failures to empty_mask error code', () async {
      final sent = <Map<String, dynamic>>[];
      final service = KritaBridgeService(
        readBaseParams: () => const ImageParams(),
        send: sent.add,
        isUiGenerating: () => false,
        generateStream: (_) => throw Exception('Inpaint mask is empty'),
        generateFallback: (_) async => const [],
        registerExternalImage: (_, {required params, addToDisplay}) async =>
            null,
        cancelGeneration: () {},
      );

      await service.handle(
        KritaImg2ImgMessage(
          id: 'img-empty-mask',
          image: Uint8List.fromList([1]),
          prompt: '',
          negativePrompt: '',
          strength: 0.5,
          noise: 0.0,
        ),
      );

      expect(sent, hasLength(1));
      expect(sent.single['type'], 'error');
      expect(sent.single['id'], 'img-empty-mask');
      expect(sent.single['code'], KritaBridgeErrorCode.emptyMask.value);
    });

    test('maps explicit API failures to stable bridge error codes', () async {
      final cases = <({String error, KritaBridgeErrorCode code})>[
        (
          error: '402 insufficient Anlas',
          code: KritaBridgeErrorCode.insufficientAnlas,
        ),
        (
          error: '429 rate limit exceeded',
          code: KritaBridgeErrorCode.rateLimited,
        ),
        (
          error: 'Dio timeout while reading stream',
          code: KritaBridgeErrorCode.timeout,
        ),
      ];

      for (final entry in cases) {
        final sent = <Map<String, dynamic>>[];
        final service = KritaBridgeService(
          readBaseParams: () => const ImageParams(),
          send: sent.add,
          isUiGenerating: () => false,
          generateStream: (_) => throw Exception(entry.error),
          generateFallback: (_) async => const [],
          registerExternalImage: (_, {required params, addToDisplay}) async =>
              null,
          cancelGeneration: () {},
        );

        await service.handle(
          KritaImg2ImgMessage(
            id: 'img-${entry.code.value}',
            image: Uint8List.fromList([1]),
            prompt: '',
            negativePrompt: '',
            strength: 0.5,
            noise: 0.0,
          ),
        );

        expect(sent, hasLength(1));
        expect(sent.single['type'], 'error');
        expect(sent.single['code'], entry.code.value);
        expectNoSensitiveBridgeData(sent.single);
      }
    });

    test(
      'does not expose auth tokens or account data in bridge errors',
      () async {
        final sent = <Map<String, dynamic>>[];
        final service = KritaBridgeService(
          readBaseParams: () => const ImageParams(),
          send: sent.add,
          isUiGenerating: () => false,
          generateStream: (_) => throw Exception(
            '401 token pst-secret account user@example.com endpoint https://nai.local',
          ),
          generateFallback: (_) async => const [],
          registerExternalImage: (_, {required params, addToDisplay}) async =>
              null,
          cancelGeneration: () {},
        );

        await service.handle(
          KritaImg2ImgMessage(
            id: 'img-auth-leak',
            image: Uint8List.fromList([1]),
            prompt: '',
            negativePrompt: '',
            strength: 0.5,
            noise: 0.0,
          ),
        );

        expect(sent, hasLength(1));
        expect(sent.single['type'], 'error');
        expect(sent.single['id'], 'img-auth-leak');
        expect(sent.single['code'], KritaBridgeErrorCode.authFailed.value);
        expectNoSensitiveBridgeData(sent.single);
      },
    );

    test('reports active request while Krita generation is running', () async {
      final activeRequests = <String?>[];
      final streamController = StreamController<ImageStreamChunk>();
      final service = KritaBridgeService(
        readBaseParams: () => const ImageParams(),
        send: (_) {},
        isUiGenerating: () => false,
        generateStream: (_) => streamController.stream,
        generateFallback: (_) async => const [],
        registerExternalImage: (_, {required params, addToDisplay}) async =>
            null,
        cancelGeneration: () {},
      )..setActiveRequestReporter(activeRequests.add);

      final generation = service.handle(
        KritaImg2ImgMessage(
          id: 'img-active',
          image: Uint8List.fromList([1]),
          prompt: '',
          negativePrompt: '',
          strength: 0.5,
          noise: 0.0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(activeRequests, ['img-active']);

      await streamController.close();
      await generation;

      expect(activeRequests, ['img-active', null]);
    });

    test(
      'relays stream progress, result, and registers history image',
      () async {
        final sent = <Map<String, dynamic>>[];
        final registered = <({Uint8List image, ImageParams params})>[];
        late KritaBridgeGenerateRequest capturedRequest;
        final finalImage = Uint8List.fromList([7, 8, 9]);

        final service = KritaBridgeService(
          readBaseParams: () => const ImageParams(
            model: 'nai-diffusion-4-full',
            width: 640,
            height: 960,
          ),
          send: sent.add,
          isUiGenerating: () => false,
          generateStream: (request) {
            capturedRequest = request;
            return Stream.fromIterable([
              ImageStreamChunk.progress(
                progress: 0.5,
                currentStep: 14,
                totalSteps: 28,
                previewImage: Uint8List.fromList([1, 2, 3]),
              ),
              ImageStreamChunk.complete(finalImage),
            ]);
          },
          generateFallback: (_) async => const [],
          registerExternalImage:
              (image, {required params, addToDisplay}) async {
                registered.add((image: image, params: params));
                return 'G:/AIdarw/generated/krita-result.png';
              },
          cancelGeneration: () {},
        );

        await service.handle(
          KritaImg2ImgMessage(
            id: 'img-2',
            image: Uint8List.fromList([4, 5, 6]),
            prompt: 'dog',
            negativePrompt: 'low quality',
            strength: 0.55,
            noise: 0.15,
          ),
        );

        expect(capturedRequest.params.action, ImageGenerationAction.img2img);
        expect(capturedRequest.params.prompt, 'dog');
        expect(capturedRequest.params.negativePrompt, 'low quality');
        expect(capturedRequest.focusedInpaintEnabled, isFalse);
        expect(sent, hasLength(2));
        expect(sent.first['type'], 'progress');
        expect(sent.first['id'], 'img-2');
        expect(sent.first['step'], 14);
        expect(sent.first['total_steps'], 28);
        expect(base64Decode(sent.first['preview_image'] as String), [1, 2, 3]);
        expect(sent.last['type'], 'result');
        expect(sent.last['id'], 'img-2');
        expect(sent.last['saved_path'], 'G:/AIdarw/generated/krita-result.png');
        expect(base64Decode(sent.last['image'] as String), finalImage);
        expect(
          sent.last['params'],
          containsPair('model', 'nai-diffusion-4-full'),
        );
        expect(sent.last['params'], containsPair('width', 640));
        expect(sent.last['params'], containsPair('height', 960));
        expect(sent.last['params'], containsPair('prompt', 'dog'));
        expect(
          sent.last['params'],
          containsPair('negative_prompt', 'low quality'),
        );
        expect(sent.last['params'], containsPair('strength', 0.55));
        expect(sent.last['params'], containsPair('noise', 0.15));
        expectNoSensitiveBridgeData(sent.first);
        expectNoSensitiveBridgeData(sent.last);
        expect(registered, hasLength(1));
        expect(registered.single.image, finalImage);
        expect(registered.single.params.prompt, 'dog');
      },
    );

    test(
      'registers bridge results for current display history ordering',
      () async {
        final displayFlags = <bool?>[];
        final service = KritaBridgeService(
          readBaseParams: () => const ImageParams(),
          send: (_) {},
          isUiGenerating: () => false,
          generateStream: (_) => Stream.value(
            ImageStreamChunk.complete(Uint8List.fromList([7, 8, 9])),
          ),
          generateFallback: (_) async => const [],
          registerExternalImage: (_, {required params, addToDisplay}) async {
            displayFlags.add(addToDisplay);
            return null;
          },
          cancelGeneration: () {},
        );

        await service.handle(
          KritaImg2ImgMessage(
            id: 'img-display-history',
            image: Uint8List.fromList([1]),
            prompt: '',
            negativePrompt: '',
            strength: 0.5,
            noise: 0.0,
          ),
        );

        expect(displayFlags, [isTrue]);
      },
    );

    test(
      'composites Krita inpaint result with source mask before writeback',
      () async {
        final sent = <Map<String, dynamic>>[];
        final registered = <Uint8List>[];
        final source = _solidPng(4, 4, 10, 20, 30);
        final generated = _solidPng(4, 4, 200, 210, 220);
        final mask = _maskPng(4, 4, const [(1, 1), (2, 1)]);
        var streamCalled = false;
        final service = KritaBridgeService(
          readBaseParams: () => const ImageParams(),
          send: sent.add,
          isUiGenerating: () => false,
          generateStream: (_) {
            streamCalled = true;
            return Stream.value(ImageStreamChunk.complete(generated));
          },
          generateFallback: (_) async => [
            _inpaintArtifact(source, mask, generated),
          ],
          registerExternalImage:
              (image, {required params, addToDisplay}) async {
                registered.add(image);
                return null;
              },
          cancelGeneration: () {},
        );

        await service.handle(
          KritaInpaintMessage(
            id: 'inpaint-compose',
            image: source,
            mask: mask,
            prompt: 'repair',
            negativePrompt: '',
            strength: 0.7,
            noise: 0.0,
            inpaintStrength: 1.0,
            minimumContextPixels: 88,
            maskClosingIterations: 0,
            maskExpansionIterations: 0,
            focusedInpaint: false,
          ),
        );

        expect(streamCalled, isFalse);
        expect(sent, hasLength(1));
        expect(sent.single['type'], 'result');
        final result = img.decodeImage(
          base64Decode(sent.single['image'] as String),
        )!;
        final historyResult = img.decodeImage(registered.single)!;

        expect(result.getPixel(1, 1).r.toInt(), equals(200));
        expect(result.getPixel(0, 0).a.toInt(), equals(0));
        expect(result.getPixel(3, 3).a.toInt(), equals(0));
        expect(historyResult.getPixel(2, 1).b.toInt(), equals(220));
        expect(historyResult.getPixel(3, 3).b.toInt(), equals(30));
      },
    );

    test(
      'uses direct fallback for Krita inpaint instead of streaming previews',
      () async {
        final sent = <Map<String, dynamic>>[];
        final source = _solidPng(4, 4, 10, 20, 30);
        final generated = _solidPng(4, 4, 200, 210, 220);
        final mask = _maskPng(4, 4, const [(1, 1)]);
        var streamCalled = false;
        final service = KritaBridgeService(
          readBaseParams: () => const ImageParams(),
          send: sent.add,
          isUiGenerating: () => false,
          generateStream: (_) {
            streamCalled = true;
            return Stream.value(
              ImageStreamChunk.progress(
                progress: 0.5,
                currentStep: 1,
                totalSteps: 2,
                previewImage: generated,
              ),
            );
          },
          generateFallback: (_) async => [
            _inpaintArtifact(source, mask, generated),
          ],
          registerExternalImage: (_, {required params, addToDisplay}) async =>
              null,
          cancelGeneration: () {},
        );

        await service.handle(
          KritaInpaintMessage(
            id: 'inpaint-preview-compose',
            image: source,
            mask: mask,
            prompt: 'repair',
            negativePrompt: '',
            strength: 0.7,
            noise: 0.0,
            inpaintStrength: 1.0,
            minimumContextPixels: 88,
            maskClosingIterations: 0,
            maskExpansionIterations: 0,
            focusedInpaint: false,
          ),
        );

        expect(streamCalled, isFalse);
        expect(sent, hasLength(1));
        expect(sent.single['type'], 'result');
        final result = img.decodeImage(
          base64Decode(sent.single['image'] as String),
        )!;

        expect(result.getPixel(1, 1).r.toInt(), equals(200));
        expect(result.getPixel(0, 0).a.toInt(), equals(0));
        expect(result.getPixel(3, 3).a.toInt(), equals(0));
      },
    );

    test(
      'keeps focused inpaint context active while writing only a masked patch',
      () async {
        final sent = <Map<String, dynamic>>[];
        final registered = <Uint8List>[];
        late KritaBridgeGenerateRequest capturedRequest;
        var streamCalled = false;
        final source = _solidPng(4, 4, 10, 20, 30);
        final generatedFullCanvas = _solidPng(4, 4, 200, 210, 220);
        final mask = _maskPng(4, 4, const [(1, 1)]);
        final service = KritaBridgeService(
          readBaseParams: () => const ImageParams(),
          send: sent.add,
          isUiGenerating: () => false,
          generateStream: (request) {
            capturedRequest = request;
            streamCalled = true;
            return Stream.value(ImageStreamChunk.complete(generatedFullCanvas));
          },
          generateFallback: (request) async {
            capturedRequest = request;
            return [_inpaintArtifact(source, mask, generatedFullCanvas)];
          },
          registerExternalImage:
              (image, {required params, addToDisplay}) async {
                registered.add(image);
                return null;
              },
          cancelGeneration: () {},
        );

        await service.handle(
          KritaInpaintMessage(
            id: 'focused-inpaint-patch',
            image: source,
            mask: mask,
            prompt: 'repair hand',
            negativePrompt: '',
            strength: 0.7,
            noise: 0.0,
            inpaintStrength: 1.0,
            minimumContextPixels: 12,
            maskClosingIterations: 0,
            maskExpansionIterations: 0,
            focusedInpaint: true,
            selectionRect: const KritaSelectionRect(
              x: 1,
              y: 1,
              width: 2,
              height: 2,
            ),
          ),
        );

        expect(capturedRequest.focusedInpaintEnabled, isTrue);
        expect(streamCalled, isFalse);
        expect(capturedRequest.minimumContextPixels, equals(16));
        expect(capturedRequest.focusedSelectionRect?.left, equals(1));
        expect(capturedRequest.focusedSelectionRect?.top, equals(1));
        expect(capturedRequest.focusedSelectionRect?.width, equals(2));
        expect(capturedRequest.focusedSelectionRect?.height, equals(2));

        expect(sent, hasLength(1));
        expect(sent.single['type'], 'result');
        final layerResult = img.decodeImage(
          base64Decode(sent.single['image'] as String),
        )!;
        final historyResult = img.decodeImage(registered.single)!;

        expect(layerResult.getPixel(1, 1).r.toInt(), equals(200));
        expect(layerResult.getPixel(1, 1).a.toInt(), equals(255));
        expect(layerResult.getPixel(0, 0).a.toInt(), equals(0));
        expect(layerResult.getPixel(3, 3).a.toInt(), equals(0));
        expect(historyResult.getPixel(1, 1).r.toInt(), equals(200));
        expect(historyResult.getPixel(0, 0).r.toInt(), equals(10));
        expect(historyResult.getPixel(3, 3).b.toInt(), equals(30));
      },
    );

    test(
      'reconstrains oversized focused rectangles from older plugins',
      () async {
        final sent = <Map<String, dynamic>>[];
        late KritaBridgeGenerateRequest capturedRequest;
        final source = _solidPng(2048, 1537, 10, 20, 30);
        final service = KritaBridgeService(
          readBaseParams: () => const ImageParams(),
          send: sent.add,
          isUiGenerating: () => false,
          generateStream: (_) => const Stream.empty(),
          generateFallback: (request) async {
            capturedRequest = request;
            return const [];
          },
          registerExternalImage: (_, {required params, addToDisplay}) async =>
              null,
          cancelGeneration: () {},
        );

        await service.handle(
          KritaInpaintMessage(
            id: 'oversized-focused-selection',
            image: source,
            mask: _maskPng(4, 4, const [(1, 1)]),
            prompt: '',
            negativePrompt: '',
            strength: 0.7,
            noise: 0,
            inpaintStrength: 1,
            minimumContextPixels: 88,
            maskClosingIterations: 0,
            maskExpansionIterations: 0,
            focusedInpaint: true,
            selectionRect: const KritaSelectionRect(
              x: 0,
              y: 0,
              width: 2048,
              height: 1537,
            ),
          ),
        );

        final selection = capturedRequest.focusedSelectionRect!;
        final geometry = FocusedInpaintUtils.resolveGeometryForSelection(
          sourceWidth: 2048,
          sourceHeight: 1537,
          selectionRect: selection,
          minContextMegaPixels: 88,
        )!;
        expect(selection.width * selection.height, lessThan(2048 * 1537));
        expect(
          geometry.contextCrop.area,
          lessThanOrEqualTo(FocusedInpaintUtils.maxRequestAreaPixels),
        );
      },
    );

    test(
      'cancels active Krita request without accepting another one',
      () async {
        final sent = <Map<String, dynamic>>[];
        var cancelCalled = false;
        final streamController = StreamController<ImageStreamChunk>();
        final service = KritaBridgeService(
          readBaseParams: () => const ImageParams(),
          send: sent.add,
          isUiGenerating: () => false,
          generateStream: (_) => streamController.stream,
          generateFallback: (_) async => const [],
          registerExternalImage: (_, {required params, addToDisplay}) async =>
              null,
          cancelGeneration: () {
            cancelCalled = true;
          },
        );

        final generation = service.handle(
          KritaImg2ImgMessage(
            id: 'img-3',
            image: Uint8List.fromList([1]),
            prompt: '',
            negativePrompt: '',
            strength: 0.5,
            noise: 0.0,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        await service.handle(const KritaCancelMessage(id: 'img-3'));
        await service.handle(
          KritaImg2ImgMessage(
            id: 'img-4',
            image: Uint8List.fromList([2]),
            prompt: '',
            negativePrompt: '',
            strength: 0.5,
            noise: 0.0,
          ),
        );

        expect(cancelCalled, isTrue);
        expect(sent.first['type'], 'cancelled');
        expect(sent.first['id'], 'img-3');
        expect(sent.last['type'], 'error');
        expect(sent.last['id'], 'img-4');
        expect(sent.last['code'], KritaBridgeErrorCode.busy.value);

        await streamController.close();
        await generation;
      },
    );

    test('cancels active request when Krita disconnects', () async {
      var cancelCalled = false;
      final streamController = StreamController<ImageStreamChunk>();
      final service = KritaBridgeService(
        readBaseParams: () => const ImageParams(),
        send: (_) {},
        isUiGenerating: () => false,
        generateStream: (_) => streamController.stream,
        generateFallback: (_) async => const [],
        registerExternalImage: (_, {required params, addToDisplay}) async =>
            null,
        cancelGeneration: () {
          cancelCalled = true;
        },
      );

      final generation = service.handle(
        KritaImg2ImgMessage(
          id: 'img-5',
          image: Uint8List.fromList([1]),
          prompt: '',
          negativePrompt: '',
          strength: 0.5,
          noise: 0.0,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      service.handleClientDisconnected();

      expect(cancelCalled, isTrue);
      await streamController.close();
      await generation;
    });
  });
}

void expectNoSensitiveBridgeData(Map<String, dynamic> message) {
  const forbiddenFragments = [
    'token',
    'access_key',
    'accesskey',
    'api_key',
    'apikey',
    'account',
    'endpoint',
    'base_url',
    'baseurl',
    'cookie',
    'session',
    'pst-',
    'bearer ',
  ];

  void check(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        for (final fragment in forbiddenFragments) {
          expect(
            key,
            isNot(contains(fragment)),
            reason: 'Bridge payload leaked sensitive key: ${entry.key}',
          );
        }
        check(entry.value);
      }
      return;
    }

    if (value is Iterable) {
      for (final item in value) {
        check(item);
      }
      return;
    }

    if (value is String) {
      final lower = value.toLowerCase();
      for (final fragment in forbiddenFragments) {
        expect(
          lower,
          isNot(contains(fragment)),
          reason: 'Bridge payload leaked sensitive text.',
        );
      }
    }
  }

  check(message);
}

Uint8List _solidPng(int width, int height, int r, int g, int b) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _maskPng(int width, int height, List<(int, int)> points) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 255));
  for (final (x, y) in points) {
    image.setPixelRgba(x, y, 255, 255, 255, 255);
  }
  return Uint8List.fromList(img.encodePng(image));
}

ImageGenerationArtifact _inpaintArtifact(
  Uint8List source,
  Uint8List mask,
  Uint8List generated,
) {
  return ImageGenerationArtifact(
    displayImageBytes: InpaintMaskUtils.compositeGeneratedImage(
      sourceImage: source,
      maskImage: mask,
      generatedImage: generated,
    ),
    transparentPatchBytes: InpaintMaskUtils.extractGeneratedPatch(
      maskImage: mask,
      generatedImage: generated,
    ),
  );
}
