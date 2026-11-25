import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/nai_api_endpoint.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/app_logger.dart';

/// Reads the credential the next generation request is sent with.
typedef NaiCredentialReader = Future<String?> Function();

/// Generation images one credential has already sent to the image server.
///
/// Each scope owns a random HMAC key, so a cache key means nothing outside this
/// process and the same image gets unrelated keys under different accounts.
class NaiImageCacheScope {
  NaiImageCacheScope() : _hmac = crypto.Hmac(crypto.sha256, _randomKey());

  final crypto.Hmac _hmac;
  final Set<String> _uploadedKeys = {};

  /// Hashes the base64 text itself, matching the web client.
  String secretKeyFor(String encodedImage) =>
      _hmac.convert(utf8.encode(encodedImage)).toString();

  bool isUploaded(String secretKey) => _uploadedKeys.contains(secretKey);

  void recordUploads(Iterable<String> secretKeys) =>
      _uploadedKeys.addAll(secretKeys);

  void forgetUploads(Iterable<String> secretKeys) =>
      _uploadedKeys.removeAll(secretKeys);

  static Uint8List _randomKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }
}

/// Keeps the upload record of the credential currently sending requests.
///
/// Switching account or endpoint starts an empty scope, so the first request
/// under the new credential carries every image again.
class NaiImageUploadCache {
  NaiImageUploadCache(this._readCredential);

  final NaiCredentialReader _readCredential;
  String? _scopeFingerprint;
  NaiImageCacheScope? _scope;

  /// Returns null when the request must carry the bytes of every image.
  Future<NaiImageCacheScope?> scopeFor(NaiApiEndpointConfig endpoint) async {
    // 中转站未必原样转发 INVALID_CACHE_KEYS，只发键会让出图直接失败
    if (!endpoint.isOfficial) return null;
    final credential = await _tryReadCredential();
    if (credential == null || credential.isEmpty) return null;

    final fingerprint = crypto.sha256
        .convert(utf8.encode('${endpoint.imageBaseUrl}\n$credential'))
        .toString();
    if (fingerprint != _scopeFingerprint) {
      _scopeFingerprint = fingerprint;
      _scope = NaiImageCacheScope();
    }
    return _scope;
  }

  Future<String?> _tryReadCredential() async {
    try {
      return await _readCredential();
    } catch (error) {
      AppLogger.w(
        'Image upload cache disabled for this request: $error',
        'ImgGen',
      );
      return null;
    }
  }
}

final naiImageUploadCacheProvider = Provider<NaiImageUploadCache>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return NaiImageUploadCache(storage.getAccessToken);
});
