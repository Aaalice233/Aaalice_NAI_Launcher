import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/resolution_preset.dart';
import '../../../widgets/common/themed_dropdown.dart';

/// 尺寸选择器 (带分组预设和自定义输入)
///
/// 从 ParameterPanel 提取的公开组件，经典布局的参数面板与
/// 官网式布局的置顶尺寸区共用。
class SizeSelector extends StatefulWidget {
  final int width;
  final int height;
  final void Function(int width, int height) onChanged;

  const SizeSelector({
    super.key,
    required this.width,
    required this.height,
    required this.onChanged,
  });

  @override
  State<SizeSelector> createState() => _SizeSelectorState();
}

class _SizeSelectorState extends State<SizeSelector> {
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late FocusNode _widthFocusNode;
  late FocusNode _heightFocusNode;
  final FocusNode _dropdownFocusNode = FocusNode();
  String? _selectedPresetId;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(text: widget.width.toString());
    _heightController = TextEditingController(text: widget.height.toString());
    _widthFocusNode = FocusNode();
    _heightFocusNode = FocusNode();
    _updateSelectedPreset();
  }

  @override
  void didUpdateWidget(covariant SizeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width || oldWidget.height != widget.height) {
      _syncFieldController(
        controller: _widthController,
        focusNode: _widthFocusNode,
        targetValue: widget.width,
      );
      _syncFieldController(
        controller: _heightController,
        focusNode: _heightFocusNode,
        targetValue: widget.height,
      );
      _updateSelectedPreset();
    }
  }

  void _syncFieldController({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int targetValue,
  }) {
    final nextText = resolveManualSizeFieldSyncText(
      currentText: controller.text,
      targetValue: targetValue,
      hasFocus: focusNode.hasFocus,
    );
    if (nextText == null) {
      return;
    }

    controller.value = controller.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );
  }

  void _updateSelectedPreset() {
    final matchedPreset =
        ResolutionPreset.findBySize(widget.width, widget.height);
    _selectedPresetId = matchedPreset?.id ?? 'custom';
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _widthFocusNode.dispose();
    _heightFocusNode.dispose();
    _dropdownFocusNode.dispose();
    super.dispose();
  }

  String _getGroupName(BuildContext context, ResolutionGroup group) {
    final l10n = context.l10n;
    return switch (group) {
      ResolutionGroup.normal => l10n.resolution_groupNormal,
      ResolutionGroup.large => l10n.resolution_groupLarge,
      ResolutionGroup.wallpaper => l10n.resolution_groupWallpaper,
      ResolutionGroup.small => l10n.resolution_groupSmall,
      ResolutionGroup.custom => l10n.resolution_groupCustom,
    };
  }

  String _getTypeName(BuildContext context, ResolutionType type) {
    final l10n = context.l10n;
    return switch (type) {
      ResolutionType.portrait => l10n.resolution_typePortrait,
      ResolutionType.landscape => l10n.resolution_typeLandscape,
      ResolutionType.square => l10n.resolution_typeSquare,
      ResolutionType.custom => l10n.resolution_typeCustom,
    };
  }

  void _onPresetSelected(String? presetId) {
    if (presetId == null) return;

    // 选择后取消焦点
    _dropdownFocusNode.unfocus();

    setState(() {
      _selectedPresetId = presetId;
    });

    if (presetId == 'custom') {
      // 保持当前宽高不变
      return;
    }

    final preset = ResolutionPreset.findById(presetId);
    if (preset != null) {
      widget.onChanged(preset.width, preset.height);
    }
  }

  void _onManualSizeChanged() {
    final newWidth = int.tryParse(_widthController.text) ?? widget.width;
    final newHeight = int.tryParse(_heightController.text) ?? widget.height;

    // 检查是否匹配某个预设
    final matchedPreset = ResolutionPreset.findBySize(newWidth, newHeight);
    setState(() {
      _selectedPresetId = matchedPreset?.id ?? 'custom';
    });

    if (newWidth != widget.width || newHeight != widget.height) {
      widget.onChanged(newWidth, newHeight);
    }
  }

  List<DropdownMenuItem<String>> _buildDropdownItems(BuildContext context) {
    final theme = Theme.of(context);
    final items = <DropdownMenuItem<String>>[];
    final groupedPresets = ResolutionPreset.groupedPresets;

    for (final group in ResolutionGroup.values) {
      final presets = groupedPresets[group] ?? [];
      if (presets.isEmpty) continue;

      // 分组标题 (不可选中)
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          value: '_header_${group.name}',
          child: Text(
            _getGroupName(context, group),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );

      // 分组内的预设
      for (final preset in presets) {
        final typeName = _getTypeName(context, preset.type);
        items.add(
          DropdownMenuItem<String>(
            value: preset.id,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                preset.getDisplayName(typeName),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        );
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 预设下拉菜单
        ThemedDropdown<String>(
          value: _selectedPresetId,
          focusNode: _dropdownFocusNode,
          items: _buildDropdownItems(context),
          selectedItemBuilder: (context) {
            // 自定义选中项显示
            return _buildDropdownItems(context).map((item) {
              final preset = ResolutionPreset.findById(item.value ?? '');
              if (preset == null) {
                return const Text('');
              }
              final typeName = _getTypeName(context, preset.type);
              final groupName = _getGroupName(context, preset.group);
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  preset.type == ResolutionType.custom
                      ? typeName
                      : '$groupName - ${preset.getDisplayName(typeName)}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList();
          },
          onChanged: _onPresetSelected,
        ),

        const SizedBox(height: 8),

        // 宽高输入框
        Row(
          children: [
            // 宽度输入
            Expanded(
              child: ThemedTextField(
                controller: _widthController,
                focusNode: _widthFocusNode,
                keyboardType: TextInputType.number,
                labelText: l10n.resolution_width,
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => _onManualSizeChanged(),
              ),
            ),
            // × 符号
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '×',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            // 高度输入
            Expanded(
              child: ThemedTextField(
                controller: _heightController,
                focusNode: _heightFocusNode,
                keyboardType: TextInputType.number,
                labelText: l10n.resolution_height,
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => _onManualSizeChanged(),
              ),
            ),
            // 交换宽高按钮
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                final temp = _widthController.text;
                _widthController.text = _heightController.text;
                _heightController.text = temp;
                _onManualSizeChanged();
              },
              icon: const Icon(Icons.swap_horiz, size: 20),
              tooltip: 'Swap',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

@visibleForTesting
String? resolveManualSizeFieldSyncText({
  required String currentText,
  required int targetValue,
  required bool hasFocus,
}) {
  if (hasFocus) {
    return null;
  }

  final nextText = targetValue.toString();
  if (currentText == nextText) {
    return null;
  }

  return nextText;
}
