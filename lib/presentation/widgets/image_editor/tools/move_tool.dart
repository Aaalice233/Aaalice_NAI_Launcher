import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../widgets/common/themed_divider.dart';
import '../core/editor_state.dart';
import 'tool_base.dart';

/// 移动工具：有选区时移动当前图层在选区内的像素，否则平移整个图层
class MoveTool extends EditorTool {
  static const String toolId = 'move';

  @override
  String get id => toolId;

  @override
  String get name => 'Move';

  @override
  IconData get icon => Icons.open_with;

  @override
  LogicalKeyboardKey? get shortcutKey => LogicalKeyboardKey.keyV;

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    state.layerMover.begin(event.localPosition);
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    state.layerMover.update(event.localPosition);
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    state.layerMover.end();
  }

  @override
  void onPointerCancel(EditorState state) {
    state.layerMover.cancel();
    state.cancelStroke();
  }

  @override
  void onDeactivateFast(EditorState state) => state.layerMover.cancel();

  @override
  bool onArrowNudge(EditorState state, Offset delta) {
    state.layerMover.nudge(delta);
    return true;
  }

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return _MoveToolPanel(state: state);
  }
}

class _MoveToolPanel extends StatelessWidget {
  const _MoveToolPanel({required this.state});

  final EditorState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            context.l10n.editor_toolMove,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const ThemedDivider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              state.selectionManager.selectionNotifier,
              state.layerManager.activeLayerNotifier,
            ]),
            builder: (context, _) {
              final layer = state.layerManager.activeLayer;
              final hint = switch ((layer, state.selectionPath)) {
                (null, _) => context.l10n.editor_moveNoLayer,
                (_, final _?) => context.l10n.editor_moveSelectionHint,
                (final active?, null)
                    when !state.layerMover.canMoveWholeLayer(active) =>
                  context.l10n.editor_moveBaseLayerHint,
                _ => context.l10n.editor_moveLayerHint,
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.editor_moveNudgeHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
