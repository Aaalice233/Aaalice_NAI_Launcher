import 'dart:io';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path/path.dart' as p;

/// 资产读取函数(测试注入用;默认 rootBundle.load)
typedef AssetBytesLoader = Future<ByteData> Function(String key);

/// 3D 编辑器本地 HTTP 服务
///
/// 只绑定 127.0.0.1;仅服务两类白名单路径:
/// - `/editor/<path>`      → Flutter assets `assets/model3d_editor/<path>`
/// - `/models/<64hex>.glb` → 模型库目录中的内容寻址文件
class LocalAssetServer {
  LocalAssetServer({
    AssetBytesLoader? assetLoader,
    Directory? modelLibraryDir,
  })  : _assetLoader = assetLoader ?? rootBundle.load,
        _modelLibraryDir = modelLibraryDir;

  static const _editorPrefix = '/editor/';
  static const _modelsPrefix = '/models/';
  static final _modelFileName = RegExp(r'^[a-f0-9]{64}\.glb$');
  static const _mimeByExtension = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.glb': 'model/gltf-binary',
    '.gltf': 'model/gltf+json',
    '.png': 'image/png',
  };

  final AssetBytesLoader _assetLoader;
  final Directory? _modelLibraryDir;
  HttpServer? _server;

  Uri get baseUri {
    final server = _server;
    if (server == null) {
      throw StateError('LocalAssetServer is not running');
    }
    return Uri.parse('http://127.0.0.1:${server.port}/');
  }

  Future<Uri> start() async {
    if (_server != null) return baseUri;
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen(_handleRequest);
        _server = server;
        return baseUri;
      } catch (e) {
        lastError = e;
      }
    }
    throw StateError('LocalAssetServer failed to bind: $lastError');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = Uri.decodeComponent(request.uri.path);
      if (request.method != 'GET' || path.contains('..')) {
        return _respond(request, HttpStatus.forbidden);
      }
      if (path.startsWith(_editorPrefix)) {
        return await _serveAsset(request, path.substring(_editorPrefix.length));
      }
      if (path.startsWith(_modelsPrefix)) {
        return await _serveModel(request, path.substring(_modelsPrefix.length));
      }
      return _respond(request, HttpStatus.notFound);
    } catch (_) {
      return _respond(request, HttpStatus.internalServerError);
    }
  }

  Future<void> _serveAsset(HttpRequest request, String relativePath) async {
    final ByteData data;
    try {
      data = await _assetLoader('assets/model3d_editor/$relativePath');
    } catch (_) {
      return _respond(request, HttpStatus.notFound);
    }
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = _contentTypeFor(relativePath)
      ..add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    await request.response.close();
  }

  Future<void> _serveModel(HttpRequest request, String fileName) async {
    final dir = _modelLibraryDir;
    if (dir == null || !_modelFileName.hasMatch(fileName)) {
      return _respond(request, HttpStatus.forbidden);
    }
    final file = File(p.join(dir.path, fileName));
    if (!await file.exists()) {
      return _respond(request, HttpStatus.notFound);
    }
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.parse('model/gltf-binary');
    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  ContentType _contentTypeFor(String path) {
    final mime = _mimeByExtension[p.extension(path).toLowerCase()];
    return mime != null ? ContentType.parse(mime) : ContentType.binary;
  }

  Future<void> _respond(HttpRequest request, int status) async {
    request.response.statusCode = status;
    await request.response.close();
  }
}
