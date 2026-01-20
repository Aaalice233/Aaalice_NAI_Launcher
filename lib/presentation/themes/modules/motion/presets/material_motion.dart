/// Material Motion - MD3 standard curves
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/motion_module.dart';

class MaterialMotion extends BaseMotionModule {
  const MaterialMotion();

  @override
  Duration get fastDuration => const Duration(milliseconds: 150);

  @override
  Duration get normalDuration => const Duration(milliseconds: 300);

  @override
  Duration get slowDuration => const Duration(milliseconds: 400);

  // MD3 curves: cubic-bezier(0.2, 0, 0, 1)
  @override
  Curve get enterCurve => const Cubic(0.2, 0, 0, 1);

  @override
  Curve get exitCurve => const Cubic(0.4, 0, 1, 1);

  @override
  Curve get standardCurve => const Cubic(0.2, 0, 0, 1);
}
