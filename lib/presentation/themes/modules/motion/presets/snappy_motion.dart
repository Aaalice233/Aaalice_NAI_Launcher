/// Snappy Motion - Quick, responsive animations
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/motion_module.dart';

class SnappyMotion extends BaseMotionModule {
  const SnappyMotion();

  @override
  Duration get fastDuration => const Duration(milliseconds: 100);

  @override
  Duration get normalDuration => const Duration(milliseconds: 150);

  @override
  Duration get slowDuration => const Duration(milliseconds: 200);

  @override
  Curve get enterCurve => Curves.easeOutExpo;

  @override
  Curve get exitCurve => Curves.easeInExpo;

  @override
  Curve get standardCurve => Curves.easeOutExpo;
}
