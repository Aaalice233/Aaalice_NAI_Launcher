import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/autocomplete/autocomplete_settings.dart'
    show replaceUnderscoresPreferenceProvider;
import '../providers/generation/generation_settings_notifiers.dart'
    show
        autoFormatPromptSettingsProvider,
        separateNumericWeightClosingSettingsProvider;
import '../widgets/prompt/prompt_blur_formatting.dart';

final promptFormattingPolicyProvider = Provider<PromptFormattingPolicy>(
  (ref) => PromptFormattingPolicy(
    autoFormat: ref.watch(autoFormatPromptSettingsProvider),
    replaceUnderscores: ref.watch(replaceUnderscoresPreferenceProvider),
    separateNumericWeightClosing: ref.watch(
      separateNumericWeightClosingSettingsProvider,
    ),
  ),
);

/// 编辑器之外写入提示词时，按用户设置执行与失焦相同的改写。
class PromptFormattingPolicy {
  const PromptFormattingPolicy({
    required this.autoFormat,
    required this.replaceUnderscores,
    required this.separateNumericWeightClosing,
  });

  final bool autoFormat;
  final bool replaceUnderscores;
  final bool separateNumericWeightClosing;

  /// 外部来源可能是 SD 语法；启动器自己生成的文本已是 NAI 语法。
  String apply(String prompt, {required bool convertSdSyntax}) =>
      PromptBlurFormatting.rewrite(
        prompt,
        sdSyntaxAutoConvert: convertSdSyntax,
        autoFormat: autoFormat,
        separateNumericWeightClosing: separateNumericWeightClosing,
        replaceUnderscores: replaceUnderscores,
      ).text;
}
