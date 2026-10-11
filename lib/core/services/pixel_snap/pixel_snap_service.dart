import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../utils/isolate_pool.dart';
import 'internal/image_resampler.dart';
import 'pixel_snap_engine.dart';
import 'pixel_snap_options.dart';
import 'pixel_snap_progress.dart';

/// 源图无法解码。
class PixelSnapDecodeException implements Exception {
  const PixelSnapDecodeException();

  @override
  String toString() => 'PixelSnapDecodeException';
}

/// 用户中途取消。
class PixelSnapCancelledException implements Exception {
  const PixelSnapCancelledException();

  @override
  String toString() => 'PixelSnapCancelledException';
}

/// 兜底异常，携带无法跨 isolate 传递的原始错误文本。
class PixelSnapFailure implements Exception {
  const PixelSnapFailure(this.message);

  final String message;

  @override
  String toString() => 'PixelSnapFailure: $message';
}

/// 源图整幅全透明，没有可分析的像素。
class PixelSnapBlankImageException implements Exception {
  const PixelSnapBlankImageException();

  @override
  String toString() => 'PixelSnapBlankImageException';
}

/// 取消令牌。
///
/// [cancel] 之后 [PixelSnapService.run] 的 Future 以
/// [PixelSnapCancelledException] 结束。
class PixelSnapCancellation {
  bool _cancelled = false;
  void Function()? _onCancel;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
  }

  void _bind(void Function() onCancel) {
    _onCancel = onCancel;
    if (_cancelled) onCancel();
  }
}

/// Pixel Snap 的最终产物。
class PixelSnapOutput {
  const PixelSnapOutput({
    required this.pngBytes,
    required this.snappedWidth,
    required this.snappedHeight,
    required this.outputWidth,
    required this.outputHeight,
    required this.pitchX,
    required this.pitchY,
    required this.paletteSize,
    required this.downscaledForAnalysis,
  });

  final Uint8List pngBytes;

  /// snap 之后、放大之前的尺寸，即"多少个像素块"。
  final int snappedWidth;
  final int snappedHeight;

  final int outputWidth;
  final int outputHeight;

  /// 检测到的原始像素块边长。
  final double pitchX;
  final double pitchY;

  final int paletteSize;

  /// 源图过大被降采样后才分析，结果精度会略降。
  final bool downscaledForAnalysis;
}

/// Pixel Snap 入口：整个过程在本机完成，不发请求、不计 Anlas。
class PixelSnapService {
  const PixelSnapService();

  Future<PixelSnapOutput> run(
    Uint8List pngBytes,
    PixelSnapOptions options, {
    void Function(PixelSnapProgress)? onProgress,
    PixelSnapCancellation? cancellation,
  }) {
    final PixelSnapEngineParams params = PixelSnapEngineParams.fromOptions(
      options,
    );
    // 单任务闸门：这活儿会把所有核吃满，放行第二个只会让两个都变慢。
    // 引擎内部还会继续往下分 isolate，闸门只挡并发的第二次 Pixel Snap。
    return ComputeGate.singleTask().run(
      () => _runInIsolate(pngBytes, params, onProgress, cancellation),
    );
  }

  /// 自己起 isolate 而不是走 [ComputeGate.runIsolate]：取消要拿到 isolate 句柄。
  ///
  /// 取消只 kill 分析 isolate。它派出去的分片 isolate 收不到消息（同步计算不会
  /// pump 事件循环），会各自跑完当前分片才退出，最多多烧几秒 CPU。
  static Future<PixelSnapOutput> _runInIsolate(
    Uint8List pngBytes,
    PixelSnapEngineParams params,
    void Function(PixelSnapProgress)? onProgress,
    PixelSnapCancellation? cancellation,
  ) async {
    final ReceivePort port = ReceivePort();
    final Completer<PixelSnapOutput> completer = Completer<PixelSnapOutput>();
    bool cancelled = false;

    final StreamSubscription<dynamic> subscription = port.listen((
      dynamic message,
    ) {
      if (message is _ProgressMessage) {
        onProgress?.call(message.progress);
        return;
      }
      if (completer.isCompleted) return;
      if (message is _ResultMessage) {
        completer.complete(message.output);
      } else if (message is _FailureMessage) {
        completer.completeError(message.error);
      } else if (message is List<dynamic>) {
        // onError 口：[错误文本, 栈文本]
        completer.completeError(PixelSnapFailure('${message.first}'));
      } else {
        // onExit 口：正常结束时结果已经先到，走到这里就是被 kill 了。
        completer.completeError(
          cancelled
              ? const PixelSnapCancelledException()
              : const PixelSnapFailure('analysis isolate exited'),
        );
      }
    });

    final Isolate isolate = await Isolate.spawn(
      _analysisEntry,
      _AnalysisRequest(port.sendPort, pngBytes, params),
      onError: port.sendPort,
      onExit: port.sendPort,
      errorsAreFatal: true,
      debugName: 'pixel-snap',
    );
    cancellation?._bind(() {
      cancelled = true;
      isolate.kill(priority: Isolate.immediate);
    });

    try {
      return await completer.future;
    } finally {
      await subscription.cancel();
      port.close();
    }
  }

