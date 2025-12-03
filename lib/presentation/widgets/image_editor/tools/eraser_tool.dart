import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/editor_state.dart';
import '../core/history_manager.dart';
import 'tool_base.dart';

/// 橡皮擦工具
class EraserTool extends EditorTool {
  /// 橡皮擦设置
  double _size = 20.0;
  double get size => _size;

  double _hardness = 1.0;
  double get hardness => _hardness;

  /// 橡皮擦模式
  EraserMode _mode = EraserMode.normal;
  EraserMode get mode => _mode;

  @override
  String get id => 'eraser';

  @override
  String get name => '橡皮擦';

  @override
  IconData get icon => Icons.auto_fix_high;

  @override
  LogicalKeyboardKey get shortcutKey => LogicalKeyboardKey.keyE;

  @override
  bool get isPaintTool => true;

  /// 设置大小
  void setSize(double size) {
    _size = size.clamp(1.0, 500.0);
  }

  /// 设置硬度
  void setHardness(double hardness) {
    _hardness = hardness.clamp(0.0, 1.0);
  }

  /// 设置模式
  void setMode(EraserMode mode) {
    _mode = mode;
  }

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    // 坐标已由 EditorCanvas 统一转换为画布坐标
    state.startStroke(event.localPosition);
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    if (state.isDrawing) {
      // 坐标已由 EditorCanvas 统一转换为画布坐标
      state.updateStroke(event.localPosition);
    }
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    if (state.isDrawing && state.currentStrokePoints.isNotEmpty) {
      final activeLayer = state.layerManager.activeLayer;
      if (activeLayer != null && !activeLayer.locked) {
        // 创建橡皮擦笔画数据
        final stroke = StrokeData(
          points: List.from(state.currentStrokePoints),
          size: _size,
          color: Colors.transparent,
          opacity: 1.0,
          hardness: _hardness,
          isEraser: true,
        );

        // 执行添加笔画操作
        state.historyManager.execute(
          AddStrokeAction(layerId: activeLayer.id, stroke: stroke),
          state,
        );
      }
    }
    state.endStroke();
  }

  @override
  double getCursorRadius(EditorState state) => _size / 2;

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return _EraserSettingsPanel(
      tool: this,
      onSettingsChanged: () {
        state.notifyListeners();
      },
    );
  }
}

/// 橡皮擦模式
enum EraserMode {
  /// 普通擦除（变为透明）
  normal,
  /// 擦除到背景色
  background,
}

extension EraserModeExtension on EraserMode {
  String get label {
    switch (this) {
      case EraserMode.normal:
        return '透明';
      case EraserMode.background:
        return '背景色';
    }
  }
}

class _EraserSettingsPanel extends StatefulWidget {
  final EraserTool tool;
  final VoidCallback onSettingsChanged;

  const _EraserSettingsPanel({
    required this.tool,
    required this.onSettingsChanged,
  });

  @override
  State<_EraserSettingsPanel> createState() => _EraserSettingsPanelState();
}

class _EraserSettingsPanelState extends State<_EraserSettingsPanel> {
  late TextEditingController _sizeController;

  @override
  void initState() {
    super.initState();
    _sizeController = TextEditingController(
      text: widget.tool.size.round().toString(),
    );
  }

  @override
  void dispose() {
    _sizeController.dispose();
    super.dispose();
  }

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
            '橡皮擦设置',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1),

        // 大小
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text('大小', style: theme.textTheme.bodySmall),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: widget.tool.size,
                    min: 1,
                    max: 500,
                    onChanged: (value) {
                      setState(() {
                        widget.tool.setSize(value);
                        _sizeController.text = value.round().toString();
                      });
                      widget.onSettingsChanged();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: TextField(
                  controller: _sizeController,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (text) {
                    final parsed = double.tryParse(text);
                    if (parsed != null) {
                      setState(() {
                        widget.tool.setSize(parsed);
                      });
                      widget.onSettingsChanged();
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // 硬度
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text('硬度', style: theme.textTheme.bodySmall),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: widget.tool.hardness * 100,
                    min: 0,
                    max: 100,
                    onChanged: (value) {
                      setState(() {
                        widget.tool.setHardness(value / 100);
                      });
                      widget.onSettingsChanged();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '${(widget.tool.hardness * 100).round()}%',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // 模式选择
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text('模式', style: theme.textTheme.bodySmall),
              ),
              Expanded(
                child: SegmentedButton<EraserMode>(
                  segments: EraserMode.values.map((mode) {
                    return ButtonSegment<EraserMode>(
                      value: mode,
                      label: Text(mode.label),
                    );
                  }).toList(),
                  selected: {widget.tool.mode},
                  onSelectionChanged: (selected) {
                    setState(() {
                      widget.tool.setMode(selected.first);
                    });
                    widget.onSettingsChanged();
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      theme.textTheme.bodySmall,
                    ),
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
