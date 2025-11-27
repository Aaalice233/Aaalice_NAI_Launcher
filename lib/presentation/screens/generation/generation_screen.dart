import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/image_generation_provider.dart';
import 'desktop_layout.dart';
import 'mobile_layout.dart';

/// 图像生成页面
class GenerationScreen extends ConsumerWidget {
  const GenerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 桌面端布局 (宽度 >= 1000)
        if (constraints.maxWidth >= 1000) {
          return const DesktopGenerationLayout();
        }

        // 移动端布局
        return const MobileGenerationLayout();
      },
    );
  }
}
