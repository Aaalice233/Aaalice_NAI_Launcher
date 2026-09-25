import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../themes/design_tokens.dart';
import '../../core/editor_state.dart';
import '../../core/editor_view_action.dart';

extension EditorViewActionLabels on EditorViewAction {
  String label(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      EditorViewAction.fitToWindow => l10n.editor_fitToWindow,
      EditorViewAction.actualSize => l10n.editor_shortcut100Zoom,
      EditorViewAction.fitWidth => l10n.editor_shortcutFitWidth,
      EditorViewAction.fitHeight => l10n.editor_shortcutFitHeight,
      EditorViewAction.rotateLeft => l10n.editor_shortcutRotateLeft15,
      EditorViewAction.rotateRight => l10n.editor_shortcutRotateRight15,
      EditorViewAction.resetRotation => l10n.editor_shortcutResetRotation,
      EditorViewAction.mirror => l10n.editor_shortcutFlipHorizontal,
      EditorViewAction.resetView => l10n.editor_resetView,
    };
  }

  String tooltip(BuildContext context) {
    final shortcut = shortcutLabel;
    return shortcut == null ? label(context) : '${label(context)} ($shortcut)';
  }
}

/// 视图分组菜单项，移动端溢出菜单与桌面缩放菜单共用
List<PopupMenuEntry<VoidCallback>> editorViewMenuEntries(
  BuildContext context,
  EditorState state,
) {
  return [
    EditorMenuSectionHeader<VoidCallback>(
      title: context.l10n.editor_menuGroupView,
    ),
    for (final action in EditorViewAction.values)
      PopupMenuItem<VoidCallback>(
        key: ValueKey('editor-view-menu-${action.name}'),
        value: () => action.perform(state),
        child: _ViewActionTile(
          action: action,
          active: action.isActiveIn(state.canvasController),
        ),
      ),
  ];
}

/// 菜单分组标题，不可选中
class EditorMenuSectionHeader<T> extends PopupMenuEntry<T> {
  const EditorMenuSectionHeader({super.key, required this.title});

  final String title;

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(T? value) => false;

  @override
  State<EditorMenuSectionHeader<T>> createState() =>
      _EditorMenuSectionHeaderState<T>();
}

class _EditorMenuSectionHeaderState<T>
    extends State<EditorMenuSectionHeader<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        // 与菜单项 ListTile 前导图标的左缘对齐
        padding: const EdgeInsetsDirectional.fromSTEB(
          DesignTokens.spacingSm + DesignTokens.spacingMd,
          DesignTokens.spacingMd,
          DesignTokens.spacingLg,
          DesignTokens.spacingXxs,
        ),
        child: Text(
          widget.title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ViewActionTile extends StatelessWidget {
  const _ViewActionTile({required this.action, required this.active});

  final EditorViewAction action;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      selected: active,
      leading: Icon(action.icon),
      title: Text(action.label(context)),
      trailing: active ? const Icon(Icons.check) : null,
    );
    return action.isToggle ? Semantics(toggled: active, child: tile) : tile;
  }
}
