/// Zen Motion - Calm, smooth animations
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/motion_module.dart';

class ZenMotion extends BaseMotionModule {
  const ZenMotion();

  @override
  Duration get fastDuration => const Duration(milliseconds: 200);

  @override
  Duration get normalDuration => const Duration(milliseconds: 350);

  @override
  Duration get slowDuration => const Duration(milliseconds: 500);

  @override
  Curve get enterCurve => Curves.easeOutCubic;

  @override
  Curve get exitCurve => Curves.easeInCubic;

  @override
  Curve get standardCurve => Curves.easeInOutCubic;
}
