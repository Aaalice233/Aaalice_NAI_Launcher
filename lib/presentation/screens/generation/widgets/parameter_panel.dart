import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/models/image/resolution_preset.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/themed_input.dart';
import '../../../widgets/common/themed_button.dart';
import 'img2img_panel.dart';
import 'vibe_transfer_panel.dart';
import 'character_panel.dart';
import 'prompt_input.dart';

/// 参数面板组件
class ParameterPanel extends ConsumerWidget {
  final bool inBottomSheet;
  final bool showInput;

  const ParameterPanel({
    super.key, 
    this.inBottomSheet = false,
    this.showInput = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(generationParamsNotifierProvider);
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final theme = Theme.of(context);
    final isGenerating = generationState.isGenerating;

    return ListView(
      padding: EdgeInsets.all(inBottomSheet ? 16 : 12),
      shrinkWrap: inBottomSheet,
      physics: inBottomSheet ? const ClampingScrollPhysics() : null,
      children: [
        // 提示词输入 (仅当 showInput 为 true 时显示)
        if (showInput) ...[
          const PromptInputWidget(compact: false),
          const SizedBox(height: 16),
          
          // 生成按钮
          SizedBox(
            height: 48,
            child: ThemedButton(
              onPressed: isGenerating
                  ? () => ref.read(imageGenerationNotifierProvider.notifier).cancel()
                  : () {
                      if (params.prompt.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.generation_pleaseInputPrompt)),
                        );
                        return;
                      }
                      ref.read(imageGenerationNotifierProvider.notifier)
                          .generate(params);
                    },
              icon: isGenerating
                  ? const Icon(Icons.stop)
                  : const Icon(Icons.auto_awesome),
              isLoading: isGenerating && false, // 不要显示加载圈，直接变 Cancel
              label: Text(isGenerating ? context.l10n.generation_cancelGeneration : context.l10n.generation_generateImage),
              style: isGenerating ? ThemedButtonStyle.outlined : ThemedButtonStyle.filled,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
        ],

        // 模型选择
        _buildSectionTitle(theme, context.l10n.generation_model),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: params.model,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: ImageModels.allModels.map((model) {
            return DropdownMenuItem(
              value: model,
              child: Text(
                ImageModels.modelDisplayNames[model] ?? model,
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref.read(generationParamsNotifierProvider.notifier)
                  .updateModel(value);
            }
          },
        ),

        const SizedBox(height: 16),

        // 尺寸设置
        _buildSectionTitle(theme, context.l10n.generation_imageSize),
        const SizedBox(height: 8),
        _SizeSelector(
          width: params.width,
          height: params.height,
          onChanged: (width, height) {
            ref.read(generationParamsNotifierProvider.notifier)
                .updateSize(width, height);
          },
        ),

        const SizedBox(height: 16),

        // 采样器
        _buildSectionTitle(theme, context.l10n.generation_sampler),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: params.sampler,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: Samplers.allSamplers.map((sampler) {
                  return DropdownMenuItem(
                    value: sampler,
                    child: Text(
                      Samplers.samplerDisplayNames[sampler] ?? sampler,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(generationParamsNotifierProvider.notifier)
                        .updateSampler(value);
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 调度器
        _buildSectionTitle(theme, context.l10n.generation_noiseSchedule),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          // V4/V4.5 模型不支持 native，如果当前值是 native 则显示 karras
          value: params.isV4Model && params.noiseSchedule == 'native'
              ? 'karras'
              : params.noiseSchedule,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            // V3 模型多一个 Native 选项
            if (!params.isV4Model)
              DropdownMenuItem(
                value: 'native',
                child: Text(
                  NoiseSchedules.displayNames['native'] ?? 'Native',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ...['karras', 'exponential', 'polyexponential'].map((schedule) {
              return DropdownMenuItem(
                value: schedule,
                child: Text(
                  NoiseSchedules.displayNames[schedule] ?? schedule,
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }),
          ],
          onChanged: (value) {
            if (value != null) {
              ref.read(generationParamsNotifierProvider.notifier)
                  .updateNoiseSchedule(value);
            }
          },
        ),

        const SizedBox(height: 16),

        // 步数
        _buildSectionTitle(theme, context.l10n.generation_steps(params.steps.toString())),
        Slider(
          value: params.steps.toDouble(),
          min: 1,
          max: 50,
          divisions: 49,
          label: params.steps.toString(),
          onChanged: (value) {
            ref.read(generationParamsNotifierProvider.notifier)
                .updateSteps(value.round());
          },
        ),

        // CFG Scale
        Row(
          children: [
            _buildSectionTitle(theme, context.l10n.generation_cfgScale(params.scale.toStringAsFixed(1))),
            const Spacer(),
            // Decrisp (仅 V3 模型)
            if (params.isV3Model) ...[
              _ToggleButton(
                label: 'Decrisp',
                isEnabled: params.decrisp,
                onChanged: (value) {
                  ref.read(generationParamsNotifierProvider.notifier)
                      .updateDecrisp(value);
                },
              ),
              const SizedBox(width: 8),
            ],
            // Variety+ (所有模型)
            _ToggleButton(
              label: 'Variety+',
              isEnabled: params.varietyPlus,
              onChanged: (value) {
                ref.read(generationParamsNotifierProvider.notifier)
                    .updateVarietyPlus(value);
              },
            ),
          ],
        ),
        Slider(
          value: params.scale,
          min: 1,
          max: 20,
          divisions: 38,
          label: params.scale.toStringAsFixed(1),
          onChanged: (value) {
            ref.read(generationParamsNotifierProvider.notifier)
                .updateScale(value);
          },
        ),

        const SizedBox(height: 16),

        // 种子
        _buildSectionTitle(theme, context.l10n.generation_seed),
        const SizedBox(height: 8),
        ThemedInput(
          controller: TextEditingController(text: params.seed == -1 ? '' : params.seed.toString())
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: params.seed == -1 ? 0 : params.seed.toString().length),
            ),
          hintText: context.l10n.generation_seedRandom,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            // 清空输入框时自动变成随机 (-1)
            final seed = value.isEmpty ? -1 : (int.tryParse(value) ?? -1);
            if (seed != params.seed) {
               ref.read(generationParamsNotifierProvider.notifier).updateSeed(seed);
            }
          },
          suffixIcon: params.seed == -1
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 复制按钮
                    _SeedIconButton(
                      icon: Icons.copy_rounded,
                      tooltip: context.l10n.common_copy,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: params.seed.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.common_copied),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    // 清空按钮
                    _SeedIconButton(
                      icon: Icons.clear_rounded,
                      tooltip: context.l10n.common_clear,
                      onPressed: () {
                        ref.read(generationParamsNotifierProvider.notifier).updateSeed(-1);
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
        ),

        const SizedBox(height: 16),

        // ==================== 新功能面板 ====================

        // 图生图面板
        const Img2ImgPanel(),

        const SizedBox(height: 8),

        // Vibe Transfer 面板
        const VibeTransferPanel(),

        const SizedBox(height: 8),

        // 多角色面板 (仅 V4 模型显示)
        const CharacterPanel(),

        const SizedBox(height: 16),

        // 高级选项
        ExpansionTile(
          title: Text(
            context.l10n.generation_advancedOptions,
            style: theme.textTheme.titleSmall,
          ),
          tilePadding: EdgeInsets.zero,
          children: [
            // V3 模型: SMEA 选项 (非 DDIM 采样器时显示)
            if (params.isV3Model && !params.sampler.contains('ddim')) ...[
              // 标题和说明
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  children: [
                    Text(
                      'SMEA',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '高分辨率采样优化',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 选项行
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    _SmeaAutoButton(
                      isAuto: params.smeaAuto,
                      onChanged: (value) {
                        ref.read(generationParamsNotifierProvider.notifier)
                            .updateSmeaAuto(value);
                      },
                    ),
                    const SizedBox(width: 16),
                    _SmeaOptions(
                      smea: params.smea,
                      smeaDyn: params.smeaDyn,
                      isAutoEnabled: params.smeaAuto,
                      onSmeaChanged: (value) {
                        ref.read(generationParamsNotifierProvider.notifier)
                            .updateSmea(value);
                      },
                      onSmeaDynChanged: (value) {
                        ref.read(generationParamsNotifierProvider.notifier)
                            .updateSmeaDyn(value);
                      },
                    ),
                  ],
                ),
              ),
              // Auto 模式说明 (仅 Auto 开启时显示)
              if (params.smeaAuto)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.l10n.generation_smeaDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
            // V4 模型: CFG Rescale
            if (params.isV4Model)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.generation_cfgRescale(params.cfgRescale.toStringAsFixed(2))),
                subtitle: Slider(
                  value: params.cfgRescale,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  onChanged: (value) {
                    ref.read(generationParamsNotifierProvider.notifier)
                        .updateCfgRescale(value);
                  },
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // 重置按钮
        ThemedButton(
          onPressed: () {
            ref.read(generationParamsNotifierProvider.notifier).reset();
          },
          icon: const Icon(Icons.restart_alt),
          label: Text(context.l10n.generation_resetParams),
          style: ThemedButtonStyle.outlined,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// 尺寸选择器 (带分组预设和自定义输入)
class _SizeSelector extends StatefulWidget {
  final int width;
  final int height;
  final void Function(int width, int height) onChanged;

  const _SizeSelector({
    required this.width,
    required this.height,
    required this.onChanged,
  });

  @override
  State<_SizeSelector> createState() => _SizeSelectorState();
}

class _SizeSelectorState extends State<_SizeSelector> {
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  final FocusNode _dropdownFocusNode = FocusNode();
  String? _selectedPresetId;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(text: widget.width.toString());
    _heightController = TextEditingController(text: widget.height.toString());
    _updateSelectedPreset();
  }

  @override
  void didUpdateWidget(covariant _SizeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width || oldWidget.height != widget.height) {
      _widthController.text = widget.width.toString();
      _heightController.text = widget.height.toString();
      _updateSelectedPreset();
    }
  }

  void _updateSelectedPreset() {
    final matchedPreset = ResolutionPreset.findBySize(widget.width, widget.height);
    _selectedPresetId = matchedPreset?.id ?? 'custom';
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _dropdownFocusNode.dispose();
    super.dispose();
  }

  String _getGroupName(BuildContext context, ResolutionGroup group) {
    final l10n = context.l10n;
    switch (group) {
      case ResolutionGroup.normal:
        return l10n.resolution_groupNormal;
      case ResolutionGroup.large:
        return l10n.resolution_groupLarge;
      case ResolutionGroup.wallpaper:
        return l10n.resolution_groupWallpaper;
      case ResolutionGroup.small:
        return l10n.resolution_groupSmall;
      case ResolutionGroup.custom:
        return l10n.resolution_groupCustom;
    }
  }

  String _getTypeName(BuildContext context, ResolutionType type) {
    final l10n = context.l10n;
    switch (type) {
      case ResolutionType.portrait:
        return l10n.resolution_typePortrait;
      case ResolutionType.landscape:
        return l10n.resolution_typeLandscape;
      case ResolutionType.square:
        return l10n.resolution_typeSquare;
      case ResolutionType.custom:
        return l10n.resolution_typeCustom;
    }
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
      items.add(DropdownMenuItem<String>(
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
      ));

      // 分组内的预设
      for (final preset in presets) {
        final typeName = _getTypeName(context, preset.type);
        items.add(DropdownMenuItem<String>(
          value: preset.id,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              preset.getDisplayName(typeName),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ));
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
        DropdownButtonFormField<String>(
          value: _selectedPresetId,
          isExpanded: true,
          focusNode: _dropdownFocusNode,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
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
              child: TextField(
                controller: _widthController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.resolution_width,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
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
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            // 高度输入
            Expanded(
              child: TextField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.resolution_height,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
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

/// SMEA Auto 按钮 (V3 模型)
class _SmeaAutoButton extends StatelessWidget {
  final bool isAuto;
  final ValueChanged<bool> onChanged;

  const _SmeaAutoButton({
    required this.isAuto,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isAuto
          ? theme.colorScheme.primary.withOpacity(0.15)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onChanged(!isAuto),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isAuto
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outline.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAuto ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: isAuto
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 4),
              Text(
                'Auto',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isAuto
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// SMEA 选项复选框 (V3 模型)
class _SmeaOptions extends StatelessWidget {
  final bool smea;
  final bool smeaDyn;
  final bool isAutoEnabled;
  final ValueChanged<bool> onSmeaChanged;
  final ValueChanged<bool> onSmeaDynChanged;

  const _SmeaOptions({
    required this.smea,
    required this.smeaDyn,
    required this.isAutoEnabled,
    required this.onSmeaChanged,
    required this.onSmeaDynChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = isAutoEnabled;

    return Row(
      children: [
        // SMEA 复选框
        _buildCheckbox(
          context: context,
          label: 'SMEA',
          value: smea,
          isDisabled: isDisabled,
          onChanged: onSmeaChanged,
          theme: theme,
        ),
        const SizedBox(width: 16),
        // DYN 复选框
        _buildCheckbox(
          context: context,
          label: 'DYN',
          value: smeaDyn,
          isDisabled: isDisabled,
          onChanged: onSmeaDynChanged,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required BuildContext context,
    required String label,
    required bool value,
    required bool isDisabled,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    final color = isDisabled
        ? theme.colorScheme.onSurface.withOpacity(0.3)
        : (value ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.7));

    return InkWell(
      onTap: isDisabled ? null : () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value ? Icons.check_box : Icons.check_box_outline_blank,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用切换按钮 (用于 Variety+, Decrisp 等)
class _ToggleButton extends StatefulWidget {
  final String label;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const _ToggleButton({
    required this.label,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 计算背景色
    Color backgroundColor;
    if (widget.isEnabled) {
      backgroundColor = _isHovered
          ? theme.colorScheme.primary.withOpacity(0.85)
          : theme.colorScheme.primary;
    } else {
      final baseColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);
      backgroundColor = _isHovered
          ? (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1))
          : baseColor;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.isEnabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isEnabled
                  ? theme.colorScheme.primary
                  : (_isHovered
                      ? theme.colorScheme.outline.withOpacity(0.4)
                      : theme.colorScheme.outline.withOpacity(0.2)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isEnabled) ...[
                Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: theme.colorScheme.onPrimary,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.isEnabled
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface.withOpacity(_isHovered ? 0.8 : 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 种子输入框内的图标按钮
class _SeedIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _SeedIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_SeedIconButton> createState() => _SeedIconButtonState();
}

class _SeedIconButtonState extends State<_SeedIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              widget.icon,
              size: 18,
              color: _isHovered
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }
}
