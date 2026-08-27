import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
// ignore: implementation_imports
import 'package:onnxruntime_v2/src/bindings/onnxruntime_bindings_generated.dart'
    as bg;

import '../../core/utils/app_logger.dart';
import '../../core/utils/contiguous_region_selector.dart';
import '../../core/utils/efficient_vit_sam_image_processor.dart';
import 'efficient_vit_sam_model_manager.dart';

enum EfficientVitSamProgressStage {
  checkingModels,
  downloadingModels,
  loadingModels,
  encodingImage,
  decodingMask,
  postprocessingMask,
}

class EfficientVitSamProgress {
  const EfficientVitSamProgress(this.stage, {this.fraction});

  final EfficientVitSamProgressStage stage;
  final double? fraction;
}

typedef EfficientVitSamProgressCallback =
    void Function(EfficientVitSamProgress progress);
typedef EfficientVitSamSelector =
    Future<ContiguousRegionSelection> Function({
      required Uint8List rgba,
      required int width,
      required int height,
      required int startX,
      required int startY,
      required bool invert,
      EfficientVitSamProgressCallback? onProgress,
    });

class EfficientVitSamService {
  EfficientVitSamService({EfficientVitSamModelManager? modelManager})
    : _modelManager = modelManager ?? EfficientVitSamModelManager();

  final EfficientVitSamModelManager _modelManager;
  OrtSession? _encoderSession;
  OrtSession? _decoderSession;
  OrtValueTensor? _cachedEmbedding;
  String? _cachedImageKey;
  int _activeOperations = 0;
  bool _disposed = false;

  Future<ContiguousRegionSelection> selectRgba({
    required Uint8List rgba,
    required int width,
    required int height,
    required int startX,
    required int startY,
    required bool invert,
    EfficientVitSamProgressCallback? onProgress,
  }) async {
    if (_disposed) {
      throw StateError('EfficientViT-SAM service has been disposed.');
    }
    if (width <= 0 ||
        height <= 0 ||
        startX < 0 ||
        startX >= width ||
        startY < 0 ||
        startY >= height) {
      throw ArgumentError('The EfficientViT-SAM prompt point is invalid.');
    }
    if (rgba.lengthInBytes < width * height * 4) {
      throw ArgumentError('RGBA buffer is smaller than the image dimensions.');
    }

    _activeOperations++;
    try {
      onProgress?.call(
        const EfficientVitSamProgress(
          EfficientVitSamProgressStage.checkingModels,
        ),
      );
      final modelFiles = await _modelManager.ensureModels(
        onProgress: (fraction, isDownloading) {
          onProgress?.call(
            EfficientVitSamProgress(
              isDownloading
                  ? EfficientVitSamProgressStage.downloadingModels
                  : EfficientVitSamProgressStage.checkingModels,
              fraction: fraction,
            ),
          );
        },
      );
      await _ensureSessions(modelFiles, onProgress);

      final imageKey =
          '$width:$height:${await EfficientVitSamImageProcessor.hashRgbaAsync(rgba)}';
      if (_cachedEmbedding == null || _cachedImageKey != imageKey) {
        onProgress?.call(
          const EfficientVitSamProgress(
            EfficientVitSamProgressStage.encodingImage,
          ),
        );
        final prepared =
            await EfficientVitSamImageProcessor.preprocessRgbaAsync(
              rgba: rgba,
              width: width,
              height: height,
            );
        final embedding = await _encodeImage(prepared.tensor);
        final previousEmbedding = _cachedEmbedding;
        _cachedEmbedding = embedding;
        _cachedImageKey = imageKey;
        previousEmbedding?.release();
      }

      onProgress?.call(
        const EfficientVitSamProgress(
          EfficientVitSamProgressStage.decodingMask,
        ),
      );
      final lowResolutionMask = await _decodePoint(
        embedding: _cachedEmbedding!,
        point: EfficientVitSamImageProcessor.scalePoint(
          x: startX.toDouble(),
          y: startY.toDouble(),
          width: width,
          height: height,
        ),
      );

      onProgress?.call(
        const EfficientVitSamProgress(
          EfficientVitSamProgressStage.postprocessingMask,
        ),
      );
      return EfficientVitSamImageProcessor.postprocessMaskAsync(
        lowResolutionMask: lowResolutionMask,
        outputWidth: width,
        outputHeight: height,
        invert: invert,
      );
    } finally {
      _activeOperations--;
      if (_disposed && _activeOperations == 0) {
        _releaseResources();
      }
    }
  }

