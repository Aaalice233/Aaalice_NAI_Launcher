/// Effect Module - Base Implementation
library;

import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';

export 'presets/none_effect.dart';
export 'presets/glassmorphism_effect.dart';
export 'presets/neon_glow_effect.dart';
export 'presets/texture_effect.dart';

/// Base implementation of [EffectModule].
abstract class BaseEffectModule implements EffectModule {
  const BaseEffectModule();
}
