/// Neon Glow Effect - Cyberpunk neon
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/effect_module.dart';

class NeonGlowEffect extends BaseEffectModule {
  final Color _glowColor;

  const NeonGlowEffect({Color glowColor = const Color(0xFFFF2975)})
      : _glowColor = glowColor;

  @override
  bool get enableGlassmorphism => false;

  @override
  bool get enableNeonGlow => true;

  @override
  TextureType get textureType => TextureType.none;

  @override
  Color? get glowColor => _glowColor;

  @override
  double get blurStrength => 0.0;
}