  Future<void> _ensureSessions(
    EfficientVitSamModelFiles modelFiles,
    EfficientVitSamProgressCallback? onProgress,
  ) async {
    if (_encoderSession != null && _decoderSession != null) {
      return;
    }
    onProgress?.call(
      const EfficientVitSamProgress(EfficientVitSamProgressStage.loadingModels),
    );

    OrtSession? encoder;
    OrtSession? decoder;
    try {
      encoder = _createFileSession(modelFiles.encoderPath);
      decoder = _createFileSession(modelFiles.decoderPath);
      if (!encoder.inputNames.contains('input_image')) {
        throw StateError(
          'EfficientViT-SAM encoder input "input_image" was not found.',
        );
      }
      const requiredDecoderInputs = <String>{
        'image_embeddings',
        'point_coords',
        'point_labels',
      };
      if (!decoder.inputNames.toSet().containsAll(requiredDecoderInputs) ||
          !decoder.outputNames.contains('masks')) {
        throw StateError(
          'EfficientViT-SAM decoder inputs or mask output are incompatible.',
        );
      }
      _encoderSession = encoder;
      _decoderSession = decoder;
    } catch (_) {
      if (encoder != null) await encoder.release();
      if (decoder != null) await decoder.release();
      rethrow;
    }
  }

