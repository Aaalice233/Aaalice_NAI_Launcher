import 'dart:math' as math;
import 'dart:typed_data';

final Float32List _froundScratch = Float32List(1);

/// 把 double 截断到 float32 精度。
///
/// spread kernel 必须逐步截断到单精度，否则结果和官网的 GPU/SIMD 后端对不上。
double fround(double value) {
  _froundScratch[0] = value;
  return _froundScratch[0];
}

/// 四舍六入五成双。
///
/// Dart 的 `round()` 是五入away-from-zero，和这里要复刻的取整规则不同，
/// 混用会让网格边界整体偏移一个像素。
int roundHalfEven(double value) {
  final int floor = value.floor();
  final double frac = value - floor;
  if (frac < 0.5) return floor;
  if (frac > 0.5) return floor + 1;
  return floor.isEven ? floor : floor + 1;
}

/// 结果恒为非负的取模。
double positiveMod(double value, double modulus) {
  final double r = value % modulus;
  return r < 0 ? r + modulus : r;
}

/// 含端点的等距序列，末位强制等于 [end] 以消掉累积误差。
Float64List linspace(double start, double end, int count) {
  final Float64List out = Float64List(count);
  if (count == 1) {
    out[0] = start;
    return out;
  }
  final double step = (end - start) / (count - 1);
  for (int i = 0; i < count; i++) {
    out[i] = i * step + start;
  }
  out[count - 1] = end;
  return out;
}

/// 线性插值分位数，[percent] 取 0-100。
double percentile(List<double> values, double percent) {
  final int n = values.length;
  if (n == 0) return double.nan;
  final Float64List sorted = Float64List.fromList(values)..sort();
  if (n == 1) return sorted[0];
  final double pos = percent / 100 * (n - 1);
  final int lo = pos.floor();
  final int hi = pos.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

/// 分块累加求和。
///
/// 直接顺序累加会在几十万项的差分曲线上积出可见误差，改变候选间距的排序。
double blockSum(List<double> data, int offset, int count) {
  if (count < 8) {
    double sum = 0;
    for (int i = 0; i < count; i++) {
      sum += data[offset + i];
    }
    return sum;
  }
  if (count <= 128) {
    double a0 = data[offset];
    double a1 = data[offset + 1];
    double a2 = data[offset + 2];
    double a3 = data[offset + 3];
    double a4 = data[offset + 4];
    double a5 = data[offset + 5];
    double a6 = data[offset + 6];
    double a7 = data[offset + 7];
    final int unrolled = count - count % 8;
    int i = 8;
    for (; i < unrolled; i += 8) {
      a0 += data[offset + i];
      a1 += data[offset + i + 1];
      a2 += data[offset + i + 2];
      a3 += data[offset + i + 3];
      a4 += data[offset + i + 4];
      a5 += data[offset + i + 5];
      a6 += data[offset + i + 6];
      a7 += data[offset + i + 7];
    }
    double sum = a0 + a1 + (a2 + a3) + (a4 + a5 + (a6 + a7));
    for (; i < count; i++) {
      sum += data[offset + i];
    }
    return sum;
  }
  int half = count ~/ 2;
  half -= half % 8;
  return blockSum(data, offset, half) +
      blockSum(data, offset + half, count - half);
}

/// 取中位数，只看 [data] 的前 [count] 项，会就地重排这段前缀。
///
/// 调用方传的都是每格重填的 scratch buffer，省掉逐格拷贝。
double medianOfPrefixInPlace(Float64List data, int count) {
  if (count == 0) return 0;
  final Float64List prefix = Float64List.sublistView(data, 0, count)..sort();
  final int mid = count >> 1;
  if (count.isOdd) return prefix[mid];
  return (prefix[mid - 1] + prefix[mid]) / 2;
}

/// `[0, 1)` 上的等距相位序列。
Float64List phaseGrid(int count) {
  final Float64List out = Float64List(count);
  for (int i = 0; i < count; i++) {
    out[i] = i / count;
  }
  return out;
}

/// 高斯平滑（`same` 卷积），[sigma] 决定核半径 `max(1, trunc(3σ))`。
Float64List gaussianSmooth(Float64List signal, double sigma) {
  final int radius = math.max(1, (3 * sigma).truncate());
  final int size = 2 * radius + 1;
  final Float64List kernel = Float64List(size);
  double total = 0;
  for (int i = 0, k = -radius; k <= radius; k++, i++) {
    kernel[i] = math.exp(-0.5 * math.pow(k / sigma, 2));
    total += kernel[i];
  }
  for (int i = 0; i < size; i++) {
    kernel[i] /= total;
  }

  final int n = signal.length;
  final int full = n + size - 1;
  final Float64List convolved = Float64List(full);
  for (int i = 0; i < full; i++) {
    double acc = 0;
    final int lo = math.max(0, i - (n - 1));
    final int hi = math.min(size - 1, i);
    for (int k = lo; k <= hi; k++) {
      acc += kernel[k] * signal[i - k];
    }
    convolved[i] = acc;
  }
  final int start = (size - 1) >> 1;
  return Float64List.fromList(convolved.sublist(start, start + n));
}

/// 把 double 数组夹到 `[0, 255]` 并按四舍六入五成双落到字节。
Uint8List toClampedBytes(Float64List values) {
  final Uint8List out = Uint8List(values.length);
  for (int i = 0; i < values.length; i++) {
    final int v = roundHalfEven(values[i]);
    out[i] = v < 0 ? 0 : (v > 255 ? 255 : v);
  }
  return out;
}
