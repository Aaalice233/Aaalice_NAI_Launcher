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

  // Bouncy curves for playful feel
  @override
  Curve get enterCurve => Curves.elasticOut;

  @override
  Curve get exitCurve => Curves.easeIn;

  @override
  Curve get standardCurve => Curves.bounceOut;
}
