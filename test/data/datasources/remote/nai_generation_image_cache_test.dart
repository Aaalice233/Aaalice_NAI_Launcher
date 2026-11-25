import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_generation_transport.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_upload_cache.dart';

import '../../../helpers/browser_multipart_reader.dart';

const String _directorField = 'director_reference_images_cached';
const String _vibeField = 'reference_image_multiple_cached';

final String _reference = base64Encode(Uint8List.fromList([1, 2, 3, 4]));
final String _otherReference = base64Encode(Uint8List.fromList([5, 6, 7]));
final String _sourceImage = base64Encode(Uint8List.fromList([8, 9, 10]));
final String _maskImage = base64Encode(Uint8List.fromList([11, 12, 13]));
final String _legacyReference = base64Encode(Uint8List.fromList([14, 15]));
final String _firstVibe = base64Encode(Uint8List.fromList([16, 17, 18]));
final String _secondVibe = base64Encode(Uint8List.fromList([19, 20, 21]));

void main() {
  late _ScriptedAdapter adapter;
  late NaiApiEndpointService endpointService;
  late NaiGenerationTransport transport;
  String? credential;

  setUp(() {
    adapter = _ScriptedAdapter();
    endpointService = NaiApiEndpointService();
    credential = 'pst-first-account';
    transport = NaiGenerationTransport(
      Dio()..httpClientAdapter = adapter,
      endpointService,
      NaiImageUploadCache(() async => credential),
    );
  });

  Future<void> sendZip(Map<String, dynamic> requestData) async {
    final request = transport.beginRequest();
    try {
      await transport.sendZip(requestData, request);
    } finally {
      transport.completeRequest(request);
    }
  }

  Future<Response<ResponseBody>> sendStream(Map<String, dynamic> requestData) {
    final request = transport.beginRequest();
    return transport
        .sendStream(requestData, request)
        .whenComplete(() => transport.completeRequest(request));
  }

  group('reuse of uploaded images', () {
    test('sends a reference uploaded earlier as its cache key alone', () async {
      adapter.queue([_ok(), _ok()]);

      await sendZip(_directorRequest([_reference]));
      await sendZip(_directorRequest([_reference]));

      final [first, second] = adapter.sent;
      final key = first.keysOf(_directorField).single;
      expect(first.imagePartNames, ['director_ref_0']);
      expect(first.entriesOf(_directorField).single, {
        'cache_secret_key': key,
        'data': 'director_ref_0',
      });
      expect(second.imagePartNames, isEmpty);
      expect(second.entriesOf(_directorField).single, {
        'cache_secret_key': key,
      });
      expect(second.body.length, lessThan(first.body.length));
    });

    test('applies the same rule to every image field', () async {
      adapter.queue([_ok(), _ok()]);

      await sendZip(_everyFieldRequest());
      await sendZip(_everyFieldRequest());

      final [first, second] = adapter.sent;
      expect(first.imagePartNames, [
        'image',
        'mask',
        'reference_image',
        'ref_multiple_0',
        'ref_multiple_1',
        'director_ref_0',
      ]);
      expect(second.imagePartNames, isEmpty);

      final parameters = second.parameters;
      for (final field in ['image', 'mask', 'reference_image']) {
        expect(parameters.containsKey(field), isFalse, reason: field);
        expect(
          parameters['${field}_cache_secret_key'],
          first.parameters['${field}_cache_secret_key'],
          reason: field,
        );
      }
      for (final field in [_vibeField, _directorField]) {
        expect(
          second.entriesOf(field).map((entry) => entry.keys.toList()),
          everyElement(['cache_secret_key']),
          reason: field,
        );
        expect(second.keysOf(field), first.keysOf(field), reason: field);
      }
    });

    test('keeps a repeated image of one request in a single part', () async {
      adapter.queue([_ok()]);

      await sendZip(<String, dynamic>{
        'input': 'repeated vibe',
        'parameters': <String, dynamic>{
          'reference_image_multiple': [_firstVibe, _secondVibe, _firstVibe],
        },
      });

      final sent = adapter.sent.single;
      expect(sent.imagePartNames, ['ref_multiple_0', 'ref_multiple_1']);
      expect(sent.entriesOf(_vibeField).map((entry) => entry['data']), [
        'ref_multiple_0',
        'ref_multiple_1',
        'ref_multiple_0',
      ]);
    });

    test('uploads a different image even after another was cached', () async {
      adapter.queue([_ok(), _ok()]);

      await sendZip(_directorRequest([_reference]));
      await sendZip(_directorRequest([_otherReference]));

      final [first, second] = adapter.sent;
      expect(second.imagePartNames, ['director_ref_0']);
      expect(
        second.keysOf(_directorField),
        isNot(first.keysOf(_directorField)),
      );
    });

    test('uploads again under a new key after switching account', () async {
      adapter.queue([_ok(), _ok(), _ok()]);

      await sendZip(_directorRequest([_reference]));
      credential = 'pst-second-account';
      await sendZip(_directorRequest([_reference]));
      credential = 'pst-first-account';
      await sendZip(_directorRequest([_reference]));

      final [first, switched, switchedBack] = adapter.sent;
      expect(switched.imagePartNames, ['director_ref_0']);
      expect(
        switched.keysOf(_directorField),
        isNot(first.keysOf(_directorField)),
      );
      expect(switchedBack.imagePartNames, ['director_ref_0']);
    });

    test('third-party endpoints always carry the image bytes', () async {
      endpointService.setCurrent(
        NaiApiEndpointConfig.fromInput(mainBaseUrl: 'https://relay.example'),
      );
      adapter.queue([_ok(), _ok()]);

      await sendZip(_directorRequest([_reference]));
      await sendZip(_directorRequest([_reference]));

      expect(
        adapter.sent.map((sent) => sent.imagePartNames),
        everyElement(['director_ref_0']),
      );
    });

    test('carries the image bytes when no credential is stored', () async {
      credential = null;
      adapter.queue([_ok(), _ok()]);

      await sendZip(_directorRequest([_reference]));
      await sendZip(_directorRequest([_reference]));

      expect(
        adapter.sent.map((sent) => sent.imagePartNames),
        everyElement(['director_ref_0']),
      );
    });

    test(
      'carries the image bytes when the credential cannot be read',
      () async {
        transport = NaiGenerationTransport(
          Dio()..httpClientAdapter = adapter,
          endpointService,
          NaiImageUploadCache(() => Future.error(StateError('locked'))),
        );
        adapter.queue([_ok(), _ok()]);

        await sendZip(_directorRequest([_reference]));
        await sendZip(_directorRequest([_reference]));

        expect(
          adapter.sent.map((sent) => sent.imagePartNames),
          everyElement(['director_ref_0']),
        );
      },
    );
  });

  group('server cache misses', () {
    test('resends only the dropped image, once', () async {
      adapter.queue([_ok()]);
      await sendZip(_directorRequest([_reference, _otherReference]));
      final keys = adapter.sent.single.keysOf(_directorField);

      adapter.queue([
        _invalidCacheKeys([keys.first]),
        _ok(),
      ]);
      await sendZip(_directorRequest([_reference, _otherReference]));

      expect(adapter.sent, hasLength(3));
      final [_, miss, resend] = adapter.sent;
      expect(miss.imagePartNames, isEmpty);
      expect(resend.imagePartNames, ['director_ref_0']);
      expect(resend.entriesOf(_directorField), [
        {'cache_secret_key': keys.first, 'data': 'director_ref_0'},
        {'cache_secret_key': keys.last},
      ]);

      adapter.queue([_ok()]);
      await sendZip(_directorRequest([_reference, _otherReference]));
      expect(adapter.sent.last.imagePartNames, isEmpty);
    });

    test('reports a second miss instead of resending again', () async {
      adapter.queue([_ok()]);
      await sendZip(_directorRequest([_reference]));
      final key = adapter.sent.single.keysOf(_directorField).single;

      adapter.queue([
        _invalidCacheKeys([key]),
        _invalidCacheKeys([key]),
      ]);
      await expectLater(
        sendZip(_directorRequest([_reference])),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'status',
            400,
          ),
        ),
      );
      expect(adapter.sent, hasLength(3));

      adapter.queue([_ok()]);
      await sendZip(_directorRequest([_reference]));
      expect(adapter.sent.last.imagePartNames, ['director_ref_0']);
    });

    test(
      'does not resend when the reported keys were already carried',
      () async {
        adapter.queue([
          _invalidCacheKeys(['0' * 64]),
        ]);

        await expectLater(
          sendZip(_directorRequest([_reference])),
          throwsA(isA<DioException>()),
        );
        expect(adapter.sent, hasLength(1));
      },
    );

    test('resends a streamed request after a miss', () async {
      adapter.queue([_ok()]);
      await sendStream(_directorRequest([_reference]));
      final key = adapter.sent.single.keysOf(_directorField).single;

      adapter.queue([
        _invalidCacheKeys([key]),
        _ok(),
      ]);
      final response = await sendStream(_directorRequest([_reference]));

      expect(response.statusCode, 200);
      expect(adapter.sent, hasLength(3));
      expect(adapter.sent.last.imagePartNames, ['director_ref_0']);
    });
  });

  group('rejected requests', () {
    test('a rejected request does not count as an upload', () async {
      adapter.queue([
        _json(400, {'statusCode': 400, 'message': 'prompt too long'}),
        _ok(),
      ]);

      await expectLater(
        sendZip(_directorRequest([_reference])),
        throwsA(isA<DioException>()),
      );
      await sendZip(_directorRequest([_reference]));

      expect(
        adapter.sent.map((sent) => sent.imagePartNames),
        everyElement(['director_ref_0']),
      );
    });

    test('other failures keep the upload record like the web client', () async {
      adapter.queue([
        _json(429, {'statusCode': 429, 'message': 'concurrent generation'}),
        _ok(),
      ]);

      await expectLater(
        sendZip(_directorRequest([_reference])),
        throwsA(isA<DioException>()),
      );
      await sendZip(_directorRequest([_reference]));

      expect(adapter.sent.last.imagePartNames, isEmpty);
    });

    test('a streamed rejection body stays readable downstream', () async {
      adapter.queue([
        _json(400, {'statusCode': 400, 'message': 'prompt too long'}),
      ]);

      final error = await sendStream(_directorRequest([_reference]))
          .then<DioException?>(
            (_) => null,
            onError: (Object e) => e as DioException,
          );

      final body = error!.response!.data as ResponseBody;
      final text = await utf8.decodeStream(body.stream);
      expect(jsonDecode(text), containsPair('message', 'prompt too long'));
    });
  });
}

