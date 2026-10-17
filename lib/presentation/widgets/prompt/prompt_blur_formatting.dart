import '../../../core/utils/nai_prompt_formatter.dart';
import '../../../core/utils/numeric_weight_closing.dart';
import '../../../core/utils/sd_to_nai_converter.dart';
import '../../../l10n/app_localizations.dart';

/// 失焦改写的统一顺序：SD 转换 → 自动格式化 → 数值权重闭合补空格。
abstract final class PromptBlurFormatting {
  static bool enabled({
    required bool sdSyntaxAutoConvert,
    required bool autoFormat,
    required bool separateNumericWeightClosing,
  }) => sdSyntaxAutoConvert || autoFormat || separateNumericWeightClosing;

  /// 未改动时 [messages] 为空。
  static ({String text, List<String> messages}) apply(
    String text,
    AppLocalizations l10n, {
    required bool sdSyntaxAutoConvert,
    required bool autoFormat,
    required bool separateNumericWeightClosing,
  }) {
    var result = text;
    final messages = <String>[];

    // SD 转换先于格式化，格式化可能会影响转换结果
    if (sdSyntaxAutoConvert) {
      final converted = SdToNaiConverter.convert(
        result,
        separateNumericWeightClosing: separateNumericWeightClosing,
      );
      if (converted != result) {
        result = converted;
        messages.add('SD→NAI');
      }
    }

    if (autoFormat) {
      final formatted = NaiPromptFormatter.format(result);
      if (formatted != result) {
        result = formatted;
        if (messages.isEmpty) messages.add(l10n.prompt_formatted);
      }
    }

    if (separateNumericWeightClosing) {
      final separated = NumericWeightClosing.separate(result);
      if (separated != result) {
        result = separated;
        messages.add(l10n.prompt_numericWeightClosingSeparated);
      }
    }

    return (text: result, messages: messages);
  }
}
