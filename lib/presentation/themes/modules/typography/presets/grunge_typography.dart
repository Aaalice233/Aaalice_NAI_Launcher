/// Grunge Typography - Distressed punk style
///
/// Display: Oswald (condensed, impactful)
/// Body: Courier Prime (typewriter feel)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/typography_module.dart';

class GrungeTypography extends BaseTypographyModule {
  const GrungeTypography();

  @override
  String get displayFontFamily => 'Oswald';

  @override
  String get bodyFontFamily => 'Courier Prime';

  @override
  TextTheme get textTheme => BaseTypographyModule.createTextTheme(
        displayFamily: displayFontFamily,
        bodyFamily: bodyFontFamily,
      );
}
