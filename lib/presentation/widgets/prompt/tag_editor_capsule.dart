import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../autocomplete/autocomplete_wrapper.dart';
import '../autocomplete/autocomplete_overlay_handle.dart';
import 'prompt_translation_caption.dart';
import 'prompt_translation_controller.dart';
import 'tag_editor_session.dart';
import 'tag_editor_weight_label.dart';
import 'tag_editor_weight_style.dart';

class TagEditorCapsule extends StatefulWidget {
  const TagEditorCapsule({
    super.key,
    required this.tag,
    required this.selected,
    required this.editing,
    required this.showTranslation,
    required this.translation,
    required this.onRetryTranslation,
    required this.onTap,
    required this.onChanged,
    required this.onSubmitted,
    required this.onTapOutside,
    required this.maxWidth,
    this.enableAutocomplete = true,
    this.selectTextOnEdit = true,
    this.autocompleteOverlay,
    this.emphasisColor,
  });
  final PromptEditorTag tag;
  final bool selected;
  final bool editing;
  final bool showTranslation;
  final PromptTranslation? translation;
  final VoidCallback onRetryTranslation;
  final VoidCallback onTap;
  final ValueChanged<TextEditingValue> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onTapOutside;
  final double maxWidth;
  final bool enableAutocomplete;
  final bool selectTextOnEdit;
  final AutocompleteOverlayHandle? autocompleteOverlay;
  final Color? emphasisColor;
  @override
  State<TagEditorCapsule> createState() => _TagEditorCapsuleState();
}

class _TagEditorCapsuleState extends State<TagEditorCapsule> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  bool _syncing = false;
  String? _lastSubmitted;
  TextEditingValue _lastReported = TextEditingValue.empty;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tag.span.label)
      ..addListener(_inputChanged);
    _lastReported = _controller.value;
    if (widget.editing) _requestFocus();
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.editing) return;
      _focus.requestFocus();
      _controller.selection = widget.selectTextOnEdit
          ? TextSelection(baseOffset: 0, extentOffset: _controller.text.length)
          : TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  void _inputChanged() {
    if (_syncing || !widget.editing) return;
    final value = _controller.value;
    if (value.text == _lastReported.text &&
        value.composing == _lastReported.composing) {
      return;
    }
    _lastReported = value;
    _lastSubmitted = _controller.text;
    setState(() {});
    widget.onChanged(_controller.value);
  }

  @override
  void didUpdateWidget(TagEditorCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.editing && widget.editing) {
      _requestFocus();
    }
    final text = widget.tag.span.label;
    if (_controller.text != text &&
        !(widget.editing && _lastSubmitted?.trim() == text.trim())) {
      final selection = _controller.selection;
      _syncing = true;
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: selection.baseOffset.clamp(0, text.length),
          extentOffset: selection.extentOffset.clamp(0, text.length),
        ),
      );
      _syncing = false;
      _lastReported = _controller.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Widget _buildEditor(TextStyle? style) {
    // RenderEditable measures the effective font, composing text and caret.
    // A separate TextPainter can disagree with the TextField's merged style.
    final availableWidth = widget.maxWidth.clamp(1.0, double.infinity);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: availableWidth.clamp(1.0, 24.0),
        maxWidth: availableWidth,
      ),
      child: IntrinsicWidth(
        child: AutocompleteWrapper(
          overlayHandle: widget.autocompleteOverlay,
          controller: _controller,
          focusNode: _focus,
          enabled: widget.enableAutocomplete,
          maxLines: null,
          child: TextField(
            key: ValueKey('tag-input-${widget.tag.id}'),
            controller: _controller,
            focusNode: _focus,
            minLines: 1,
            maxLines: null,
            style: style,
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.done,
            decoration: null,
            onSubmitted: (_) => widget.onSubmitted(),
            onTapOutside: (_) => widget.onTapOutside(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final span = widget.tag.span;
    final emphasisColor = widget.emphasisColor;
    final background = widget.selected
        ? Color.alphaBlend(
            scheme.secondary.withValues(alpha: 0.12),
            scheme.surfaceContainerHigh,
          )
        : emphasisColor != null && !span.disabled
        ? TagEditorWeightStyle(
            emphasisColor,
          ).surface(scheme.surfaceContainerHigh)
        : scheme.surfaceContainerHigh;
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: span.disabled ? scheme.onSurfaceVariant : scheme.onSurface,
      decoration: span.disabled ? TextDecoration.lineThrough : null,
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.editing)
              _buildEditor(style)
            else
              Text(span.label, style: style),
            if (span.prefix.isNotEmpty || span.suffix.isNotEmpty)
              TagEditorWeightLabel(
                span: span,
                emphasisColor: span.disabled ? null : emphasisColor,
              ),
          ],
        ),
        if (widget.showTranslation)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: PromptTranslationLabel(
              value: widget.translation,
              onRetry: widget.onRetryTranslation,
            ),
          ),
        if (!span.complete)
          Text(
            context.l10n.tagMode_invalidSyntax,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
      ],
    );
    return Semantics(
      selected: widget.selected,
      label: span.disabled ? context.l10n.common_disabled : null,
      child: Material(
        color: span.disabled
            ? Color.alphaBlend(Colors.black.withValues(alpha: 0.32), background)
            : background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: widget.selected
              ? BorderSide(color: scheme.secondary.withValues(alpha: 0.5))
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