  Future<OrtValueTensor> _encodeImage(Float32List input) async {
    final session = _encoderSession!;
    final runOptions = OrtRunOptions();
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      input,
      const <int>[1, 3, 512, 512],
    );
    List<OrtValue?>? outputs;
    try {
      final future = session.runAsyncWithTimeout(
        runOptions,
        <String, OrtValue>{'input_image': inputTensor},
        const Duration(minutes: 2),
        const <String>['image_embeddings'],
      );
      if (future == null) {
        throw StateError('EfficientViT-SAM encoder could not start.');
      }
      outputs = await future;
      if (outputs.isEmpty || outputs.first is! OrtValueTensor) {
        throw StateError('EfficientViT-SAM encoder returned no embedding.');
      }
      final embedding = outputs.first! as OrtValueTensor;
      outputs[0] = null;
      return embedding;
    } finally {
      for (final output in outputs ?? const <OrtValue?>[]) {
        output?.release();
      }
      inputTensor.release();
      runOptions.release();
    }
  }

  Future<EfficientVitSamLowResolutionMask> _decodePoint({
    required OrtValueTensor embedding,
    required Float32List point,
  }) async {
    final session = _decoderSession!;
    final runOptions = OrtRunOptions();
    final pointTensor = OrtValueTensor.createTensorWithDataList(
      point,
      const <int>[1, 1, 2],
    );
    final labelTensor = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(const <double>[1]),
      const <int>[1, 1],
    );
    List<OrtValue?>? outputs;
    try {
      final future = session.runAsyncWithTimeout(
        runOptions,
        <String, OrtValue>{
          'image_embeddings': embedding,
          'point_coords': pointTensor,
          'point_labels': labelTensor,
        },
        const Duration(minutes: 2),
        const <String>['masks'],
      );
      if (future == null) {
        throw StateError('EfficientViT-SAM decoder could not start.');
      }
      outputs = await future;
      if (outputs.isEmpty || outputs.first is! OrtValueTensor) {
        throw StateError('EfficientViT-SAM decoder returned no mask.');
      }
      return EfficientVitSamImageProcessor.parseLowResolutionMask(
        outputs.first!.value,
      );
    } finally {
      for (final output in outputs ?? const <OrtValue?>[]) {
        output?.release();
      }
      pointTensor.release();
      labelTensor.release();
      runOptions.release();
    }
  }

  OrtSession _createFileSession(String modelPath) {
    if (!Platform.isWindows) {
      final options = OrtSessionOptions()
        ..setInterOpNumThreads(1)
        ..setIntraOpNumThreads(2)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
      try {
        return OrtSession.fromFile(File(modelPath), options);
      } finally {
        options.release();
      }
    }

    final options = _createNativeSessionOptions();
    try {
      _configureNativeSessionOptions(options);
      return _createWindowsSessionFromPath(modelPath, options);
    } finally {
      _releaseNativeSessionOptions(options);
    }
  }

  ffi.Pointer<bg.OrtSessionOptions> _createNativeSessionOptions() {
    final optionsPtrPtr = calloc<ffi.Pointer<bg.OrtSessionOptions>>();
    try {
      final statusPtr = OrtEnv.instance.ortApiPtr.ref.CreateSessionOptions
          .asFunction<
            bg.OrtStatusPtr Function(
              ffi.Pointer<ffi.Pointer<bg.OrtSessionOptions>>,
            )
          >()(optionsPtrPtr);
      OrtStatus.checkOrtStatus(statusPtr);
      return optionsPtrPtr.value;
    } finally {
      calloc.free(optionsPtrPtr);
    }
  }

  void _configureNativeSessionOptions(
    ffi.Pointer<bg.OrtSessionOptions> options,
  ) {
    var statusPtr = OrtEnv.instance.ortApiPtr.ref.SetInterOpNumThreads
        .asFunction<
          bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtSessionOptions>, int)
        >()(options, 1);
    OrtStatus.checkOrtStatus(statusPtr);
    statusPtr = OrtEnv.instance.ortApiPtr.ref.SetIntraOpNumThreads
        .asFunction<
          bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtSessionOptions>, int)
        >()(options, 2);
    OrtStatus.checkOrtStatus(statusPtr);
    statusPtr = OrtEnv.instance.ortApiPtr.ref.SetSessionGraphOptimizationLevel
        .asFunction<
          bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtSessionOptions>, int)
        >()(options, GraphOptimizationLevel.ortEnableAll.value);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  OrtSession _createWindowsSessionFromPath(
    String modelPath,
    ffi.Pointer<bg.OrtSessionOptions> options,
  ) {
    final sessionPtrPtr = calloc<ffi.Pointer<bg.OrtSession>>();
    final pathPtr = File(modelPath).absolute.path.toNativeUtf16();
    try {
      final statusPtr =
          OrtEnv.instance.ortApiPtr.ref.CreateSession
              .asFunction<
                bg.OrtStatusPtr Function(
                  ffi.Pointer<bg.OrtEnv>,
                  ffi.Pointer<ffi.Char>,
                  ffi.Pointer<bg.OrtSessionOptions>,
                  ffi.Pointer<ffi.Pointer<bg.OrtSession>>,
                )
              >()(
            OrtEnv.instance.ptr,
            pathPtr.cast<ffi.Char>(),
            options,
            sessionPtrPtr,
          );
      OrtStatus.checkOrtStatus(statusPtr);
      return OrtSession.fromAddress(sessionPtrPtr.value.address);
    } finally {
      calloc.free(pathPtr);
      calloc.free(sessionPtrPtr);
    }
  }

  void _releaseNativeSessionOptions(ffi.Pointer<bg.OrtSessionOptions> options) {
    OrtEnv.instance.ortApiPtr.ref.ReleaseSessionOptions
        .asFunction<void Function(ffi.Pointer<bg.OrtSessionOptions>)>()(
      options,
    );
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (_activeOperations == 0) {
      _releaseResources();
    }
  }

  void _releaseResources() {
    _cachedEmbedding?.release();
    _cachedEmbedding = null;
    _cachedImageKey = null;
    final encoderSession = _encoderSession;
    _encoderSession = null;
    final decoderSession = _decoderSession;
    _decoderSession = null;
    if (encoderSession != null) {
      unawaited(_releaseSession(encoderSession));
    }
    if (decoderSession != null) {
      unawaited(_releaseSession(decoderSession));
    }
  }

  Future<void> _releaseSession(OrtSession session) async {
    try {
      await session.release();
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to release EfficientViT-SAM ONNX session',
        error,
        stackTrace,
        'EfficientVitSamService',
      );
    }
  }
}
