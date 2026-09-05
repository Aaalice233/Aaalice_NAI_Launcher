import 'package:flutter/material.dart';

import '../../../core/utils/character_prompt_block_parser.dart';
import '../../../core/utils/prompt_edit_document.dart';
import 'nai_syntax_controller.dart';

/// 权重解析结果
class PromptWeightValue {
  final String baseText;
  final double weight;

  const PromptWeightValue({required this.baseText, required this.weight});
}

class PromptWeightEditing {
  static bool protectNegativeBlockSyntax(TextEditingController controller) {
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return false;

    final parsed = CharacterPromptBlockParser.parse(controller.text);
    for (final block in parsed.blocks) {
      final overlapsBlock =
          selection.start < block.range.end &&
          selection.end > block.range.start;
      if (!overlapsBlock) continue;

      final insideContent =
          selection.start >= block.contentRange.start &&
          selection.end <= block.contentRange.end;
      final containsWholeBlock =
          selection.start == block.range.start &&
          selection.end == block.range.end;
      if (!insideContent && !containsWholeBlock) return false;

      final start = selection.start.clamp(
        block.contentRange.start,
        block.contentRange.end,
      );
      final end = selection.end.clamp(
        block.contentRange.start,
        block.contentRange.end,
      );
      if (start >= end) return false;
      if (start != selection.start || end != selection.end) {
        controller.selection = TextSelection(
          baseOffset: start,
          extentOffset: end,
        );
      }
      return true;
    }
    return true;
  }

  static bool hasSelection(TextEditingController controller) {
    final selection = controller.selection;
    return selection.isValid &&
        selection.start != selection.end &&
        selection.start >= 0 &&
        selection.end <= controller.text.length;
  }

  static PromptWeightValue parseSelection(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0 || end > text.length || start >= end) {
      return const PromptWeightValue(baseText: '', weight: 1.0);
    }

    final selectedText = text.substring(start, end);
    return parseWeightSyntax(selectedText);
  }

  static PromptWeightValue parseWeightSyntax(String text) {
    text = PromptEditDocument.decodeDisabled(text);
    var baseText = text;
    var weight = 1.0;

    final trimmed = text.trim();

    // NAI 数值权重语法: weight::text:: 或 weight::text
    final naiWeightMatch = RegExp(
      r'^(-?\d+\.?\d*)::(.+?)(?:::$|$)',
    ).firstMatch(trimmed);

    if (naiWeightMatch != null) {
      final weightValue = double.tryParse(naiWeightMatch.group(1)!);
      if (weightValue != null) {
        weight = weightValue;
        baseText = naiWeightMatch.group(2)!.trim();
        return PromptWeightValue(baseText: baseText, weight: weight);
      }
    }

    // 括号权重语法 {text} 或 [text]
    var braceCount = 0;
    var bracketCount = 0;

    var i = 0;
    while (i < trimmed.length) {
      if (trimmed[i] == '{') {
        braceCount++;
        i++;
      } else if (trimmed[i] == '[') {
        bracketCount++;
        i++;
      } else {
        break;
      }
    }

    var j = trimmed.length - 1;
    var closeBraceCount = 0;
    var closeBracketCount = 0;
    while (j >= i) {
      if (trimmed[j] == '}') {
        closeBraceCount++;
        j--;
      } else if (trimmed[j] == ']') {
        closeBracketCount++;
        j--;
      } else {
        break;
      }
    }

    final effectiveBraces = braceCount < closeBraceCount
        ? braceCount
        : closeBraceCount;
    final effectiveBrackets = bracketCount < closeBracketCount
        ? bracketCount
        : closeBracketCount;

    if (effectiveBraces > 0) {
      weight = 1.0 + (effectiveBraces * 0.05);
      baseText = trimmed
          .substring(effectiveBraces, trimmed.length - effectiveBraces)
          .trim();
    } else if (effectiveBrackets > 0) {
      weight = 1.0 - (effectiveBrackets * 0.05);
      baseText = trimmed
          .substring(effectiveBrackets, trimmed.length - effectiveBrackets)
          .trim();
    }

    return PromptWeightValue(
      baseText: baseText.trim(),
      weight: weight.clamp(0.1, 3.0),
    );
  }

  static bool applyWeight(TextEditingController controller, double newWeight) {
    final result = parseSelection(controller);
    final baseText = result.baseText;

    if (baseText.isEmpty) return false;

    final selectedText = controller.selection.textInside(controller.text);
    final newText = withWeight(
      selectedText,
      newWeight,
      numericEmphasisEnabled:
          controller is! NaiSyntaxController ||
          controller.numericEmphasisEnabled,
    );

    final text = controller.text;
    final selection = controller.selection;
    final newTextValue =
        text.substring(0, selection.start) +
        newText +
        text.substring(selection.end);

    controller.text = newTextValue;

    final newSelectionEnd = selection.start + newText.length;
    controller.selection = TextSelection(
      baseOffset: selection.start,
      extentOffset: newSelectionEnd,
    );

    return true;
  }

  static String withWeight(
    String source,
    double weight, {
    bool numericEmphasisEnabled = true,
  }) {
    final spans = PromptEditDocument.parse(source);
    final disabled = spans.length == 1 && spans.single.disabled;
    final parsed = parseWeightSyntax(source);
    final value = weight.clamp(0.1, 3.0);
    String text;
    if ((value - 1).abs() < 0.00001) {
      text = parsed.baseText;
    } else if (numericEmphasisEnabled) {
      text = '${value.toStringAsFixed(2)}::${parsed.baseText}::';
    } else {
      final depth = ((value - 1).abs() / 0.05).round();
      final opening = value > 1 ? '{' : '[';
      final closing = value > 1 ? '}' : ']';
      text = '${opening * depth}${parsed.baseText}${closing * depth}';
    }
    return disabled ? PromptEditDocument.disable(text) : text;
  }
}
