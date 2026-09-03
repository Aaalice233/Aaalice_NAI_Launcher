import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/autocomplete/tag_translation_lookup.dart';
import '../../../core/utils/prompt_tag_utils.dart';
import '../../../core/utils/tag_normalizer.dart';

/// Read-only tag label that keeps the canonical tag visible and appends the
/// optional Chinese dictionary result without changing the stored value.
class TranslatedTagText extends ConsumerStatefulWidget {
  const TranslatedTagText(
    this.tag, {
    super.key,
    this.style,
    this.translationStyle,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String tag;
  final TextStyle? style;
  final TextStyle? translationStyle;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  ConsumerState<TranslatedTagText> createState() => _TranslatedTagTextState();
}

class _TranslatedTagTextState extends ConsumerState<TranslatedTagText> {
  String? _translation;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TranslatedTagText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag == widget.tag) return;
    _translation = null;
    _load();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    TagTranslationLookup lookup;
    try {
      lookup = ref.read(tagTranslationLookupProvider);
    } on StateError {
      // Standalone widget harnesses may intentionally omit the app provider
      // tree. The canonical tag remains the complete fallback presentation.
      return;
    }
    final translation = await lookup.translate(widget.tag);
    if (!mounted || revision != _revision) return;
    setState(() => _translation = translation);
  }

  @override
  Widget build(BuildContext context) {
    final display = TagNormalizer.toDisplay(widget.tag);
    final translation = _translation?.trim();
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final secondaryStyle =
        widget.translationStyle ??
        baseStyle.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Text.rich(
      TextSpan(
        text: display,
        children: [
          if (translation?.isNotEmpty == true)
            TextSpan(text: '  $translation', style: secondaryStyle),
        ],
      ),
      key: ValueKey('translated-tag-${widget.tag}'),
      style: baseStyle,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}

/// Read-only prompt presentation with a separate Chinese summary. Copying and
/// editing continue to use the untouched canonical prompt.
class TranslatedPromptText extends ConsumerStatefulWidget {
  const TranslatedPromptText(
    this.prompt, {
    super.key,
    this.style,
    this.translationStyle,
    this.selectable = true,
    this.maxLines,
    this.originalText,
  });

  final String prompt;
  final TextStyle? style;
  final TextStyle? translationStyle;
  final bool selectable;
  final int? maxLines;
  final String? originalText;

  @override
  ConsumerState<TranslatedPromptText> createState() =>
      _TranslatedPromptTextState();
}

class _TranslatedPromptTextState extends ConsumerState<TranslatedPromptText> {
  List<String> _translations = const [];
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TranslatedPromptText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prompt == widget.prompt) return;
    _translations = const [];
    _load();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    final tags = PromptTagUtils.parseForDisplay(widget.prompt);
    TagTranslationLookup lookup;
    try {
      lookup = ref.read(tagTranslationLookupProvider);
    } on StateError {
      return;
    }
    final values = await lookup.translateBatch(tags);
    if (!mounted || revision != _revision) return;
    final translations = <String>[];
    final seen = <String>{};
    for (final tag in tags) {
      final normalized = TagTranslationLookup.normalizeTag(tag);
      final translation = values[normalized]?.trim();
      if (translation != null &&
          translation.isNotEmpty &&
          seen.add(translation)) {
        translations.add(translation);
      }
    }
    setState(() => _translations = translations);
  }

  @override
  Widget build(BuildContext context) {
    final displayPrompt = widget.originalText ?? widget.prompt;
    final original = widget.selectable
        ? SelectableText(
            displayPrompt,
            key: const ValueKey('translated-prompt-original'),
            style: widget.style,
            maxLines: widget.maxLines,
          )
        : Text(
            displayPrompt,
            key: const ValueKey('translated-prompt-original'),
            style: widget.style,
            maxLines: widget.maxLines,
            overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
          );
    if (_translations.isEmpty) return original;
    final translationText = _translations.join('，');
    final translationStyle =
        widget.translationStyle ??
        Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.45,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        original,
        const SizedBox(height: 4),
        Text(
          translationText,
          key: const ValueKey('translated-prompt-translation'),
          style: translationStyle,
          maxLines: widget.maxLines,
          overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
