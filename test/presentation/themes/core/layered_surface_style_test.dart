import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/grunge_palette.dart';

void main() {
  test('Grunge 暗色主题仍能形成画布、区块和控件三级色面', () {
    final colors = const GrungePalette().darkScheme;
    final section = sectionSurfaceColor(colors);
    final control = controlSurfaceColor(colors);
    final overlay = overlaySurfaceColor(colors);

    expect(section, isNot(colors.surface));
    expect(control, isNot(colors.surface));
    expect(overlay, isNot(colors.surface));
    expect(control, isNot(section));
    expect(
      section.computeLuminance(),
      greaterThan(colors.surface.computeLuminance()),
    );
    expect(control.computeLuminance(), greaterThan(section.computeLuminance()));
    expect(overlay.computeLuminance(), greaterThan(section.computeLuminance()));
    expect(section.r, section.g);
    expect(section.g, section.b);
  });

  test('补全缺失的中性色面阶梯', () {
    final source = const GrungePalette().darkScheme;
    final colors = resolveLayeredSurfaceColors(source);

    expect(colors.surfaceContainerLow, isNot(colors.surface));
    expect(colors.surfaceContainer, isNot(colors.surfaceContainerLow));
    expect(colors.surfaceContainerHigh, isNot(colors.surfaceContainer));
    expect(colors.surfaceContainerHighest, isNot(colors.surfaceContainerHigh));
    expect(colors.surfaceContainerLow.r, colors.surfaceContainerLow.g);
    expect(colors.surfaceContainerLow.g, colors.surfaceContainerLow.b);
  });

  test('最终主题在 Android 和桌面使用同一套中性色面', () {
    final theme = const ThemeComposer(
      color: GrungePalette(),
      typography: _TestTypography(),
      shape: _TestShape(),
      motion: _TestMotion(),
    ).buildTheme(Brightness.dark);
    final colors = theme.colorScheme;

    expect(theme.cardTheme.color, colors.surfaceContainerLow);
    expect(colors.surfaceContainerLow, isNot(colors.surface));
    expect(colors.surfaceContainerLow.r, colors.surfaceContainerLow.g);
    expect(colors.surfaceContainerLow.g, colors.surfaceContainerLow.b);

    final androidTheme = theme.copyWith(platform: TargetPlatform.android);
    final windowsTheme = theme.copyWith(platform: TargetPlatform.windows);
    expect(
      androidTheme.colorScheme.surfaceContainerLow,
      windowsTheme.colorScheme.surfaceContainerLow,
    );
    expect(androidTheme.cardTheme.color, windowsTheme.cardTheme.color);
  });

  test('已经声明容器色的主题保持原有语义颜色', () {
    final colors = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );

    expect(sectionSurfaceColor(colors), colors.surfaceContainerLow);
    expect(controlSurfaceColor(colors), colors.surfaceContainer);
    expect(overlaySurfaceColor(colors), colors.surfaceContainerHigh);
  });
}

class _TestTypography implements TypographyModule {
  const _TestTypography();

  @override
  String get bodyFontFamily => 'Test';

  @override
  String get displayFontFamily => 'Test';

  @override
  TextTheme get textTheme => const TextTheme();
}

class _TestShape implements ShapeModule {
  const _TestShape();

  @override
  ShapeBorder get buttonShape => const RoundedRectangleBorder();

  @override
  ShapeBorder get cardShape => const RoundedRectangleBorder();

  @override
  ShapeBorder get inputShape => const RoundedRectangleBorder();

  @override
  double get largeRadius => 8;

  @override
  double get mediumRadius => 6;

  @override
  double get menuRadius => 4;

  @override
  ShapeBorder get menuShape => const RoundedRectangleBorder();

  @override
  double get smallRadius => 4;
}

class _TestMotion implements MotionModule {
  const _TestMotion();

  @override
  Curve get enterCurve => Curves.easeOut;

  @override
  Curve get exitCurve => Curves.easeIn;

  @override
  Duration get fastDuration => const Duration(milliseconds: 100);

  @override
  Duration get normalDuration => const Duration(milliseconds: 200);

  @override
  Duration get slowDuration => const Duration(milliseconds: 300);

  @override
  Curve get standardCurve => Curves.easeInOut;
}
