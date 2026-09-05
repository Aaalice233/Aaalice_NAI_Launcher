import 'package:flutter/material.dart';

/// 提示词组成预览使用的业务语义色。
///
/// 提示词来源需要在同一浮层内稳定区分，不能直接复用数量不足且可能同色的
/// Material `secondary` / `error` 角色。这里集中定义颜色，避免各入口自行分配。
@immutable
class PromptSemanticColors extends ThemeExtension<PromptSemanticColors> {
  const PromptSemanticColors._({
    required this.mainPrompt,
    required this.positiveQuality,
    required this.negativeQuality,
    required this.positiveFixedTag,
    required this.negativeFixedTag,
    required this.positivePrompt,
    required this.negativePrompt,
    required this.fixedTag,
  });

  factory PromptSemanticColors.from(ColorScheme colors) {
    final isDark = colors.brightness == Brightness.dark;
    return PromptSemanticColors._(
      positivePrompt: colors.primary,
      negativePrompt: colors.error,
      fixedTag: isDark ? const Color(0xFF6AA9E9) : const Color(0xFF285F98),
      mainPrompt: isDark ? const Color(0xFF82B1FF) : const Color(0xFF2457A7),
      positiveQuality: isDark
          ? const Color(0xFFF6C453)
          : const Color(0xFF7A5200),
      negativeQuality: isDark
          ? const Color(0xFFC4A7E7)
          : const Color(0xFF6B3FA0),
      positiveFixedTag: isDark
          ? const Color(0xFF73DACA)
          : const Color(0xFF00695C),
      negativeFixedTag: isDark
          ? const Color(0xFFFF8A80)
          : const Color(0xFFB42318),
    );
  }

  final Color mainPrompt;
  final Color positiveQuality;
  final Color negativeQuality;
  final Color positiveFixedTag;
  final Color negativeFixedTag;
  final Color positivePrompt;
  final Color negativePrompt;
  final Color fixedTag;

  @override
  PromptSemanticColors copyWith({
    Color? mainPrompt,
    Color? positiveQuality,
    Color? negativeQuality,
    Color? positiveFixedTag,
    Color? negativeFixedTag,
    Color? positivePrompt,
    Color? negativePrompt,
    Color? fixedTag,
  }) => PromptSemanticColors._(
    mainPrompt: mainPrompt ?? this.mainPrompt,
    positiveQuality: positiveQuality ?? this.positiveQuality,
    negativeQuality: negativeQuality ?? this.negativeQuality,
    positiveFixedTag: positiveFixedTag ?? this.positiveFixedTag,
    negativeFixedTag: negativeFixedTag ?? this.negativeFixedTag,
    positivePrompt: positivePrompt ?? this.positivePrompt,
    negativePrompt: negativePrompt ?? this.negativePrompt,
    fixedTag: fixedTag ?? this.fixedTag,
  );

  @override
  PromptSemanticColors lerp(covariant PromptSemanticColors? other, double t) {
    if (other == null) return this;
    return PromptSemanticColors._(
      mainPrompt: Color.lerp(mainPrompt, other.mainPrompt, t)!,
      positiveQuality: Color.lerp(positiveQuality, other.positiveQuality, t)!,
      negativeQuality: Color.lerp(negativeQuality, other.negativeQuality, t)!,
      positiveFixedTag: Color.lerp(
        positiveFixedTag,
        other.positiveFixedTag,
        t,
      )!,
      negativeFixedTag: Color.lerp(
        negativeFixedTag,
        other.negativeFixedTag,
        t,
      )!,
      positivePrompt: Color.lerp(positivePrompt, other.positivePrompt, t)!,
      negativePrompt: Color.lerp(negativePrompt, other.negativePrompt, t)!,
      fixedTag: Color.lerp(fixedTag, other.fixedTag, t)!,
    );
  }
}

extension PromptSemanticTheme on ThemeData {
  PromptSemanticColors get promptSemanticColors =>
      extension<PromptSemanticColors>() ??
      PromptSemanticColors.from(colorScheme);
}
