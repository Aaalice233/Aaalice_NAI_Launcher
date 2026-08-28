import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/nai_api_endpoint_service.dart';
import '../../../core/utils/app_logger.dart';

/// Owns every transport request started by one generation run.
///
/// A run can cancel its own in-flight request without relying on the
/// transport-wide "latest request" compatibility pointer.
class NaiGenerationCancellationLease {
  NaiGenerationCancellationLease();

  final Set<NaiGenerationRequest> _activeRequests = {};
  NaiGenerationRequest? _currentRequest;
  bool _isCancelled = false;
  bool _isReleased = false;

  @visibleForTesting
  int get activeRequestCountForTesting => _activeRequests.length;
}

/// A request-scoped transport token. Completing an older request cannot clear
/// either a newer request or another run's cancellation lease.
class NaiGenerationRequest {
  NaiGenerationRequest._(this.cancelToken, this.lease);

  final CancelToken cancelToken;
  final NaiGenerationCancellationLease? lease;
}

class NaiGenerationTransport {
  NaiGenerationTransport(this._dio, this._endpointService);

  static const String _correlationIdAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz123456789';
  static final Random _correlationIdRandom = Random.secure();
  static final Uint8List _imageCacheHmacKey = Uint8List.fromList(
    List<int>.generate(32, (_) => Random.secure().nextInt(256)),
  );

  final Dio _dio;
  final NaiApiEndpointService _endpointService;
  final Set<NaiGenerationRequest> _activeRequests = {};
  NaiGenerationRequest? _currentRequest;

  NaiGenerationCancellationLease createCancellationLease() =>
      NaiGenerationCancellationLease();

  NaiGenerationRequest beginRequest([NaiGenerationCancellationLease? lease]) {
    if (lease?._isReleased ?? false) {
      throw StateError('Generation cancellation lease has been released');
    }
    final request = NaiGenerationRequest._(CancelToken(), lease);
    _activeRequests.add(request);
    _currentRequest = request;
    if (lease != null) {
      lease._activeRequests.add(request);
      lease._currentRequest = request;
      if (lease._isCancelled) {
        request.cancelToken.cancel('Generation run cancelled');
      }
    }
    return request;
  }

  void completeRequest(NaiGenerationRequest request) {
    _activeRequests.remove(request);
    if (identical(_currentRequest, request)) _currentRequest = null;
    final lease = request.lease;
    lease?._activeRequests.remove(request);
    if (identical(lease?._currentRequest, request)) {
      lease?._currentRequest = null;
    }
  }

  void cancelLease(NaiGenerationCancellationLease lease) {
    if (lease._isReleased) return;
    lease._isCancelled = true;
    final requests = lease._activeRequests.toList(growable: false);
    AppLogger.w(
      'cancelGeneration: scopedInFlightRequests=${requests.length}',
      'ImgGen',
    );
    for (final request in requests) {
      request.cancelToken.cancel('Generation run cancelled');
    }
  }

  void cancelCurrentRequest([NaiGenerationCancellationLease? lease]) {
    final request = lease == null ? _currentRequest : lease._currentRequest;
    AppLogger.w(
      'cancelGeneration: hasInFlightToken=${request != null}, '
          'requestScoped=${lease != null}',
      'ImgGen',
    );
    if (lease == null) {
      _currentRequest = null;
    } else if (identical(lease._currentRequest, request)) {
      lease._currentRequest = null;
    }
    request?.cancelToken.cancel('User cancelled');
  }

  void releaseLease(NaiGenerationCancellationLease lease) {
    if (lease._isReleased) return;
    lease._isReleased = true;
    for (final request in lease._activeRequests.toList(growable: false)) {
      request.cancelToken.cancel('Generation run ended');
      completeRequest(request);
    }
    lease._currentRequest = null;
  }

  Future<Response<Uint8List>> sendZip(
    Map<String, dynamic> requestData,
    NaiGenerationRequest request, {
    void Function(int, int)? onProgress,
  }) {
    return _dio.post<Uint8List>(
      _endpointService.imageUrl(ApiConstants.generateImageEndpoint),
      data: buildGenerationFormData(requestData),
      cancelToken: request.cancelToken,
      onReceiveProgress: onProgress,
      options: Options(
        responseType: ResponseType.bytes,
        headers: _requestHeaders('application/x-zip-compressed'),
      ),
    );
  }

