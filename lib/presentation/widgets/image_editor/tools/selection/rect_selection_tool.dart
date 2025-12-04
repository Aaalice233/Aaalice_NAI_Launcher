import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/editor_state.dart';
import '../tool_base.dart';

/// 矩形选区工具
class RectSelectionTool extends EditorTool {
  /// 选区设置
  SelectionSettings _settings = const SelectionSettings();
  SelectionSettings get settings => _settings;

  /// 起始点
  Offset? _startPoint;

  @override
  String get id => 'rect_selection';

  @override
  String get name => '矩形选区';

  @override
  IconData get icon => Icons.crop_square;

  @override
  LogicalKeyboardKey get shortcutKey => LogicalKeyboardKey.keyM;

  @override
  bool get isSelectionTool => true;

  /// 更新设置
  void updateSettings(SelectionSettings settings) {
    _settings = settings;
  }

  /// 设置选区模式
  void setMode(SelectionMode mode) {
    _settings = _settings.copyWith(mode: mode);
  }

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    // 坐标已由 EditorCanvas 统一转换为画布坐标
    _startPoint = event.localPosition;
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    if (_startPoint != null) {
      // 坐标已由 EditorCanvas 统一转换为画布坐标
      final currentPoint = event.localPosition;
      final rect = Rect.fromPoints(_startPoint!, currentPoint);
      state.setSelectionPreview(rect);
    }
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    if (_startPoint != null) {
      // 坐标已由 EditorCanvas 统一转换为画布坐标
      final endPoint = event.localPosition;
      final rect = Rect.fromPoints(_startPoint!, endPoint);

      if (rect.width > 2 && rect.height > 2) {
        final path = Path()..addRect(rect);
        _applySelection(state, path);
      }
    }

    _startPoint = null;
    state.setSelectionPreview(null);
  }

  @override
  void onPointerCancel(EditorState state) {
    _startPoint = null;
    state.setSelectionPreview(null);
    state.cancelStroke();
  }

  void _applySelection(EditorState state, Path path) {
    switch (_settings.mode) {
      case SelectionMode.replace:
        state.setSelection(path);
        break;
      case SelectionMode.add:
        state.addToSelection(path);
        break;
      case SelectionMode.subtract:
        state.subtractFromSelection(path);
        break;
      case SelectionMode.intersect:
        state.intersectSelection(path);
        break;
    }
  }

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return _SelectionSettingsPanel(
      tool: this,
      onSettingsChanged: () {
        state.requestUiUpdate();
      },
      onClearSelection: () {
        state.clearSelection();
      },
      onInvertSelection: () {
        state.invertSelection();
      },
    );
  }
}

class _SelectionSettingsPanel extends StatelessWidget {
  final RectSelectionTool tool;
  final VoidCallback onSettingsChanged;
  final VoidCallback onClearSelection;
  final VoidCallback onInvertSelection;

  const _SelectionSettingsPanel({
    required this.tool,
    required this.onSettingsChanged,
    required this.onClearSelection,
    required this.onInvertSelection,
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
            '矩形选区',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1),

        // 模式选择
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选区模式', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: SelectionMode.values.map((mode) {
                  final isSelected = tool.settings.mode == mode;
                  return ChoiceChip(
                    label: Text(mode.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        tool.setMode(mode);
                        onSettingsChanged();
                      }
                    },
                    labelStyle: theme.textTheme.bodySmall,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // 操作按钮
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onClearSelection,
                icon: const Icon(Icons.deselect, size: 16),
                label: const Text('清除选区'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: theme.textTheme.bodySmall,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onInvertSelection,
                icon: const Icon(Icons.flip, size: 16),
                label: const Text('反转选区'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
