import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/resolution_preset.dart';
import '../../../providers/generation/generation_params_selectors.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/krita/krita_bridge_notifier.dart';
import '../../../providers/layout_state_provider.dart';
import '../../../utils/asset_protection_guard.dart';
import '../../../widgets/common/themed_dropdown.dart';
import '../../../widgets/common/themed_input.dart';
import '../../../widgets/common/themed_button.dart';
import '../../../widgets/common/themed_slider.dart';
import '../../../widgets/common/themed_divider.dart';
import 'collapsible_model_selector.dart';
import 'img2img_panel.dart';
import 'reverse_prompt_panel.dart';
import 'unified_reference_panel.dart';
import 'precise_reference_panel.dart';
import 'prompt_input.dart';

import '../../../widgets/common/app_toast.dart';

/// 参数面板组件
class ParameterPanel extends ConsumerStatefulWidget {
  final bool inBottomSheet;
  final bool showInput;
  final bool collapsibleModelSelector;

  const ParameterPanel({
    super.key,
    this.inBottomSheet = false,
    this.showInput = false,
    this.collapsibleModelSelector = false,
  });

  @override
  ConsumerState<ParameterPanel> createState() => _ParameterPanelState();
}

class _ParameterPanelState extends ConsumerState<ParameterPanel> {
  late final TextEditingController _seedController;
  late final FocusNode _seedFocusNode;

  @override
  void initState() {
    super.initState();
    _seedController = TextEditingController();
    _seedFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _seedController.dispose();
    _seedFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = ref.watch(
      generationParamsNotifierProvider.select(selectParameterPanelViewData),
    );
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final kritaBridgeState = ref.watch(kritaBridgeNotifierProvider);
    final theme = Theme.of(context);
    final isLauncherGenerating = generationState.isGenerating;
    final isGenerating =
        isLauncherGenerating || kritaBridgeState.isBridgeGenerating;
    final canSkipCurrentBatch = isLauncherGenerating &&
        generationState.currentImage > 0 &&
        generationState.totalImages > generationState.currentImage;
    final generationProgressText =
        '${generationState.currentImage}/${generationState.totalImages}';

    _syncSeedController(params.seed);

    return ListView(
      padding: EdgeInsets.all(widget.inBottomSheet ? 16 : 12),
      shrinkWrap: widget.inBottomSheet,
      physics: widget.inBottomSheet ? const ClampingScrollPhysics() : null,
      children: [
        // 提示词输入 (仅当 showInput 为 true 时显示)
        if (widget.showInput) ...[
          const PromptInputWidget(compact: false),
          const SizedBox(height: 16),

          // 生成按钮
          SizedBox(
            height: 48,
            child: isLauncherGenerating
                ? Row(
                    children: [
                      if (canSkipCurrentBatch) ...[
                        Expanded(
                          child: ThemedButton(
                            onPressed: () => ref
                                .read(imageGenerationNotifierProvider.notifier)
                                .skipCurrentRequest(),
                            icon: const Icon(Icons.skip_next),
                            label: Text(
                              '${context.l10n.generation_skipCurrentBatch} $generationProgressText',
                            ),
                            style: ThemedButtonStyle.outlined,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: ThemedButton(
                          onPressed: () => ref
                              .read(imageGenerationNotifierProvider.notifier)
                              .cancel(),
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Text(
                            context.l10n.generation_stopAllGeneration,
                          ),
                          style: ThemedButtonStyle.outlined,
                        ),
                      ),
                    ],
                  )
                : ThemedButton(
                    onPressed: isGenerating
                        ? null
                        : () async {
                            if (ref
                                .read(kritaBridgeNotifierProvider)
                                .isBridgeGenerating) {
                              AppToast.warning(
                                context,
                                context.l10n.kritaBridge_busyGenerating,
                              );
                              return;
                            }
                            if (params.prompt.isEmpty) {
                              AppToast.info(
                                context,
                                context.l10n.generation_pleaseInputPrompt,
                              );
                              return;
                            }
                            final confirmed =
                                await AssetProtectionGuard.confirmHighAnlasCost(
                              context: context,
                              ref: ref,
                            );
                            if (!confirmed || !context.mounted) {
                              return;
                            }
                            ref
                                .read(imageGenerationNotifierProvider.notifier)
                                .generate(
                                  ref.read(generationParamsNotifierProvider),
                                );
                          },
                    icon: isGenerating ? null : const Icon(Icons.auto_awesome),
                    isLoading: isGenerating,
                    label: Text(
                      isGenerating
                          ? context.l10n.generation_generating
                          : context.l10n.generation_generateImage,
                    ),
                    style: ThemedButtonStyle.filled,
                  ),
          ),          const SizedBox(height: 24),
          const ThemedDivider(),
          const SizedBox(height: 16),
        ],

        // 模型选择
        if (widget.collapsibleModelSelector)
          CollapsibleModelSelector(
            title: context.l10n.generation_model,
            currentModelName:
                ImageModels.modelDisplayNames[params.model] ?? params.model,
            initiallyExpanded:
                ref.read(layoutStateNotifierProvider).webModelDrawerExpanded,
            onExpansionChanged: (expanded) => ref
                .read(layoutStateNotifierProvider.notifier)
                .setWebModelDrawerExpanded(expanded),
            child: _buildModelDropdown(),
          )
        else ...[
          _buildSectionTitle(theme, context.l10n.generation_model),
          const SizedBox(height: 8),
          _buildModelDropdown(),
        ],

        const SizedBox(height: 16),

        // 尺寸设置
        _buildSectionTitle(theme, context.l10n.generation_imageSize),
        const SizedBox(height: 8),
        _SizeSelector(
          width: params.width,
          height: params.height,
          onChanged: (width, height) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .updateSize(width, height);
          },
        ),

        const SizedBox(height: 16),

        // 采样器
        _buildSectionTitle(theme, context.l10n.generation_sampler),
        const SizedBox(height: 8),
        ThemedDropdown<String>(
          value: params.sampler,
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
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .updateSampler(value);
            }
          },
        ),

        const SizedBox(height: 16),

        // 调度器
        _buildSectionTitle(theme, context.l10n.generation_noiseSchedule),
        const SizedBox(height: 8),
        ThemedDropdown<String>(
          // V4/V4.5 模型不支持 native，如果当前值是 native 则显示 karras
          value: params.isV4Model && params.noiseSchedule == 'native'
              ? 'karras'
              : params.noiseSchedule,
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
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .updateNoiseSchedule(value);
            }
          },
        ),

