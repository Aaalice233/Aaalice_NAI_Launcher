import '../../../core/utils/nai_prompt_formatter.dart';
import '../../../core/utils/numeric_weight_closing.dart';
import '../../../core/utils/sd_to_nai_converter.dart';
import '../../../l10n/app_localizations.dart';

enum PromptBlurStep { sdSyntaxConverted, formatted, numericClosingSeparated }

/// 失焦与跨页写入共用的改写顺序：SD 转换 → 自动格式化 → 数值权重闭合补空格。
abstract final class PromptBlurFormatting {
  static bool enabled({
    required bool sdSyntaxAutoConvert,
    required bool autoFormat,
    required bool separateNumericWeightClosing,
  }) => sdSyntaxAutoConvert || autoFormat || separateNumericWeightClosing;

  /// [steps] 只记录实际改动了文本的步骤。
  static ({String text, Set<PromptBlurStep> steps}) rewrite(
    String text, {
    required bool sdSyntaxAutoConvert,
    required bool autoFormat,
    required bool separateNumericWeightClosing,
    required bool replaceUnderscores,
  }) {
    var result = text;
    final steps = <PromptBlurStep>{};

    // SD 转换先于格式化，格式化可能会影响转换结果
    if (sdSyntaxAutoConvert) {
      final converted = SdToNaiConverter.convert(
        result,
        separateNumericWeightClosing: separateNumericWeightClosing,
      );
      if (converted != result) {
        result = converted;
        steps.add(PromptBlurStep.sdSyntaxConverted);
      }
    }

    if (autoFormat) {
      final formatted = NaiPromptFormatter.format(
        result,
        replaceUnderscores: replaceUnderscores,
      );
      if (formatted != result) {
        result = formatted;
        steps.add(PromptBlurStep.formatted);
      }
    }

    if (separateNumericWeightClosing) {
      final separated = NumericWeightClosing.separate(result);
      if (separated != result) {
        result = separated;
        steps.add(PromptBlurStep.numericClosingSeparated);
      }
    }

    return (text: result, steps: steps);
  }

  /// 未改动时 [messages] 为空。
  static ({String text, List<String> messages}) apply(
    String text,
    AppLocalizations l10n, {
    required bool sdSyntaxAutoConvert,
    required bool autoFormat,
    required bool separateNumericWeightClosing,
    required bool replaceUnderscores,
  }) {
    final result = rewrite(
      text,
      sdSyntaxAutoConvert: sdSyntaxAutoConvert,
      autoFormat: autoFormat,
      separateNumericWeightClosing: separateNumericWeightClosing,
      replaceUnderscores: replaceUnderscores,
    );
    final steps = result.steps;
    return (
      text: result.text,
      messages: [
        if (steps.contains(PromptBlurStep.sdSyntaxConverted))
          'SD→NAI'
        else if (steps.contains(PromptBlurStep.formatted))
          l10n.prompt_formatted,
        if (steps.contains(PromptBlurStep.numericClosingSeparated))
          l10n.prompt_numericWeightClosingSeparated,
      ],
    );
  }
}
