import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import 'tag_editor_scope.dart';
import 'tag_editor_session.dart';
import 'tag_editor_view.dart';
import 'nai_syntax_controller.dart';
import '../common/themed_confirm_dialog.dart';

/// Keeps the text editor mounted so its viewport and native editing state
/// survive mode switches. Tag edits are transactions on the same controller.
class TagModePromptField extends StatefulWidget {
  const TagModePromptField({
    super.key,
    required this.controller,
    required this.child,
    this.sourceFocusNode,
    this.surfaceColor,
    this.enabled = true,
    this.onModeChanged,
    this.onChanged,
    this.onSearch,
    this.enableAutocomplete = true,
    this.tagFocusNode,
    this.onClear,
    this.clearNeedsConfirm = false,
  });
  final TextEditingController controller;
  final Widget child;
  final FocusNode? sourceFocusNode;
  final FocusNode? tagFocusNode;
  final VoidCallback? onClear;
  final bool clearNeedsConfirm;
  final Color? surfaceColor;
  final bool enabled;
  final bool enableAutocomplete;
  final ValueChanged<bool>? onModeChanged;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onSearch;
  @override
  State<TagModePromptField> createState() => _TagModePromptFieldState();
}

class _TagModePromptFieldState extends State<TagModePromptField> {
  late TagEditorSession _session;
  String _lastText = '';
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _session = TagEditorSession(widget.controller)..addListener(_changed);
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
    if (oldWidget.controller != widget.controller) {
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

  void _toggle() {
    _session.endEdit();
    setState(() => _session.tagMode = !_session.tagMode);
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
    final scheme = Theme.of(context).colorScheme;
    final extent = context.interactionPolicy.minimumControlExtent.clamp(
      44.0,
      double.infinity,
    );
    final tooltip = _session.tagMode
        ? context.l10n.tagMode_exit
        : context.l10n.tagMode_enter;
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
            Visibility(
              visible: !_session.tagMode,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: widget.child,
            ),
            if (_session.tagMode)
              Positioned.fill(
                child: TagEditorView(
                  session: _session,
                  surfaceColor: widget.surfaceColor,
                  enabled: widget.enabled,
                  enableAutocomplete: widget.enableAutocomplete,
                  onSearch: widget.onSearch,
                  focusNode: widget.tagFocusNode,
                ),
              ),
            if (_session.tagMode && widget.onClear != null)
              PositionedDirectional(
                end: extent + 8,
                bottom: 4,
                child: IconButton(
                  key: const ValueKey('tag-clear-button'),
                  tooltip: context.l10n.common_clear,
                  onPressed: widget.enabled ? _clear : null,
                  icon: const Icon(Icons.clear, size: 19),
                ),
              ),
            PositionedDirectional(
              end: 4,
              bottom: 4,
              width: extent,
              height: extent,
              child: Semantics(
                button: true,
                toggled: _session.tagMode,
                label: tooltip,
                child: IconButton(
                  key: const ValueKey('tag-mode-button'),
                  tooltip: tooltip,
                  onPressed: widget.enabled || _session.tagMode
                      ? _toggle
                      : null,
                  style: IconButton.styleFrom(
                    foregroundColor: _session.tagMode
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    backgroundColor: _session.tagMode
                        ? scheme.primaryContainer
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: Icon(
                    _session.tagMode ? Icons.sell : Icons.sell_outlined,
                    size: 19,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
