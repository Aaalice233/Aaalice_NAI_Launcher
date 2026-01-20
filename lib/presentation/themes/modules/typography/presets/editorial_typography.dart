/// Editorial Typography - Sophisticated magazine style
///
/// Display/Body: Inter (fallback for Satoshi, which is not on Google Fonts)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/typography_module.dart';

class EditorialTypography extends BaseTypographyModule {
  const EditorialTypography();

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
