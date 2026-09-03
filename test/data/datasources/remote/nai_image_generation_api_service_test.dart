import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint_service.dart';
import 'package:nai_launcher/core/network/critical_network_activity.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/presentation/providers/generation/image_generation_service.dart';

import '../../../helpers/image_pixel_matchers.dart';

void main() {
  test(
    'encodes generation payloads with the official multipart layout',
    () async {
      final imageBytes = Uint8List.fromList([1, 2, 3, 4]);
      final maskBytes = Uint8List.fromList([5, 6, 7, 8]);
      final vibeBytes = Uint8List.fromList([9, 10, 11]);
      final directorBytes = Uint8List.fromList([12, 13, 14]);
      final formData = NAIImageGenerationApiService.buildGenerationFormData({
        'input': 'test',
        'model': ImageModels.animeDiffusionV5Curated,
        'action': 'infill',
        'parameters': {
          'image': base64Encode(imageBytes),
          'mask': base64Encode(maskBytes),
          'reference_image_multiple': [base64Encode(vibeBytes)],
          'director_reference_images': [base64Encode(directorBytes)],
        },
        'use_new_shared_trial': true,
      });

      expect(formData.fields, isEmpty);
      expect(
        formData.files.map((entry) => entry.key),
        orderedEquals([
          'image',
          'mask',
          'ref_multiple_0',
          'director_ref_0',
          'request',
        ]),
      );
      final parts = {
        for (final entry in formData.files) entry.key: entry.value,
      };
      final request =
          jsonDecode(utf8.decode(await _readMultipartFile(parts['request']!)))
              as Map<String, dynamic>;
      final parameters = request['parameters'] as Map<String, dynamic>;
      final cachedVibes =
          parameters['reference_image_multiple_cached'] as List<dynamic>;
      final cachedDirectors =
          parameters['director_reference_images_cached'] as List<dynamic>;

      expect(await _readMultipartFile(parts['image']!), imageBytes);
      expect(await _readMultipartFile(parts['mask']!), maskBytes);
      expect(await _readMultipartFile(parts['ref_multiple_0']!), vibeBytes);
      expect(await _readMultipartFile(parts['director_ref_0']!), directorBytes);
      expect(parts['request']!.filename, 'blob');
      expect(parts['request']!.contentType.toString(), 'application/json');
      expect(parts['image']!.filename, 'blob');
      expect(parts['image']!.contentType.toString(), 'image/png');
      expect(parameters['image'], 'image');
      expect(parameters['mask'], 'mask');
      expect(parameters['image_cache_secret_key'], matches(r'^[0-9a-f]{64}$'));
      expect(parameters['mask_cache_secret_key'], matches(r'^[0-9a-f]{64}$'));
      expect(parameters.containsKey('reference_image_multiple'), isFalse);
      expect(parameters.containsKey('director_reference_images'), isFalse);
      expect(cachedVibes.single['data'], 'ref_multiple_0');
      expect(
        cachedVibes.single['cache_secret_key'],
        matches(r'^[0-9a-f]{64}$'),
      );
      expect(cachedDirectors.single['data'], 'director_ref_0');
      expect(
        cachedDirectors.single['cache_secret_key'],
        matches(r'^[0-9a-f]{64}$'),
      );
    },
  );

  test('encodes text-only generation as one JSON multipart part', () async {
    final formData = NAIImageGenerationApiService.buildGenerationFormData({
      'input': 'test',
      'model': ImageModels.animeDiffusionV5Curated,
      'action': 'generate',
      'parameters': {'seed': 1},
      'use_new_shared_trial': true,
    });

    expect(formData.files, hasLength(1));
    expect(formData.files.single.key, 'request');
    expect(formData.files.single.value.filename, 'blob');
    expect(
      formData.files.single.value.contentType.toString(),
      'application/json',
    );
  });

  test('maps DDIM onto Euler Ancestral for every v4-structure model', () {
    // V5 之前的判定是 contains('diffusion-4')，V5 会漏掉并把 ddim 原样发出。
    for (final model in [
      ImageModels.animeDiffusionV4Full,
      ImageModels.animeDiffusionV45Full,
      ImageModels.animeDiffusionV5Curated,
      ImageModels.animeDiffusionV5Full,
    ]) {
      expect(
        NAIImageGenerationApiService.mapSamplerForModel(Samplers.ddim, model),
        Samplers.kEulerAncestral,
        reason: model,
      );
    }

    expect(
      NAIImageGenerationApiService.mapSamplerForModel(
        Samplers.ddim,
        ImageModels.animeDiffusionV3,
      ),
      Samplers.ddimV3,
    );
    expect(
      NAIImageGenerationApiService.mapSamplerForModel(
        Samplers.kEulerAncestral,
        ImageModels.animeDiffusionV5Curated,
      ),
      Samplers.kEulerAncestral,
    );
  });

  test('sends official transport headers with generation requests', () async {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );

    final generation = service.generateImage(
      const ImageParams(prompt: 'transport headers'),
    );
    await _waitForRequestCount(adapter, 1);
    final headers = adapter.requests.single.options.headers;

    expect(headers['Accept'], 'application/x-zip-compressed');
    expect(
      headers['x-correlation-id'],
      matches(r'^[A-Zabcdefghijkmnopqrstuvwxyz1-9]{6}$'),
    );
    expect(DateTime.tryParse(headers['x-initiated-at'] as String), isNotNull);
    expect(adapter.requests.single.options.data, isA<FormData>());

    adapter.requests.single.completeWithEmptyZip();
    await expectLater(generation, throwsA(isA<Exception>()));
  });

  test(
    'proxy multipart read timeout remains a failed generation and releases QoS',
    () async {
      final adapter = _PendingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final endpointService = NaiApiEndpointService();
      final networkActivity = CriticalNetworkActivityCoordinator();
      final service = NAIImageGenerationApiService(
        dio,
        NAIImageEnhancementApiService(dio, endpointService),
        endpointService,
        networkActivity,
      );

      final generation = service.generateImage(
        const ImageParams(prompt: 'slow multipart contract'),
      );
      await _waitForRequestCount(adapter, 1);
      expect(networkActivity.isActive, isTrue);
      adapter.requests.single.completeWithStatus(
        400,
        'failed to read multipart part: multipart: NextPart: '
        'read tcp 10.5.218.109:3000->10.4.100.238:50298: i/o timeout',
      );

      await expectLater(
        generation,
        throwsA(
          isA<DioException>().having(
            (error) {
              final data = error.response?.data;
              return data is List<int> ? utf8.decode(data) : data.toString();
            },
            'response body',
            contains('multipart: NextPart'),
          ),
        ),
      );
      expect(networkActivity.isActive, isFalse);
    },
  );

  test('generation retains its lease across nested vibe encoding', () async {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final networkActivity = CriticalNetworkActivityCoordinator();
    final enhancementService = NAIImageEnhancementApiService(
      dio,
      endpointService,
      networkActivity,
    );
    final service = NAIImageGenerationApiService(
      dio,
      enhancementService,
      endpointService,
      networkActivity,
    );

    final generation = service.generateImage(
      ImageParams(
        prompt: 'nested vibe lease',
        model: ImageModels.animeDiffusionV4Full,
        vibeReferencesV4: [
          VibeReference(
            displayName: 'raw',
            vibeEncoding: '',
            rawImageData: Uint8List.fromList(const [1, 2, 3]),
          ),
        ],
      ),
    );
    await _waitForRequestCount(adapter, 1);
    expect(networkActivity.activeTypes, {
      CriticalNetworkActivityType.imageGeneration,
      CriticalNetworkActivityType.vibeEncoding,
    });

    adapter.requests.single.response.complete(
      ResponseBody.fromBytes(const [4, 5, 6], 200),
    );
    await _waitForRequestCount(adapter, 2);
    expect(networkActivity.activeTypes, {
      CriticalNetworkActivityType.imageGeneration,
    });

    adapter.requests[1].completeWithEmptyZip();
    await expectLater(generation, throwsA(isA<Exception>()));
    expect(networkActivity.isActive, isFalse);
  });

  test('completed older request must not clear newer cancel token', () async {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );

    final first = service.generateImage(
      const ImageParams(prompt: 'first request'),
    );
    final firstHandled = first
        .then<Object?>((_) => null)
        .catchError((_) => null);
    await _waitForRequestCount(adapter, 1);

    final second = service.generateImage(
      const ImageParams(prompt: 'second request'),
    );
    final secondHandled = second
        .then<Object?>((_) => null)
        .catchError((_) => null);
    await _waitForRequestCount(adapter, 2);

    adapter.requests[0].completeWithEmptyZip();
    await firstHandled;

    service.cancelGeneration();

    expect(
      await adapter.requests[1].cancelledWithin(
        const Duration(milliseconds: 100),
      ),
      isTrue,
    );

    adapter.requests[1].completeWithError(
      DioException(
        requestOptions: adapter.requests[1].options,
        type: DioExceptionType.cancel,
      ),
    );
    await secondHandled;
  });

  test(
    'completed older stream request must not clear newer cancel token',
    () async {
      final adapter = _PendingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final endpointService = NaiApiEndpointService();
      final service = NAIImageGenerationApiService(
        dio,
        NAIImageEnhancementApiService(dio, endpointService),
        endpointService,
      );

      final first = service
          .generateImageStream(const ImageParams(prompt: 'first stream'))
          .drain<Object?>();
      final firstHandled = first
          .then<Object?>((_) => null)
          .catchError((_) => null);
      await _waitForRequestCount(adapter, 1);

      final second = service
          .generateImageStream(const ImageParams(prompt: 'second stream'))
          .drain<Object?>();
      final secondHandled = second
          .then<Object?>((_) => null)
          .catchError((_) => null);
      await _waitForRequestCount(adapter, 2);

      adapter.requests[0].completeWithError(
        DioException(
          requestOptions: adapter.requests[0].options,
          type: DioExceptionType.cancel,
        ),
      );
      await firstHandled;

      service.cancelGeneration();

      expect(
        await adapter.requests[1].cancelledWithin(
          const Duration(milliseconds: 100),
        ),
        isTrue,
      );

      adapter.requests[1].completeWithError(
        DioException(
          requestOptions: adapter.requests[1].options,
          type: DioExceptionType.cancel,
        ),
      );
      await secondHandled;
    },
  );

  test(
    'shared API keeps concurrent ImageGenerationService run cancellation isolated',
    () async {
      final adapter = _PendingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final endpointService = NaiApiEndpointService();
      final apiService = NAIImageGenerationApiService(
        dio,
        NAIImageEnhancementApiService(dio, endpointService),
        endpointService,
      );
      final serviceA = ImageGenerationService(apiService: apiService);
      final serviceB = ImageGenerationService(apiService: apiService);

      final runA = serviceA.generateSingle(
        const ImageParams(prompt: 'service run A'),
      );
      await _waitForRequestCount(adapter, 1);
      final runB = serviceB.generateSingle(
        const ImageParams(prompt: 'service run B'),
      );
      await _waitForRequestCount(adapter, 2);

      serviceA.cancel();

      expect(
        await adapter.requests[0].cancelledWithin(
          const Duration(milliseconds: 100),
        ),
        isTrue,
      );
      expect(
        await adapter.requests[1].cancelledWithin(
          const Duration(milliseconds: 100),
        ),
        isFalse,
      );

      adapter.requests[0].completeWithError(
        DioException(
          requestOptions: adapter.requests[0].options,
          type: DioExceptionType.cancel,
        ),
      );
      adapter.requests[1].completeWithMsgpackMessages([
        {
          'event_type': 'final',
          'samp_ix': 0,
          'image': Uint8List.fromList([9, 8, 7]),
        },
      ]);

      final resultA = await runA.timeout(const Duration(seconds: 1));
      final resultB = await runB.timeout(const Duration(seconds: 1));
      expect(resultA.isCancelled, isTrue);
      expect(resultB.isSuccess, isTrue);
    },
  );

  test(
    'scoped stream cancellation for run A does not cancel non-stream run B',
    () async {
      final adapter = _PendingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final endpointService = NaiApiEndpointService();
      final service = NAIImageGenerationApiService(
        dio,
        NAIImageEnhancementApiService(dio, endpointService),
        endpointService,
      );
      final leaseA = service.createCancellationLease();
      final leaseB = service.createCancellationLease();

      final runA = service
          .generateImageStream(
            const ImageParams(prompt: 'stream run A'),
            cancellationLease: leaseA,
          )
          .drain<Object?>();
      final handledA = runA.then<Object?>((_) => null).catchError((_) => null);
      await _waitForRequestCount(adapter, 1);
      final runB = service.generateImage(
        const ImageParams(prompt: 'non-stream run B'),
        cancellationLease: leaseB,
      );
      final handledB = runB.then<Object?>((_) => null).catchError((_) => null);
      await _waitForRequestCount(adapter, 2);

      service.cancelGeneration(leaseA);

      expect(
        await adapter.requests[0].cancelledWithin(
          const Duration(milliseconds: 100),
        ),
        isTrue,
      );
      expect(
        await adapter.requests[1].cancelledWithin(
          const Duration(milliseconds: 100),
        ),
        isFalse,
      );

      adapter.requests[0].completeWithError(
        DioException(
          requestOptions: adapter.requests[0].options,
          type: DioExceptionType.cancel,
        ),
      );
      adapter.requests[1].completeWithEmptyZip();
      await Future.wait([handledA, handledB]);
      service.releaseCancellationLease(leaseA);
      service.releaseCancellationLease(leaseB);
    },
  );

  test(
    'scoped non-stream cancellation for run A does not cancel stream run B',
    () async {
      final adapter = _PendingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final endpointService = NaiApiEndpointService();
      final service = NAIImageGenerationApiService(
        dio,
        NAIImageEnhancementApiService(dio, endpointService),
        endpointService,
      );
      final leaseA = service.createCancellationLease();
      final leaseB = service.createCancellationLease();

      final runA = service.generateImage(
        const ImageParams(prompt: 'non-stream run A'),
        cancellationLease: leaseA,
      );
      final handledA = runA.then<Object?>((_) => null).catchError((_) => null);
      await _waitForRequestCount(adapter, 1);
      final runB = service
          .generateImageStream(
            const ImageParams(prompt: 'stream run B'),
            cancellationLease: leaseB,
          )
          .toList();
      await _waitForRequestCount(adapter, 2);

      service.cancelGeneration(leaseA);

      expect(
        await adapter.requests[0].cancelledWithin(
          const Duration(milliseconds: 100),
        ),
        isTrue,
      );
      expect(
        await adapter.requests[1].cancelledWithin(
          const Duration(milliseconds: 100),
        ),
        isFalse,
      );

      adapter.requests[0].completeWithError(
        DioException(
          requestOptions: adapter.requests[0].options,
          type: DioExceptionType.cancel,
        ),
      );
      adapter.requests[1].completeWithEmptyStream();
      await handledA;
      await runB;
      service.releaseCancellationLease(leaseA);
      service.releaseCancellationLease(leaseB);
    },
  );

  test(
    'non-stream inpaint returns one display and transparent patch artifact',
    () async {
      final adapter = _PendingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final endpointService = NaiApiEndpointService();
      final service = NAIImageGenerationApiService(
        dio,
        NAIImageEnhancementApiService(dio, endpointService),
        endpointService,
      );
      final source = _solidPng(width: 256, height: 256, r: 10, g: 20, b: 30);
      final mask = _rectMaskPng(
        width: 256,
        height: 256,
        x: 112,
        y: 112,
        rectWidth: 32,
        rectHeight: 32,
      );
      final generated = _solidPng(
        width: 256,
        height: 256,
        r: 200,
        g: 210,
        b: 220,
      );

      final resultFuture = service.generateImageArtifactsCancellable(
        ImageParams(
          action: ImageGenerationAction.infill,
          model: 'nai-diffusion-4-5-full-inpainting',
          width: 256,
          height: 256,
          sourceImage: source,
          maskImage: mask,
        ),
      );
      await _waitForRequestCount(adapter, 1);
      adapter.requests.single.completeWithZipImage(generated);

      final artifacts = await resultFuture.timeout(const Duration(seconds: 2));
      expect(artifacts, hasLength(1));
      final display = img.decodeImage(artifacts.single.displayImageBytes)!;
      final patch = img.decodeImage(artifacts.single.transparentPatchBytes!)!;
      final reconstructed = img.decodeImage(source)!;
      img.compositeImage(reconstructed, patch, blend: img.BlendMode.alpha);

      expect((display.width, display.height), equals((256, 256)));
      expect((patch.width, patch.height), equals((256, 256)));
      expect(display.getPixel(0, 0).r.toInt(), equals(10));
      expect(display.getPixel(128, 128).r.toInt(), greaterThan(190));
      expect(patch.getPixel(0, 0).a.toInt(), equals(0));
      expect(patch.getPixel(128, 128).a.toInt(), equals(255));
      expectPixelsWithin(
        reconstructed,
        display,
        tolerance: inpaintQuantizationTolerance,
      );
    },
  );

  test('creating a stream without listening owns no active request', () {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );
    final lease = service.createCancellationLease();

    service.generateImageStream(
      const ImageParams(prompt: 'never listened'),
      cancellationLease: lease,
    );

    expect(lease.activeRequestCountForTesting, 0);
    expect(adapter.requests, isEmpty);
    service.releaseCancellationLease(lease);
  });

  test('scoped cancellation before listen must not start a request', () async {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );
    final lease = service.createCancellationLease();
    final stream = service.generateImageStream(
      const ImageParams(prompt: 'cancel before listen'),
      cancellationLease: lease,
    );

    service.cancelGeneration(lease);
    final chunks = await stream.toList().timeout(
      const Duration(milliseconds: 100),
    );

    expect(adapter.requests, isEmpty);
    expect(chunks, hasLength(1));
    expect(chunks.single.error, contains('Cancelled'));
    expect(lease.activeRequestCountForTesting, 0);
    service.releaseCancellationLease(lease);
  });

  test('legacy cancellation before listen must not start a request', () async {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );
    final stream = service.generateImageStream(
      const ImageParams(prompt: 'legacy cancel before listen'),
    );

    service.cancelGeneration();
    final chunks = await stream.toList().timeout(
      const Duration(milliseconds: 100),
    );

    expect(adapter.requests, isEmpty);
    expect(chunks, hasLength(1));
    expect(chunks.single.error, contains('Cancelled'));
  });

  test('stream completion releases its request-scoped lease', () async {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );
    final lease = service.createCancellationLease();

    final chunksFuture = service
        .generateImageStream(
          const ImageParams(prompt: 'normal cleanup'),
          cancellationLease: lease,
        )
        .toList();
    await _waitForRequestCount(adapter, 1);
    expect(lease.activeRequestCountForTesting, 1);

    adapter.requests.single.completeWithEmptyStream();
    await chunksFuture.timeout(const Duration(seconds: 2));

    expect(lease.activeRequestCountForTesting, 0);
    service.releaseCancellationLease(lease);
  });

  test('stream cancellation releases its request-scoped lease', () async {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );
    final lease = service.createCancellationLease();

    final chunksFuture = service
        .generateImageStream(
          const ImageParams(prompt: 'cancel cleanup'),
          cancellationLease: lease,
        )
        .toList();
    await _waitForRequestCount(adapter, 1);
    expect(lease.activeRequestCountForTesting, 1);

    service.cancelGeneration(lease);
    expect(
      await adapter.requests.single.cancelledWithin(
        const Duration(milliseconds: 100),
      ),
      isTrue,
    );
    adapter.requests.single.completeWithError(
      DioException(
        requestOptions: adapter.requests.single.options,
        type: DioExceptionType.cancel,
      ),
    );
    final chunks = await chunksFuture.timeout(const Duration(seconds: 2));

    expect(chunks, hasLength(1));
    expect(chunks.single.error, contains('Cancelled'));
    expect(lease.activeRequestCountForTesting, 0);
    service.releaseCancellationLease(lease);
  });

  test('stream completes only from final event image', () async {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );

    final chunksFuture = service
        .generateImageStream(const ImageParams(prompt: 'final'))
        .toList();
    await _waitForRequestCount(adapter, 1);

    final preview = Uint8List.fromList([1, 2, 3]);
    final finalImage = Uint8List.fromList([9, 8, 7]);
    adapter.requests.single.completeWithMsgpackMessages([
      {
        'event_type': 'intermediate',
        'samp_ix': 0,
        'step_ix': 0,
        'image': preview,
      },
      {'event_type': 'final', 'samp_ix': 0, 'image': finalImage},
    ]);

    final chunks = await chunksFuture.timeout(const Duration(seconds: 2));

    expect(chunks, hasLength(2));
    expect(chunks.first.hasPreview, isTrue);
    expect(chunks.first.sampleIndex, 0);
    expect(chunks.first.previewImage, orderedEquals(preview));
    expect(chunks.last.hasFinalImage, isTrue);
    expect(chunks.last.sampleIndex, 0);
    expect(chunks.last.finalImage, orderedEquals(finalImage));
  });

  test('stream ending without final event returns error', () async {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );

    final chunksFuture = service
        .generateImageStream(const ImageParams(prompt: 'missing final'))
        .toList();
    await _waitForRequestCount(adapter, 1);

    final preview = Uint8List.fromList([1, 2, 3]);
    adapter.requests.single.completeWithMsgpackMessages([
      {
        'event_type': 'intermediate',
        'samp_ix': 0,
        'step_ix': 0,
        'image': preview,
      },
    ]);

    final chunks = await chunksFuture.timeout(const Duration(seconds: 2));

    expect(chunks, hasLength(2));
    expect(chunks.first.previewImage, orderedEquals(preview));
    expect(chunks.last.hasError, isTrue);
    expect(chunks.last.error, contains('No final image'));
    expect(chunks.last.hasFinalImage, isFalse);
  });

  test('stream preserves sample indexes for multi-sample finals', () async {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );

    final chunksFuture = service
        .generateImageStream(const ImageParams(prompt: 'multi', nSamples: 2))
        .toList();
    await _waitForRequestCount(adapter, 1);

    final first = Uint8List.fromList([1]);
    final second = Uint8List.fromList([2]);
    adapter.requests.single.completeWithMsgpackMessages([
      {'event_type': 'final', 'samp_ix': 1, 'image': second},
      {'event_type': 'final', 'samp_ix': 0, 'image': first},
    ]);

    final chunks = await chunksFuture.timeout(const Duration(seconds: 2));

    expect(chunks, hasLength(2));
    expect(chunks[0].sampleIndex, 1);
    expect(chunks[0].finalImage, orderedEquals(second));
    expect(chunks[1].sampleIndex, 0);
    expect(chunks[1].finalImage, orderedEquals(first));
    expect(chunks.any((chunk) => chunk.hasError), isFalse);
  });

  test(
    'stream inpaint preview reuses full-frame artifacts and final composites',
    () async {
      final adapter = _PendingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final endpointService = NaiApiEndpointService();
      final service = NAIImageGenerationApiService(
        dio,
        NAIImageEnhancementApiService(dio, endpointService),
        endpointService,
      );

      final source = _solidPng(width: 256, height: 256, r: 10, g: 20, b: 30);
      final mask = _rectMaskPng(
        width: 256,
        height: 256,
        x: 120,
        y: 120,
        rectWidth: 16,
        rectHeight: 16,
      );
      final generated = _solidPng(
        width: 256,
        height: 256,
        r: 200,
        g: 210,
        b: 220,
      );

      final chunksFuture = service
          .generateImageStream(
            ImageParams(
              action: ImageGenerationAction.infill,
              model: 'nai-diffusion-4-5-full-inpainting',
              width: 256,
              height: 256,
              sourceImage: source,
              maskImage: mask,
            ),
          )
          .toList();
      await _waitForRequestCount(adapter, 1);

      adapter.requests.single.completeWithMsgpackMessages([
        {
          'event_type': 'intermediate',
          'samp_ix': 0,
          'step_ix': 0,
          'image': generated,
        },
        {'event_type': 'final', 'samp_ix': 0, 'image': generated},
      ]);

      final chunks = await chunksFuture.timeout(const Duration(seconds: 2));
      final placement = chunks.first.focusedPreviewPlacement;
      final decoded = img.decodeImage(chunks.last.finalImage!)!;

      expect(chunks, hasLength(2));
      expect(placement, isNotNull);
      expect(placement!.sourceImage, orderedEquals(source));
      expect(placement.hasMask, isTrue);
      expect(placement.xPercent, 0);
      expect(placement.yPercent, 0);
      expect(placement.widthPercent, 1);
      expect(placement.heightPercent, 1);
      final previewMask = img.decodeImage(placement.maskImage!)!;
      expect(previewMask.width, 256);
      expect(previewMask.height, 256);
      expect(previewMask.getPixel(0, 0).a.toInt(), 0);
      expect(previewMask.getPixel(128, 128).a.toInt(), greaterThan(250));

      expect(decoded.getPixel(0, 0).r.toInt(), equals(10));
      expect(decoded.getPixel(0, 0).g.toInt(), equals(20));
      expect(decoded.getPixel(0, 0).b.toInt(), equals(30));
      expect(decoded.getPixel(128, 128).r.toInt(), greaterThan(190));
      expect(decoded.getPixel(128, 128).g.toInt(), greaterThan(200));
      expect(decoded.getPixel(128, 128).b.toInt(), greaterThan(210));
    },
  );

  test('focused stream preview keeps raw crop and carries placement', () async {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );

    final source = _solidPng(width: 256, height: 256, r: 10, g: 20, b: 30);
    final mask = _rectMaskPng(
      width: 256,
      height: 256,
      x: 96,
      y: 96,
      rectWidth: 64,
      rectHeight: 64,
    );
    final previewCrop = _solidPng(
      width: 128,
      height: 128,
      r: 120,
      g: 130,
      b: 140,
    );
    final finalCrop = _solidPng(
      width: 128,
      height: 128,
      r: 220,
      g: 230,
      b: 240,
    );

    final chunksFuture = service
        .generateImageStream(
          ImageParams(
            action: ImageGenerationAction.infill,
            model: 'nai-diffusion-4-5-full-inpainting',
            width: 256,
            height: 256,
            sourceImage: source,
            maskImage: mask,
          ),
          focusedInpaintEnabled: true,
          minimumContextMegaPixels: 32,
          focusedSelectionRect: const Rect.fromLTWH(96, 96, 64, 64),
        )
        .toList();
    await _waitForRequestCount(adapter, 1);

    adapter.requests.single.completeWithMsgpackMessages([
      {
        'event_type': 'intermediate',
        'samp_ix': 0,
        'step_ix': 0,
        'image': previewCrop,
      },
      {'event_type': 'final', 'samp_ix': 0, 'image': finalCrop},
    ]);

    final chunks = await chunksFuture.timeout(const Duration(seconds: 2));
    final preview = chunks.first;
    final placement = preview.focusedPreviewPlacement;
    final decodedFinal = img.decodeImage(chunks.last.finalImage!)!;

    expect(chunks, hasLength(2));
    expect(preview.hasPreview, isTrue);
    expect(preview.previewImage, orderedEquals(previewCrop));
    expect(placement, isNotNull);
    expect(placement!.sourceImage, orderedEquals(source));
    expect(placement.hasMask, isTrue);
    final previewMask = img.decodeImage(placement.maskImage!)!;
    expect(previewMask.width, equals(1024));
    expect(previewMask.height, equals(1024));
    expect(previewMask.getPixel(0, 0).a.toInt(), equals(0));
    expect(previewMask.getPixel(512, 512).a.toInt(), equals(255));
    expect(placement.xPercent, closeTo(0.25, 0.001));
    expect(placement.yPercent, closeTo(0.25, 0.001));
    expect(placement.widthPercent, closeTo(0.5, 0.001));
    expect(placement.heightPercent, closeTo(0.5, 0.001));
    expect(decodedFinal.width, equals(256));
    expect(decodedFinal.height, equals(256));
    expect(decodedFinal.getPixel(0, 0).r.toInt(), equals(10));
    expect(decodedFinal.getPixel(128, 128).r.toInt(), greaterThan(210));
    expect(decodedFinal.getPixel(128, 128).g.toInt(), greaterThan(220));
    expect(decodedFinal.getPixel(128, 128).b.toInt(), greaterThan(230));
  });

  test('stream outpaint final preserves official raw service image', () async {
    final adapter = _PendingDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final endpointService = NaiApiEndpointService();
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );

    final source = _solidPng(width: 256, height: 256, r: 10, g: 20, b: 30);
    final mask = _rectMaskPng(
      width: 256,
      height: 256,
      x: 224,
      y: 0,
      rectWidth: 32,
      rectHeight: 256,
    );
    final generated = _solidPng(
      width: 256,
      height: 256,
      r: 200,
      g: 210,
      b: 220,
    );

    final chunksFuture = service
        .generateImageStream(
          ImageParams(
            action: ImageGenerationAction.infill,
            model: 'nai-diffusion-4-5-full-inpainting',
            width: 256,
            height: 256,
            sourceImage: source,
            maskImage: mask,
            isOutpaint: true,
          ),
        )
        .toList();
    await _waitForRequestCount(adapter, 1);

    adapter.requests.single.completeWithMsgpackMessages([
      {'event_type': 'final', 'samp_ix': 0, 'image': generated},
    ]);

    final chunks = await chunksFuture.timeout(const Duration(seconds: 2));
    final decoded = img.decodeImage(chunks.single.finalImage!)!;

    expect(decoded.getPixel(0, 0).r.toInt(), equals(200));
    expect(decoded.getPixel(0, 0).g.toInt(), equals(210));
    expect(decoded.getPixel(0, 0).b.toInt(), equals(220));
    expect(decoded.getPixel(240, 128).r.toInt(), equals(200));
    expect(decoded.getPixel(240, 128).g.toInt(), equals(210));
    expect(decoded.getPixel(240, 128).b.toInt(), equals(220));
  });

  test('cancelGeneration must abort the connection on the wire', () async {
    // 真实 socket 验证：取消必须让服务器观察到连接断开，
    // 否则 NovelAI 不会释放账号并发额度，后续请求持续 429。
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close());

    final requestReceived = Completer<void>();
    final connectionClosed = Completer<void>();
    server.listen((socket) {
      socket.listen(
        (_) {
          if (!requestReceived.isCompleted) requestReceived.complete();
        },
        onDone: () {
          if (!connectionClosed.isCompleted) connectionClosed.complete();
        },
        onError: (_) {
          if (!connectionClosed.isCompleted) connectionClosed.complete();
        },
      );
    });

    // 与 imageGenerationDioClient 一致：默认 HTTP/1.1 适配器
    final dio = Dio();
    final endpointService = NaiApiEndpointService()
      ..setCurrent(
        NaiApiEndpointConfig.fromInput(mainBaseUrl: '127.0.0.1:${server.port}'),
      );
    final service = NAIImageGenerationApiService(
      dio,
      NAIImageEnhancementApiService(dio, endpointService),
      endpointService,
    );

    final generation = service
        .generateImageStream(const ImageParams(prompt: 'abort on wire'))
        .drain<Object?>()
        .then<Object?>((_) => null)
        .catchError((_) => null);

    // 服务器已收到请求但故意不响应（模拟 NAI 正在排队出图）
    await requestReceived.future.timeout(const Duration(seconds: 10));
    expect(connectionClosed.isCompleted, isFalse);

    service.cancelGeneration();

    await connectionClosed.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => fail(
        'cancelGeneration() did not abort the connection: the server never '
        'observed a disconnect, so NovelAI would keep the per-account '
        'generation slot busy',
      ),
    );

    await generation;
  });
}

