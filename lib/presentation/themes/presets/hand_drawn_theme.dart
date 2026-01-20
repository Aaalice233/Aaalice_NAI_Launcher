/// Hand-Drawn Theme Preset
///
/// 手绘风格主题 - 不规则边框、纸纹纹理、硬偏移阴影
/// Reference: docs/UI设计提示词合集/第七套UI.txt
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/hand_drawn_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/hand_drawn_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/wobbly_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/presets/hard_offset_shadow.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/jitter_motion.dart';
import 'package:nai_launcher/presentation/themes/modules/divider/none_divider.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Hand-Drawn theme configuration.
///
/// Combines:
/// - HandDrawnPalette (#FDFBF7, #2D2D2D, #FF4D4D)
/// - HandDrawnTypography (Kalam + Patrick Hand)
/// - WobblyShapes (irregular hand-drawn borders)
/// - HardOffsetShadow (4px 4px 0)
/// - TextureEffect (paper grain texture - paperGrain)
/// - JitterMotion (playful, bouncy movement)
///
/// Note: This theme only supports light mode.
class HandDrawnTheme {
  const HandDrawnTheme._();

  /// Custom texture effect that uses paperGrain instead of grunge
  static const _paperTextureEffect = _PaperTextureEffect();

  static const _composer = ThemeComposer(
    color: HandDrawnPalette(),
    typography: HandDrawnTypography(),
    shape: WobblyShapes(),
    shadow: HardOffsetShadow(),
    effect: _paperTextureEffect,
    motion: JitterMotion(),
    divider: NoneDividerModule(),
  );

  /// The light theme.
  static ThemeData get light => _composer.buildTheme(Brightness.light);

  /// The dark theme (falls back to light as this theme doesn't support dark mode).
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);

  /// The theme extension for light mode.
  static AppThemeExtension get lightExtension =>
      _composer.buildExtension(Brightness.light);

  /// The theme extension for dark mode.
  static AppThemeExtension get darkExtension =>
      _composer.buildExtension(Brightness.dark);

  /// Whether this theme supports dark mode.
  static bool get supportsDarkMode => false;

  /// Theme display name.
  static String get displayName => 'Hand-Drawn';

  /// Theme description.
  static String get description =>
      '手绘风格 - 不规则边框、纸纹纹理、可爱手写字体的温馨设计';
}

/// Paper texture effect (uses paperGrain instead of grunge)
class _PaperTextureEffect implements EffectModule {
  const _PaperTextureEffect();

  @override
  bool get enableGlassmorphism => false;

  @override
  bool get enableNeonGlow => false;

  @override
  TextureType get textureType => TextureType.paperGrain;

  @override
  Color? get glowColor => null;

  @override
  double get blurStrength => 0.0;
}
