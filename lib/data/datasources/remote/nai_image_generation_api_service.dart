import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/models/image_generation_artifact.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/critical_network_activity.dart';
import '../../../core/network/nai_api_endpoint_service.dart';
import '../../../core/network/request_builders/nai_image_request_builder.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/image/image_params.dart';
import '../../models/image/image_stream_chunk.dart';
import 'nai_generation_response_processor.dart';
import 'nai_generation_transport.dart';
import 'nai_image_enhancement_api_service.dart';

part 'nai_image_generation_api_service.g.dart';

/// Compatibility facade for NovelAI image generation.
///
/// Request construction remains coordinated here while transport mechanics and
/// response decoding/composition live in dedicated collaborators.
class NAIImageGenerationApiService {
  NAIImageGenerationApiService(
    Dio dio,
    this._enhancementService,
    NaiApiEndpointService endpointService, [
    CriticalNetworkActivityCoordinator? networkActivity,
  ]) : _transport = NaiGenerationTransport(dio, endpointService),
       _responseProcessor = NaiGenerationResponseProcessor(),
       _networkActivity =
           networkActivity ?? CriticalNetworkActivityCoordinator.instance;

  static final Object _cancellationLeaseZoneKey = Object();

  final NAIImageEnhancementApiService _enhancementService;
  final NaiGenerationTransport _transport;
  final NaiGenerationResponseProcessor _responseProcessor;
  final CriticalNetworkActivityCoordinator _networkActivity;
  var _legacyCancellationEpoch = 0;

  static T withCancellationLease<T>(
    NaiGenerationCancellationLease lease,
    T Function() action,
  ) => runZoned(
    action,
    zoneValues: <Object?, Object?>{_cancellationLeaseZoneKey: lease},
  );

  static NaiGenerationCancellationLease? _effectiveCancellationLease(
    NaiGenerationCancellationLease? explicitLease,
  ) =>
      explicitLease ??
      Zone.current[_cancellationLeaseZoneKey]
          as NaiGenerationCancellationLease?;

  /// Maps model-specific sampler compatibility exactly as the legacy service.
  @visibleForTesting
  static String mapSamplerForModel(String sampler, String model) {
    if (sampler == Samplers.ddim || sampler == Samplers.ddimV3) {
      if (ImageModels.isV4Model(model) || model == 'N/A') {
        AppLogger.w(
          'Model $model does not support DDIM sampler, falling back to Euler Ancestral',
          'ImgGen',
        );
        return Samplers.kEulerAncestral;
      }
      if (model.contains('diffusion-3')) {
        AppLogger.i('Mapping DDIM to DDIM v3 for model: $model', 'ImgGen');
        return Samplers.ddimV3;
      }
    }
    return sampler;
  }

  /// Retained for callers and tests that inspect the official multipart shape.
  @visibleForTesting
  static FormData buildGenerationFormData(Map<String, dynamic> requestData) {
    return NaiGenerationTransport.buildGenerationFormData(requestData);
  }

  Future<(List<Uint8List>, Map<int, String>)> generateImage(
    ImageParams params, {
    void Function(int, int)? onProgress,
    bool focusedInpaintEnabled = false,
    double minimumContextMegaPixels = 88.0,
    Rect? focusedSelectionRect,
    NaiGenerationCancellationLease? cancellationLease,
  }) async {
    final result = await _generateImageArtifacts(
      params,
      onProgress: onProgress,
      focusedInpaintEnabled: focusedInpaintEnabled,
      minimumContextMegaPixels: minimumContextMegaPixels,
      focusedSelectionRect: focusedSelectionRect,
      cancellationLease: cancellationLease,
    );
    return (
      result.$1
          .map((artifact) => artifact.displayImageBytes)
          .toList(growable: false),
      result.$2,
    );
  }

  Future<(List<Uint8List>, Map<int, String>)>
  generateImageWithEncodingsCancellable(
    ImageParams params, {
    void Function(int, int)? onProgress,
    bool focusedInpaintEnabled = false,
    double minimumContextMegaPixels = 88.0,
    Rect? focusedSelectionRect,
    NaiGenerationCancellationLease? cancellationLease,
  }) {
    return generateImage(
      params,
      onProgress: onProgress,
      focusedInpaintEnabled: focusedInpaintEnabled,
      minimumContextMegaPixels: minimumContextMegaPixels,
      focusedSelectionRect: focusedSelectionRect,
      cancellationLease: cancellationLease,
    );
  }

