import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../core/editor_view_action.dart';
import '../toolbar/editor_view_menu.dart';

/// 展示图像编辑器的自适应快捷键帮助面板。
void presentEditorShortcutHelp(
  BuildContext context, {
  required bool includeFrameTool,
  required bool includeCloneStamp,
}) {
  unawaited(
    AdaptivePresenter.showForm<void>(
      context: context,
      dialogWidth: 440,
      titleBuilder: (panelContext) => Row(
        children: [
          const Icon(Icons.keyboard),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              panelContext.l10n.editor_shortcutHelpTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      builder: (panelContext, scrollController) => ListView(
        key: const ValueKey('image-editor-shortcut-help-scroll'),
        controller: scrollController,
        shrinkWrap: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        children: [
          _buildShortcutSection(
            panelContext,
            context.l10n.editor_shortcutPaintTools,
            [
              ('B', context.l10n.editor_toolBrush),
              ('E', context.l10n.editor_toolEraser),
              ('G', context.l10n.editor_toolFill),
              ('W', context.l10n.editor_toolMagicWand),
              ('P', context.l10n.editor_toolColorPicker),
              ('Alt', context.l10n.editor_shortcutTemporaryColorPicker),
              if (includeCloneStamp)
                ('Alt + Click', context.l10n.editor_shortcutCloneStampSource),
              ('V', context.l10n.editor_toolMove),
              if (includeFrameTool) ('C', context.l10n.editor_toolFrame),
            ],
          ),
          _buildShortcutSection(
            panelContext,
            context.l10n.editor_shortcutSelectionTools,
            [
              ('M', context.l10n.editor_shortcutRectSelection),
              ('U', context.l10n.editor_shortcutEllipseSelection),
              ('L', context.l10n.editor_shortcutLassoSelection),
            ],
          ),
          _buildShortcutSection(
            panelContext,
            context.l10n.editor_shortcutCanvasView,
            [
              for (final action in EditorViewAction.byShortcut)
                (action.shortcutLabel!, action.label(context)),
              (context.l10n.editor_shortcutWheel, context.l10n.editor_zoom),
              ('Ctrl+0', context.l10n.editor_shortcut100Zoom),
              ('Ctrl++', context.l10n.editor_zoomIn),
              ('Ctrl+-', context.l10n.editor_zoomOut),
            ],
          ),
          _buildShortcutSection(
            panelContext,
            context.l10n.editor_shortcutBrushAdjust,
            [
              ('[', context.l10n.editor_shortcutBrushSmaller),
              (']', context.l10n.editor_shortcutBrushLarger),
              ('I', context.l10n.editor_shortcutOpacityLower),
              ('O', context.l10n.editor_shortcutOpacityHigher),
              ('Shift + Drag', context.l10n.editor_shortcutDragBrushSize),
            ],
          ),
          _buildShortcutSection(
            panelContext,
            context.l10n.editor_shortcutColors,
            [('X', context.l10n.editor_shortcutSwapColors)],
          ),
          _buildShortcutSection(
            panelContext,
            context.l10n.editor_shortcutCanvasActions,
            [
              ('Space + Drag', context.l10n.editor_shortcutPanCanvas),
              ('Middle Drag', context.l10n.editor_shortcutPanCanvas),
            ],
          ),
          _buildShortcutSection(
            panelContext,
            context.l10n.editor_shortcutHistoryActions,
            [
              ('Ctrl+Z', context.l10n.editor_undo),
              ('Ctrl+Shift+Z', context.l10n.editor_redo),
              ('Ctrl+Y', context.l10n.editor_redo),
            ],
          ),
          _buildShortcutSection(
            panelContext,
            context.l10n.editor_shortcutSelectionActions,
            [
              ('Delete', context.l10n.editor_shortcutClearSelectionContent),
              ('Backspace', context.l10n.editor_shortcutClearSelectionContent),
              ('← ↑ → ↓', context.l10n.editor_shortcutNudge),
              ('Shift + ← ↑ → ↓', context.l10n.editor_shortcutNudgeFar),
              ('Ctrl+T', context.l10n.editor_shortcutFreeTransform),
              ('Enter', context.l10n.editor_shortcutApplyTransform),
              ('Esc', context.l10n.editor_shortcutCancelCurrentAction),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildShortcutSection(
  BuildContext context,
  String title,
  List<(String, String)> shortcuts,
) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // 按键名最多占半行，放大文字时在自身框内换行，不把说明顶出右侧
            final keyMaxWidth = constraints.maxWidth / 2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in shortcuts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          constraints: BoxConstraints(maxWidth: keyMaxWidth),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            s.$1,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(s.$2, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
