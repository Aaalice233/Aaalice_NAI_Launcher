import 'package:flutter/widgets.dart';

// 与 Text 的样式解析一致，测得的宽度即渲染宽度
double singleLineTextWidth(
  BuildContext context,
  String text, [
  TextStyle? style,
]) {
  var effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    effectiveStyle = effectiveStyle.merge(
      const TextStyle(fontWeight: FontWeight.bold),
    );
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: effectiveStyle),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width.ceilToDouble();
  painter.dispose();
  return width;
}