  Future<List<Uint8List>> generateImageCancellable(
    ImageParams params, {
    void Function(int, int)? onProgress,
    bool focusedInpaintEnabled = false,
    double minimumContextMegaPixels = 88.0,
    Rect? focusedSelectionRect,
    NaiGenerationCancellationLease? cancellationLease,
  }) async {
    final result = await generateImageWithEncodingsCancellable(
      params,
      onProgress: onProgress,
      focusedInpaintEnabled: focusedInpaintEnabled,
      minimumContextMegaPixels: minimumContextMegaPixels,
      focusedSelectionRect: focusedSelectionRect,
      cancellationLease: cancellationLease,
    );
    return result.$1;
  }

  Future<List<ImageGenerationArtifact>> generateImageArtifactsCancellable(
    ImageParams params, {
    void Function(int, int)? onProgress,
    bool focusedInpaintEnabled = false,
    double minimumContextMegaPixels = 88.0,
    Rect? focusedSelectionRect,
    NaiGenerationCancellationLease? cancellationLease,
  }) async {
    final result = await _generateImageArtifacts(
      params,
      onProgress: onProgress,
      focusedInpaintEnabled: focusedInpaintEnabled,
      minimumContextMegaPixels: minimumContextMegaPixels,
      focusedSelectionRect: focusedSelectionRect,
      cancellationLease: cancellationLease,
    );
    return result.$1;
  }

  Future<(List<ImageGenerationArtifact>, Map<int, String>)>
  _generateImageArtifacts(
    ImageParams params, {
    void Function(int, int)? onProgress,
    required bool focusedInpaintEnabled,
    required double minimumContextMegaPixels,
    Rect? focusedSelectionRect,
    NaiGenerationCancellationLease? cancellationLease,
  }) async {
    final activity = _networkActivity.acquire(
      CriticalNetworkActivityType.imageGeneration,
    );
    final request = _transport.beginRequest(
      _effectiveCancellationLease(cancellationLease),
    );
    try {
      final command = await _prepareCommand(
        params,
        isStream: false,
        focusedInpaintEnabled: focusedInpaintEnabled,
        minimumContextMegaPixels: minimumContextMegaPixels,
        focusedSelectionRect: focusedSelectionRect,
      );
      final response = await _transport.sendZip(
        command.buildResult.requestData,
        request,
        onProgress: onProgress,
      );
      final artifacts = await _responseProcessor.processZip(
        response.data!,
        command.responseContext,
      );
      return (artifacts, command.buildResult.vibeEncodingMap);
    } finally {
      _transport.completeRequest(request);
      activity.release();
    }
  }

  NaiGenerationCancellationLease createCancellationLease() =>
      _transport.createCancellationLease();

  /// Cancels one run when [lease] is supplied. The no-argument form is kept
  /// for legacy callers and targets only the transport's latest request.
  void cancelGeneration([NaiGenerationCancellationLease? lease]) {
    if (lease == null) {
      _legacyCancellationEpoch += 1;
      _transport.cancelCurrentRequest();
    } else {
      _transport.cancelLease(lease);
    }
  }

  void cancelCurrentGenerationRequest(NaiGenerationCancellationLease lease) =>
      _transport.cancelCurrentRequest(lease);

  void releaseCancellationLease(NaiGenerationCancellationLease lease) =>
      _transport.releaseLease(lease);

  Stream<ImageStreamChunk> generateImageStream(
    ImageParams params, {
    bool focusedInpaintEnabled = false,
    double minimumContextMegaPixels = 88.0,
    Rect? focusedSelectionRect,
    NaiGenerationCancellationLease? cancellationLease,
  }) {
    final effectiveLease = _effectiveCancellationLease(cancellationLease);
    final legacyCancellationEpoch = effectiveLease == null
        ? _legacyCancellationEpoch
        : null;
    return _generateImageStream(
      params,
      effectiveLease,
      legacyCancellationEpoch: legacyCancellationEpoch,
      focusedInpaintEnabled: focusedInpaintEnabled,
      minimumContextMegaPixels: minimumContextMegaPixels,
      focusedSelectionRect: focusedSelectionRect,
    );
  }

