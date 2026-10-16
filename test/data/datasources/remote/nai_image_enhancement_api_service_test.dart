import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/core/network/critical_network_activity.dart';
import 'package:nai_launcher/core/network/dio_client.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint_service.dart';

import '../../../helpers/browser_multipart_reader.dart';
import '../../../helpers/exif_orientation_fixture.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  test('provider uses the HTTP/1.1 image generation client', () async {
    final generationDio = _MockDio();
    final generalDio = _MockDio();
    final container = ProviderContainer(
      overrides: [
        imageGenerationDioClientProvider.overrideWithValue(generationDio),
        dioClientProvider.overrideWithValue(generalDio),
      ],
    );
    addTearDown(container.dispose);

    final service = container.read(naiImageEnhancementApiServiceProvider);
    when(
      () => generationDio.post<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
        onReceiveProgress: any(named: 'onReceiveProgress'),
      ),
    ).thenThrow(StateError('stop after routing'));

    await expectLater(
      service.upscaleImage(_buildPng(width: 8, height: 8), scale: 2),
      throwsA(isA<StateError>()),
    );
    verify(
      () => generationDio.post<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
        onReceiveProgress: any(named: 'onReceiveProgress'),
      ),
    ).called(1);
    verifyZeroInteractions(generalDio);
  });

  group('NAIImageEnhancementApiService', () {
    test('upscaleImage should send the v2 body to the image host', () async {
      final dio = _MockDio();
      final sourceImage = _buildPng(width: 48, height: 32);
      final zipBytes = _buildZipWithSingleImage(sourceImage);
      final capture = _RequestCapture();
      String? capturedUrl;

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer((invocation) async {
        capturedUrl = invocation.positionalArguments.first as String;
        capture.record(invocation);
        return Response<dynamic>(
          data: zipBytes,
          requestOptions: RequestOptions(path: '/ai/upscale'),
        );
      });

      final service = NAIImageEnhancementApiService(dio);
      final result = await service.upscaleImage(sourceImage, scale: 2);

      final parts = capture.parts;
      final request = capture.requestJson;

      expect(result, isNotEmpty);
      expect(capturedUrl, contains('image.novelai.net'));
      expect(
        parts.map((part) => part.name),
        orderedEquals(['image', 'request']),
      );
      expect(parts.first.filename, 'blob');
      expect(parts.first.contentType, 'image/png');
      expect(parts.first.bytes, sourceImage);
      expect(parts.last.filename, 'blob');
      expect(parts.last.contentType, 'application/json');
      expect(
        request.keys,
        orderedEquals(['image', 'model', 'declared_blur_sigma']),
      );
      expect(request['image'], equals('image'));
      expect(request['model'], equals('nai-diffusion-5-curated'));
      expect(request['declared_blur_sigma'], equals(0));
      expect(capture.options.headers, isNull);
    });

    test(
      'upscaleImage should fall back with a 2x legacy body on 422',
      () async {
        final dio = _MockDio();
        final sourceImage = _buildPng(width: 48, height: 32);
        final zipBytes = _buildZipWithSingleImage(sourceImage);
        final capturedBodies = <Object?>[];
        final capturedUrls = <String>[];

        when(
          () => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).thenAnswer((invocation) async {
          capturedUrls.add(invocation.positionalArguments.first as String);
          capturedBodies.add(invocation.namedArguments[#data]);
          if (capturedBodies.length == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/ai/upscale'),
              response: Response<dynamic>(
                statusCode: 422,
                requestOptions: RequestOptions(path: '/ai/upscale'),
              ),
              type: DioExceptionType.badResponse,
            );
          }
          return Response<dynamic>(
            data: zipBytes,
            requestOptions: RequestOptions(path: '/ai/upscale'),
          );
        });

        final service = NAIImageEnhancementApiService(dio);
        final result = await service.upscaleImage(sourceImage);

        expect(result, isNotEmpty);
        expect(capturedBodies, hasLength(2));
        expect(capturedBodies.first, isA<Uint8List>());
        final legacyBody = Map<String, dynamic>.from(
          capturedBodies.last! as Map,
        );
        expect(legacyBody['scale'], equals(2));
        expect(legacyBody['width'], equals(48));
        expect(legacyBody['height'], equals(32));
        expect(capturedUrls.last, contains('api.novelai.net'));
      },
    );

    test('upscaleImage should not retry on billing errors', () async {
      final dio = _MockDio();
      final sourceImage = _buildPng(width: 48, height: 32);
      var callCount = 0;

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer((invocation) async {
        callCount++;
        throw DioException(
          requestOptions: RequestOptions(path: '/ai/upscale'),
          response: Response<dynamic>(
            statusCode: 402,
            requestOptions: RequestOptions(path: '/ai/upscale'),
          ),
          type: DioExceptionType.badResponse,
        );
      });

      final service = NAIImageEnhancementApiService(dio);

      await expectLater(
        () => service.upscaleImage(sourceImage),
        throwsA(isA<Exception>()),
      );
      // 计费类错误直接抛出，绝不能换格式重试造成二次扣费。
      expect(callCount, 1);
    });

    test(
      'should send director tool parameters in the official order',
      () async {
        final dio = _MockDio();
        final sourceImage = _buildPng(width: 48, height: 32);
        final zipBytes = _buildZipWithSingleImage(sourceImage);
        final capture = _RequestCapture();

        when(
          () => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          capture.record(invocation);
          return Response<dynamic>(
            data: zipBytes,
            requestOptions: RequestOptions(path: '/augment-image'),
          );
        });

        final service = NAIImageEnhancementApiService(dio);
        final result = await service.removeBackground(sourceImage);
        final request = capture.requestJson;

        expect(result, isNotEmpty);
        expect(
          capture.parts.map((part) => part.name),
          orderedEquals(['image', 'request']),
        );
        expect(capture.parts.first.bytes, sourceImage);
        expect(
          request.keys,
          orderedEquals([
            'req_type',
            'use_new_shared_trial',
            'width',
            'height',
            'image',
          ]),
        );
        expect(request['req_type'], equals('bg-removal'));
        expect(request['use_new_shared_trial'], isTrue);
        expect(request['width'], equals(48));
        expect(request['height'], equals(32));
        expect(request['image'], equals('image'));
        expect(capture.options.headers, isNull);
      },
    );

    test('director prompt sits before defry like the web client', () async {
      final dio = _MockDio();
      final sourceImage = _buildPng(width: 16, height: 16);
      final zipBytes = _buildZipWithSingleImage(sourceImage);
      final capture = _RequestCapture();

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        capture.record(invocation);
        return Response<dynamic>(
          data: zipBytes,
          requestOptions: RequestOptions(path: '/augment-image'),
        );
      });

      await NAIImageEnhancementApiService(
        dio,
      ).colorize(sourceImage, prompt: 'blue eyes', defry: 3);

      expect(
        capture.requestJson.keys,
        orderedEquals([
          'req_type',
          'use_new_shared_trial',
          'prompt',
          'defry',
          'width',
          'height',
          'image',
        ]),
      );
      expect(capture.requestJson['defry'], equals(3));
    });

    test('encodeVibe should send information_extracted to API', () async {
      final dio = _MockDio();
      final sourceImage = _buildPng(width: 32, height: 32);
      final capture = _RequestCapture();

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        capture.record(invocation);
        return Response<dynamic>(
          data: Uint8List.fromList(const [1, 2, 3]),
          requestOptions: RequestOptions(path: '/encode-vibe'),
        );
      });

      final service = NAIImageEnhancementApiService(dio);
      final result = await service.encodeVibe(
        sourceImage,
        model: 'nai-diffusion-4-5-full',
        informationExtracted: 0.35,
      );
      final request = capture.requestJson;

      expect(result, isNotEmpty);
      expect(
        capture.parts.map((part) => part.name),
        orderedEquals(['image', 'request']),
      );
      expect(capture.parts.first.bytes, sourceImage);
      expect(
        request.keys,
        orderedEquals(['image', 'information_extracted', 'model']),
      );
      expect(request['image'], equals('image'));
      expect(request['model'], equals('nai-diffusion-4-5-full'));
      expect(request['information_extracted'], equals(0.35));
      expect(request.containsKey('informationExtracted'), isFalse);
    });

    test(
      'critical network lease covers transport and releases on error',
      () async {
        final dio = _MockDio();
        final activity = CriticalNetworkActivityCoordinator();
        final response = Completer<Response<dynamic>>();
        when(
          () => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) => response.future);
        final service = NAIImageEnhancementApiService(
          dio,
          NaiApiEndpointService(),
          activity,
        );

        final request = service.encodeVibe(
          _buildPng(width: 8, height: 8),
          model: 'nai-diffusion-4-5-full',
          informationExtracted: 1,
        );
        await Future<void>.delayed(Duration.zero);
        expect(activity.isActive, isTrue);
        expect(activity.activeTypes, {
          CriticalNetworkActivityType.vibeEncoding,
        });

        response.completeError(
          DioException(requestOptions: RequestOptions(path: '/encode-vibe')),
        );
        await expectLater(request, throwsA(isA<Exception>()));
        expect(activity.isActive, isFalse);
      },
    );

    test('cloud upscale uses its own critical network activity type', () async {
      final dio = _MockDio();
      final activity = CriticalNetworkActivityCoordinator();
      final response = Completer<Response<dynamic>>();
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer((_) => response.future);
      final service = NAIImageEnhancementApiService(
        dio,
        NaiApiEndpointService(),
        activity,
      );

      final request = service.upscaleImage(_buildPng(width: 8, height: 8));
      await Future<void>.delayed(Duration.zero);
      expect(activity.activeTypes, {CriticalNetworkActivityType.cloudUpscale});

      response.completeError(
        DioException(
          requestOptions: RequestOptions(path: '/upscale'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/upscale'),
            statusCode: 500,
          ),
        ),
      );
      await expectLater(request, throwsA(isA<Exception>()));
      expect(activity.isActive, isFalse);
    });

    test(
      'legacy upscale fallback holds the lease until its request settles',
      () async {
        for (final succeeds in [true, false]) {
          final dio = _MockDio();
          final activity = CriticalNetworkActivityCoordinator();
          final legacyResponse = Completer<Response<dynamic>>();
          var calls = 0;
          when(
            () => dio.post<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            ),
          ).thenAnswer((_) {
            calls++;
            if (calls == 1) {
              return Future.error(
                DioException(
                  requestOptions: RequestOptions(path: '/ai/upscale'),
                  response: Response<dynamic>(
                    statusCode: 404,
                    requestOptions: RequestOptions(path: '/ai/upscale'),
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            }
            return legacyResponse.future;
          });
          final service = NAIImageEnhancementApiService(
            dio,
            NaiApiEndpointService(),
            activity,
          );

          final request = service.upscaleImage(_buildPng(width: 8, height: 8));
          await pumpEventQueue();
          expect(calls, 2, reason: 'succeeds=$succeeds');
          expect(activity.activeTypes, {
            CriticalNetworkActivityType.cloudUpscale,
          }, reason: 'succeeds=$succeeds');

          if (succeeds) {
            legacyResponse.complete(
              Response<dynamic>(
                data: _buildZipWithSingleImage(
                  _buildPng(width: 16, height: 16),
                ),
                requestOptions: RequestOptions(path: '/ai/upscale'),
              ),
            );
            expect(await request, isNotEmpty);
          } else {
            legacyResponse.completeError(
              DioException(
                requestOptions: RequestOptions(path: '/ai/upscale'),
                response: Response<dynamic>(
                  statusCode: 500,
                  requestOptions: RequestOptions(path: '/ai/upscale'),
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            await expectLater(request, throwsA(isA<Exception>()));
          }
          expect(activity.isActive, isFalse, reason: 'succeeds=$succeeds');
        }
      },
    );

    test(
      'director tools send the decoded size for oriented jpeg and gif sources',
      () async {
        final cases = [
          (_buildOrientedJpeg(orientation: 6), (4, 6)),
          (
            Uint8List.fromList(img.encodeGif(img.Image(width: 20, height: 12))),
            (20, 12),
          ),
        ];

        for (final (source, size) in cases) {
          final decoded = img.decodeImage(source)!;
          final request = await _directorRequestFor(source);

          expect((decoded.width, decoded.height), size);
          expect((request['width'], request['height']), size);
        }
      },
    );

    test('legacy upscale sends the decoded size of an oriented jpeg', () async {
      final dio = _MockDio();
      final zipBytes = _buildZipWithSingleImage(_buildPng(width: 8, height: 8));
      final capturedBodies = <Object?>[];
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer((invocation) async {
        capturedBodies.add(invocation.namedArguments[#data]);
        if (capturedBodies.length == 1) {
          throw DioException(
            requestOptions: RequestOptions(path: '/ai/upscale'),
            response: Response<dynamic>(
              statusCode: 404,
              requestOptions: RequestOptions(path: '/ai/upscale'),
            ),
            type: DioExceptionType.badResponse,
          );
        }
        return Response<dynamic>(
          data: zipBytes,
          requestOptions: RequestOptions(path: '/ai/upscale'),
        );
      });
      final source = _buildOrientedJpeg(orientation: 8);

      await NAIImageEnhancementApiService(dio).upscaleImage(source);

      final legacyBody = Map<String, dynamic>.from(capturedBodies.last! as Map);
      expect(legacyBody['width'], 4);
      expect(legacyBody['height'], 6);
    });

    test('oriented jpeg uploads are sent as the png they display as', () async {
      final source = _buildOrientedJpeg(orientation: 6);
      final uploads = await _multipartUploadsFor(source);

      for (final MapEntry(key: endpoint, value: upload) in uploads.entries) {
        final sent = img.decodePng(upload.image);
        expect(sent, isNotNull, reason: endpoint);
        expect((sent!.width, sent.height), (4, 6), reason: endpoint);
      }
      final director = uploads['augment-image']!.request;
      expect((director['width'], director['height']), (4, 6));
    });

    test('legacy upscale sends an oriented jpeg as a png', () async {
      final body = await _legacyUpscaleBodyFor(
        _buildOrientedJpeg(orientation: 8),
      );

      final sent = img.decodePng(base64Decode(body['image'] as String))!;
      expect((sent.width, sent.height), (body['width'], body['height']));
      expect((sent.width, sent.height), (4, 6));
    });

    test('webp uploads carry the displayed pixels', () async {
      for (final orientation in [1, 2, 3, 4, 5, 6, 7, 8]) {
        final source = orientedCameraWebp(orientation: orientation);
        final size = orientation >= 5 ? (14, 20) : (20, 14);
        final displayed = displayedWebp(source, orientation);
        final uploads = await _multipartUploadsFor(source);
        final legacy = await _legacyUpscaleBodyFor(source);
        final sentImages = {
          for (final MapEntry(key: endpoint, value: upload) in uploads.entries)
            endpoint: upload.image,
          'legacy upscale': base64Decode(legacy['image'] as String),
        };

        for (final MapEntry(key: endpoint, value: sent) in sentImages.entries) {
          final reason = 'orientation $orientation $endpoint';
          if (orientation == 1) {
            expect(sent, source, reason: reason);
            continue;
          }
          final png = img.decodePng(sent);
          expect(png, isNotNull, reason: reason);
          expect((png!.width, png.height), size, reason: reason);
          expect(
            png.getBytes(order: img.ChannelOrder.rgb),
            displayed.getBytes(order: img.ChannelOrder.rgb),
            reason: reason,
          );
        }
        final director = uploads['augment-image']!.request;
        expect((director['width'], director['height']), size);
        expect((legacy['width'], legacy['height']), size);
      }
    });

    test('unrotated uploads keep their exact bytes', () async {
      final cases = <String, Uint8List>{
        'jpeg orientation 1': _buildOrientedJpeg(orientation: 1),
        'png': _buildPng(width: 6, height: 4),
        'webp': _webpLossless,
      };

      for (final MapEntry(key: name, value: source) in cases.entries) {
        final uploads = await _multipartUploadsFor(source);
        for (final MapEntry(key: endpoint, value: upload) in uploads.entries) {
          expect(upload.image, source, reason: '$name $endpoint');
        }
        final legacy = await _legacyUpscaleBodyFor(source);
        expect(legacy['image'], base64Encode(source), reason: name);
      }
    });

    test('undecodable director sources keep the size error', () async {
      final service = NAIImageEnhancementApiService(_MockDio());
      final source = Uint8List.fromList(utf8.encode('not an image at all'));
      expect(img.decodeImage(source), isNull);

      await expectLater(
        service.declutter(source),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('无法解析图像尺寸'),
          ),
        ),
      );
    });

    test('director lease releases when local validation fails', () async {
      final activity = CriticalNetworkActivityCoordinator();
      final service = NAIImageEnhancementApiService(
        _MockDio(),
        NaiApiEndpointService(),
        activity,
      );

      await expectLater(
        service.augmentImage(Uint8List(0), reqType: 'bg-removal'),
        throwsA(isA<RangeError>()),
      );
      expect(activity.isActive, isFalse);
    });
  });
}

Uint8List _buildPng({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  return Uint8List.fromList(img.encodePng(image));
}

Future<Map<String, dynamic>> _directorRequestFor(Uint8List source) async {
  final dio = _MockDio();
  final capture = _RequestCapture();
  final zipBytes = _buildZipWithSingleImage(_buildPng(width: 8, height: 8));
  when(
    () => dio.post<dynamic>(
      any(),
      data: any(named: 'data'),
      options: any(named: 'options'),
    ),
  ).thenAnswer((invocation) async {
    capture.record(invocation);
    return Response<dynamic>(
      data: zipBytes,
      requestOptions: RequestOptions(path: '/augment-image'),
    );
  });

  await NAIImageEnhancementApiService(dio).declutter(source);
  return capture.requestJson;
}

typedef _Upload = ({Uint8List image, Map<String, dynamic> request});

/// 依次调用 v2 放大、导演工具与 Vibe 编码，按端点记录上传的图片分块。
Future<Map<String, _Upload>> _multipartUploadsFor(Uint8List source) async {
  final dio = _MockDio();
  final uploads = <String, _Upload>{};
  final zipBytes = _buildZipWithSingleImage(_buildPng(width: 8, height: 8));
  Future<Response<dynamic>> answer(Invocation invocation) async {
    final url = invocation.positionalArguments.first as String;
    final capture = _RequestCapture()..record(invocation);
    uploads[url.split('/').last] = (
      image: capture.parts.firstWhere((part) => part.name == 'image').bytes,
      request: capture.requestJson,
    );
    return Response<dynamic>(
      data: zipBytes,
      requestOptions: RequestOptions(path: url),
    );
  }

  when(
    () => dio.post<dynamic>(
      any(),
      data: any(named: 'data'),
      options: any(named: 'options'),
    ),
  ).thenAnswer(answer);
  when(
    () => dio.post<dynamic>(
      any(),
      data: any(named: 'data'),
      options: any(named: 'options'),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  ).thenAnswer(answer);

  final service = NAIImageEnhancementApiService(dio);
  await service.upscaleImage(source);
  await service.declutter(source);
  await service.encodeVibe(source, model: 'nai-diffusion-4-5-full');
  expect(
    uploads.keys,
    unorderedEquals(['upscale', 'augment-image', 'encode-vibe']),
  );
  return uploads;
}

Future<Map<String, dynamic>> _legacyUpscaleBodyFor(Uint8List source) async {
  final dio = _MockDio();
  final bodies = <Object?>[];
  when(
    () => dio.post<dynamic>(
      any(),
      data: any(named: 'data'),
      options: any(named: 'options'),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  ).thenAnswer((invocation) async {
    bodies.add(invocation.namedArguments[#data]);
    if (bodies.length == 1) {
      throw DioException(
        requestOptions: RequestOptions(path: '/ai/upscale'),
        response: Response<dynamic>(
          statusCode: 404,
          requestOptions: RequestOptions(path: '/ai/upscale'),
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return Response<dynamic>(
      data: _buildZipWithSingleImage(_buildPng(width: 8, height: 8)),
      requestOptions: RequestOptions(path: '/ai/upscale'),
    );
  });

  await NAIImageEnhancementApiService(dio).upscaleImage(source);
  return Map<String, dynamic>.from(bodies.last! as Map);
}

final _webpLossless = base64Decode(
  'UklGRqAAAABXRUJQVlA4TJQAAAAvE0ADALkyRPQ/FgrSNmC6419vpZhp28b8Ebfdjuh//CUC'
  'gEEjSYrqSQH617p0EhS3bePGmFx79WMUSZLi+Ebk8Yvxdx6YJFxMAOGaVt4jYOUS3RKsMPhm'
  'JIIJEyqwAwNK8ECyAPfQYkXeIGEBAIVto8UCABfAbebs4ATAXzkF+FEcULLiAwANBxB2ALwg'
  '1Xr3AwAS',
);

Uint8List _buildOrientedJpeg({required int orientation}) {
  final image = img.Image(width: 6, height: 4)
    ..exif.imageIfd.orientation = orientation;
  return Uint8List.fromList(img.encodeJpg(image));
}

Uint8List _buildZipWithSingleImage(Uint8List imageBytes) {
  final archive = Archive()
    ..addFile(ArchiveFile('result.png', imageBytes.length, imageBytes));
  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded!);
}

/// 收集一次 `dio.post` 调用的 multipart 请求体与 Options。
class _RequestCapture {
  late final Uint8List body;
  late final Options options;

  void record(Invocation invocation) {
    body = invocation.namedArguments[#data] as Uint8List;
    options = invocation.namedArguments[#options] as Options;
  }

  List<DecodedMultipartPart> get parts =>
      parseBrowserMultipart(body, boundaryOf(options.contentType!));

  Map<String, dynamic> get requestJson =>
      jsonDecode(parts.firstWhere((part) => part.name == 'request').text)
          as Map<String, dynamic>;
}
