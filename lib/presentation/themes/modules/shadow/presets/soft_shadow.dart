/// Soft Shadow - Zen-inspired diffused shadows
///
/// Design Reference: docs/UI设计提示词合集/默认主题.txt
/// - box-shadow: 0 4px 24px -1px rgba(0, 0, 0, 0.2)
/// - Very soft, large blur radius for premium feel
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/shadow_module.dart';

class SoftShadow extends BaseShadowModule {
  const SoftShadow();

  @override
  List<BoxShadow> get elevation1 => const [
        BoxShadow(
          color: Color(0x1A000000), // 0.1 opacity
          blurRadius: 8,
          spreadRadius: -1,
          offset: Offset(0, 2),
        ),
      ];

  @override
  List<BoxShadow> get elevation2 => const [
        BoxShadow(
          color: Color(0x26000000), // 0.15 opacity
          blurRadius: 16,
          spreadRadius: -1,
          offset: Offset(0, 3),
        ),
      ];

  @override
  List<BoxShadow> get elevation3 => const [
        BoxShadow(
          color: Color(0x33000000), // 0.2 opacity - matches design spec
          blurRadius: 24,
          spreadRadius: -1,
          offset: Offset(0, 4),
        ),
      ];

  /// Card shadow matching design spec exactly:
  /// box-shadow: 0 4px 24px -1px rgba(0, 0, 0, 0.2)
  @override
  List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x33000000), // rgba(0,0,0,0.2)
          blurRadius: 24,
          spreadRadius: -1,
          offset: Offset(0, 4),
        ),
      ];
}
