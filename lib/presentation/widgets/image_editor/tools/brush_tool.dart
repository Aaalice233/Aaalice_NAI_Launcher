import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../core/editor_state.dart';
import '../core/history_manager.dart';
import 'color_picker_tool.dart';
import 'tool_base.dart';
import 'tool_setting_rows.dart';
import '../../../widgets/common/horizontal_action_strip.dart';
import '../../../widgets/common/themed_divider.dart';

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

  BrushSettings toSettings() =>
      BrushSettings(size: size, opacity: opacity, hardness: hardness);
}

/// 默认笔刷预设列表
const List<BrushPreset> defaultBrushPresets = [
  BrushPreset(
    name: 'Pencil',
    icon: Icons.edit,
    size: 2,
    opacity: 1.0,
    hardness: 1.0,
  ),
  BrushPreset(
    name: 'Fine Brush',
    icon: Icons.brush,
    size: 5,
    opacity: 1.0,
    hardness: 0.9,
  ),
  BrushPreset(
    name: 'Standard Brush',
    icon: Icons.brush_outlined,
    size: 20,
    opacity: 1.0,
    hardness: 0.8,
  ),
  BrushPreset(
    name: 'Soft Brush',
    icon: Icons.blur_on,
    size: 30,
    opacity: 0.8,
    hardness: 0.3,
  ),
  BrushPreset(
    name: 'Airbrush',
    icon: Icons.blur_circular,
    size: 50,
    opacity: 0.5,
    hardness: 0.1,
  ),
  BrushPreset(
    name: 'Marker',
    icon: Icons.format_color_fill,
    size: 15,
    opacity: 0.7,
    hardness: 0.6,
  ),
  BrushPreset(
    name: 'Thick Brush',
    icon: Icons.format_paint,
    size: 80,
    opacity: 1.0,
    hardness: 0.7,
  ),
  BrushPreset(
    name: 'Smudge Brush',
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

  /// 当前选中的预设索引（-1 表示自定义/无选中）
  int _selectedPresetIndex = 2; // Default to "Standard Brush".
  int get selectedPresetIndex => _selectedPresetIndex;

  @override
  String get id => 'brush';

  @override
  String get name => 'Brush';

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
  void applyPreset(BrushPreset preset, int index) {
    _settings = preset.toSettings();
    _selectedPresetIndex = index;
  }

  /// 直接设置预设索引（用于恢复持久化设置）
  void setSelectedPresetIndex(int index) {
    _selectedPresetIndex = index;
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
    // Alt 模式下不开始绘画，等待 pointerUp 取色
    if (state.isAltPressed) return;

    // 如果上一个笔画还在进行中（快速连续点击），先提交它
    if (state.isDrawing && state.currentStrokePoints.isNotEmpty) {
      _commitCurrentStroke(state);
    }

    // 坐标已由 EditorCanvas 统一转换为画布坐标
    state.startStroke(event.localPosition);
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    // Alt 模式下不更新笔画
    if (state.isAltPressed) return;

    if (state.isDrawing) {
      // 坐标已由 EditorCanvas 统一转换为画布坐标
      state.updateStroke(event.localPosition);
    }
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    // Alt 模式：取色
    if (state.isAltPressed) {
      _pickColorAndApply(event.localPosition, state);
      return;
    }

    if (state.isDrawing && state.currentStrokePoints.isNotEmpty) {
      _commitCurrentStroke(state);
    } else {
      state.endStroke();
    }
  }

  /// 提交当前笔画（抽取公共逻辑，供 onPointerDown 和 onPointerUp 调用）
  void _commitCurrentStroke(EditorState state) {
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
    state.endStroke();
  }

  /// Alt 模式下取色并应用
  Future<void> _pickColorAndApply(Offset canvasPoint, EditorState state) async {
    final color = await ColorPickerTool.pickColorAt(canvasPoint, state);
    if (color != null) {
      state.setForegroundColor(color);
    }
  }

  @override
  double getCursorRadius(EditorState state) => _settings.size / 2;

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return _BrushSettingsPanel(
      tool: this,
      onSettingsChanged: () {
        // 触发刷新
        state.requestUiUpdate();
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
            context.l10n.editor_brushSettings,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const ThemedDivider(height: 1),

        // 笔刷预设
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.editor_brushPresets,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              HorizontalActionStrip(
                child: Row(
                  spacing: 8,
                  children: [
                    for (final (index, preset) in defaultBrushPresets.indexed)
                      _BrushPresetButton(
                        key: ValueKey('brush-preset-$index'),
                        preset: preset,
                        presetIndex: index,
                        isSelected: widget.tool.selectedPresetIndex == index,
                        onTap: () {
                          setState(() {
                            widget.tool.applyPreset(preset, index);
                            _sizeController.text = preset.size
                                .round()
                                .toString();
                          });
                          widget.onSettingsChanged();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const ThemedDivider(height: 1),

        ToolSettingRows(
          rows: [
            // 大小
            ToolSettingRow.slider(
              label: context.l10n.editor_size,
              value: settings.size,
              min: 1,
              max: 500,
              controller: _sizeController,
              onChanged: (value) {
                setState(() {
                  widget.tool.setSize(value);
                  _sizeController.text = value.round().toString();
                });
                widget.onSettingsChanged();
              },
            ),

            // 不透明度
            ToolSettingRow.slider(
              label: context.l10n.editor_opacity,
              value: settings.opacity * 100,
              min: 0,
              max: 100,
              suffix: '%',
              onChanged: (value) {
                setState(() {
                  widget.tool.setOpacity(value / 100);
                });
                widget.onSettingsChanged();
              },
            ),

            // 硬度
            ToolSettingRow.slider(
              label: context.l10n.editor_hardness,
              value: settings.hardness * 100,
              min: 0,
              max: 100,
              suffix: '%',
              onChanged: (value) {
                setState(() {
                  widget.tool.setHardness(value / 100);
                });
                widget.onSettingsChanged();
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// 笔刷预设按钮
class _BrushPresetButton extends StatelessWidget {
  final BrushPreset preset;
  final int presetIndex;
  final bool isSelected;
  final VoidCallback onTap;

  const _BrushPresetButton({
    super.key,
    required this.preset,
    required this.presetIndex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presetName = _localizedPresetName(context);
    final foreground = isSelected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: foreground);
    // 描边画在 Material 前景、不占内边距；Ink/Container 会让选中磁贴变宽
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: isSelected
          ? BorderSide(color: theme.colorScheme.primary, width: 1)
          : BorderSide.none,
    );

    return Semantics(
      container: true,
      label: presetName,
      hint: context.l10n.brushPreset_selectHint,
      button: true,
      selected: isSelected,
      enabled: true,
      // 底色放在 Material 上，墨水才画在底色之上；不透明子节点会盖住高亮
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainer,
        shape: shape,
        // Material 只插值描边、底色瞬切，统一瞬切
        animationDuration: Duration.zero,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          // 名称由外层 Semantics 提供；只排除文字，点击与焦点动作仍来自 InkWell
          child: ExcludeSemantics(
            // 只设下限：文字放大时磁贴随标签长高变宽
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 56, minHeight: 70),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(preset.icon, size: 24, color: foreground),
                    const SizedBox(height: 2),
                    // 按粗体占宽：选中切换字重时磁贴宽度不变
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Visibility.maintain(
                          visible: false,
                          child: Text(
                            presetName,
                            style: labelStyle?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            softWrap: false,
                          ),
                        ),
                        Text(
                          presetName,
                          style: labelStyle?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          softWrap: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _localizedPresetName(BuildContext context) {
    switch (presetIndex) {
      case 0:
        return context.l10n.brushPreset_pencil;
      case 1:
        return context.l10n.brushPreset_fine;
      case 2:
        return context.l10n.brushPreset_standard;
      case 3:
        return context.l10n.brushPreset_soft;
      case 4:
        return context.l10n.brushPreset_airbrush;
      case 5:
        return context.l10n.brushPreset_marker;
      case 6:
        return context.l10n.brushPreset_thick;
      case 7:
        return context.l10n.brushPreset_smudge;
      default:
        return preset.name;
    }
  }
}
