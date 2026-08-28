import 'package:flutter/material.dart';

/// Renders valid `[imageN]` references as attachment tokens without changing
/// the underlying editing value or IME composing range.
class AgentChatInputController extends TextEditingController {
  AgentChatInputController({
    required this.onImageEnter,
    required this.onImageExit,
  });

  static final RegExp imagePattern = RegExp(r'\[image(\d+)\]');

  final void Function(int imageNumber, Offset pointerPosition) onImageEnter;
  final VoidCallback onImageExit;
  int _imageCount = 0;

  int get imageCount => _imageCount;

  set imageCount(int value) {
    if (_imageCount == value) return;
    _imageCount = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final theme = Theme.of(context);
    final tokenStyle = (style ?? const TextStyle()).copyWith(
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.55,
      ),
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
    );
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in imagePattern.allMatches(text)) {
      if (match.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final imageNumber = int.tryParse(match.group(1) ?? '');
      if (imageNumber != null &&
          imageNumber >= 1 &&
          imageNumber <= _imageCount) {
        children.add(
          TextSpan(
            text: match.group(0),
            style: tokenStyle,
            mouseCursor: SystemMouseCursors.click,
            onEnter: (event) => onImageEnter(imageNumber, event.position),
            onExit: (_) => onImageExit(),
          ),
        );
      } else {
        children.add(TextSpan(text: match.group(0)));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }
}
