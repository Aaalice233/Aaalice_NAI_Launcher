import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../core/editor_state.dart';
import 'editor_view_menu.dart';

/// 顶栏放不下时收进溢出菜单的一项画布操作
class EditorMenuAction {
  const EditorMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool enabled;
}

/// 移动端顶栏溢出菜单：画布操作与视图控制分组呈现
class EditorOverflowMenu extends StatelessWidget {
  const EditorOverflowMenu({
    super.key,
    required this.state,
    this.canvasActions,
  });

  final EditorState state;

  /// 在打开菜单时求值，启用状态跟随当时的编辑状态
  final List<EditorMenuAction> Function()? canvasActions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      onSelected: (action) => action(),
      itemBuilder: (menuContext) {
        final actions = canvasActions?.call() ?? const <EditorMenuAction>[];
        return [
          if (actions.isNotEmpty)
            EditorMenuSectionHeader<VoidCallback>(
              title: menuContext.l10n.editor_menuGroupCanvas,
            ),
          for (final action in actions)
            PopupMenuItem<VoidCallback>(
              value: action.onSelected,
              enabled: action.enabled,
              child: ListTile(
                enabled: action.enabled,
                leading: Icon(action.icon),
                title: Text(action.label),
              ),
            ),
          ...editorViewMenuEntries(menuContext, state),
        ];
      },
    );
  }
}
