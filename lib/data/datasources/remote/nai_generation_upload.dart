import 'dart:convert';

import '../../../core/network/browser_multipart_body.dart';
import '../../../core/network/js_compatible_json.dart';
import 'nai_image_upload_cache.dart';

/// One generation request with its images in the web client's cache layout.
///
/// With a scope, images that earlier requests uploaded travel as their
/// `cache_secret_key` alone; [restoreImages] puts their bytes back when the
/// server reports that it no longer holds them.
class NaiGenerationUpload {
  NaiGenerationUpload._(this._requestData, this._keyScope, this._reuseScope) {
    _layout = _layOut(omit: _reuseScope?.isUploaded ?? _carryEverything);
    _reuseScope?.recordUploads(_layout.carriedKeys);
  }

  /// Without [scope] every image carries its bytes and nothing is recorded.
  factory NaiGenerationUpload.prepare(
    Map<String, dynamic> requestData, {
    NaiImageCacheScope? scope,
  }) => NaiGenerationUpload._(requestData, scope ?? _detachedScope, scope);

  static final NaiImageCacheScope _detachedScope = NaiImageCacheScope();

  final Map<String, dynamic> _requestData;
  final NaiImageCacheScope _keyScope;
  final NaiImageCacheScope? _reuseScope;
  final Map<String, String> _secretKeys = {};
  late _CacheLayout _layout;

  /// Keys the image server reports missing, or null for any other rejection.
  static List<String>? invalidCacheKeysIn(Object? errorBody) {
    if (errorBody is! Map || errorBody['message'] != 'INVALID_CACHE_KEYS') {
      return null;
    }
    final details = errorBody['details'];
    final invalidKeys = details is Map ? details['invalidKeys'] : null;
    if (invalidKeys is! List) return null;
    return invalidKeys.whereType<String>().toList(growable: false);
  }

  /// Images that travel as their cache key alone.
  int get reusedImageCount => _layout.omittedKeys.length;

  /// Images whose bytes travel in the request.
  int get uploadedImageCount => _layout.carriedKeys.length;

  BrowserMultipartBody encode() => _encodeMultipart(_layout.request);

  /// Returns false when none of [invalidKeys] was sent without its bytes.
  bool restoreImages(Iterable<String> invalidKeys) {
    final reuseScope = _reuseScope;
    if (reuseScope == null) return false;
    final missingKeys = _layout.omittedKeys.intersection(invalidKeys.toSet());
    if (missingKeys.isEmpty) return false;
    final stillOmitted = _layout.omittedKeys.difference(missingKeys);
    _layout = _layOut(omit: stillOmitted.contains);
    reuseScope.recordUploads(missingKeys);
    return true;
  }

  /// A rejected request may not have left its images on the server.
  void forgetUploads() => _reuseScope?.forgetUploads(_layout.carriedKeys);

  static bool _carryEverything(String secretKey) => false;

  String _secretKeyFor(String encodedImage) => _secretKeys.putIfAbsent(
    encodedImage,
    () => _keyScope.secretKeyFor(encodedImage),
  );

  /// Copies only the rewritten containers: re-encoding every base64 payload
  /// just to obtain a writable copy costs more than the request.
  _CacheLayout _layOut({required bool Function(String secretKey) omit}) {
    final request = Map<String, dynamic>.of(_requestData);
    final omittedKeys = <String>{};
    final carriedKeys = <String>{};

    bool omitImage(String secretKey) {
      final omitted = omit(secretKey);
      (omitted ? omittedKeys : carriedKeys).add(secretKey);
      return omitted;
    }

    void layOutValue(
      Map<String, dynamic> parameters,
      String valueKey,
      String cacheKey,
    ) {
      final value = parameters[valueKey];
      if (value is! String || value.isEmpty) return;
      final secretKey = _secretKeyFor(value);
      if (omitImage(secretKey)) parameters.remove(valueKey);
      parameters[cacheKey] = secretKey;
    }

    Map<String, dynamic> cachedEntry(Object? value, String sourceKey) {
      if (value is! String) {
        throw ArgumentError.value(value, sourceKey, 'Expected base64 strings');
      }
      final secretKey = _secretKeyFor(value);
      return <String, dynamic>{
        'cache_secret_key': secretKey,
        if (!omitImage(secretKey)) 'data': value,
      };
    }

    void layOutList(
      Map<String, dynamic> parameters,
      String sourceKey,
      String cachedKey,
    ) {
      final source = parameters[sourceKey];
      if (source is! List || source.isEmpty) return;
      parameters[cachedKey] = <Map<String, dynamic>>[
        for (final value in source) cachedEntry(value, sourceKey),
      ];
      parameters.remove(sourceKey);
    }

    final parametersValue = request['parameters'];
    if (parametersValue is Map) {
      final parameters = _copyStringKeyedMap(parametersValue, 'parameters');
      request['parameters'] = parameters;
      layOutValue(parameters, 'image', 'image_cache_secret_key');
      layOutValue(parameters, 'mask', 'mask_cache_secret_key');
      layOutValue(
        parameters,
        'reference_image',
        'reference_image_cache_secret_key',
      );
      layOutList(
        parameters,
        'reference_image_multiple',
        'reference_image_multiple_cached',
      );
      layOutList(
        parameters,
        'director_reference_images',
        'director_reference_images_cached',
      );
    }
    return _CacheLayout(request, omittedKeys, carriedKeys);
  }

