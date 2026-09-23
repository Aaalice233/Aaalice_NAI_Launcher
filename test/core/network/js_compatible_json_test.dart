import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/js_compatible_json.dart';

void main() {
  group('encodeJsCompatibleJson', () {
    test('writes integral doubles as integers', () {
      expect(encodeJsCompatibleJson({'strength': 1.0}), '{"strength":1}');
      expect(encodeJsCompatibleJson({'noise': 0.0}), '{"noise":0}');
      expect(encodeJsCompatibleJson({'noise': -0.0}), '{"noise":0}');
      expect(encodeJsCompatibleJson({'scale': -3.0}), '{"scale":-3}');
    });

    test('keeps fractional doubles untouched', () {
      expect(encodeJsCompatibleJson({'strength': 0.7}), '{"strength":0.7}');
      expect(encodeJsCompatibleJson({'noise': 0.1}), '{"noise":0.1}');
      expect(encodeJsCompatibleJson([1.5, 2.0]), '[1.5,2]');
    });

    test('keeps doubles at or beyond the JS safe integer bound', () {
      expect(
        encodeJsCompatibleJson([9007199254740992.0]),
        '[9007199254740992.0]',
      );
      expect(encodeJsCompatibleJson([1e21]), '[1e+21]');
    });

    test('rewrites numbers nested in lists and maps', () {
      expect(
        encodeJsCompatibleJson({
          'reference_strength_multiple': [1.0, 0.6],
          'img2img': {'strength': 1.0, 'color_correct': true},
        }),
        '{"reference_strength_multiple":[1,0.6],'
        '"img2img":{"strength":1,"color_correct":true}}',
      );
    });

    test('preserves key insertion order', () {
      expect(
        encodeJsCompatibleJson({'z': 1.0, 'a': 2.0, 'm': 3.0}),
        '{"z":1,"a":2,"m":3}',
      );
    });

    test('leaves the source graph unmodified', () {
      final source = <String, dynamic>{
        'strength': 1.0,
        'nested': <String, dynamic>{'noise': 2.0},
      };

      encodeJsCompatibleJson(source);

      expect(source['strength'], isA<double>());
      expect((source['nested'] as Map)['noise'], isA<double>());
    });
  });

  test('JsCompatibleJsonTransformer encodes dio request bodies', () async {
    final transformer = JsCompatibleJsonTransformer();
    final options = RequestOptions(
      path: '/user/login',
      method: 'POST',
      headers: {'content-type': 'application/json'},
      data: {'key': 'abc', 'strength': 1.0},
    );

    expect(
      await transformer.transformRequest(options),
      '{"key":"abc","strength":1}',
    );
  });
}