Map<String, dynamic> _directorRequest(List<String> references) =>
    <String, dynamic>{
      'input': 'precise reference',
      'model': 'nai-diffusion-4-5-full',
      'action': 'generate',
      'parameters': <String, dynamic>{
        'width': 832,
        'director_reference_images': references,
      },
      'use_new_shared_trial': true,
    };

Map<String, dynamic> _everyFieldRequest() => <String, dynamic>{
  'input': 'every field',
  'model': 'nai-diffusion-4-5-full',
  'action': 'infill',
  'parameters': <String, dynamic>{
    'image': _sourceImage,
    'mask': _maskImage,
    'reference_image': _legacyReference,
    'reference_image_multiple': [_firstVibe, _secondVibe],
    'director_reference_images': [_reference],
  },
  'use_new_shared_trial': true,
};

ResponseBody _ok() => ResponseBody.fromBytes(const [0x50, 0x4b], 200);

ResponseBody _json(int status, Map<String, Object?> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody _invalidCacheKeys(List<String> keys) => _json(400, {
  'statusCode': 400,
  'message': 'INVALID_CACHE_KEYS',
  'details': {'invalidKeys': keys},
});

class _SentRequest {
  _SentRequest(this.body, String contentType)
    : parts = parseBrowserMultipart(body, boundaryOf(contentType));

  final Uint8List body;
  final List<DecodedMultipartPart> parts;

  List<String> get imagePartNames => [
    for (final part in parts)
      if (part.name != 'request') part.name,
  ];

  Map<String, dynamic> get parameters {
    final request = parts.singleWhere((part) => part.name == 'request');
    final json = jsonDecode(request.text) as Map<String, dynamic>;
    return json['parameters'] as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> entriesOf(String field) =>
      (parameters[field] as List).cast<Map<String, dynamic>>();

  List<String> keysOf(String field) => [
    for (final entry in entriesOf(field)) entry['cache_secret_key'] as String,
  ];
}

class _ScriptedAdapter implements HttpClientAdapter {
  final List<ResponseBody> _responses = [];
  final List<_SentRequest> sent = [];

  void queue(List<ResponseBody> responses) => _responses.addAll(responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = BytesBuilder(copy: false);
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        body.add(chunk);
      }
    }
    sent.add(_SentRequest(body.takeBytes(), options.contentType!));
    if (_responses.isEmpty) {
      throw StateError('No scripted response for ${options.path}');
    }
    return _responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}
