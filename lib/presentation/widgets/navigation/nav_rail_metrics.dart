import 'package:flutter/material.dart';

const double navRailCollapsedWidth = 60;
const double navRailExpandedWidth = 196;

double navRailExpandedWidthFor(BuildContext context) {
  final scaledBodySize = MediaQuery.textScalerOf(context).scale(14);
  return (navRailExpandedWidth + (scaledBodySize - 14).clamp(0, 28) * 3)
      .clamp(navRailExpandedWidth, 280)
      .toDouble();
}

Duration boundedNavRailMotionDuration(
  BuildContext context,
  Duration source, {
  required int minMilliseconds,
  required int maxMilliseconds,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
  return Duration(
    milliseconds: source.inMilliseconds.clamp(minMilliseconds, maxMilliseconds),
  );
}

double navRailItemMinHeight(BuildContext context) =>
    MediaQuery.textScalerOf(
      context,
    ).scale(14).clamp(36, double.infinity).toDouble() +
    12;
