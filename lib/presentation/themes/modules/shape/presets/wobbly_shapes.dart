/// 手绘主题使用的轻微非对称轮廓。
///
/// 不用粗描边模拟“手绘”，而让四角半径略有差异；这样主题仍保留性格，
/// 又不会把所有控件变成高对比线框。
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/shape_module.dart';

class WobblyShapes extends BaseShapeModule {
  const WobblyShapes();

  @override
  double get smallRadius => 8;

  @override
  double get mediumRadius => 12;

  @override
  double get largeRadius => 16;

  @override
  double get menuRadius => 8;

  @override
  ShapeBorder get cardShape => const RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(10),
      bottomRight: Radius.circular(15),
      bottomLeft: Radius.circular(11),
    ),
  );

  @override
  ShapeBorder get buttonShape => const RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(7),
      bottomRight: Radius.circular(9),
      bottomLeft: Radius.circular(6),
    ),
  );

  @override
  ShapeBorder get inputShape => const RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(9),
      topRight: Radius.circular(7),
      bottomRight: Radius.circular(8),
      bottomLeft: Radius.circular(6),
    ),
  );

  @override
  ShapeBorder get menuShape => const RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(7),
      bottomRight: Radius.circular(9),
      bottomLeft: Radius.circular(8),
    ),
  );
}
