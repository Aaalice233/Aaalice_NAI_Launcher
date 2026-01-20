/// Texture Effect - Paper/grunge overlays
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/effect_module.dart';

class TextureEffect extends BaseEffectModule {
  final TextureType _textureType;

  const TextureEffect({TextureType textureType = TextureType.paperGrain})
      : _textureType = textureType;

  /// Paper grain texture (Hand-drawn style)
  const TextureEffect.paper() : _textureType = TextureType.paperGrain;

  /// Grunge texture (Punk/distressed style)
  const TextureEffect.grunge() : _textureType = TextureType.grunge;

  /// Halftone dot texture (Print media style)
  const TextureEffect.halftone() : _textureType = TextureType.halftone;

  /// Dot matrix texture (Terminal style)
  const TextureEffect.dotMatrix() : _textureType = TextureType.dotMatrix;

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
}
