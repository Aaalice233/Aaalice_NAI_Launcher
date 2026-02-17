import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Vibe 详情页沉浸式背景
///
/// 三层叠加结构：
/// 1. 模糊放大的图片（σ=30）
/// 2. 暗色线性渐变遮罩
/// 3. 无图片时纯黑兜底
class VibeDetailBackground extends StatelessWidget {
  /// 背景图片数据
  final Uint8List? imageBytes;

  const VibeDetailBackground({
    super.key,
    this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBytes == null) {
      return const ColoredBox(color: Colors.black);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: 模糊背景图
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: 30,
            sigmaY: 30,
            tileMode: TileMode.decal,
          ),
          child: Image.memory(
            imageBytes!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: Colors.black),
          ),
        ),

        // Layer 2: 暗色渐变遮罩
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
