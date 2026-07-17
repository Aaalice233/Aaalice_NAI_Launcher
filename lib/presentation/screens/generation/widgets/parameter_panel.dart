import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/image_generation_provider.dart';
import 'generation_param_sections.dart';
import 'img2img_panel.dart';
import 'precise_reference_panel.dart';
import 'reverse_prompt_panel.dart';
import 'unified_reference_panel.dart';

/// 参数面板组件（经典布局与移动端使用）
///
/// 由 generation_param_sections.dart 中的分节控件组合而成，
/// 官网式布局的一体滚动列复用同一批分节控件。
class ParameterPanel extends ConsumerWidget {
  const ParameterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final advancedOptionsExpanded = ref.watch(
      generationParamsNotifierProvider
          .select((params) => params.advancedOptionsExpanded),
    );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 模型选择
        const ModelSection(),

        const SizedBox(height: 16),

        // 尺寸设置
        const SizeSection(),

        const SizedBox(height: 16),

        // 采样器
        const SamplerSection(),

        const SizedBox(height: 16),

        // 调度器
        const NoiseScheduleSection(),

        const SizedBox(height: 16),

        // 步数
        const StepsSection(),

        // CFG Scale
        const CfgScaleSection(),

        const SizedBox(height: 16),

        // 种子
        const SeedSection(),

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
          initiallyExpanded: advancedOptionsExpanded,
          onExpansionChanged: (expanded) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .setAdvancedOptionsExpanded(expanded);
          },
          children: const [
            AdvancedSamplingOptions(),
          ],
        ),
      ],
    );
  }
}