  /// 不经闸门直接分析，供测试与 isolate 内部使用。
  static Future<PixelSnapOutput> analyze(
    Uint8List pngBytes,
    PixelSnapEngineParams params, {
    bool parallel = true,
    void Function(PixelSnapProgress)? onProgress,
  }) async {
    final img.Image? decoded = img.decodeImage(pngBytes);
    if (decoded == null) throw const PixelSnapDecodeException();

    final img.Image source =
        decoded.numChannels == 4 && decoded.format == img.Format.uint8
        ? decoded
        : decoded.convert(format: img.Format.uint8, numChannels: 4);
    final Uint8List rgba = source.getBytes(order: img.ChannelOrder.rgba);

    final int sourceWidth = source.width;
    final int sourceHeight = source.height;
    final int pixels = sourceWidth * sourceHeight;

    final Uint8List rgb = Uint8List(pixels * 3);
    final Uint8List alphaPlane = Uint8List(pixels);
    bool hasTranslucency = false;
    bool fullyTransparent = true;
    for (int i = 0; i < pixels; i++) {
      final int a = rgba[4 * i + 3];
      alphaPlane[i] = a;
      if (a < 255) hasTranslucency = true;
      // 全透明像素的 RGB 留 0：PNG 里这些通道常是垃圾值，带进中位数会污染边缘。
      if (a != 0) {
        fullyTransparent = false;
        rgb[3 * i] = rgba[4 * i];
        rgb[3 * i + 1] = rgba[4 * i + 1];
        rgb[3 * i + 2] = rgba[4 * i + 2];
      }
    }
    if (fullyTransparent) throw const PixelSnapBlankImageException();

    Uint8List analysisRgb = rgb;
    Uint8List? analysisAlpha = hasTranslucency ? alphaPlane : null;
    int analysisWidth = sourceWidth;
    int analysisHeight = sourceHeight;

    final ({int width, int height})? target =
        PixelSnapEngine.analysisTargetSize(sourceWidth, sourceHeight);
    if (target != null) {
      analysisRgb = downscaleRgb(
        rgb,
        sourceWidth,
        sourceHeight,
        target.width,
        target.height,
      );
      if (analysisAlpha != null) {
        analysisAlpha = downscaleAlpha(
          analysisAlpha,
          sourceWidth,
          sourceHeight,
          target.width,
          target.height,
        );
      }
      analysisWidth = target.width;
      analysisHeight = target.height;
    }

    final PixelSnapEngineResult result = await PixelSnapEngine.run(
      rgb: analysisRgb,
      alpha: analysisAlpha,
      width: analysisWidth,
      height: analysisHeight,
      params: params,
      parallel: parallel,
      onProgress: onProgress,
    );

    // 放大倍率按原始尺寸算，降采样过的图也能放回接近原来的大小。
    final int factor = params.upscale
        ? _atLeastOne(
            ((sourceWidth / result.width + sourceHeight / result.height) / 2)
                .round(),
          )
        : 1;

    final Uint8List snapped = _composeRgba(result);
    final Uint8List outputRgba = upscaleRgbaNearest(
      snapped,
      result.width,
      result.height,
      factor,
    );
    final int outputWidth = result.width * factor;
    final int outputHeight = result.height * factor;

    final img.Image out = img.Image.fromBytes(
      width: outputWidth,
      height: outputHeight,
      bytes: outputRgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    return PixelSnapOutput(
      pngBytes: img.encodePng(out),
      snappedWidth: result.width,
      snappedHeight: result.height,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
      pitchX: result.pitchX,
      pitchY: result.pitchY,
      paletteSize: result.paletteSize,
      downscaledForAnalysis: target != null,
    );
  }

  static Uint8List _composeRgba(PixelSnapEngineResult result) {
    final int count = result.width * result.height;
    final Uint8List out = Uint8List(count * 4);
    final Uint8List? alpha = result.alpha;
    for (int i = 0; i < count; i++) {
      out[4 * i] = result.rgb[3 * i];
      out[4 * i + 1] = result.rgb[3 * i + 1];
      out[4 * i + 2] = result.rgb[3 * i + 2];
      out[4 * i + 3] = alpha != null ? alpha[i] : 255;
    }
    return out;
  }

  static int _atLeastOne(int value) => value < 1 ? 1 : value;
}

class _AnalysisRequest {
  const _AnalysisRequest(this.reply, this.pngBytes, this.params);

  final SendPort reply;
  final Uint8List pngBytes;
  final PixelSnapEngineParams params;
}

class _ProgressMessage {
  const _ProgressMessage(this.progress);

  final PixelSnapProgress progress;
}

class _ResultMessage {
  const _ResultMessage(this.output);

  final PixelSnapOutput output;
}

class _FailureMessage {
  const _FailureMessage(this.error);

  final Object error;
}

Future<void> _analysisEntry(_AnalysisRequest request) async {
  try {
    final PixelSnapOutput output = await PixelSnapService.analyze(
      request.pngBytes,
      request.params,
      onProgress: (PixelSnapProgress progress) =>
          request.reply.send(_ProgressMessage(progress)),
    );
    request.reply.send(_ResultMessage(output));
  } catch (error) {
    try {
      request.reply.send(_FailureMessage(error));
    } on ArgumentError {
      // 第三方抛出的对象不一定能跨 isolate 传，退回文本。
      request.reply.send(_FailureMessage(PixelSnapFailure(error.toString())));
    }
  }
}
