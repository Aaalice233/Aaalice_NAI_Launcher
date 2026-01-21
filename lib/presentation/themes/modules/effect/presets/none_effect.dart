/// None Effect - No special effects (but with subtle inset shadow)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/effect_module.dart';

class NoneEffect extends BaseEffectModule {
  final bool _enableInsetShadow;
  final double _insetShadowDepth;
  final double _insetShadowBlur;

  const NoneEffect({
    bool enableInsetShadow = true,
    double insetShadowDepth = 0.12,
    double insetShadowBlur = 8.0,
  })  : _enableInsetShadow = enableInsetShadow,
        _insetShadowDepth = insetShadowDepth,
        _insetShadowBlur = insetShadowBlur;

  /// Completely flat - no effects at all
  const NoneEffect.flat()
      : _enableInsetShadow = false,
        _insetShadowDepth = 0.0,
        _insetShadowBlur = 0.0;

  @override
  bool get enableGlassmorphism => false;

  @override
  bool get enableNeonGlow => false;

  @override
  TextureType get textureType => TextureType.none;

  @override
  Color? get glowColor => null;

  @override
  double get blurStrength => 0.0;

  @override
  bool get enableInsetShadow => _enableInsetShadow;

  @override
  double get insetShadowDepth => _insetShadowDepth;

  @override
  double get insetShadowBlur => _insetShadowBlur;
}