  Stream<ImageStreamChunk> _generateImageStream(
    ImageParams params,
    NaiGenerationCancellationLease? cancellationLease, {
    required int? legacyCancellationEpoch,
    required bool focusedInpaintEnabled,
    required double minimumContextMegaPixels,
    Rect? focusedSelectionRect,
  }) async* {
    // async* does not execute until listen, so an abandoned stream owns no
    // transport request. Leases and the legacy epoch retain pre-listen cancel.
    final activity = _networkActivity.acquire(
      CriticalNetworkActivityType.imageGeneration,
    );
    final request = _transport.beginRequest(cancellationLease);
    try {
      if (legacyCancellationEpoch != null &&
          legacyCancellationEpoch != _legacyCancellationEpoch) {
        request.cancelToken.cancel('Generation cancelled before listen');
      }
      if (request.cancelToken.isCancelled) {
        yield ImageStreamChunk.error('Cancelled');
        return;
      }
      final command = await _prepareCommand(
        params,
        isStream: true,
        focusedInpaintEnabled: focusedInpaintEnabled,
        minimumContextMegaPixels: minimumContextMegaPixels,
        focusedSelectionRect: focusedSelectionRect,
      );
      if (request.cancelToken.isCancelled) {
        yield ImageStreamChunk.error('Cancelled');
        return;
      }

      final response = await _transport.sendStream(
        command.buildResult.requestData,
        request,
      );
      yield* _responseProcessor.processMessagePackStream(
        response.data!.stream,
        command.responseContext,
        cancelToken: request.cancelToken,
      );
    } on DioException catch (error) {
      yield ImageStreamChunk.error(
        await _responseProcessor.formatStreamDioError(error),
      );
    } catch (error) {
      AppLogger.e('Stream generation failed: $error', 'ImgGen');
      yield ImageStreamChunk.error(error.toString());
    } finally {
      _transport.completeRequest(request);
      activity.release();
    }
  }

  Future<_PreparedGeneration> _prepareCommand(
    ImageParams params, {
    required bool isStream,
    required bool focusedInpaintEnabled,
    required double minimumContextMegaPixels,
    Rect? focusedSelectionRect,
  }) async {
    final focusedRequest = await _responseProcessor.prepareFocusedInpaint(
      params,
      enabled: focusedInpaintEnabled,
      minimumContextMegaPixels: minimumContextMegaPixels,
      focusedSelectionRect: focusedSelectionRect,
    );
    final effectiveParams = _responseProcessor.applyFocusedRequest(
      params,
      focusedRequest,
    );

    if (effectiveParams.hasVibeReferencesV4 &&
        effectiveParams.hasPreciseReferences) {
      AppLogger.d(
        'Both Vibe Transfer and Precise Reference are enabled; skipping vibe payload in favor of Precise Reference',
        'ImgGen',
      );
    }
    final preciseReferences = effectiveParams.isV45Model
        ? effectiveParams.enabledPreciseReferences
        : <PreciseReference>[];
    final buildResult =
        await NAIImageRequestBuilder(
          params: effectiveParams,
          encodeVibe: _enhancementService.encodeVibe,
          preciseReferences: preciseReferences,
        ).build(
          sampler: mapSamplerForModel(
            effectiveParams.sampler,
            effectiveParams.model,
          ),
          isStream: isStream,
        );

    AppLogger.d(
      'Generating image with action: ${effectiveParams.action.value}, model: ${effectiveParams.model}',
      'ImgGen',
    );

    return _PreparedGeneration(
      buildResult: buildResult,
      responseContext: NaiGenerationResponseContext(
        originalParams: params,
        focusedRequest: focusedRequest,
        requestBuildResult: buildResult,
      ),
    );
  }
}

class _PreparedGeneration {
  const _PreparedGeneration({
    required this.buildResult,
    required this.responseContext,
  });

  final NAIImageRequestBuildResult buildResult;
  final NaiGenerationResponseContext responseContext;
}

/// NAIImageGenerationApiService Provider.
///
/// keepAlive ensures cancellation reaches the same facade and transport lease
/// that started the in-flight request.
@Riverpod(keepAlive: true)
NAIImageGenerationApiService naiImageGenerationApiService(Ref ref) {
  final dio = ref.watch(imageGenerationDioClientProvider);
  final enhancementService = ref.watch(naiImageEnhancementApiServiceProvider);
  final endpointService = ref.watch(naiApiEndpointServiceProvider);
  return NAIImageGenerationApiService(dio, enhancementService, endpointService);
}
