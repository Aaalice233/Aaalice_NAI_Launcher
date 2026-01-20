/// None Shadow - Flat design, no shadows
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/shadow_module.dart';

class NoneShadow extends BaseShadowModule {
  const NoneShadow();

  @override
  List<BoxShadow> get elevation1 => const [];

  @override
  List<BoxShadow> get elevation2 => const [];

  @override
  List<BoxShadow> get elevation3 => const [];

  @override
  List<BoxShadow> get cardShadow => const [];
}