        const SizedBox(height: 16),

        // 步数
        _buildSectionTitle(
          theme,
          context.l10n.generation_steps(params.steps.toString()),
        ),
        ThemedSlider(
          value: params.steps.toDouble(),
          min: 1,
          max: 50,
          divisions: 49,
          onChanged: (value) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .updateSteps(value.round());
          },
        ),

        // CFG Scale
        Row(
          children: [
            _buildSectionTitle(
              theme,
              context.l10n.generation_cfgScale(params.scale.toStringAsFixed(1)),
            ),
            const Spacer(),
            // Decrisp (仅 V3 模型)
            if (params.isV3Model) ...[
              _ToggleButton(
                label: 'Decrisp',
                isEnabled: params.decrisp,
                onChanged: (value) {
                  ref
                      .read(generationParamsNotifierProvider.notifier)
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
                ref
                    .read(generationParamsNotifierProvider.notifier)
                    .updateVarietyPlus(value);
              },
            ),
          ],
        ),
        ThemedSlider(
          value: params.scale,
          min: 1,
          max: 20,
          divisions: 190,
          onChanged: (value) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .updateScale(value);
          },
        ),

        const SizedBox(height: 16),

        // 种子
        _buildSectionTitle(theme, context.l10n.generation_seed),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ThemedInput(
                controller: _seedController,
                focusNode: _seedFocusNode,
                hintText: context.l10n.generation_seedRandom,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  // 清空输入框时自动变成随机 (-1)
                  final seed = value.isEmpty ? -1 : (int.tryParse(value) ?? -1);
                  if (seed != params.seed) {
                    ref
                        .read(generationParamsNotifierProvider.notifier)
                        .updateSeed(seed);
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
                              Clipboard.setData(
                                ClipboardData(text: params.seed.toString()),
                              );
                              AppToast.success(
                                context,
                                context.l10n.common_copied,
                              );
                            },
                          ),
                          // 清空按钮
                          _SeedIconButton(
                            icon: Icons.clear_rounded,
                            tooltip: context.l10n.common_clear,
                            onPressed: () {
                              _seedController.clear();
                              ref
                                  .read(
                                    generationParamsNotifierProvider.notifier,
                                  )
                                  .updateSeed(-1);
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 8),
            // 种子锁定按钮
            IconButton(
              icon: Icon(
                ref
                        .watch(generationParamsNotifierProvider.notifier)
                        .isSeedLocked
                    ? Icons.lock
                    : Icons.lock_open,
                size: 20,
              ),
              onPressed: () {
                // 先同步输入框的值到 state（防止用户输入后 state 未更新）
                final inputText = _seedController.text.trim();
                final inputSeed =
                    inputText.isEmpty ? -1 : (int.tryParse(inputText) ?? -1);
                if (inputSeed !=
                    ref.read(generationParamsNotifierProvider).seed) {
                  ref
                      .read(generationParamsNotifierProvider.notifier)
                      .updateSeed(inputSeed);
                }

                ref
                    .read(generationParamsNotifierProvider.notifier)
                    .toggleSeedLock();
                // 更新输入框显示
                final newSeed = ref.read(generationParamsNotifierProvider).seed;
                _seedController.text = newSeed == -1 ? '' : newSeed.toString();
              },
              tooltip: ref
                      .watch(generationParamsNotifierProvider.notifier)
                      .isSeedLocked
                  ? context.l10n.generation_seedUnlock
                  : context.l10n.generation_seedLock,
              style: IconButton.styleFrom(
                backgroundColor: ref
                        .watch(generationParamsNotifierProvider.notifier)
                        .isSeedLocked
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ==================== 新功能面板 ====================

        // 反推面板
        const ReversePromptPanel(),

        const SizedBox(height: 8),

        // 图生图面板
        const Img2ImgPanel(),

        const SizedBox(height: 8),

        // 风格迁移面板 (Vibe Transfer)
        const UnifiedReferencePanel(),

        const SizedBox(height: 8),

        // Precise Reference 面板 (角色/风格参考)
        const PreciseReferencePanel(),

        const SizedBox(height: 16),

        // 高级选项
        ExpansionTile(
          title: Text(
            context.l10n.generation_advancedOptions,
            style: theme.textTheme.titleSmall,
          ),
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: params.advancedOptionsExpanded,
          onExpansionChanged: (expanded) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .setAdvancedOptionsExpanded(expanded);
          },
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
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
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
                        ref
                            .read(generationParamsNotifierProvider.notifier)
                            .updateSmeaAuto(value);
                      },
                    ),
                    const SizedBox(width: 16),
                    _SmeaOptions(
                      smea: params.smea,
                      smeaDyn: params.smeaDyn,
                      isAutoEnabled: params.smeaAuto,
                      onSmeaChanged: (value) {
                        ref
                            .read(generationParamsNotifierProvider.notifier)
                            .updateSmea(value);
                      },
                      onSmeaDynChanged: (value) {
                        ref
                            .read(generationParamsNotifierProvider.notifier)
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
                title: Text(
                  context.l10n.generation_cfgRescale(
                    params.cfgRescale.toStringAsFixed(2),
                  ),
                ),
                subtitle: ThemedSlider(
                  value: params.cfgRescale,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  onChanged: (value) {
                    ref
                        .read(generationParamsNotifierProvider.notifier)
                        .updateCfgRescale(value);
                  },
                ),
              ),
          ],
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

  Widget _buildModelDropdown() {
    final model = ref.watch(
      generationParamsNotifierProvider.select((params) => params.model),
    );
    return ThemedDropdown<String>(
      value: model,
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
          ref
              .read(generationParamsNotifierProvider.notifier)
              .updateModel(value);
        }
      },
    );
  }

  void _syncSeedController(int seed) {
    final nextText = resolveSeedFieldSyncText(
      currentText: _seedController.text,
      seed: seed,
      hasFocus: _seedFocusNode.hasFocus,
    );
    if (nextText == null) {
      return;
    }

    _seedController.value = _seedController.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
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
  void didUpdateWidget(covariant _SizeSelector oldWidget) {
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

@visibleForTesting
String? resolveSeedFieldSyncText({
  required String currentText,
  required int seed,
  required bool hasFocus,
}) {
  if (hasFocus) {
    return null;
  }

  final nextText = seed == -1 ? '' : seed.toString();
  if (currentText == nextText) {
    return null;
  }

  return nextText;
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
          ? theme.colorScheme.primary.withValues(alpha: 0.15)
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
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
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
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                'Auto',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isAuto
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
        ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
        : (value
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.7));

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
          ? theme.colorScheme.primary.withValues(alpha: 0.85)
          : theme.colorScheme.primary;
    } else {
      final baseColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05);
      backgroundColor = _isHovered
          ? (isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.1))
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
                      ? theme.colorScheme.outline.withValues(alpha: 0.4)
                      : theme.colorScheme.outline.withValues(alpha: 0.2)),
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
                      : theme.colorScheme.onSurface
                          .withValues(alpha: _isHovered ? 0.8 : 0.6),
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
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
