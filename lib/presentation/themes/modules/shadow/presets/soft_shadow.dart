/// Soft Shadow - Subtle, diffused shadows
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/shadow_module.dart';

class SoftShadow extends BaseShadowModule {
  const SoftShadow();

  @override
  List<BoxShadow> get elevation1 => const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ];

  @override
  List<BoxShadow> get elevation2 => const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ];

  @override
  List<BoxShadow> get elevation3 => const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  @override
  List<BoxShadow> get cardShadow => elevation2;
}
