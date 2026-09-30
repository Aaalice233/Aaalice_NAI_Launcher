import 'package:flutter/widgets.dart';

double singleLineTextWidth(
  BuildContext context,
  String text, [
  TextStyle? style,
]) => singleLineTextSize(context, text, style).width;

// 与 Text 的样式解析一致，测得的尺寸即渲染尺寸
Size singleLineTextSize(BuildContext context, String text, [TextStyle? style]) {
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
  final size = Size(painter.width.ceilToDouble(), painter.height.ceilToDouble());
  painter.dispose();
  return size;
}
