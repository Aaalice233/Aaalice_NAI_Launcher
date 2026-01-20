/// Hard Offset Shadow - Hand-drawn style (4px 4px 0)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/shadow_module.dart';

class HardOffsetShadow extends BaseShadowModule {
  const HardOffsetShadow();

  static const Color _shadowColor = Color(0xFF2D2D2D);

  @override
  List<BoxShadow> get elevation1 => const [
        BoxShadow(
          color: _shadowColor,
          blurRadius: 0,
          offset: Offset(2, 2),
        ),
      ];

  @override
  List<BoxShadow> get elevation2 => const [
        BoxShadow(
          color: _shadowColor,
          blurRadius: 0,
          offset: Offset(4, 4),
        ),
      ];

  @override
  List<BoxShadow> get elevation3 => const [
        BoxShadow(
          color: _shadowColor,
          blurRadius: 0,
          offset: Offset(6, 6),
        ),
      ];

  @override
  List<BoxShadow> get cardShadow => elevation2;
}
