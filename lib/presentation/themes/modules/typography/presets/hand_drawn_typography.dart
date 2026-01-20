/// Hand-Drawn Typography - Sketchy casual style
///
/// Display: Kalam (handwritten)
/// Body: Patrick Hand (casual handwriting)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/typography_module.dart';

class HandDrawnTypography extends BaseTypographyModule {
  const HandDrawnTypography();

  @override
  String get displayFontFamily => 'Kalam';

  @override
  String get bodyFontFamily => 'Patrick Hand';

  @override
  TextTheme get textTheme => BaseTypographyModule.createTextTheme(
        displayFamily: displayFontFamily,
        bodyFamily: bodyFontFamily,
      );
}
