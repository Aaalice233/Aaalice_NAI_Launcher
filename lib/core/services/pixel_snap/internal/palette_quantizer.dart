import 'dart:math' as math;
import 'dart:typed_data';

import 'numeric_utils.dart';

/// sRGB 转 CIELAB（D65）。
///
/// 合并近似色必须在 LAB 里比距离：RGB 的欧氏距离和人眼感知差得太远，
/// 按它合并会先吃掉暗部层次。
List<double> rgbToLab(double r, double g, double b) {
  double linear(double channel) {
    final double c = channel / 255;
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final double lr = linear(r);
  final double lg = linear(g);
  final double lb = linear(b);

  double transfer(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;

  final double fx = transfer(
    (0.4124 * lr + 0.3576 * lg + 0.1805 * lb) / 0.95047,
  );
  final double fy = transfer(0.2126 * lr + 0.7152 * lg + 0.0722 * lb);
  final double fz = transfer(
    (0.0193 * lr + 0.1192 * lg + 0.9505 * lb) / 1.08883,
  );

  return <double>[116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

class _OctreeNode {
  _OctreeNode(this.isLeaf);

  bool isLeaf;
  int count = 0;
  int r = 0;
  int g = 0;
  int b = 0;
  List<_OctreeNode?>? kids;
}

class _PaletteEntry {
  _PaletteEntry(this.r, this.g, this.b, this.count) : lab = rgbToLab(r, g, b);

  double r;
  double g;
  double b;
  int count;
  List<double> lab;
}

/// 八叉树取色：按位逐层细分 RGB 空间，叶子数超限就折叠最冷门的分支。
List<_PaletteEntry> _buildOctreePalette(
  Float64List cells,
  int cellCount,
  int maxLeaves,
) {
  final List<List<_OctreeNode>> reducible = List<List<_OctreeNode>>.generate(
    8,
    (_) => <_OctreeNode>[],
  );
  final _OctreeNode root = _OctreeNode(false);
  int leaves = 0;

  void reduce() {
    int level = 7;
    while (level >= 0 && reducible[level].isEmpty) {
      level--;
    }
    if (level < 0) return;
    final List<_OctreeNode> bucket = reducible[level];
    int target = 0;
    for (int i = 1; i < bucket.length; i++) {
      if (bucket[i].count < bucket[target].count) target = i;
    }
    final _OctreeNode node = bucket.removeAt(target);
    int merged = 0;
    for (final _OctreeNode? kid in node.kids!) {
      if (kid == null) continue;
      node.r += kid.r;
      node.g += kid.g;
      node.b += kid.b;
      node.count += kid.count;
      merged++;
    }
    node.kids = null;
    node.isLeaf = true;
    leaves += 1 - merged;
  }

  for (int i = 0; i < cellCount; i++) {
    final int r = roundHalfEven(cells[3 * i]).clamp(0, 255);
    final int g = roundHalfEven(cells[3 * i + 1]).clamp(0, 255);
    final int b = roundHalfEven(cells[3 * i + 2]).clamp(0, 255);

    _OctreeNode node = root;
    int depth = 0;
    while (!node.isLeaf && depth < 8) {
      final int shift = 7 - depth;
      final int branch =
          ((r >> shift) & 1) << 2 |
          ((g >> shift) & 1) << 1 |
          ((b >> shift) & 1);
      if (node.kids == null) {
        node.kids = List<_OctreeNode?>.filled(8, null);
        reducible[depth].add(node);
      }
      if (node.kids![branch] == null) {
        final bool isLeaf = depth == 7;
        node.kids![branch] = _OctreeNode(isLeaf);
        if (isLeaf) leaves++;
      }
      node = node.kids![branch]!;
      depth++;
    }
    node.count++;
    node.r += r;
    node.g += g;
    node.b += b;
    while (leaves > maxLeaves) {
      reduce();
    }
  }

  final List<_PaletteEntry> palette = <_PaletteEntry>[];
  void collect(_OctreeNode node) {
    final List<_OctreeNode?>? kids = node.kids;
    if (kids != null) {
      for (final _OctreeNode? kid in kids) {
        if (kid != null) collect(kid);
      }
    } else if (node.count > 0) {
      palette.add(
        _PaletteEntry(
          node.r / node.count,
          node.g / node.count,
          node.b / node.count,
          node.count,
        ),
      );
    }
  }

  collect(root);
  return palette;
}

/// 量化结果。
class QuantizedCells {
  const QuantizedCells(this.rgb, this.paletteSize);

  final Float64List rgb;
  final int paletteSize;
}

/// 反复合并 LAB 距离最近的一对颜色，直到 [shouldStop] 说停。
///
/// 距离会按颜色的出现次数放大：只占几格的杂色更容易被吞掉，画面主色更难被动。
QuantizedCells _quantize(
  Float64List cells,
  int cellCount,
  int maxLeaves,
  bool Function(double distance, int paletteSize) shouldStop,
) {
  final List<_PaletteEntry> palette = _buildOctreePalette(
    cells,
    cellCount,
    maxLeaves,
  );

  double rarityBoost(int count) {
    return 1 +
        math.max(
          math.max(0, 1 - count / cellCount / 0.02),
          3 * math.max(0, 1 - count / 16),
        );
  }

  while (palette.length > 1) {
    int leftIndex = -1;
    int rightIndex = -1;
    double closest = double.infinity;
    for (int i = 0; i < palette.length; i++) {
      for (int j = i + 1; j < palette.length; j++) {
        final _PaletteEntry a = palette[i];
        final _PaletteEntry b = palette[j];
        final double dl = a.lab[0] - b.lab[0];
        final double da = a.lab[1] - b.lab[1];
        final double db = a.lab[2] - b.lab[2];
        final double distance =
            math.sqrt(dl * dl + da * da + db * db) /
            rarityBoost(math.min(a.count, b.count));
        if (distance < closest) {
          closest = distance;
          leftIndex = i;
          rightIndex = j;
        }
      }
    }
    if (shouldStop(closest, palette.length)) break;

    final _PaletteEntry left = palette[leftIndex];
    final _PaletteEntry right = palette[rightIndex];
    final int total = left.count + right.count;
    left.r = (left.r * left.count + right.r * right.count) / total;
    left.g = (left.g * left.count + right.g * right.count) / total;
    left.b = (left.b * left.count + right.b * right.count) / total;
    left.count = total;
    left.lab = rgbToLab(left.r, left.g, left.b);
    palette.removeAt(rightIndex);
  }

  final Float64List out = Float64List(3 * cellCount);
  final Set<int> used = <int>{};
  for (int i = 0; i < cellCount; i++) {
    final List<double> lab = rgbToLab(
      cells[3 * i],
      cells[3 * i + 1],
      cells[3 * i + 2],
    );
    int nearest = 0;
    double best = double.infinity;
    for (int p = 0; p < palette.length; p++) {
      final List<double> candidate = palette[p].lab;
      final double dl = lab[0] - candidate[0];
      final double da = lab[1] - candidate[1];
      final double db = lab[2] - candidate[2];
      final double distance = dl * dl + da * da + db * db;
      if (distance < best) {
        best = distance;
        nearest = p;
      }
    }
    used.add(nearest);
    out[3 * i] = palette[nearest].r;
    out[3 * i + 1] = palette[nearest].g;
    out[3 * i + 2] = palette[nearest].b;
  }
  return QuantizedCells(out, used.length);
}

/// 自动定色数：合并到最近一对颜色的距离超过 [tolerance] 为止。
QuantizedCells quantizeAuto(
  Float64List cells,
  int cellCount,
  double tolerance,
) {
  if (cellCount == 0) {
    return QuantizedCells(Float64List.fromList(cells), 0);
  }
  return _quantize(
    cells,
    cellCount,
    256,
    (double distance, int _) => distance > tolerance,
  );
}

/// 固定色数。
QuantizedCells quantizeToCount(
  Float64List cells,
  int cellCount,
  int targetColors,
) {
  if (cellCount == 0) {
    return QuantizedCells(Float64List.fromList(cells), 0);
  }
  return _quantize(
    cells,
    cellCount,
    math.max(256, targetColors),
    (double _, int paletteSize) => paletteSize <= targetColors,
  );
}
