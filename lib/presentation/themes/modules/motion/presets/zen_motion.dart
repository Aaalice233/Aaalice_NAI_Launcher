/// Zen Motion - Calm, meditative animations
///
/// Design Reference: docs/UI设计提示词合集/默认主题.txt
/// - Animation duration: 1.2s for slow transitions
/// - Curve: cubic-bezier(0.2, 0.8, 0.2, 1) - gentle ease-out
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/motion_module.dart';

/// Custom curve matching design spec: cubic-bezier(0.2, 0.8, 0.2, 1)
const _zenCurve = Cubic(0.2, 0.8, 0.2, 1.0);

class ZenMotion extends BaseMotionModule {
  const ZenMotion();

  @override
  Duration get fastDuration => const Duration(milliseconds: 400);

  @override
  Duration get normalDuration => const Duration(milliseconds: 800);

  @override
  Duration get slowDuration => const Duration(milliseconds: 1200);

  @override
  Curve get enterCurve => _zenCurve;

  @override
  Curve get exitCurve => Curves.easeInCubic;

  @override
  Curve get standardCurve => _zenCurve;
}
