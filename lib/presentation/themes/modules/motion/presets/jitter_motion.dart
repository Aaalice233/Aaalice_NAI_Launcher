/// Jitter Motion - Shaky, hand-drawn feel
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/motion_module.dart';

class JitterMotion extends BaseMotionModule {
  const JitterMotion();

  @override
  Duration get fastDuration => const Duration(milliseconds: 100);

  @override
  Duration get normalDuration => const Duration(milliseconds: 200);

  @override
  Duration get slowDuration => const Duration(milliseconds: 300);

  // Keep the preset brisk without moving controls past their final geometry.
  @override
  Curve get enterCurve => Curves.easeOutCubic;

  @override
  Curve get exitCurve => Curves.easeInCubic;

  @override
  Curve get standardCurve => Curves.easeInOutCubic;
}