  /// Moves image bytes into parts named like the web client, one per payload.
  static BrowserMultipartBody _encodeMultipart(Map<String, dynamic> layout) {
    final request = Map<String, dynamic>.of(layout);
    final parts = <BrowserMultipartPart>[];
    final partNamesByPayload = <String, String>{};

    String appendImagePart(String encodedImage, String requestedPartName) {
      final existingPartName = partNamesByPayload[encodedImage];
      if (existingPartName != null) return existingPartName;
      parts.add(
        BrowserMultipartPart(
          name: requestedPartName,
          bytes: base64Decode(encodedImage),
          filename: 'blob',
          contentType: 'image/png',
        ),
      );
      partNamesByPayload[encodedImage] = requestedPartName;
      return requestedPartName;
    }

    void extractValue(
      Map<String, dynamic> container,
      String valueKey,
      String partName,
    ) {
      final value = container[valueKey];
      if (value is! String || value.isEmpty) return;
      container[valueKey] = appendImagePart(value, partName);
    }

    void extractCachedList(
      Map<String, dynamic> parameters,
      String cachedKey,
      String partPrefix,
    ) {
      final cachedValues = parameters[cachedKey];
      if (cachedValues is! List) return;
      final extractedValues = <dynamic>[];
      for (var index = 0; index < cachedValues.length; index += 1) {
        final cachedValue = cachedValues[index];
        final data = cachedValue is Map ? cachedValue['data'] : null;
        if (cachedValue is! Map || data is! String || data.isEmpty) {
          extractedValues.add(cachedValue);
          continue;
        }
        final extractedValue = _copyStringKeyedMap(cachedValue, cachedKey);
        extractedValue['data'] = appendImagePart(data, '$partPrefix$index');
        extractedValues.add(extractedValue);
      }
      parameters[cachedKey] = extractedValues;
    }

    extractValue(request, 'image', 'image');
    extractValue(request, 'mask', 'mask');
    final parametersValue = request['parameters'];
    if (parametersValue is Map) {
      final parameters = _copyStringKeyedMap(parametersValue, 'parameters');
      request['parameters'] = parameters;
      extractValue(parameters, 'image', 'image');
      extractValue(parameters, 'mask', 'mask');
      extractValue(parameters, 'reference_image', 'reference_image');
      extractCachedList(
        parameters,
        'reference_image_multiple_cached',
        'ref_multiple_',
      );
      extractCachedList(
        parameters,
        'director_reference_images_cached',
        'director_ref_',
      );
    }

    parts.add(
      BrowserMultipartPart(
        name: 'request',
        bytes: utf8.encode(encodeJsCompatibleJson(request)),
        filename: 'blob',
        contentType: 'application/json',
      ),
    );
    return BrowserMultipartBody.encode(parts);
  }

  /// Copies one JSON object container; nested values stay shared with [source].
  static Map<String, dynamic> _copyStringKeyedMap(
    Map<dynamic, dynamic> source,
    String name,
  ) {
    final copy = <String, dynamic>{};
    for (final entry in source.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError.value(key, name, 'Expected string keys');
      }
      copy[key] = entry.value;
    }
    return copy;
  }
}

class _CacheLayout {
  const _CacheLayout(this.request, this.omittedKeys, this.carriedKeys);

  final Map<String, dynamic> request;

  /// Images sent as a cache key only.
  final Set<String> omittedKeys;

  /// Images whose bytes travel in this request.
  final Set<String> carriedKeys;
}
