import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/autocomplete/autocomplete_providers.dart';
import '../../../core/autocomplete/tag_translation_lookup.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../router/app_routes.dart';
import '../../themes/core/input_surface_style.dart';
import '../common/app_toast.dart';
import '../common/themed_confirm_dialog.dart';
import '../common/themed_input.dart';
import 'nai_syntax_controller.dart';

/// Adds a local bundled/ffdkj translation preview to a prompt editor.
///
/// The translated editor owns a separate controller. Its text can be selected
/// or edited for inspection, but the source controller remains untouched and
/// is revealed intact when the preview closes.
class QuickTranslatePromptField extends ConsumerStatefulWidget {
  const QuickTranslatePromptField({
    super.key,
    required this.controller,
    required this.child,
    this.sourceFocusNode,
    this.surfaceColor,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode? sourceFocusNode;
  final Widget child;
  final Color? surfaceColor;
  final bool enabled;

  @override
  ConsumerState<QuickTranslatePromptField> createState() =>
      _QuickTranslatePromptFieldState();
}

class _QuickTranslatePromptFieldState
    extends ConsumerState<QuickTranslatePromptField> {
  final NaiSyntaxController _previewController = NaiSyntaxController();
  final FocusNode _previewFocusNode = FocusNode();
  TextEditingValue? _sourceSnapshot;
  bool _showingTranslation = false;
  bool _isTranslating = false;
  bool _sourceHasText = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _sourceHasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_handleSourceChanged);
  }

  @override
  void didUpdateWidget(QuickTranslatePromptField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleSourceChanged);
    widget.controller.addListener(_handleSourceChanged);
    _sourceHasText = widget.controller.text.trim().isNotEmpty;
    _closePreview(restoreFocus: false);
  }

  @override
  void dispose() {
    _requestGeneration += 1;
    widget.controller.removeListener(_handleSourceChanged);
    _previewController.dispose();
    _previewFocusNode.dispose();
    super.dispose();
  }

  void _handleSourceChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final sourceChangedDuringPreview =
        _showingTranslation && widget.controller.value != _sourceSnapshot;
    if (!sourceChangedDuringPreview && hasText == _sourceHasText) return;
    setState(() {
      _sourceHasText = hasText;
      if (sourceChangedDuringPreview) {
        _showingTranslation = false;
        _sourceSnapshot = null;
        _previewController.clear();
        _requestGeneration += 1;
      }
    });
    if (sourceChangedDuringPreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.sourceFocusNode?.requestFocus();
      });
    }
  }

  Future<void> _toggleTranslation() async {
    if (_showingTranslation) {
      _closePreview();
      return;
    }
    if (_isTranslating || !_sourceHasText) return;

    final dictionary = ref.read(zhDictionaryServiceProvider);
    await dictionary.initialize();
    if (!mounted) return;

    final snapshot = widget.controller.value;
    final requestGeneration = ++_requestGeneration;
    setState(() => _isTranslating = true);
    TagTextTranslation result;
    try {
      result = await ref
          .read(tagTranslationLookupProvider)
          .translateTagText(snapshot.text);
    } catch (error, stack) {
      AppLogger.e('Quick prompt translation failed', error, stack);
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() => _isTranslating = false);
      AppToast.error(context, context.l10n.quickTranslate_failed);
      return;
    }
    if (!mounted || requestGeneration != _requestGeneration) return;
    setState(() => _isTranslating = false);
    if (widget.controller.value != snapshot) return;
    if (!result.hasTranslations) {
      if (!dictionary.state.isInstalled) {
        await _offerDictionaryInstall(dictionary.state.isBusy);
        return;
      }
      AppToast.info(context, context.l10n.quickTranslate_noMatches);
      return;
    }

    _sourceSnapshot = snapshot;
    final sourceController = widget.controller;
    if (sourceController is NaiSyntaxController) {
      _previewController
        ..highlightEnabled = sourceController.highlightEnabled
        ..numericEmphasisEnabled = sourceController.numericEmphasisEnabled;
    }
    _previewController.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.text.length),
    );
    setState(() => _showingTranslation = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showingTranslation) _previewFocusNode.requestFocus();
    });
  }

  Future<void> _offerDictionaryInstall(bool installInProgress) async {
    if (installInProgress) {
      context.go(AppRoutes.storageSettings);
      return;
    }
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.quickTranslate_missingTitle,
      content: context.l10n.quickTranslate_missingMessage,
      confirmText: context.l10n.quickTranslate_download,
      cancelText: context.l10n.common_cancel,
      icon: Icons.download_outlined,
    );
    if (!confirmed || !mounted) return;

    final service = ref.read(zhDictionaryServiceProvider);
    context.go(AppRoutes.storageSettings);
    try {
      await service.installOrUpdate();
    } on Object {
      // ZhDictionaryService records the original diagnostic in its state; the
      // destination settings page presents that actionable error in place.
    }
  }

  void _closePreview({bool restoreFocus = true}) {
    _requestGeneration += 1;
    if (!_showingTranslation && !_isTranslating) return;
    setState(() {
      _showingTranslation = false;
      _isTranslating = false;
      _sourceSnapshot = null;
      _previewController.clear();
    });
    if (restoreFocus) widget.sourceFocusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final policy = context.interactionPolicy;
    final buttonExtent = policy.minimumControlExtent;
    final tooltip = _showingTranslation
        ? context.l10n.quickTranslate_restore
        : context.l10n.quickTranslate_show;

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.hardEdge,
      children: [
        IgnorePointer(
          ignoring: _showingTranslation,
          child: ExcludeSemantics(
            excluding: _showingTranslation,
            child: widget.child,
          ),
        ),
        if (_showingTranslation)
          Positioned.fill(
            child: Semantics(
              label: context.l10n.quickTranslate_previewSemantics,
              textField: true,
              child: ThemedInput(
                key: const ValueKey('quick-translate-preview-input'),
                controller: _previewController,
                focusNode: _previewFocusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                surfaceColor: Color.alphaBlend(
                  theme.colorScheme.primary.withValues(alpha: 0.055),
                  widget.surfaceColor ??
                      inputSurfaceFillColor(theme.colorScheme),
                ),
                contentPadding: const EdgeInsetsDirectional.fromSTEB(
                  12,
                  10,
                  12,
                  10,
                ),
              ),
            ),
          ),
        PositionedDirectional(
          end: 4,
          bottom: 4,
          width: buttonExtent,
          height: buttonExtent,
          child: Semantics(
            button: true,
            toggled: _showingTranslation,
            label: tooltip,
            child: IconButton(
              key: const ValueKey('quick-translate-button'),
              tooltip: tooltip,
              onPressed: widget.enabled && _sourceHasText
                  ? _toggleTranslation
                  : null,
              style: IconButton.styleFrom(
                foregroundColor: _showingTranslation
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                backgroundColor: _showingTranslation
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.78,
                      ),
                disabledForegroundColor: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.38),
                disabledBackgroundColor: theme.colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              padding: EdgeInsets.zero,
              icon: _isTranslating
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _showingTranslation
                          ? Icons.translate
                          : Icons.translate_outlined,
                      size: 19,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
