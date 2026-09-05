import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/prompt_editor_preferences_provider.dart';
import '../../../core/utils/localization_extension.dart';
import 'prompt_tag_mode_toggle.dart';
import 'tag_editor_scope.dart';
import 'tag_editor_session.dart';
import 'tag_editor_view.dart';
import 'nai_syntax_controller.dart';
import 'prompt_viewport_actions.dart';
import '../common/themed_confirm_dialog.dart';

/// Keeps the text editor mounted so its viewport and native editing state
/// survive mode switches. Tag edits are transactions on the same controller.
class TagModePromptField extends ConsumerStatefulWidget {
  const TagModePromptField({
    super.key,
    required this.controller,
    required this.child,
    this.sourceFocusNode,
    this.sessionId,
    this.assistant,
    this.bottomPadding = 58,
    this.fitContent = false,
    this.surfaceColor,
    this.enabled = true,
    this.onModeChanged,
    this.onChanged,
    this.onSearch,
    this.enableAutocomplete = true,
    this.tagFocusNode,
    this.onClear,
    this.clearNeedsConfirm = false,
    this.showModeSwitch = true,
  });
  final TextEditingController controller;
  final Object? sessionId;

  /// A shared assistant mount that belongs inside the editor Stack.
  final Widget? assistant;
  final double bottomPadding;

  /// In content sizing, only the active editor contributes layout height.
  final bool fitContent;
  final Widget child;
  final FocusNode? sourceFocusNode;
  final FocusNode? tagFocusNode;
  final VoidCallback? onClear;
  final bool clearNeedsConfirm;
  final bool showModeSwitch;
  final Color? surfaceColor;
  final bool enabled;
  final bool enableAutocomplete;
  final ValueChanged<bool>? onModeChanged;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onSearch;
  @override
  ConsumerState<TagModePromptField> createState() => _TagModePromptFieldState();
}

class _TagModePromptFieldState extends ConsumerState<TagModePromptField> {
  late TagEditorSession _session;
  String _lastText = '';
  Object get _modeId => widget.sessionId ?? widget.controller;
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _session = TagEditorSession(widget.controller)
      ..tagMode = ref.read(promptTagModeProvider(_modeId))
      ..addListener(_changed);
    _lastText = widget.controller.text;
  }

  void _changed() {
    final text = widget.controller.text;
    if (text != _lastText) {
      _lastText = text;
      if (_session.tagMode) widget.onChanged?.call(text);
    }
  }

  @override
  void didUpdateWidget(TagModePromptField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.sessionId != widget.sessionId) {
      _session.dispose();
      _attach();
    }
    if (oldWidget.enabled && !widget.enabled) _session.endEdit();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _modeChanged(bool tagMode) {
    _session.endEdit();
    _session.tagMode = tagMode;
    widget.onModeChanged?.call(_session.tagMode);
    if (_session.tagMode) {
      widget.sourceFocusNode?.unfocus();
    } else {
      widget.sourceFocusNode?.requestFocus();
    }
  }

  Future<void> _clear() async {
    if (widget.clearNeedsConfirm) {
      final l10n = context.l10n;
      final confirmed = await ThemedConfirmDialog.show(
        context: context,
        title: l10n.common_confirmClear,
        content: l10n.common_clearInputConfirm,
        confirmText: l10n.common_clear,
        cancelText: l10n.common_cancel,
        type: ThemedConfirmDialogType.warning,
        icon: Icons.clear_all,
      );
      if (!mounted || !confirmed) return;
    }
    _session.endEdit();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(promptTagModeProvider(_modeId), (_, tagMode) {
      if (_session.tagMode != tagMode) _modeChanged(tagMode);
    });
    final tagMode = ref.watch(promptTagModeProvider(_modeId));
    _session.tagMode = tagMode;
    return TagEditorScope(
      session: _session,
      child: Actions(
        actions: <Type, Action<Intent>>{
          if (widget.controller case final NaiSyntaxController controller)
            CopySelectionTextIntent: controller.displayController
                .clipboardAction(enabled: widget.enabled),
          UndoTextIntent: CallbackAction<UndoTextIntent>(
            onInvoke: (_) {
              _session.undo();
              return null;
            },
          ),
          RedoTextIntent: CallbackAction<RedoTextIntent>(
            onInvoke: (_) {
              _session.redo();
              return null;
            },
          ),
        },
        child: Stack(
          fit: StackFit.passthrough,
          clipBehavior: Clip.hardEdge,
          children: [
            // Keep the same editing subtree in both sizing modes. Offstage
            // removes its height contribution without losing native state.
            Offstage(
              offstage: widget.fitContent && _session.tagMode,
              child: Visibility(
                visible: !_session.tagMode,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: widget.child,
              ),
            ),
            // Null insets use normal Stack sizing without reparenting the
            // tag editor when switching between manual and content heights.
            if (_session.tagMode)
              Positioned(
                left: widget.fitContent ? null : 0,
                right: widget.fitContent ? null : 0,
                top: widget.fitContent ? null : 0,
                bottom: widget.fitContent ? null : 0,
                child: TagEditorView(
                  key: ValueKey(_modeId),
                  bottomPadding: widget.bottomPadding,
                  session: _session,
                  surfaceColor: widget.surfaceColor,
                  enabled: widget.enabled,
                  enableAutocomplete: widget.enableAutocomplete,
                  onSearch: widget.onSearch,
                  focusNode: widget.tagFocusNode,
                ),
              ),
            Positioned.fill(child: _viewportActions(context)),
            if (widget.assistant != null) widget.assistant!,
          ],
        ),
      ),
    );
  }

  Widget _viewportActions(BuildContext context) => PromptViewportActions(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_session.tagMode && widget.onClear != null) ...[
          IconButton(
            key: const ValueKey('tag-clear-button'),
            tooltip: context.l10n.common_clear,
            onPressed: widget.enabled ? _clear : null,
            icon: const Icon(Icons.clear, size: 19),
          ),
          const SizedBox(width: 4),
        ],
        if (widget.showModeSwitch) _modeSwitch(context),
      ],
    ),
  );

  Widget _modeSwitch(BuildContext context) =>
      PromptTagModeToggle(sessionId: _modeId, enabled: widget.enabled);
}
