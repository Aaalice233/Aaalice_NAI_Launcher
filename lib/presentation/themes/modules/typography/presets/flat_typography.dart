/// Flat Typography - Clean minimal style
///
/// Display/Body: Outfit (geometric, clean)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/typography_module.dart';

class FlatTypography extends BaseTypographyModule {
  const FlatTypography();

  @override
  String get displayFontFamily => 'Outfit';

  @override
  String get bodyFontFamily => 'Outfit';

  @override
  TextTheme get textTheme => BaseTypographyModule.createTextTheme(
        displayFamily: displayFontFamily,
        bodyFamily: bodyFontFamily,
      );
}
