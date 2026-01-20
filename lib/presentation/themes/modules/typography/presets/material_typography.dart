/// Material Typography - Google Material Design 3
///
/// Display/Body: Roboto (Material default)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/typography_module.dart';

class MaterialTypography extends BaseTypographyModule {
  const MaterialTypography();

  @override
  String get displayFontFamily => 'Roboto';

  @override
  String get bodyFontFamily => 'Roboto';

  @override
  TextTheme get textTheme => BaseTypographyModule.createTextTheme(
        displayFamily: displayFontFamily,
        bodyFamily: bodyFontFamily,
      );
}
