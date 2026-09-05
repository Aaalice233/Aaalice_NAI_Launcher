import 'package:flutter/material.dart';

/// Visible surfaces share geometry; Material keeps a separate padded hit area.
abstract final class PromptFooterStyle {
  static const double iconSize = 18;

  static double height(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(12) * 1.4 + 12).clamp(
        32.0,
        double.infinity,
      );

  static ButtonStyle button(
    BuildContext context, {
    double? width,
  }) => ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(width ?? 32, height(context))),
    maximumSize: WidgetStatePropertyAll(Size(double.infinity, height(context))),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.padded,
    shape: const WidgetStatePropertyAll(StadiumBorder()),
    textStyle: WidgetStatePropertyAll(
      Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 12),
    ),
  );
}
