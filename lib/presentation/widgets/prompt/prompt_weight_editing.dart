import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/character_prompt_block_parser.dart';
import '../../../core/utils/emphasis_weight_format.dart';
import '../../../core/utils/prompt_edit_document.dart';
import 'nai_syntax_controller.dart';

/// 权重解析结果
class PromptWeightValue {
  final String baseText;
  final double weight;

  const PromptWeightValue({required this.baseText, required this.weight});
}

// A non-null [group] rewrites only that group's weight wrapper.
class _PromptWeightTarget {
  const _PromptWeightTarget(
    this.start,
    this.end, {
    required this.numericAllowed,
    this.group,
  });

  final int start;
  final int end;
  final bool numericAllowed;
  final PromptEditSpan? group;
}

class PromptWeightEditing {
  static final RegExp _naiWeightPattern = RegExp(
    r'^(-?\d+\.?\d*)::(.+?)(?:::$|$)',
    // Selections can span paragraphs; subsequent edits must replace this shell.
    dotAll: true,
  );
  static final RegExp _bracketShell = RegExp(r'^[\{\[]+$');

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
    final target = _resolveTarget(controller.text, controller.selection);
    if (target == null) {
      return const PromptWeightValue(baseText: '', weight: 1.0);
    }
    return _valueOf(controller.text, target);
  }

  // A selection inside an existing weight rewrites it instead of nesting.
  static _PromptWeightTarget? _resolveTarget(
    String text,
    TextSelection selection,
  ) {
    if (!selection.isValid || selection.isCollapsed) return null;
    var start = math.max(0, selection.start);
    var end = math.min(text.length, selection.end);
    while (start < end && _isSeparator(text[start])) {
      start++;
    }
    while (end > start && _isSeparator(text[end - 1])) {
      end--;
    }
    if (start >= end) return null;

    final ancestors = <PromptEditSpan>[];
    var siblings = PromptEditDocument.parse(text);
    while (true) {
      final touched = [
        for (final span in siblings)
          if (span.start < end && span.end > start) span,
      ];
      if (touched.isEmpty || touched.any((span) => !span.complete)) {
        return _freeTarget(text, start, end, ancestors);
      }
      if (touched.length > 1 || start < touched.single.start) {
        return _freeTarget(
          text,
          math.min(start, touched.first.start),
          math.max(end, touched.last.end),
          ancestors,
        );
      }
      final span = touched.single;
      if (end > span.end) {
        return _freeTarget(text, span.start, end, ancestors);
      }
      if (span.children.isEmpty) {
        final coversTag = start <= span.editStart && end >= span.editEnd;
        if (coversTag || span.disabled || isEmphasisPrefix(span.prefix)) {
          return _spanTarget(span, ancestors);
        }
        return _partialTarget(text, span, start, end, ancestors);
      }
      final withinChildren =
          start >= span.children.first.start &&
          end <= span.children.last.end &&
          (start > span.children.first.start || end < span.children.last.end);
      if (!withinChildren) {
        if (isEmphasisPrefix(span.prefix)) {
          return _spanTarget(span, ancestors, group: true);
        }
        return _freeTarget(
          text,
          span.children.first.start,
          span.children.last.end,
          [...ancestors, span],
        );
      }
      ancestors.add(span);
      siblings = span.children;
    }
  }

  static bool isEmphasisPrefix(String prefix) {
    final trimmed = prefix.trim();
    return trimmed.endsWith('::') ||
        trimmed.endsWith('{') ||
        trimmed.endsWith('[');
  }

  // `::` resets every emphasis, so new numeric wrappers avoid weighted scopes.
  static bool allowsNumericWeight({
    required bool numericWrapper,
    required bool insideEmphasis,
    required Iterable<String> content,
  }) =>
      numericWrapper ||
      (!insideEmphasis && !content.any((part) => part.contains('::')));

  static (String, String) rewrap(
    PromptEditSpan span,
    double weight, {
    required bool numericEmphasisEnabled,
  }) {
    final shell = withWeight(
      '${span.prefix}x${span.suffix}',
      weight,
      numericEmphasisEnabled: numericEmphasisEnabled,
    );
    final split = shell.indexOf('x');
    return (shell.substring(0, split), shell.substring(split + 1));
  }

  static bool _isSeparator(String char) => char == ',' || char.trim().isEmpty;

  static bool _isBracket(String char) => char == '{' || char == '[';

  static bool _weighted(List<PromptEditSpan> ancestors) =>
      ancestors.any((ancestor) => isEmphasisPrefix(ancestor.prefix));

  static _PromptWeightTarget _spanTarget(
    PromptEditSpan span,
    List<PromptEditSpan> ancestors, {
    bool group = false,
  }) => _PromptWeightTarget(
    span.start,
    span.end,
    group: group ? span : null,
    numericAllowed: allowsNumericWeight(
      numericWrapper: span.prefix.trim().endsWith('::'),
      insideEmphasis: _weighted(ancestors),
      content: span.children.map((child) => child.raw),
    ),
  );

  static _PromptWeightTarget _freeTarget(
    String text,
    int start,
    int end,
    List<PromptEditSpan> ancestors,
  ) => _PromptWeightTarget(
    start,
    end,
    numericAllowed: allowsNumericWeight(
      numericWrapper: false,
      insideEmphasis: _weighted(ancestors),
      content: [text.substring(start, end)],
    ),
  );

  // Inline weights inside an unweighted tag, e.g. a sentence, are edited in place.
  static _PromptWeightTarget _partialTarget(
    String text,
    PromptEditSpan tag,
    int start,
    int end,
    List<PromptEditSpan> ancestors,
  ) {
    final ranges = PromptEditDocument.emphasisRanges(text, tag.start, tag.end);
    (int, int)? innermost;
    for (final range in ranges) {
      if (range.$1 <= start &&
          end <= range.$2 &&
          (innermost == null ||
              range.$2 - range.$1 < innermost.$2 - innermost.$1)) {
        innermost = range;
      }
    }
    if (innermost == null) {
      var (from, to) = (start, end);
      // Never split an inline wrapper the selection only partly covers.
      for (var grown = true; grown;) {
        grown = false;
        for (final (rangeStart, rangeEnd) in ranges) {
          if (rangeStart < to &&
              rangeEnd > from &&
              (rangeStart < from || rangeEnd > to)) {
            from = math.min(from, rangeStart);
            to = math.max(to, rangeEnd);
            grown = true;
          }
        }
      }
      return _freeTarget(text, from, to, ancestors);
    }
    final region = innermost;
    final (regionStart, regionEnd) = region;
    if (regionStart == tag.start && regionEnd == tag.end) {
      return _spanTarget(tag, ancestors);
    }
    return _PromptWeightTarget(
      regionStart,
      regionEnd,
      numericAllowed: allowsNumericWeight(
        numericWrapper: !_isBracket(text[regionStart]),
        insideEmphasis:
            _weighted(ancestors) ||
            ranges.any(
              (range) =>
                  range != region &&
                  range.$1 <= regionStart &&
                  regionEnd <= range.$2,
            ),
        content: [text.substring(regionStart, regionEnd)],
      ),
    );
  }

  static PromptWeightValue _valueOf(String text, _PromptWeightTarget target) {
    final group = target.group;
    if (group == null) {
      return parseWeightSyntax(text.substring(target.start, target.end));
    }
    return PromptWeightValue(
      baseText: text.substring(group.editStart, group.editEnd),
      weight: parseWeightSyntax('${group.prefix}x${group.suffix}').weight,
    );
  }

  static PromptWeightValue parseWeightSyntax(String text) {
    text = PromptEditDocument.decodeDisabled(text);
    var baseText = text;
    var weight = 1.0;

    final trimmed = text.trim();

    // NAI 数值权重语法: weight::text:: 或 weight::text
    final naiWeightMatch = _naiWeightPattern.firstMatch(trimmed);

    if (naiWeightMatch != null) {
      final weightValue = double.tryParse(naiWeightMatch.group(1)!);
      if (weightValue != null) {
        weight = weightValue;
        baseText = naiWeightMatch.group(2)!.trim();
        // A numeric opening overrides the previous one; stacks weigh as innermost.
        final inner = PromptEditDocument.parse(baseText);
        if (inner.length == 1 &&
            inner.single.raw == baseText &&
            inner.single.contentStart != null &&
            _naiWeightPattern.hasMatch(baseText)) {
          return parseWeightSyntax(baseText);
        }
        return PromptWeightValue(baseText: baseText, weight: weight);
      }
    }

    // Peel only complete enclosing shells; edge brackets may belong to
    // different tags (for example `{cat}, {dog}`) and must stay intact.
    final spans = PromptEditDocument.parse(trimmed);
    if (spans.length == 1) {
      final span = spans.single;
      final prefix = span.prefix;
      if (prefix.isNotEmpty && _bracketShell.hasMatch(prefix)) {
        final exponent = prefix
            .split('')
            .fold<int>(0, (value, char) => value + (char == '{' ? 1 : -1));
        weight = math.pow(1.05, exponent).toDouble();
        baseText = span.label;
      }
    }
    return PromptWeightValue(baseText: baseText.trim(), weight: weight);
  }

  static bool applyWeight(TextEditingController controller, double newWeight) {
    final text = controller.text;
    final target = _resolveTarget(text, controller.selection);
    if (target == null || _valueOf(text, target).baseText.isEmpty) {
      return false;
    }
    final numeric =
        target.numericAllowed &&
        (controller is! NaiSyntaxController ||
            controller.numericEmphasisEnabled);
    final group = target.group;
    final String replacement;
    if (group == null) {
      replacement = withWeight(
        text.substring(target.start, target.end),
        newWeight,
        numericEmphasisEnabled: numeric,
      );
    } else {
      final (prefix, suffix) = rewrap(
        group,
        newWeight,
        numericEmphasisEnabled: numeric,
      );
      replacement =
          '$prefix${text.substring(group.editStart, group.editEnd)}$suffix';
    }
    controller.value = TextEditingValue(
      text: text.replaceRange(target.start, target.end, replacement),
      selection: TextSelection(
        baseOffset: target.start,
        extentOffset: target.start + replacement.length,
      ),
    );
    return true;
  }

  static bool stepWeight(TextEditingController controller, double step) =>
      applyWeight(controller, parseSelection(controller).weight + step);

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
      text = '${formatEmphasisWeight(value)}::${parsed.baseText}::';
    } else {
      final depth = (math.log(value).abs() / math.log(1.05)).round();
      final opening = value > 1 ? '{' : '[';
      final closing = value > 1 ? '}' : ']';
      text = '${opening * depth}${parsed.baseText}${closing * depth}';
    }
    return disabled ? PromptEditDocument.disable(text) : text;
  }
}
