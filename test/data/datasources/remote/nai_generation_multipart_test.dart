import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/browser_multipart_body.dart';
import 'package:nai_launcher/data/datasources/remote/nai_generation_transport.dart';

import '../../../helpers/browser_multipart_reader.dart';

const String _transportSourcePath =
    'lib/data/datasources/remote/nai_generation_transport.dart';

final String _sourceImage = base64Encode(Uint8List.fromList([1, 2, 3, 4]));
final String _maskImage = base64Encode(Uint8List.fromList([5, 6, 7, 8]));
final String _referenceImage = base64Encode(Uint8List.fromList([9, 10, 11]));
final String _firstVibe = base64Encode(Uint8List.fromList([12, 13, 14]));
final String _secondVibe = base64Encode(Uint8List.fromList([15, 16, 17]));
final String _directorImage = base64Encode(Uint8List.fromList([18, 19, 20]));

void main() {
  test('leaves the caller request graph and payload strings untouched', () {
    final requestData = _buildRequest();
    final parameters = requestData['parameters'] as Map<String, dynamic>;
    final vibes = parameters['reference_image_multiple'] as List<String>;
    final directors = parameters['director_reference_images'] as List<String>;
    final snapshot = jsonEncode(requestData);

    NaiGenerationTransport.buildGenerationMultipart(requestData);

    expect(jsonEncode(requestData), snapshot);
    expect(identical(requestData['parameters'], parameters), isTrue);
    expect(identical(parameters['reference_image_multiple'], vibes), isTrue);
    expect(
      identical(parameters['director_reference_images'], directors),
      isTrue,
    );
    expect(identical(requestData['image'], _sourceImage), isTrue);
    expect(identical(requestData['mask'], _maskImage), isTrue);
    expect(identical(parameters['image'], _sourceImage), isTrue);
    expect(identical(parameters['mask'], _maskImage), isTrue);
    expect(identical(parameters['reference_image'], _referenceImage), isTrue);
    expect(identical(vibes[0], _firstVibe), isTrue);
    expect(identical(vibes[1], _secondVibe), isTrue);
    expect(identical(directors[0], _directorImage), isTrue);
    expect(parameters.containsKey('image_cache_secret_key'), isFalse);
    expect(parameters.containsKey('reference_image_multiple_cached'), isFalse);
    expect(parameters.containsKey('director_reference_images_cached'), isFalse);
  });

  test('keeps image part order, payload dedup and the request json', () {
    final parts = _parts(
      NaiGenerationTransport.buildGenerationMultipart(_buildRequest()),
    );

    expect(
      parts.map((part) => part.name),
      orderedEquals([
        'image',
        'mask',
        'reference_image',
        'ref_multiple_0',
        'ref_multiple_1',
        'director_ref_0',
        'request',
      ]),
    );

    final byName = {for (final part in parts) part.name: part};
    expect(byName['image']!.bytes, base64Decode(_sourceImage));
    expect(byName['mask']!.bytes, base64Decode(_maskImage));
    expect(byName['reference_image']!.bytes, base64Decode(_referenceImage));
    expect(byName['ref_multiple_0']!.bytes, base64Decode(_firstVibe));
    expect(byName['ref_multiple_1']!.bytes, base64Decode(_secondVibe));
    expect(byName['director_ref_0']!.bytes, base64Decode(_directorImage));
    expect(byName['image']!.filename, 'blob');
    expect(byName['image']!.contentType, 'image/png');
    expect(byName['request']!.filename, 'blob');
    expect(byName['request']!.contentType, 'application/json');

    final requestJson = byName['request']!.text;
    expect(_withMaskedCacheKeys(requestJson), _expectedRequestJson);

    final request = jsonDecode(requestJson) as Map<String, dynamic>;
    final parameters = request['parameters'] as Map<String, dynamic>;
    final cachedVibes =
        parameters['reference_image_multiple_cached'] as List<dynamic>;
    final cachedDirectors =
        parameters['director_reference_images_cached'] as List<dynamic>;

    expect(parameters['image_cache_secret_key'], matches(r'^[0-9a-f]{64}$'));
    expect(
      cachedVibes[0]['cache_secret_key'],
      cachedVibes[2]['cache_secret_key'],
    );
    expect(
      cachedVibes[0]['cache_secret_key'],
      isNot(cachedVibes[1]['cache_secret_key']),
    );
    expect(
      cachedDirectors[1]['cache_secret_key'],
      cachedVibes[0]['cache_secret_key'],
    );
  });

  test('writes integral doubles the way the web client does', () {
    final request = _requestJson(
      NaiGenerationTransport.buildGenerationMultipart(<String, dynamic>{
        'input': 'numbers',
        'parameters': <String, dynamic>{
          'strength': 1.0,
          'noise': 0.0,
          'reference_strength_multiple': <double>[1.0, 0.6],
        },
      }),
    );

    expect(
      request,
      '{"input":"numbers","parameters":{"strength":1,"noise":0,'
      '"reference_strength_multiple":[1,0.6]}}',
    );
  });

  test('uses a fresh WebKit boundary for every request', () {
    final first = NaiGenerationTransport.buildGenerationMultipart(
      _buildRequest(),
    );
    final second = NaiGenerationTransport.buildGenerationMultipart(
      _buildRequest(),
    );

    expect(
      first.boundary,
      matches(r'^----WebKitFormBoundary[A-Za-z0-9]{16}$'),
    );
    expect(first.contentType, 'multipart/form-data; boundary=${first.boundary}');
    expect(first.boundary, isNot(second.boundary));
  });

  test('encodes the same request map identically on every call', () {
    final requestData = _buildRequest();

    final first = _requestJson(
      NaiGenerationTransport.buildGenerationMultipart(requestData),
    );
    final second = _requestJson(
      NaiGenerationTransport.buildGenerationMultipart(requestData),
    );

    expect(second, first);
  });

  test('extracts images from dynamically typed parameter containers', () {
    final body = NaiGenerationTransport.buildGenerationMultipart(
      <String, dynamic>{
        'input': 'dynamic containers',
        'parameters': <dynamic, dynamic>{
          'image': _sourceImage,
          'reference_image_multiple': <dynamic>[_firstVibe],
        },
      },
    );

    expect(
      _parts(body).map((part) => part.name),
      orderedEquals(['image', 'ref_multiple_0', 'request']),
    );
    final request = jsonDecode(_requestJson(body)) as Map<String, dynamic>;
    final parameters = request['parameters'] as Map<String, dynamic>;
    final cachedVibes =
        parameters['reference_image_multiple_cached'] as List<dynamic>;

    expect(parameters['image'], 'image');
    expect(parameters['image_cache_secret_key'], matches(r'^[0-9a-f]{64}$'));
    expect(cachedVibes.single['data'], 'ref_multiple_0');
  });

  test('rejects parameter containers that are not keyed by strings', () {
    expect(
      () => NaiGenerationTransport.buildGenerationMultipart(<String, dynamic>{
        'input': 'invalid keys',
        'parameters': <dynamic, dynamic>{1: _sourceImage},
      }),
      throwsArgumentError,
    );
  });

  test('builds the multipart request without a json round trip', () {
    final source = File(_transportSourcePath).readAsStringSync();

    expect(source, isNot(contains('jsonDecode(jsonEncode(')));
    expect(source, isNot(contains('json.decode(json.encode(')));
  });
}

