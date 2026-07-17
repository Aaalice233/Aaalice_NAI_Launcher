import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/model3d_editor/local_asset_server.dart';

void main() {
  late Directory tempDir;
  late LocalAssetServer server;

  Future<ByteData> fakeAssets(String key) async {
    if (key == 'assets/model3d_editor/editor.html') {
      return ByteData.sublistView(
        Uint8List.fromList(utf8.encode('<html>ok</html>')),
      );
    }
    throw FlutterError('asset not found: $key');
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('model3d_test');
    server = LocalAssetServer(
      assetLoader: fakeAssets,
      modelLibraryDir: tempDir,
    );
  });

  tearDown(() async {
    await server.stop();
    await tempDir.delete(recursive: true);
  });

  Future<HttpClientResponse> get(Uri base, String path) async {
    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.getUrl(base.resolve(path));
    return request.close();
  }

  test('serves editor asset with html mime', () async {
    final base = await server.start();
    final response = await get(base, 'editor/editor.html');
    expect(response.statusCode, 200);
    expect(response.headers.contentType?.mimeType, 'text/html');
    expect(await utf8.decodeStream(response), '<html>ok</html>');
  });

  test('404 for unknown asset', () async {
    final base = await server.start();
    final response = await get(base, 'editor/missing.js');
    expect(response.statusCode, 404);
  });

  test('403 for path traversal', () async {
    final base = await server.start();
    final response = await get(base, 'editor/..%2Fsecret.txt');
    expect(response.statusCode, 403);
  });

  test('serves model file from library dir', () async {
    final hash = 'a' * 64;
    await File('${tempDir.path}/$hash.glb').writeAsBytes([1, 2, 3]);
    final base = await server.start();
    final response = await get(base, 'models/$hash.glb');
    expect(response.statusCode, 200);
    expect(response.headers.contentType?.mimeType, 'model/gltf-binary');
    expect((await response.toList()).expand((c) => c).toList(), [1, 2, 3]);
  });

  test('403 for non content-addressed model filename', () async {
    final base = await server.start();
    final response = await get(base, 'models/evil.glb');
    expect(response.statusCode, 403);
  });

  test('404 for missing model', () async {
    final base = await server.start();
    final response = await get(base, 'models/${'b' * 64}.glb');
    expect(response.statusCode, 404);
  });

  test('start is idempotent and binds loopback', () async {
    final base1 = await server.start();
    final base2 = await server.start();
    expect(base1, base2);
    expect(base1.host, '127.0.0.1');
  });
}
