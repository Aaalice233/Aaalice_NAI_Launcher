/// Glassmorphism Effect - Frosted glass with subtle depth
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/effect_module.dart';

class GlassmorphismEffect extends BaseEffectModule {
  final double _blurStrength;
  final double _insetShadowDepth;
  final double _insetShadowBlur;

  const GlassmorphismEffect({
    double blurStrength = 12.0,
    double insetShadowDepth = 0.1,
    double insetShadowBlur = 6.0,
  })  : _blurStrength = blurStrength,
        _insetShadowDepth = insetShadowDepth,
        _insetShadowBlur = insetShadowBlur;

  @override
  bool get enableGlassmorphism => true;

  @override
  bool get enableNeonGlow => false;

  @override
  TextureType get textureType => TextureType.none;

  @override
  Color? get glowColor => null;

  @override
  double get blurStrength => _blurStrength;

  @override
  bool get enableInsetShadow => true;

  @override
  double get insetShadowDepth => _insetShadowDepth;

  @override
  double get insetShadowBlur => _insetShadowBlur;
}
