/// Theme Testing Helpers
///
/// This file provides utility functions for testing the modular theme system.
/// Use these helpers to create consistent test fixtures across all theme tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a minimal [ThemeData] for testing purposes.
///
/// This is useful when you need a valid ThemeData but don't care about
/// specific theme properties.
///
/// Example:
/// ```dart
/// final theme = createTestTheme();
/// expect(theme.brightness, Brightness.light);
/// ```
ThemeData createTestTheme({
  Brightness brightness = Brightness.light,
  ColorScheme? colorScheme,
}) {
  final scheme = colorScheme ?? createTestColorScheme(brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
  );
}

/// Creates a minimal [ColorScheme] for testing purposes.
///
/// Provides sensible defaults that work for most test scenarios.
///
/// Example:
/// ```dart
/// final scheme = createTestColorScheme(brightness: Brightness.dark);
/// expect(scheme.brightness, Brightness.dark);
/// ```
ColorScheme createTestColorScheme({
  Brightness brightness = Brightness.light,
  Color? primary,
  Color? secondary,
  Color? surface,
  Color? error,
}) {
  if (brightness == Brightness.light) {
    return ColorScheme.light(
      primary: primary ?? const Color(0xFF6750A4),
      secondary: secondary ?? const Color(0xFF625B71),
      surface: surface ?? const Color(0xFFFFFBFE),
      error: error ?? const Color(0xFFB3261E),
    );
  } else {
    return ColorScheme.dark(
      primary: primary ?? const Color(0xFFD0BCFF),
      secondary: secondary ?? const Color(0xFFCCC2DC),
      surface: surface ?? const Color(0xFF1C1B1F),
      error: error ?? const Color(0xFFF2B8B5),
    );
  }
}

/// Pumps a widget wrapped with [MaterialApp] and the given [theme].
///
/// This is the primary way to test widgets that depend on theme.
///
/// Example:
/// ```dart
/// await pumpThemedWidget(
///   tester,
///   child: MyThemedWidget(),
///   theme: createTestTheme(),
/// );
/// ```
Future<void> pumpThemedWidget(
  WidgetTester tester, {
  required Widget child,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? createTestTheme(brightness: Brightness.light),
      darkTheme: darkTheme ?? createTestTheme(brightness: Brightness.dark),
      themeMode: themeMode,
      home: child,
    ),
  );
}

/// Creates a [BoxDecoration] for testing shadow modules.
///
/// Example:
/// ```dart
/// final decoration = createTestBoxDecoration(
///   shadows: [BoxShadow(offset: Offset(4, 4))],
/// );
/// ```
BoxDecoration createTestBoxDecoration({
  Color? color,
  BorderRadius? borderRadius,
  List<BoxShadow>? shadows,
  Border? border,
}) {
  return BoxDecoration(
    color: color ?? Colors.white,
    borderRadius: borderRadius ?? BorderRadius.circular(8),
    boxShadow: shadows,
    border: border,
  );
}

/// Creates a [TextStyle] for testing typography modules.
///
/// Example:
/// ```dart
/// final style = createTestTextStyle(fontSize: 24.0);
/// expect(style.fontSize, 24.0);
/// ```
TextStyle createTestTextStyle({
  String? fontFamily,
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize ?? 14.0,
    fontWeight: fontWeight ?? FontWeight.normal,
    color: color ?? Colors.black,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// Calculates the contrast ratio between two colors.
///
/// Returns a value between 1 and 21. WCAG AA requires at least 4.5:1
/// for normal text, 3:1 for large text.
///
/// Example:
/// ```dart
/// final ratio = calculateContrastRatio(Colors.black, Colors.white);
/// expect(ratio, greaterThanOrEqualTo(4.5));
/// ```
double calculateContrastRatio(Color foreground, Color background) {
  final fgLuminance = foreground.computeLuminance();
  final bgLuminance = background.computeLuminance();

  final lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
  final darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;

  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG AA minimum contrast ratio for normal text.
const double wcagAAContrastRatio = 4.5;

/// WCAG AA minimum contrast ratio for large text (18pt+ or 14pt+ bold).
const double wcagAALargeTextContrastRatio = 3.0;

/// WCAG AAA minimum contrast ratio for normal text.
const double wcagAAAContrastRatio = 7.0;

/// Matcher for verifying a color meets WCAG AA contrast requirements
/// against a background color.
Matcher meetsWcagAA(Color background) {
  return predicate<Color>(
    (foreground) => calculateContrastRatio(foreground, background) >= wcagAAContrastRatio,
    'meets WCAG AA contrast ratio (>= 4.5:1) against background',
  );
}

/// Golden test helper - wraps widget in a repaint boundary for golden testing.
///
/// Example:
/// ```dart
/// await tester.pumpWidget(goldenTestWidget(MyWidget()));
/// await expectLater(find.byType(MyWidget), matchesGoldenFile('my_widget.png'));
/// ```
Widget goldenTestWidget(Widget child, {Size size = const Size(400, 300)}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: child,
      ),
    ),
  );
}

/// Extension for easier theme access in tests.
extension ThemeTestExtension on BuildContext {
  /// Shorthand for Theme.of(context)
  ThemeData get theme => Theme.of(this);

  /// Shorthand for Theme.of(context).colorScheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Shorthand for Theme.of(context).textTheme
  TextTheme get textTheme => Theme.of(this).textTheme;
}
