import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/browser_multipart_body.dart';
import '../../../core/network/dio_error_response_parser.dart';
import '../../../core/network/nai_api_endpoint_service.dart';
import '../../../core/utils/app_logger.dart';
import 'nai_generation_upload.dart';
import 'nai_image_upload_cache.dart';

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
  NaiGenerationTransport(this._dio, this._endpointService, [this._uploadCache]);

  static const int _badRequestStatus = 400;

  final Dio _dio;
  final NaiApiEndpointService _endpointService;

  /// Without it every request carries the bytes of all its images.
  final NaiImageUploadCache? _uploadCache;
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
  }) async {
    final upload = await _prepareUpload(requestData);
    return _sendRestoringCacheMisses(
      upload,
      (body) => _dio.post<Uint8List>(
        _endpointService.imageUrl(ApiConstants.generateImageEndpoint),
        data: body.bytes,
        cancelToken: request.cancelToken,
        onReceiveProgress: onProgress,
        options: Options(
          responseType: ResponseType.bytes,
          contentType: body.contentType,
        ),
      ),
    );
  }

  Future<Response<ResponseBody>> sendStream(
    Map<String, dynamic> requestData,
    NaiGenerationRequest request,
  ) async {
    final upload = await _prepareUpload(requestData);
    return _sendRestoringCacheMisses(
      upload,
      (body) => _dio.post<ResponseBody>(
        _endpointService.imageUrl(ApiConstants.generateImageStreamEndpoint),
        data: body.bytes,
        cancelToken: request.cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          contentType: body.contentType,
        ),
      ),
    );
  }

  /// Encodes the official multipart layout with the bytes of every image.
  static BrowserMultipartBody buildGenerationMultipart(
    Map<String, dynamic> requestData,
  ) => NaiGenerationUpload.prepare(requestData).encode();

  Future<NaiGenerationUpload> _prepareUpload(
    Map<String, dynamic> requestData,
  ) async {
    final scope = await _uploadCache?.scopeFor(_endpointService.current);
    return NaiGenerationUpload.prepare(requestData, scope: scope);
  }

  /// Resends once with the bytes of the images the server no longer holds.
  static Future<Response<T>> _sendRestoringCacheMisses<T>(
    NaiGenerationUpload upload,
    Future<Response<T>> Function(BrowserMultipartBody body) post,
  ) async {
    try {
      return await post(upload.encode());
    } on DioException catch (error, stackTrace) {
      if (error.response?.statusCode != _badRequestStatus) rethrow;
      final rejection = await _readRejection(error);
      final invalidKeys = NaiGenerationUpload.invalidCacheKeysIn(
        rejection.body,
      );
      if (invalidKeys == null || !upload.restoreImages(invalidKeys)) {
        upload.forgetUploads();
        Error.throwWithStackTrace(rejection.error, stackTrace);
      }
      AppLogger.w(
        'Image server no longer holds ${invalidKeys.length} cached image(s), '
            'resending with their data',
        'ImgGen',
      );
    }
    try {
      return await post(upload.encode());
    } on DioException catch (error) {
      if (error.response?.statusCode == _badRequestStatus) {
        upload.forgetUploads();
      }
      rethrow;
    }
  }

  /// Decodes a rejected body; a streamed body is buffered and handed back so
  /// downstream error formatting can still read it.
  static Future<({DioException error, Object? body})> _readRejection(
    DioException error,
  ) async {
    final response = error.response!;
    final data = response.data;
    if (data is! ResponseBody) {
      return (error: error, body: decodeDioErrorResponse(data));
    }

    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in data.stream) {
        bytes.add(chunk);
      }
    } catch (readError) {
      AppLogger.w(
        'Failed to read rejected generation body: $readError',
        'ImgGen',
      );
      return (error: error, body: null);
    }
    final buffered = bytes.takeBytes();
    final replayableResponse = Response<dynamic>(
      data: ResponseBody.fromBytes(
        buffered,
        data.statusCode,
        statusMessage: data.statusMessage,
        isRedirect: data.isRedirect,
        headers: data.headers,
      ),
      requestOptions: response.requestOptions,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      isRedirect: response.isRedirect,
      redirects: response.redirects,
      extra: response.extra,
      headers: response.headers,
    );
    return (
      error: error.copyWith(response: replayableResponse),
      body: decodeDioErrorResponse(buffered),
    );
  }
}
