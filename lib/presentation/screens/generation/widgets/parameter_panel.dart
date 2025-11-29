import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/image_params.dart';
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
        DropdownButtonFormField<String>(
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
        _buildSectionTitle(theme, context.l10n.generation_cfgScale(params.scale.toStringAsFixed(1))),
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
            // SMEA
            SwitchListTile(
              title: Text(context.l10n.generation_smea),
              subtitle: Text(context.l10n.generation_smeaSubtitle),
              value: params.smea,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                ref.read(generationParamsNotifierProvider.notifier)
                    .updateSmea(value);
              },
            ),

            // SMEA DYN
            SwitchListTile(
              title: Text(context.l10n.generation_smeaDyn),
              subtitle: Text(context.l10n.generation_smeaDynSubtitle),
              value: params.smeaDyn,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                ref.read(generationParamsNotifierProvider.notifier)
                    .updateSmeaDyn(value);
              },
            ),

            // CFG Rescale (V4 模型)
            if (params.isV4Model) ...[
              const SizedBox(height: 8),
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

            // 噪声调度 (V4+ 模型: Karras/Exponential/Polyexponential, V3: 多一个 Native 选项)
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.generation_noiseSchedule),
              trailing: DropdownButton<String>(
                // V4/V4.5 模型不支持 native，如果当前值是 native 则显示 karras
                value: params.isV4Model && params.noiseSchedule == 'native'
                    ? 'karras'
                    : params.noiseSchedule,
                items: [
                  // V3 模型多一个 Native 选项
                  if (!params.isV4Model)
                    const DropdownMenuItem(value: 'native', child: Text('Native')),
                  const DropdownMenuItem(value: 'karras', child: Text('Karras')),
                  const DropdownMenuItem(value: 'exponential', child: Text('Exponential')),
                  const DropdownMenuItem(value: 'polyexponential', child: Text('Polyexponential')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(generationParamsNotifierProvider.notifier)
                        .updateNoiseSchedule(value);
                  }
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

/// 尺寸选择器
class _SizeSelector extends StatelessWidget {
  final int width;
  final int height;
  final void Function(int width, int height) onChanged;

  const _SizeSelector({
    required this.width,
    required this.height,
    required this.onChanged,
  });

  List<(int, int, String)> _getPresets(BuildContext context) {
    final l10n = context.l10n;
    return [
      (832, 1216, l10n.generation_sizePortrait('832', '1216')),
      (1216, 832, l10n.generation_sizeLandscape('1216', '832')),
      (1024, 1024, l10n.generation_sizeSquare('1024', '1024')),
      (640, 640, l10n.generation_sizeSmallSquare('640', '640')),
      (1472, 1472, l10n.generation_sizeLargeSquare('1472', '1472')),
      (1088, 1920, l10n.generation_sizeTallPortrait('1088', '1920')),
      (1920, 1088, l10n.generation_sizeWideLandscape('1920', '1088')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final presets = _getPresets(context);
    // 找到当前选中的预设值
    final currentValue = presets.firstWhere(
      (p) => p.$1 == width && p.$2 == height,
      orElse: () => presets.first,
    );
    final currentKey = '${currentValue.$1}x${currentValue.$2}';

    return DropdownButtonFormField<String>(
      value: currentKey,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: presets.map((preset) {
        final key = '${preset.$1}x${preset.$2}';
        return DropdownMenuItem(
          value: key,
          child: Text(
            preset.$3,
            style: const TextStyle(fontSize: 13),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          final preset = presets.firstWhere(
            (p) => '${p.$1}x${p.$2}' == value,
          );
          onChanged(preset.$1, preset.$2);
        }
      },
    );
  }
}
