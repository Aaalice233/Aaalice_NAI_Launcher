import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../autocomplete/autocomplete_wrapper.dart';
import '../autocomplete/autocomplete_overlay_handle.dart';
import 'prompt_translation_caption.dart';
import 'prompt_translation_controller.dart';
import 'tag_editor_session.dart';

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
    required this.maxWidth,
    this.enableAutocomplete = true,
    this.selectTextOnEdit = true,
    this.autocompleteOverlay,
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
  final double maxWidth;
  final bool enableAutocomplete;
  final bool selectTextOnEdit;
  final AutocompleteOverlayHandle? autocompleteOverlay;
  @override
  State<TagEditorCapsule> createState() => _TagEditorCapsuleState();
}

class _TagEditorCapsuleState extends State<TagEditorCapsule> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  bool _syncing = false;
  String? _lastSubmitted;
  Size? _editingSize;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tag.span.label)
      ..addListener(_inputChanged);
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
    _lastSubmitted = _controller.text;
    widget.onChanged(_controller.value);
  }

  @override
  void didUpdateWidget(TagEditorCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.editing && widget.editing) {
      final box = context.findRenderObject();
      _editingSize = box is RenderBox && box.hasSize ? box.size : null;
      _requestFocus();
    }
    if (oldWidget.editing && !widget.editing) _editingSize = null;
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
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Widget _buildEditor(TextStyle? style) {
    // Existing tags keep their measured footprint; newly created tags have no
    // previous layout, so measure the source text with the same typography.
    final text = TextPainter(
      text: TextSpan(text: _controller.text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: widget.maxWidth);
    final size =
        _editingSize ??
        Size(text.width + 20, (text.height + 16).clamp(44, double.infinity));
    text.dispose();
    return SizedBox(
      width: (size.width - 20).clamp(1.0, widget.maxWidth),
      height: (size.height - 16).clamp(1.0, double.infinity),
      child: AutocompleteWrapper(
        overlayHandle: widget.autocompleteOverlay,
        controller: _controller,
        focusNode: _focus,
        enabled: widget.enableAutocomplete,
        expands: true,
        child: TextField(
          key: ValueKey('tag-input-${widget.tag.id}'),
          controller: _controller,
          focusNode: _focus,
          maxLines: null,
          expands: true,
          style: style,
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration.collapsed(
            hintText: '',
            filled: false,
          ),
          onSubmitted: (_) => widget.onSubmitted(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final span = widget.tag.span;
    final background = widget.selected
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHigh;
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: span.disabled ? scheme.onSurfaceVariant : scheme.onSurface,
      decoration: span.disabled ? TextDecoration.lineThrough : null,
    );
    final content = widget.editing
        ? _buildEditor(style)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(span.label, style: style),
              if (span.prefix.isNotEmpty || span.suffix.isNotEmpty)
                Text(
                  '${span.prefix}…${span.suffix}',
                  style: theme.textTheme.labelSmall,
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
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
        borderRadius: BorderRadius.circular(8),
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
