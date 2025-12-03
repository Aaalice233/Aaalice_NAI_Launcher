import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/editor_state.dart';
import '../core/history_manager.dart';
import 'tool_base.dart';

/// 笔刷预设
class BrushPreset {
  final String name;
  final IconData icon;
  final double size;
  final double opacity;
  final double hardness;

  const BrushPreset({
    required this.name,
    required this.icon,
    required this.size,
    required this.opacity,
    required this.hardness,
  });

  BrushSettings toSettings() => BrushSettings(
        size: size,
        opacity: opacity,
        hardness: hardness,
      );
}

/// 默认笔刷预设列表
const List<BrushPreset> defaultBrushPresets = [
  BrushPreset(
    name: '铅笔',
    icon: Icons.edit,
    size: 2,
    opacity: 1.0,
    hardness: 1.0,
  ),
  BrushPreset(
    name: '细笔',
    icon: Icons.brush,
    size: 5,
    opacity: 1.0,
    hardness: 0.9,
  ),
  BrushPreset(
    name: '标准笔刷',
    icon: Icons.brush_outlined,
    size: 20,
    opacity: 1.0,
    hardness: 0.8,
  ),
  BrushPreset(
    name: '软笔刷',
    icon: Icons.blur_on,
    size: 30,
    opacity: 0.8,
    hardness: 0.3,
  ),
  BrushPreset(
    name: '喷枪',
    icon: Icons.blur_circular,
    size: 50,
    opacity: 0.5,
    hardness: 0.1,
  ),
  BrushPreset(
    name: '马克笔',
    icon: Icons.format_color_fill,
    size: 15,
    opacity: 0.7,
    hardness: 0.6,
  ),
  BrushPreset(
    name: '粗笔刷',
    icon: Icons.format_paint,
    size: 80,
    opacity: 1.0,
    hardness: 0.7,
  ),
  BrushPreset(
    name: '涂抹笔',
    icon: Icons.gesture,
    size: 40,
    opacity: 0.6,
    hardness: 0.2,
  ),
];

/// 画笔工具
class BrushTool extends EditorTool {
  /// 画笔设置
  BrushSettings _settings = const BrushSettings();
  BrushSettings get settings => _settings;

  @override
  String get id => 'brush';

  @override
  String get name => '画笔';

  @override
  IconData get icon => Icons.brush;

  @override
  LogicalKeyboardKey get shortcutKey => LogicalKeyboardKey.keyB;

  @override
  bool get isPaintTool => true;

  /// 更新设置
  void updateSettings(BrushSettings settings) {
    _settings = settings;
  }

  /// 应用预设
  void applyPreset(BrushPreset preset) {
    _settings = preset.toSettings();
  }

  /// 设置画笔大小
  void setSize(double size) {
    _settings = _settings.copyWith(size: size.clamp(1.0, 500.0));
  }

  /// 设置不透明度
  void setOpacity(double opacity) {
    _settings = _settings.copyWith(opacity: opacity.clamp(0.0, 1.0));
  }

  /// 设置硬度
  void setHardness(double hardness) {
    _settings = _settings.copyWith(hardness: hardness.clamp(0.0, 1.0));
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
        // 创建笔画数据
        final stroke = StrokeData(
          points: List.from(state.currentStrokePoints),
          size: _settings.size,
          color: state.foregroundColor,
          opacity: _settings.opacity,
          hardness: _settings.hardness,
          isEraser: false,
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
  double getCursorRadius(EditorState state) => _settings.size / 2;

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return _BrushSettingsPanel(
      tool: this,
      onSettingsChanged: () {
        // 触发刷新
        state.notifyListeners();
      },
    );
  }
}

class _BrushSettingsPanel extends StatefulWidget {
  final BrushTool tool;
  final VoidCallback onSettingsChanged;

  const _BrushSettingsPanel({
    required this.tool,
    required this.onSettingsChanged,
  });

  @override
  State<_BrushSettingsPanel> createState() => _BrushSettingsPanelState();
}

class _BrushSettingsPanelState extends State<_BrushSettingsPanel> {
  late TextEditingController _sizeController;

  @override
  void initState() {
    super.initState();
    _sizeController = TextEditingController(
      text: widget.tool.settings.size.round().toString(),
    );
  }

  @override
  void didUpdateWidget(_BrushSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当工具设置外部变化时，同步更新控制器
    final newSizeText = widget.tool.settings.size.round().toString();
    if (_sizeController.text != newSizeText) {
      _sizeController.text = newSizeText;
    }
  }

  @override
  void dispose() {
    _sizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.tool.settings;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '画笔设置',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1),

        // 笔刷预设
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '笔刷预设',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: defaultBrushPresets.length,
                  itemBuilder: (context, index) {
                    final preset = defaultBrushPresets[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _BrushPresetButton(
                        preset: preset,
                        onTap: () {
                          setState(() {
                            widget.tool.applyPreset(preset);
                            _sizeController.text = preset.size.round().toString();
                          });
                          widget.onSettingsChanged();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 大小
        _SettingRow(
          label: '大小',
          value: settings.size,
          min: 1,
          max: 500,
          controller: _sizeController,
          onChanged: (value) {
            widget.tool.setSize(value);
            _sizeController.text = value.round().toString();
            widget.onSettingsChanged();
          },
        ),

        // 不透明度
        _SettingRow(
          label: '不透明度',
          value: settings.opacity * 100,
          min: 0,
          max: 100,
          suffix: '%',
          onChanged: (value) {
            widget.tool.setOpacity(value / 100);
            widget.onSettingsChanged();
          },
        ),

        // 硬度
        _SettingRow(
          label: '硬度',
          value: settings.hardness * 100,
          min: 0,
          max: 100,
          suffix: '%',
          onChanged: (value) {
            widget.tool.setHardness(value / 100);
            widget.onSettingsChanged();
          },
        ),
      ],
    );
  }
}

/// 笔刷预设按钮
class _BrushPresetButton extends StatelessWidget {
  final BrushPreset preset;
  final VoidCallback onTap;

  const _BrushPresetButton({
    required this.preset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(preset.icon, size: 24),
            const SizedBox(height: 2),
            Text(
              preset.name,
              style: theme.textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置行组件
class _SettingRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String? suffix;
  final TextEditingController? controller;
  final ValueChanged<double> onChanged;

  const _SettingRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.suffix,
    this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: controller != null
                ? TextField(
                    controller: controller,
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
                        onChanged(parsed.clamp(min, max));
                      }
                    },
                  )
                : Text(
                    '${value.round()}${suffix ?? ''}',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
          ),
        ],
      ),
    );
  }
}
