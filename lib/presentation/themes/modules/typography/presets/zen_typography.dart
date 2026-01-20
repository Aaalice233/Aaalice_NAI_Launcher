/// Zen Typography - Calm minimalist style
///
/// Display/Body: Plus Jakarta Sans (modern, clean)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/typography_module.dart';

class ZenTypography extends BaseTypographyModule {
  const ZenTypography();

  @override
  String get displayFontFamily => 'Plus Jakarta Sans';

  @override
  String get bodyFontFamily => 'Plus Jakarta Sans';

  @override
  TextTheme get textTheme => BaseTypographyModule.createTextTheme(
        displayFamily: displayFontFamily,
        bodyFamily: bodyFontFamily,
      );
}
