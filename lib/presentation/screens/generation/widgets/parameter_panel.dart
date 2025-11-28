import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
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
                          const SnackBar(content: Text('请输入提示词')),
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
              label: Text(isGenerating ? '取消生成' : '生成图像'),
              style: isGenerating ? ThemedButtonStyle.outlined : ThemedButtonStyle.filled,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
        ],

        // 模型选择
        _buildSectionTitle(theme, '模型'),
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
        _buildSectionTitle(theme, '图像尺寸'),
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

        // 生成数量
        _buildSectionTitle(theme, '生成数量: ${params.nSamples}'),
        Slider(
          value: params.nSamples.toDouble(),
          min: 1,
          max: 4,
          divisions: 3,
          label: params.nSamples.toString(),
          onChanged: (value) {
            ref.read(generationParamsNotifierProvider.notifier)
                .updateNSamples(value.round());
          },
        ),

        const SizedBox(height: 8),

        // 采样器
        _buildSectionTitle(theme, '采样器'),
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
        _buildSectionTitle(theme, '步数: ${params.steps}'),
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
        _buildSectionTitle(theme, 'CFG Scale: ${params.scale.toStringAsFixed(1)}'),
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
        _buildSectionTitle(theme, '种子'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ThemedInput(
                controller: TextEditingController(text: params.seed == -1 ? '' : params.seed.toString())
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: params.seed == -1 ? 0 : params.seed.toString().length),
                  ),
                hintText: '随机',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final seed = int.tryParse(value) ?? -1;
                  // 避免循环更新导致的光标跳动问题 (此处简化处理)
                  if (seed != params.seed) {
                     ref.read(generationParamsNotifierProvider.notifier).updateSeed(seed);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () {
                ref.read(generationParamsNotifierProvider.notifier)
                    .randomizeSeed();
              },
              icon: const Icon(Icons.casino),
              tooltip: '随机种子',
            ),
          ],
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
            '高级选项',
            style: theme.textTheme.titleSmall,
          ),
          tilePadding: EdgeInsets.zero,
          children: [
            // SMEA
            SwitchListTile(
              title: const Text('SMEA'),
              subtitle: const Text('改善大图像的生成质量'),
              value: params.smea,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                ref.read(generationParamsNotifierProvider.notifier)
                    .updateSmea(value);
              },
            ),

            // SMEA DYN
            SwitchListTile(
              title: const Text('SMEA DYN'),
              subtitle: const Text('SMEA 动态变体'),
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
                title: Text('CFG Rescale: ${params.cfgRescale.toStringAsFixed(2)}'),
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

            // 噪声调度 (V4 模型)
            if (params.isV4Model) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('噪声调度'),
                trailing: DropdownButton<String>(
                  value: params.noiseSchedule,
                  items: const [
                    DropdownMenuItem(value: 'native', child: Text('Native')),
                    DropdownMenuItem(value: 'karras', child: Text('Karras')),
                    DropdownMenuItem(value: 'exponential', child: Text('Exponential')),
                    DropdownMenuItem(value: 'polyexponential', child: Text('Polyexponential')),
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
          ],
        ),

        const SizedBox(height: 16),

        // 重置按钮
        ThemedButton(
          onPressed: () {
            ref.read(generationParamsNotifierProvider.notifier).reset();
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('重置参数'),
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

  static const _presets = [
    (832, 1216, '竖屏 (832×1216)'),
    (1216, 832, '横屏 (1216×832)'),
    (1024, 1024, '方形 (1024×1024)'),
    (640, 640, '小方形 (640×640)'),
    (1472, 1472, '大方形 (1472×1472)'),
    (1088, 1920, '竖长 (1088×1920)'),
    (1920, 1088, '横长 (1920×1088)'),
  ];

  @override
  Widget build(BuildContext context) {
    // 找到当前选中的预设值
    final currentValue = _presets.firstWhere(
      (p) => p.$1 == width && p.$2 == height,
      orElse: () => _presets.first,
    );
    final currentKey = '${currentValue.$1}x${currentValue.$2}';

    return DropdownButtonFormField<String>(
      value: currentKey,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _presets.map((preset) {
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
          final preset = _presets.firstWhere(
            (p) => '${p.$1}x${p.$2}' == value,
          );
          onChanged(preset.$1, preset.$2);
        }
      },
    );
  }
}
