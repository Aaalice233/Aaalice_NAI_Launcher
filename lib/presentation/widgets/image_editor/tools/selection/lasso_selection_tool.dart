import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/editor_state.dart';
import '../tool_base.dart';

/// 套索选区工具（自由选区）
class LassoSelectionTool extends EditorTool {
  /// 选区设置
  SelectionSettings _settings = const SelectionSettings();
  SelectionSettings get settings => _settings;

  /// 采集的点
  final List<Offset> _points = [];

  @override
  String get id => 'lasso_selection';

  @override
  String get name => '套索选区';

  @override
  IconData get icon => Icons.gesture;

  @override
  LogicalKeyboardKey get shortcutKey => LogicalKeyboardKey.keyL;

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
    _points.clear();
    // 坐标已由 EditorCanvas 统一转换为画布坐标
    final point = event.localPosition;
    _points.add(point);
    _updatePreviewPath(state);
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    if (_points.isNotEmpty) {
      // 坐标已由 EditorCanvas 统一转换为画布坐标
      final point = event.localPosition;

      // 简化路径：只有距离足够远才添加新点
      if (_points.isEmpty || (_points.last - point).distance > 3) {
        _points.add(point);
        _updatePreviewPath(state);
      }
    }
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    if (_points.length >= 3) {
      final path = _createPath();
      path.close(); // 闭合路径
      _applySelection(state, path);
    }

    _points.clear();
    state.setLassoPreviewPath(null);
  }

  @override
  void onPointerCancel(EditorState state) {
    _points.clear();
    state.setLassoPreviewPath(null);
    state.cancelStroke();
  }

  void _updatePreviewPath(EditorState state) {
    if (_points.length < 2) {
      state.setLassoPreviewPath(null);
      return;
    }

    final path = _createPath();
    // 添加回到起点的虚线预览
    path.lineTo(_points.first.dx, _points.first.dy);
    state.setLassoPreviewPath(path);
  }

  Path _createPath() {
    final path = Path();
    if (_points.isEmpty) return path;

    path.moveTo(_points.first.dx, _points.first.dy);

    // 使用平滑曲线连接点
    if (_points.length <= 2) {
      for (int i = 1; i < _points.length; i++) {
        path.lineTo(_points[i].dx, _points[i].dy);
      }
    } else {
      for (int i = 1; i < _points.length - 1; i++) {
        final p0 = _points[i];
        final p1 = _points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        final midY = (p0.dy + p1.dy) / 2;
        path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
      }
      path.lineTo(_points.last.dx, _points.last.dy);
    }

    return path;
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
    return _LassoSelectionSettingsPanel(
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

class _LassoSelectionSettingsPanel extends StatelessWidget {
  final LassoSelectionTool tool;
  final VoidCallback onSettingsChanged;
  final VoidCallback onClearSelection;
  final VoidCallback onInvertSelection;

  const _LassoSelectionSettingsPanel({
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
            '套索选区',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1),

        // 使用提示
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
                    '按住鼠标拖动绘制自由形状选区，松开自动闭合',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

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
