import 'dart:io';
import 'dart:typed_data';

import 'mcp_origin_policy.dart';
import 'mcp_token_generator.dart';

typedef McpImageDisplayPublisher =
    McpImageDisplayLink? Function(
      Uint8List bytes, {
      required String mimeType,
      required bool metadataStripped,
    });

class McpImageDisplayLink {
  const McpImageDisplayLink(this.url, this.expiresAt);

  final Uri url;
  final DateTime expiresAt;
}

/// Capability URLs expose only prepared image bytes, never filesystem paths.
/// This is separate from authenticated MCP RPCs: an HTML img cannot add Bearer.
class McpImageHttpEndpoint {
  McpImageHttpEndpoint({
    DateTime Function()? clock,
    bool Function()? requiresStrippedMetadata,
    this.lifetime = const Duration(hours: 1),
    this.maxBytes = 128 * 1024 * 1024,
    this.maxEntries = 64,
  }) : _clock = clock ?? DateTime.now,
       _requiresStrippedMetadata = requiresStrippedMetadata ?? (() => false);

  static const pathPrefix = '/mcp/images/';
  static const _extensions = {
    'image/png': 'png',
    'image/jpeg': 'jpg',
    'image/webp': 'webp',
    'image/gif': 'gif',
  };

  final DateTime Function() _clock;
  final bool Function() _requiresStrippedMetadata;
  final Duration lifetime;
  final int maxBytes;
  final int maxEntries;
  final _entries = <String, _DisplayImage>{};
  Uri? _endpoint;
  int _byteCount = 0;

  void start(Uri endpoint) {
    stop();
    _endpoint = endpoint;
  }

  void stop() {
    _endpoint = null;
    _entries.clear();
    _byteCount = 0;
  }

  void prune() {
    final now = _clock();
    final strip = _requiresStrippedMetadata();
    for (final key in _entries.keys.toList(growable: false)) {
      final entry = _entries[key]!;
      if (!now.isBefore(entry.expiresAt) ||
          (strip && !entry.metadataStripped)) {
        _remove(key);
      }
    }
  }

  McpImageDisplayLink? publish(
    Uint8List bytes, {
    required String mimeType,
    required bool metadataStripped,
  }) {
    final endpoint = _endpoint;
    final extension = _extensions[mimeType];
    if (endpoint == null ||
        extension == null ||
        bytes.isEmpty ||
        bytes.length > maxBytes ||
        maxEntries < 1) {
      return null;
    }
    prune();
    if (_requiresStrippedMetadata() && !metadataStripped) return null;
    while (_entries.length >= maxEntries ||
        _byteCount + bytes.length > maxBytes) {
      _remove(_entries.keys.first);
    }
    final path = '$pathPrefix${generateMcpServerToken()}.$extension';
    final expiresAt = _clock().add(lifetime).toUtc();
    final snapshot = Uint8List.fromList(bytes);
    _entries[path] = _DisplayImage(
      snapshot,
      mimeType,
      metadataStripped,
      expiresAt,
    );
    _byteCount += snapshot.length;
    return McpImageDisplayLink(endpoint.replace(path: path), expiresAt);
  }

  bool matches(HttpRequest request) => request.uri.path.startsWith(pathPrefix);

  Future<void> handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store, private')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer');
    final endpoint = _endpoint;
    final host = request.headers.value(HttpHeaders.hostHeader);
    // Exact authority prevents DNS rebinding and cross-port confused deputies.
    if (endpoint == null ||
        host != endpoint.authority ||
        request.connectionInfo?.remoteAddress.isLoopback != true) {
      response.statusCode = HttpStatus.forbidden;
      return response.close();
    }
    final origin = request.headers.value('origin');
    // Electron file-based renderers use the opaque "null" origin. The random
    // per-image capability remains required, including for these requests.
    if (origin != 'null' && !McpOriginPolicy.allows(origin)) {
      response.statusCode = HttpStatus.forbidden;
      return response.close();
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
      response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
      return response.close();
    }
    prune();
    final entry = request.uri.hasQuery ? null : _entries[request.uri.path];
    if (entry == null) {
      response.statusCode = HttpStatus.notFound;
      return response.close();
    }
    if (origin != null && origin.isNotEmpty) {
      response.headers
        ..set('Access-Control-Allow-Origin', origin)
        ..set(HttpHeaders.varyHeader, 'Origin');
    }
    response.headers
      ..contentType = ContentType.parse(entry.mimeType)
      ..set(
        'Content-Disposition',
        'inline; filename="image.${_extensions[entry.mimeType]}"',
      );
    response.contentLength = entry.bytes.length;
    if (request.method == 'GET') response.add(entry.bytes);
    await response.close();
  }

  void _remove(String key) {
    final removed = _entries.remove(key);
    if (removed != null) _byteCount -= removed.bytes.length;
  }
}

class _DisplayImage {
  const _DisplayImage(
    this.bytes,
    this.mimeType,
    this.metadataStripped,
    this.expiresAt,
  );

  final Uint8List bytes;
  final String mimeType;
  final bool metadataStripped;
  final DateTime expiresAt;
}
