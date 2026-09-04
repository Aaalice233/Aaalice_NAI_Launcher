import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/grunge_palette.dart';

void main() {
  test('Grunge 暗色主题仍能形成画布、区块和控件三级色面', () {
    final colors = const GrungePalette().darkScheme;
    final section = sectionSurfaceColor(colors);
    final control = controlSurfaceColor(colors);

    expect(section, isNot(colors.surface));
    expect(control, isNot(colors.surface));
    expect(control, isNot(section));
    expect(
      section.computeLuminance(),
      greaterThan(colors.surface.computeLuminance()),
    );
    expect(control.computeLuminance(), greaterThan(section.computeLuminance()));
  });

  test('已经声明容器色的主题保持原有语义颜色', () {
    final colors = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );

    expect(sectionSurfaceColor(colors), colors.surfaceContainerLow);
    expect(controlSurfaceColor(colors), colors.surfaceContainer);
  });
}
