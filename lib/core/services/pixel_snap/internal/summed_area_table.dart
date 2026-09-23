import 'dart:typed_data';

/// 六通道积分图：Σr Σg Σb Σr² Σg² Σb²。
///
/// 用它把"任意矩形内三通道标准差"降成 4 次查表，网格搜索才跑得动。
class SummedAreaTable {
  SummedAreaTable._(this.data, this.width, this.height) : stride = width + 1;

  /// 按 uint32 环绕累加。
  ///
  /// Σx² 在整图上会溢出 32 位，但取差得到的单个格子和仍在范围内，
  /// 模 2^32 的差值因此仍是准确值——环绕是刻意的，不是溢出 bug。
  factory SummedAreaTable.build(Uint8List rgb, int width, int height) {
    final int stride = width + 1;
    final Uint32List table = Uint32List((height + 1) * stride * 6);
    for (int y = 1; y <= height; y++) {
      final int up = (y - 1) * stride;
      final int cur = y * stride;
      for (int x = 1; x <= width; x++) {
        final int src = ((y - 1) * width + (x - 1)) * 3;
        final int r = rgb[src];
        final int g = rgb[src + 1];
        final int b = rgb[src + 2];
        final int o = (cur + x) * 6;
        final int oUp = (up + x) * 6;
        final int oLeft = (cur + x - 1) * 6;
        final int oUpLeft = (up + x - 1) * 6;
        table[o] = r + table[oUp] + table[oLeft] - table[oUpLeft];
        table[o + 1] =
            g + table[oUp + 1] + table[oLeft + 1] - table[oUpLeft + 1];
        table[o + 2] =
            b + table[oUp + 2] + table[oLeft + 2] - table[oUpLeft + 2];
        table[o + 3] =
            r * r + table[oUp + 3] + table[oLeft + 3] - table[oUpLeft + 3];
        table[o + 4] =
            g * g + table[oUp + 4] + table[oLeft + 4] - table[oUpLeft + 4];
        table[o + 5] =
            b * b + table[oUp + 5] + table[oLeft + 5] - table[oUpLeft + 5];
      }
    }
    return SummedAreaTable._(table, width, height);
  }

  final Uint32List data;
  final int width;
  final int height;

  /// 行跨度（像素），= width + 1。
  final int stride;
}
