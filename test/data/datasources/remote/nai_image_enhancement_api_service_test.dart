import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/core/network/critical_network_activity.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint_service.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  group('NAIImageEnhancementApiService', () {
    test('upscaleImage should send the v2 body to the image host', () async {
      final dio = _MockDio();
      final sourceImage = _buildPng(width: 48, height: 32);
      final zipBytes = _buildZipWithSingleImage(sourceImage);
      FormData? capturedData;
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
        capturedData = invocation.namedArguments[#data] as FormData;
        return Response<dynamic>(
          data: zipBytes,
          requestOptions: RequestOptions(path: '/ai/upscale'),
        );
      });

      final service = NAIImageEnhancementApiService(dio);
      final result = await service.upscaleImage(sourceImage, scale: 2);

      final parts = {
        for (final entry in capturedData!.files) entry.key: entry.value,
      };
      final request =
          jsonDecode(utf8.decode(await _readMultipartFile(parts['request']!)))
              as Map<String, dynamic>;

      expect(result, isNotEmpty);
      expect(capturedUrl, contains('image.novelai.net'));
      expect(parts.keys, unorderedEquals(['image', 'request']));
      expect(parts['image']!.filename, 'blob');
      expect(parts['image']!.contentType.toString(), 'image/png');
      expect(await _readMultipartFile(parts['image']!), sourceImage);
      expect(parts['request']!.filename, 'blob');
      expect(parts['request']!.contentType.toString(), 'application/json');
      expect(request['image'], equals('image'));
      expect(request['model'], equals('nai-diffusion-5-curated'));
      expect(request['declared_blur_sigma'], equals(0));
      expect(request.containsKey('scale'), isFalse);
      expect(request.containsKey('width'), isFalse);
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
        expect(capturedBodies.first, isA<FormData>());
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
      'should send source image width and height for director tools',
      () async {
        final dio = _MockDio();
        final sourceImage = _buildPng(width: 48, height: 32);
        final zipBytes = _buildZipWithSingleImage(sourceImage);
        Map<String, dynamic>? capturedData;

        when(
          () => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          capturedData = Map<String, dynamic>.from(
            invocation.namedArguments[#data] as Map,
          );
          return Response<dynamic>(
            data: zipBytes,
            requestOptions: RequestOptions(path: '/augment-image'),
          );
        });

        final service = NAIImageEnhancementApiService(dio);
        final result = await service.removeBackground(sourceImage);

        expect(result, isNotEmpty);
        expect(capturedData?['req_type'], equals('bg-removal'));
        expect(capturedData?['width'], equals(48));
        expect(capturedData?['height'], equals(32));
      },
    );

    test('encodeVibe should send information_extracted to API', () async {
      final dio = _MockDio();
      final sourceImage = _buildPng(width: 32, height: 32);
      Map<String, dynamic>? capturedData;

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        capturedData = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
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

      expect(result, isNotEmpty);
      expect(capturedData?['model'], equals('nai-diffusion-4-5-full'));
      expect(capturedData?['information_extracted'], equals(0.35));
      expect(capturedData?.containsKey('informationExtracted'), isFalse);
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

Uint8List _buildZipWithSingleImage(Uint8List imageBytes) {
  final archive = Archive()
    ..addFile(ArchiveFile('result.png', imageBytes.length, imageBytes));
  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded!);
}

Future<Uint8List> _readMultipartFile(MultipartFile file) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.finalize()) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}
