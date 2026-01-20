/// Retro Typography - Bold Retro style
///
/// Display: Montserrat (geometric sans-serif)
/// Body: Open Sans (clean, readable)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/typography_module.dart';

class RetroTypography extends BaseTypographyModule {
  const RetroTypography();

  @override
  String get displayFontFamily => 'Montserrat';

  @override
  String get bodyFontFamily => 'Open Sans';

  @override
  TextTheme get textTheme => BaseTypographyModule.createTextTheme(
        displayFamily: displayFontFamily,
        bodyFamily: bodyFontFamily,
      );
}
