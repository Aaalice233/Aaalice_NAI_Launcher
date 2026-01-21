/// Texture Effect - Paper/grunge overlays with subtle depth
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/effect_module.dart';

class TextureEffect extends BaseEffectModule {
  final TextureType _textureType;
  final bool _enableInsetShadow;
  final double _insetShadowDepth;
  final double _insetShadowBlur;

  const TextureEffect({
    TextureType textureType = TextureType.paperGrain,
    bool enableInsetShadow = true,
    double insetShadowDepth = 0.08,
    double insetShadowBlur = 6.0,
  })  : _textureType = textureType,
        _enableInsetShadow = enableInsetShadow,
        _insetShadowDepth = insetShadowDepth,
        _insetShadowBlur = insetShadowBlur;

  /// Paper grain texture (Hand-drawn style)
  const TextureEffect.paper()
      : _textureType = TextureType.paperGrain,
        _enableInsetShadow = true,
        _insetShadowDepth = 0.06,
        _insetShadowBlur = 4.0;

  /// Grunge texture (Punk/distressed style) - deeper shadows
  const TextureEffect.grunge()
      : _textureType = TextureType.grunge,
        _enableInsetShadow = true,
        _insetShadowDepth = 0.15,
        _insetShadowBlur = 8.0;

  /// Halftone dot texture (Print media style)
  const TextureEffect.halftone()
      : _textureType = TextureType.halftone,
        _enableInsetShadow = true,
        _insetShadowDepth = 0.1,
        _insetShadowBlur = 6.0;

  /// Dot matrix texture (Terminal style) - sharp shadows
  const TextureEffect.dotMatrix()
      : _textureType = TextureType.dotMatrix,
        _enableInsetShadow = true,
        _insetShadowDepth = 0.18,
        _insetShadowBlur = 4.0;

  @override
  bool get enableGlassmorphism => false;

  @override
  bool get enableNeonGlow => false;

  @override
  TextureType get textureType => _textureType;

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