  Future<Response<ResponseBody>> sendStream(
    Map<String, dynamic> requestData,
    NaiGenerationRequest request,
  ) {
    return _dio.post<ResponseBody>(
      _endpointService.imageUrl(ApiConstants.generateImageStreamEndpoint),
      data: buildGenerationFormData(requestData),
      cancelToken: request.cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: _requestHeaders('application/x-msgpack'),
      ),
    );
  }

  static Map<String, String> _requestHeaders(String accept) {
    return {
      'Accept': accept,
      'x-correlation-id': List.generate(
        6,
        (_) =>
            _correlationIdAlphabet[_correlationIdRandom.nextInt(
              _correlationIdAlphabet.length,
            )],
        growable: false,
      ).join(),
      'x-initiated-at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Encodes the official multipart layout while preserving image-part order.
  static FormData buildGenerationFormData(Map<String, dynamic> requestData) {
    final transformedRequest = jsonDecode(jsonEncode(requestData));
    if (transformedRequest is! Map<String, dynamic>) {
      throw ArgumentError.value(requestData, 'requestData', 'Expected a map');
    }

    final formData = FormData();
    final partNamesByPayload = <String, String>{};

    String appendImagePart(String encodedImage, String requestedPartName) {
      final existingPartName = partNamesByPayload[encodedImage];
      if (existingPartName != null) return existingPartName;
      formData.files.add(
        MapEntry(
          requestedPartName,
          MultipartFile.fromBytes(
            base64Decode(encodedImage),
            filename: 'blob',
            contentType: DioMediaType('image', 'png'),
          ),
        ),
      );
      partNamesByPayload[encodedImage] = requestedPartName;
      return requestedPartName;
    }

    void prepareCachedValue(
      Map<String, dynamic> parameters,
      String valueKey,
      String cacheKey,
    ) {
      final value = parameters[valueKey];
      if (value is! String || value.isEmpty) return;
      parameters[cacheKey] = _imageCacheSecretKey(value);
    }

    void prepareCachedList(
      Map<String, dynamic> parameters,
      String sourceKey,
      String cachedKey,
    ) {
      final source = parameters[sourceKey];
      if (source is! List || source.isEmpty) return;
      parameters[cachedKey] = source
          .map((value) {
            if (value is! String) {
              throw ArgumentError.value(
                value,
                sourceKey,
                'Expected base64 strings',
              );
            }
            return <String, dynamic>{
              'cache_secret_key': _imageCacheSecretKey(value),
              'data': value,
            };
          })
          .toList(growable: false);
      parameters.remove(sourceKey);
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
      for (var index = 0; index < cachedValues.length; index += 1) {
        final cachedValue = cachedValues[index];
        if (cachedValue is! Map<String, dynamic>) continue;
        final data = cachedValue['data'];
        if (data is! String || data.isEmpty) continue;
        cachedValue['data'] = appendImagePart(data, '$partPrefix$index');
      }
    }

    final parametersValue = transformedRequest['parameters'];
    final parameters = parametersValue is Map<String, dynamic>
        ? parametersValue
        : null;
    if (parameters != null) {
      prepareCachedValue(parameters, 'image', 'image_cache_secret_key');
      prepareCachedValue(parameters, 'mask', 'mask_cache_secret_key');
      prepareCachedValue(
        parameters,
        'reference_image',
        'reference_image_cache_secret_key',
      );
      prepareCachedList(
        parameters,
        'reference_image_multiple',
        'reference_image_multiple_cached',
      );
      prepareCachedList(
        parameters,
        'director_reference_images',
        'director_reference_images_cached',
      );
    }

    extractValue(transformedRequest, 'image', 'image');
    extractValue(transformedRequest, 'mask', 'mask');
    if (parameters != null) {
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

    formData.files.add(
      MapEntry(
        'request',
        MultipartFile.fromBytes(
          utf8.encode(jsonEncode(transformedRequest)),
          filename: 'blob',
          contentType: DioMediaType('application', 'json'),
        ),
      ),
    );
    return formData;
  }

  static String _imageCacheSecretKey(String encodedImage) {
    return crypto.Hmac(
      crypto.sha256,
      _imageCacheHmacKey,
    ).convert(utf8.encode(encodedImage)).toString();
  }
}
