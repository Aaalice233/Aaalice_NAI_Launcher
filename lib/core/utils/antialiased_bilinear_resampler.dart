import 'dart:math' as math;
import 'dart:typed_data';

// 与 torchvision antialias=True 的双线性缩放一致：缩小时三角核按比例展宽，
// 先横向后纵向，尺寸不变的轴不参与计算
abstract final class AntialiasedBilinearResampler {
  // rgb 为逐行紧密排列的 8 位 RGB，结果按 R、G、B 分平面，取值 0..1
  static Float32List resizeRgbToPlanes(
    Uint8List rgb, {
    required int sourceWidth,
    required int sourceHeight,
    required int targetWidth,
    required int targetHeight,
  }) {
    if (rgb.length < sourceWidth * sourceHeight * 3) {
      throw ArgumentError.value(rgb.length, 'rgb', 'Too few RGB samples');
    }
    final horizontal = sourceWidth == targetWidth
        ? null
        : _ResampleKernel.build(sourceWidth, targetWidth);
    final vertical = sourceHeight == targetHeight
        ? null
        : _ResampleKernel.build(sourceHeight, targetHeight);
    final planeSize = targetWidth * targetHeight;
    final planes = Float32List(planeSize * 3);
    final rows = Float32List(sourceHeight * targetWidth);

    for (var channel = 0; channel < 3; channel++) {
      _resampleRows(
        rgb,
        channel: channel,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        targetWidth: targetWidth,
        kernel: horizontal,
        rows: rows,
      );
      _resampleColumns(
        rows,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        kernel: vertical,
        plane: Float32List.sublistView(
          planes,
          channel * planeSize,
          (channel + 1) * planeSize,
        ),
      );
    }
    return planes;
  }

  static void _resampleRows(
    Uint8List rgb, {
    required int channel,
    required int sourceWidth,
    required int sourceHeight,
    required int targetWidth,
    required _ResampleKernel? kernel,
    required Float32List rows,
  }) {
    for (var y = 0; y < sourceHeight; y++) {
      final sourceRow = y * sourceWidth * 3 + channel;
      final targetRow = y * targetWidth;
      for (var x = 0; x < targetWidth; x++) {
        if (kernel == null) {
          rows[targetRow + x] = rgb[sourceRow + x * 3] / 255;
          continue;
        }
        final start = kernel.starts[x];
        final weightOffset = x * kernel.stride;
        var sum = 0.0;
        for (var tap = 0; tap < kernel.sizes[x]; tap++) {
          sum +=
              kernel.weights[weightOffset + tap] *
              rgb[sourceRow + (start + tap) * 3];
        }
        rows[targetRow + x] = sum / 255;
      }
    }
  }

  static void _resampleColumns(
    Float32List rows, {
    required int targetWidth,
    required int targetHeight,
    required _ResampleKernel? kernel,
    required Float32List plane,
  }) {
    if (kernel == null) {
      plane.setRange(0, targetWidth * targetHeight, rows);
      return;
    }
    for (var y = 0; y < targetHeight; y++) {
      final start = kernel.starts[y];
      final weightOffset = y * kernel.stride;
      final targetRow = y * targetWidth;
      for (var x = 0; x < targetWidth; x++) {
        var sum = 0.0;
        for (var tap = 0; tap < kernel.sizes[y]; tap++) {
          sum +=
              kernel.weights[weightOffset + tap] *
              rows[(start + tap) * targetWidth + x];
        }
        plane[targetRow + x] = sum;
      }
    }
  }
}

final class _ResampleKernel {
  const _ResampleKernel._(this.starts, this.sizes, this.weights, this.stride);

  final Int32List starts;
  final Int32List sizes;
  final Float32List weights;
  final int stride;

  // torch 对 float32 输入在 float32 下算采样中心与权重，千像素级坐标的取整差会让
  // 结果偏离约 1e-4，这里在相同位置做 float32 取整以逐值对齐
  factory _ResampleKernel.build(int inputSize, int outputSize) {
    final scale = _f32(inputSize / outputSize);
    final support = scale >= 1 ? scale : 1.0;
    final inverseScale = scale >= 1 ? _f32(1 / scale) : 1.0;
    final stride = support.ceil() * 2 + 1;
    final starts = Int32List(outputSize);
    final sizes = Int32List(outputSize);
    final weights = Float32List(outputSize * stride);

    for (var index = 0; index < outputSize; index++) {
      final center = _f32(scale * (index + 0.5));
      final start = math.max((_f32(center - support) + 0.5).truncate(), 0);
      final end = math.min(
        (_f32(center + support) + 0.5).truncate(),
        inputSize,
      );
      final size = math.min(end - start, stride);
      final offset = index * stride;
      var total = 0.0;
      for (var tap = 0; tap < size; tap++) {
        final distance = _f32(tap + start - center) + 0.5;
        final weight = _triangle(_f32(distance * inverseScale));
        weights[offset + tap] = weight;
        total = _f32(total + weight);
      }
      if (total != 0) {
        for (var tap = 0; tap < size; tap++) {
          weights[offset + tap] = weights[offset + tap] / total;
        }
      }
      starts[index] = start;
      sizes[index] = size;
    }
    return _ResampleKernel._(starts, sizes, weights, stride);
  }

  static final Float32List _float32Scratch = Float32List(1);

  static double _f32(double value) {
    _float32Scratch[0] = value;
    return _float32Scratch[0];
  }

  static double _triangle(double x) {
    final distance = x.abs();
    return distance < 1 ? _f32(1 - distance) : 0;
  }
}
