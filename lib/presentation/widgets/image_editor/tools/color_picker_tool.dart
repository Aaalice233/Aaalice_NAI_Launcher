import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/editor_state.dart';
import 'tool_base.dart';

/// 拾色器工具
class ColorPickerTool extends EditorTool {
  /// 取样范围
  ColorPickerSampleMode _sampleMode = ColorPickerSampleMode.point;
  ColorPickerSampleMode get sampleMode => _sampleMode;

  /// 取样来源
  ColorPickerSource _source = ColorPickerSource.allLayers;
  ColorPickerSource get source => _source;

  /// 预览颜色
  Color? _previewColor;
  Color? get previewColor => _previewColor;

  /// 预览位置
  Offset? _previewPosition;
  Offset? get previewPosition => _previewPosition;

  @override
  String get id => 'color_picker';

  @override
  String get name => '拾色器';

  @override
  IconData get icon => Icons.colorize;

  @override
  LogicalKeyboardKey get shortcutKey => LogicalKeyboardKey.keyI;

  /// 设置取样模式
  void setSampleMode(ColorPickerSampleMode mode) {
    _sampleMode = mode;
  }

  /// 设置取样来源
  void setSource(ColorPickerSource source) {
    _source = source;
  }

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    _pickColor(event.localPosition, state);
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    _updatePreview(event.localPosition, state);
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    if (_previewColor != null) {
      state.setForegroundColor(_previewColor!);
      // 切回上一个工具
      state.switchToPreviousTool();
    }
    _clearPreview(state);
  }

  @override
  void onPointerCancel(EditorState state) {
    _clearPreview(state);
    state.cancelStroke();
  }

  Future<void> _pickColor(Offset screenPosition, EditorState state) async {
    final color = await _sampleColorAt(screenPosition, state);
    if (color != null) {
      _previewColor = color;
      _previewPosition = screenPosition;
      state.notifyListeners();
    }
  }

  Future<void> _updatePreview(Offset screenPosition, EditorState state) async {
    final color = await _sampleColorAt(screenPosition, state);
    if (color != null) {
      _previewColor = color;
      _previewPosition = screenPosition;
      state.notifyListeners();
    }
  }

  void _clearPreview(EditorState state) {
    _previewColor = null;
    _previewPosition = null;
    state.notifyListeners();
  }

  /// 在指定画布坐标位置采样颜色
  /// 注意：坐标已由 EditorCanvas 统一转换为画布坐标
  Future<Color?> _sampleColorAt(Offset canvasPoint, EditorState state) async {
    // 检查是否在画布范围内
    if (canvasPoint.dx < 0 ||
        canvasPoint.dy < 0 ||
        canvasPoint.dx >= state.canvasSize.width ||
        canvasPoint.dy >= state.canvasSize.height) {
      return null;
    }

    // 创建临时图像来采样颜色
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 根据来源绘制
    if (_source == ColorPickerSource.currentLayer) {
      final activeLayer = state.layerManager.activeLayer;
      if (activeLayer != null) {
        activeLayer.render(canvas, state.canvasSize);
      }
    } else {
      state.layerManager.renderAll(canvas, state.canvasSize);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      state.canvasSize.width.toInt(),
      state.canvasSize.height.toInt(),
    );

    // 获取像素颜色
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();

    if (byteData == null) return null;

    final x = canvasPoint.dx.toInt();
    final y = canvasPoint.dy.toInt();
    final width = state.canvasSize.width.toInt();

    if (_sampleMode == ColorPickerSampleMode.point) {
      // 单点采样
      final offset = (y * width + x) * 4;
      if (offset >= 0 && offset + 3 < byteData.lengthInBytes) {
        final r = byteData.getUint8(offset);
        final g = byteData.getUint8(offset + 1);
        final b = byteData.getUint8(offset + 2);
        final a = byteData.getUint8(offset + 3);
        return Color.fromARGB(a, r, g, b);
      }
    } else {
      // 区域采样（3x3平均）
      int totalR = 0, totalG = 0, totalB = 0, totalA = 0;
      int count = 0;

      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          final px = (x + dx).clamp(0, width - 1);
          final py = (y + dy).clamp(0, state.canvasSize.height.toInt() - 1);
          final offset = (py * width + px) * 4;

          if (offset >= 0 && offset + 3 < byteData.lengthInBytes) {
            totalR += byteData.getUint8(offset);
            totalG += byteData.getUint8(offset + 1);
            totalB += byteData.getUint8(offset + 2);
            totalA += byteData.getUint8(offset + 3);
            count++;
          }
        }
      }

      if (count > 0) {
        return Color.fromARGB(
          (totalA / count).round(),
          (totalR / count).round(),
          (totalG / count).round(),
          (totalB / count).round(),
        );
      }
    }

    return null;
  }

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return _ColorPickerSettingsPanel(
      tool: this,
      onSettingsChanged: () {
        state.notifyListeners();
      },
    );
  }

  @override
  Widget? buildCursor(EditorState state) {
    if (_previewColor != null && _previewPosition != null) {
      return Positioned(
        left: _previewPosition!.dx - 30,
        top: _previewPosition!.dy - 60,
        child: _ColorPreviewBubble(color: _previewColor!),
      );
    }
    return null;
  }
}

/// 取样模式
enum ColorPickerSampleMode {
  /// 单点取样
  point,
  /// 区域取样（3x3）
  area,
}

extension ColorPickerSampleModeExtension on ColorPickerSampleMode {
  String get label {
    switch (this) {
      case ColorPickerSampleMode.point:
        return '单点';
      case ColorPickerSampleMode.area:
        return '区域';
    }
  }
}

/// 取样来源
enum ColorPickerSource {
  /// 当前图层
  currentLayer,
  /// 所有图层
  allLayers,
}

extension ColorPickerSourceExtension on ColorPickerSource {
  String get label {
    switch (this) {
      case ColorPickerSource.currentLayer:
        return '当前图层';
      case ColorPickerSource.allLayers:
        return '所有图层';
    }
  }
}

class _ColorPickerSettingsPanel extends StatelessWidget {
  final ColorPickerTool tool;
  final VoidCallback onSettingsChanged;

  const _ColorPickerSettingsPanel({
    required this.tool,
    required this.onSettingsChanged,
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
            '拾色器',
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
                    '点击画布任意位置取色，松开后自动切回上一工具',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 取样模式
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text('取样', style: theme.textTheme.bodySmall),
              ),
              Expanded(
                child: SegmentedButton<ColorPickerSampleMode>(
                  segments: ColorPickerSampleMode.values.map((mode) {
                    return ButtonSegment<ColorPickerSampleMode>(
                      value: mode,
                      label: Text(mode.label),
                    );
                  }).toList(),
                  selected: {tool.sampleMode},
                  onSelectionChanged: (selected) {
                    tool.setSampleMode(selected.first);
                    onSettingsChanged();
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(theme.textTheme.bodySmall),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 取样来源
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text('来源', style: theme.textTheme.bodySmall),
              ),
              Expanded(
                child: SegmentedButton<ColorPickerSource>(
                  segments: ColorPickerSource.values.map((source) {
                    return ButtonSegment<ColorPickerSource>(
                      value: source,
                      label: Text(source.label),
                    );
                  }).toList(),
                  selected: {tool.source},
                  onSelectionChanged: (selected) {
                    tool.setSource(selected.first);
                    onSettingsChanged();
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(theme.textTheme.bodySmall),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 颜色预览气泡
class _ColorPreviewBubble extends StatelessWidget {
  final Color color;

  const _ColorPreviewBubble({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
            style: const TextStyle(fontSize: 8, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
