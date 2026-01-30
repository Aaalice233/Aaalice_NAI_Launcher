/// Shadow Module - Base Implementation
library;

import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';

export 'presets/none_shadow.dart';
export 'presets/soft_shadow.dart';
export 'presets/hard_offset_shadow.dart';
export 'presets/glow_shadow.dart';
export 'presets/layered_shadow.dart';

/// Base implementation of [ShadowModule].
abstract class BaseShadowModule implements ShadowModule {
  const BaseShadowModule();
}
