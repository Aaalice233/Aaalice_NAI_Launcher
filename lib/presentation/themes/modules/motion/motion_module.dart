/// Motion Module - Base Implementation
library;

import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';

export 'presets/zen_motion.dart';
export 'presets/material_motion.dart';
export 'presets/jitter_motion.dart';
export 'presets/snappy_motion.dart';

/// Base implementation of [MotionModule].
abstract class BaseMotionModule implements MotionModule {
  const BaseMotionModule();
}
