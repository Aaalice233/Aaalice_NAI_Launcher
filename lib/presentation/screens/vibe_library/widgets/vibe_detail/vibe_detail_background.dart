import 'package:flutter/material.dart';

/// Vibe 详情页背景
///
/// 纯黑色不透明背景，与本地画廊图像详情保持一致
class VibeDetailBackground extends StatelessWidget {
  const VibeDetailBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
    );
  }
}
