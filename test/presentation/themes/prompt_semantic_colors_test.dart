import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/prompt_semantic_colors.dart';

void main() {
  for (final brightness in Brightness.values) {
    test('提示词五类业务语义色在 ${brightness.name} 主题下互不混用', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: brightness,
      );
      final colors = PromptSemanticColors.from(scheme);
      final roles = {
        colors.mainPrompt,
        colors.positiveQuality,
        colors.negativeQuality,
        colors.positiveFixedTag,
        colors.negativeFixedTag,
      };

      expect(roles, hasLength(5));
      for (final color in roles) {
        final background = Color.alphaBlend(
          color.withValues(
            alpha: brightness == Brightness.dark ? 0.075 : 0.045,
          ),
          scheme.surfaceContainerLow,
        );
        expect(_contrastRatio(color, background), greaterThanOrEqualTo(4.5));
      }
    });
  }
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
