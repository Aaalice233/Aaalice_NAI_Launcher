import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nai_launcher/presentation/themes/app_theme.dart';
import 'package:nai_launcher/presentation/themes/core/input_surface_style.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/themes/prompt_control_colors.dart';
import 'package:nai_launcher/presentation/themes/prompt_semantic_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final style in AppStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${style.name}/${brightness.name}: input depth and prompt control contrast',
        (tester) async {
          final theme = AppTheme.getTheme(style, brightness);
          final scheme = theme.colorScheme;
          expect(theme.chipTheme.backgroundColor, Colors.transparent);
          expect(theme.chipTheme.selectedColor, scheme.primaryContainer);
          expect(
            theme.primaryTextTheme.bodyMedium?.fontFamily,
            theme.textTheme.bodyMedium?.fontFamily,
          );
          expect(
            theme.tooltipTheme.textStyle?.fontFamily,
            theme.textTheme.bodySmall?.fontFamily,
          );
          expect(theme.primaryTextTheme.bodyMedium?.color, scheme.onPrimary);
          final input = inputSurfaceFillColor(scheme);
          expect(theme.inputDecorationTheme.fillColor, input);
          for (final prominent in [false, true]) {
            final fill = inputSurfaceFillColor(scheme, prominent: prominent);
            expect(
              fill.computeLuminance(),
              lessThanOrEqualTo(scheme.surface.computeLuminance()),
            );
            expect(
              fill.computeLuminance(),
              lessThanOrEqualTo(sectionSurfaceColor(scheme).computeLuminance()),
            );
            expect(
              _contrast(scheme.onSurface, fill),
              greaterThanOrEqualTo(4.5),
              reason: 'input text',
            );
            expect(
              _contrast(theme.inputDecorationTheme.hintStyle!.color!, fill),
              greaterThanOrEqualTo(4.5),
              reason: 'input hint',
            );
          }
          expect(theme.extension<PromptSemanticColors>(), isNotNull);
          final semantic = theme.promptSemanticColors;
          final roles = [
            semantic.positivePrompt,
            semantic.negativePrompt,
            semantic.fixedTag,
            semantic.positiveQuality,
            semantic.negativeQuality,
          ];
          expect(roles.toSet(), hasLength(5));
          for (final role in roles) {
            for (final active in [false, true]) {
              for (final hovered in [false, true]) {
                final colors = PromptControlColors(
                  theme,
                  role,
                  active: active,
                  hovered: hovered,
                );
                final paintedSurface = Color.alphaBlend(
                  colors.background,
                  sectionSurfaceColor(scheme),
                );
                expect(
                  colors.background.a,
                  active || hovered ? greaterThan(0) : 0,
                );
                expect(
                  _contrast(colors.foreground, paintedSurface),
                  greaterThanOrEqualTo(4.5),
                );
                expect(
                  _contrast(colors.accent, paintedSurface),
                  greaterThanOrEqualTo(4.5),
                );
              }
            }
          }
          for (final platform in [
            TargetPlatform.android,
            TargetPlatform.windows,
            TargetPlatform.macOS,
          ]) {
            final other = theme.copyWith(platform: platform);
            expect(inputSurfaceFillColor(other.colorScheme), input);
            expect(other.promptSemanticColors, same(semantic));
          }
        },
      );
    }
  }

  testWidgets(
    'custom semantic colors survive theme composition and interpolate',
    (tester) async {
      final first = AppTheme.getTheme(AppStyle.grungeCollage, Brightness.dark);
      final original = first.promptSemanticColors;
      final custom = original.copyWith(positivePrompt: Colors.orange);
      final theme = first.copyWith(
        extensions: [
          ...first.extensions.values.where(
            (extension) => extension is! PromptSemanticColors,
          ),
          custom,
        ],
      );
      expect(theme.promptSemanticColors.positivePrompt, Colors.orange);
      final midpoint = ThemeData.lerp(first, theme, 0.5);
      expect(
        midpoint.promptSemanticColors.positivePrompt,
        Color.lerp(original.positivePrompt, Colors.orange, 0.5),
      );
    },
  );
}

double _contrast(Color foreground, Color background) {
  final a = Color.alphaBlend(foreground, background).computeLuminance();
  final b = background.computeLuminance();
  return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
}
