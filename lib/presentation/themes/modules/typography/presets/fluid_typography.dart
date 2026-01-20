/// Fluid Typography - Modern fluid style
///
/// Display/Body: Inter (highly legible, variable)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/typography_module.dart';

class FluidTypography extends BaseTypographyModule {
  const FluidTypography();

  @override
  String get displayFontFamily => 'Inter';

  @override
  String get bodyFontFamily => 'Inter';

  @override
  TextTheme get textTheme => BaseTypographyModule.createTextTheme(
        displayFamily: displayFontFamily,
        bodyFamily: bodyFontFamily,
      );
}
