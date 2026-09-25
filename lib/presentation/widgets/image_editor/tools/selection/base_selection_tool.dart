import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../core/editor_state.dart';
import '../tool_base.dart';
import '../../../../widgets/common/themed_divider.dart';

/// 选区工具基类
/// 提供所有选区工具的共享功能
abstract class BaseSelectionTool extends EditorTool {
  /// 轮廓拖动的起点；为 null 表示当前手势在绘制新选区
  Offset? outlineDragStart;

  @override
  bool get isSelectionTool => true;

  @override
  void onDeactivateFast(EditorState state) => _abortGesture(state);

  @override
  void onPointerCancel(EditorState state) {
    _abortGesture(state);
    state.cancelStroke();
  }

  void _abortGesture(EditorState state) {
    onSelectionCancel();
    outlineDragStart = null;
    state.selectionManager.cancelDrag();
    state.clearPreview();
  }

  /// 在已有选区内按下时拖动轮廓；返回是否已接管本次拖动
  bool beginOutlineDrag(EditorState state, Offset position) {
    final selection = state.selectionManager;
    if (!selection.hasSelection || !selection.hitTestSelection(position)) {
      return false;
    }
    outlineDragStart = position;
    selection.beginDrag();
    return true;
  }

  bool updateOutlineDrag(EditorState state, Offset position) {
    final start = outlineDragStart;
    if (start == null) return false;
    state.selectionManager.updateDrag(position - start);
    return true;
  }

  bool endOutlineDrag(EditorState state) {
    if (outlineDragStart == null) return false;
    outlineDragStart = null;
    state.selectionManager.commitDrag();
    return true;
  }

  /// 新选区太小时视为单击空白处：取消选区，并进选区历史
  void commitNewSelection(EditorState state, Path? path) {
    state.clearPreview();
    if (path != null) {
      state.setSelection(path);
    } else {
      state.clearSelection();
    }
  }

  /// 子类实现：取消选区时清理内部状态
  void onSelectionCancel();

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return SelectionSettingsPanel(
      title: _localizedTitle(context),
      state: state,
      helpText: _localizedHelpText(context),
    );
  }

  /// 子类可重写：提供帮助文本
  String? get helpText => null;

  String _localizedTitle(BuildContext context) {
    switch (id) {
      case 'rect_selection':
        return context.l10n.editor_toolRectSelect;
      case 'ellipse_selection':
        return context.l10n.editor_toolEllipseSelect;
      case 'lasso_selection':
        return context.l10n.editor_toolLassoSelect;
      default:
        return name;
    }
  }

  String? _localizedHelpText(BuildContext context) {
    switch (id) {
      case 'lasso_selection':
        return context.l10n.editor_lassoSelectionHelp;
      default:
        return helpText;
    }
  }
}

/// 形状选区工具基类
/// 用于矩形、椭圆等两点确定形状的选区工具
abstract class ShapeSelectionTool extends BaseSelectionTool {
  /// 起始点
  Offset? startPoint;

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    final pos = event.localPosition;
    if (beginOutlineDrag(state, pos)) return;
    state.clearPreview();
    startPoint = pos;
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    if (updateOutlineDrag(state, event.localPosition)) return;

    final start = startPoint;
    if (start != null) {
      state.setPreviewPath(createShapePath(_constrainedRect(state, start, event.localPosition)));
    }
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    if (endOutlineDrag(state)) return;

    final start = startPoint;
    startPoint = null;
    if (start == null) return;
    final rect = _constrainedRect(state, start, event.localPosition);
    commitNewSelection(
      state,
      rect.width > 2 && rect.height > 2 ? createShapePath(rect) : null,
    );
  }

  @override
  void onSelectionCancel() {
    startPoint = null;
  }

  Rect _constrainedRect(EditorState state, Offset start, Offset end) {
    final candidate = Rect.fromPoints(start, end);
    return id == 'rect_selection'
        ? state.constrainRectSelection(candidate, start)
        : candidate;
  }

  /// 子类实现：根据矩形创建形状路径
  Path createShapePath(Rect rect);
}

/// 选区设置面板
/// 所有选区工具共享的设置面板
class SelectionSettingsPanel extends StatelessWidget {
  final String title;
  final EditorState state;
  final String? helpText;

  const SelectionSettingsPanel({
    super.key,
    required this.title,
    required this.state,
    this.helpText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const ThemedDivider(height: 1),

        // 帮助文本（可选）
        if (helpText != null) ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      helpText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ThemedDivider(height: 1),
        ],

        // 操作按钮：选区与当前图层变化时刷新可用状态
        Padding(
          padding: const EdgeInsets.all(12),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              state.selectionManager.selectionNotifier,
              state.layerManager,
              state.layerManager.activeLayerNotifier,
              state.layerManager.uiUpdateNotifier,
            ]),
            builder: (context, _) => _SelectionActions(state: state),
          ),
        ),
      ],
    );
  }
}

class _SelectionActions extends StatelessWidget {
  const _SelectionActions({required this.state});

  final EditorState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commands = state.layerCommands;
    final hasSelection = state.selectionPath != null;
    final canEditPixels = commands.canEditSelectionPixels;
    final activeName = state.layerManager.activeLayer?.name ?? '';
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    final outlined = OutlinedButton.styleFrom(
      padding: padding,
      textStyle: theme.textTheme.bodySmall,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: hasSelection ? () => state.clearSelection() : null,
          icon: const Icon(Icons.deselect, size: 16),
          label: Text(context.l10n.selection_clear_selection),
          style: outlined,
        ),
        OutlinedButton.icon(
          onPressed: hasSelection ? () => state.invertSelection() : null,
          icon: const Icon(Icons.flip, size: 16),
          label: Text(context.l10n.selection_invert_selection),
          style: outlined,
        ),
        OutlinedButton.icon(
          onPressed: canEditPixels ? commands.clearSelectionPixels : null,
          icon: const Icon(Icons.backspace_outlined, size: 16),
          label: Text(context.l10n.selection_clearPixels),
          style: outlined,
        ),
        FilledButton.icon(
          onPressed: canEditPixels
              ? () => commands.cutSelectionToNewLayer(
                  layerName: context.l10n.selection_cutLayerName(activeName),
                )
              : null,
          icon: const Icon(Icons.content_cut, size: 16),
          label: Text(context.l10n.selection_cut_to_layer),
          style: FilledButton.styleFrom(
            padding: padding,
            textStyle: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
