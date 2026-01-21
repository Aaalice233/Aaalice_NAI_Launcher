/// Neon Glow Effect - Cyberpunk neon with deep inset shadows
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/effect_module.dart';

class NeonGlowEffect extends BaseEffectModule {
  final Color _glowColor;
  final double _insetShadowDepth;
  final double _insetShadowBlur;

  const NeonGlowEffect({
    Color glowColor = const Color(0xFFFF2975),
    double insetShadowDepth = 0.2,
    double insetShadowBlur = 10.0,
  })  : _glowColor = glowColor,
        _insetShadowDepth = insetShadowDepth,
        _insetShadowBlur = insetShadowBlur;

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

  @override
  bool get enableInsetShadow => true;

  @override
  double get insetShadowDepth => _insetShadowDepth;

  @override
  double get insetShadowBlur => _insetShadowBlur;
}