Map<String, dynamic> _buildRequest() => <String, dynamic>{
  'input': 'fixture',
  'model': 'nai-diffusion-4-5-full',
  'action': 'infill',
  'image': _sourceImage,
  'mask': _maskImage,
  'parameters': <String, dynamic>{
    'width': 832,
    'image': _sourceImage,
    'mask': _maskImage,
    'reference_image': _referenceImage,
    'reference_image_multiple': <String>[_firstVibe, _secondVibe, _firstVibe],
    'reference_strength_multiple': <double>[0.6, 0.7, 0.6],
    'director_reference_images': <String>[_directorImage, _firstVibe],
  },
  'use_new_shared_trial': true,
};

const String _expectedRequestJson =
    '{"input":"fixture","model":"nai-diffusion-4-5-full","action":"infill",'
    '"image":"image","mask":"mask","parameters":{"width":832,"image":"image",'
    '"mask":"mask","reference_image":"reference_image",'
    '"reference_strength_multiple":[0.6,0.7,0.6],'
    '"image_cache_secret_key":"<cache-key>",'
    '"mask_cache_secret_key":"<cache-key>",'
    '"reference_image_cache_secret_key":"<cache-key>",'
    '"reference_image_multiple_cached":['
    '{"cache_secret_key":"<cache-key>","data":"ref_multiple_0"},'
    '{"cache_secret_key":"<cache-key>","data":"ref_multiple_1"},'
    '{"cache_secret_key":"<cache-key>","data":"ref_multiple_0"}],'
    '"director_reference_images_cached":['
    '{"cache_secret_key":"<cache-key>","data":"director_ref_0"},'
    '{"cache_secret_key":"<cache-key>","data":"ref_multiple_0"}]},'
    '"use_new_shared_trial":true}';

String _withMaskedCacheKeys(String requestJson) =>
    requestJson.replaceAll(RegExp('[0-9a-f]{64}'), '<cache-key>');

List<DecodedMultipartPart> _parts(BrowserMultipartBody body) =>
    parseBrowserMultipart(body.bytes, body.boundary);

String _requestJson(BrowserMultipartBody body) =>
    _parts(body).firstWhere((part) => part.name == 'request').text;