Future<void> _waitForRequestCount(
  _PendingDioAdapter adapter,
  int expectedCount,
) async {
  // 聚焦重绘等预处理已移入后台 isolate，请求发出前存在真实耗时；
  // 条件满足即返回，上限放宽不会拖慢通过路径。
  for (var attempt = 0; attempt < 500; attempt += 1) {
    if (adapter.requests.length >= expectedCount) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Expected $expectedCount request(s), got ${adapter.requests.length}.');
}

class _PendingDioAdapter implements HttpClientAdapter {
  final List<_PendingRequest> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final request = _PendingRequest(options, cancelFuture);
    requests.add(request);
    return request.response.future;
  }

  @override
  void close({bool force = false}) {}
}

Uint8List _solidPng({
  required int width,
  required int height,
  required int r,
  required int g,
  required int b,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _rectMaskPng({
  required int width,
  required int height,
  required int x,
  required int y,
  required int rectWidth,
  required int rectHeight,
}) {
  final mask = img.Image(width: width, height: height);
  img.fill(mask, color: img.ColorRgba8(0, 0, 0, 255));
  for (var py = y; py < y + rectHeight; py++) {
    for (var px = x; px < x + rectWidth; px++) {
      mask.setPixelRgba(px, py, 255, 255, 255, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(mask));
}

class _PendingRequest {
  _PendingRequest(this.options, Future<void>? cancelFuture) {
    cancelFuture?.then((_) {
      if (!_cancelled.isCompleted) {
        _cancelled.complete();
      }
    });
  }

  final RequestOptions options;
  final Completer<ResponseBody> response = Completer<ResponseBody>();
  final Completer<void> _cancelled = Completer<void>();

  Future<bool> cancelledWithin(Duration timeout) async {
    try {
      await _cancelled.future.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  void completeWithEmptyZip() {
    final bytes = ZipEncoder().encode(Archive()) ?? const <int>[];
    response.complete(
      ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          Headers.contentTypeHeader: ['application/x-zip-compressed'],
        },
      ),
    );
  }

  void completeWithZipImage(Uint8List imageBytes) {
    final archive = Archive()
      ..addFile(ArchiveFile('image.png', imageBytes.length, imageBytes));
    final bytes = ZipEncoder().encode(archive) ?? const <int>[];
    response.complete(
      ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          Headers.contentTypeHeader: ['application/x-zip-compressed'],
        },
      ),
    );
  }

  void completeWithEmptyStream() {
    response.complete(
      ResponseBody.fromBytes(
        const <int>[],
        200,
        headers: {
          Headers.contentTypeHeader: ['application/x-msgpack'],
        },
      ),
    );
  }

  void completeWithMsgpackMessages(List<Map<String, Object?>> messages) {
    final bytes = <int>[];
    for (final message in messages) {
      final encoded = msgpack.serialize(message);
      final length = encoded.length;
      bytes
        ..add((length >> 24) & 0xFF)
        ..add((length >> 16) & 0xFF)
        ..add((length >> 8) & 0xFF)
        ..add(length & 0xFF)
        ..addAll(encoded);
    }
    response.complete(
      ResponseBody.fromBytes(
        Uint8List.fromList(bytes),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/x-msgpack'],
        },
      ),
    );
  }

  void completeWithError(Object error) {
    response.completeError(error);
  }

  void completeWithStatus(int statusCode, String body) {
    response.complete(
      ResponseBody.fromString(
        body,
        statusCode,
        headers: {
          Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
        },
      ),
    );
  }
}

Future<Uint8List> _readMultipartFile(MultipartFile file) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.finalize()) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}
