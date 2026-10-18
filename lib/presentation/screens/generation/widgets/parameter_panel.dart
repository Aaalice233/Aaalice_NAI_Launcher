import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/character/inline_character_section.dart';
import '../../../widgets/common/draggable_number_input.dart';
import '../../../widgets/generation/auto_save_toggle_chip.dart';
import 'generation_controls/batch_settings_button.dart';
import 'generation_param_sections.dart';
import 'img2img_panel.dart';
import 'precise_reference_panel.dart';
import 'reverse_prompt_panel.dart';
import 'unified_reference_panel.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/generation/web_panel_modules_provider.dart';
import '../../../providers/reverse_prompt_provider.dart';

/// 参数面板组件（经典布局与移动端使用）
///
/// 由 generation_param_sections.dart 中的分节控件组合而成，
/// 官网式布局的一体滚动列复用同一批分节控件。
class ParameterPanel extends ConsumerWidget {
  const ParameterPanel({super.key, this.showCharacterEditor = false});

  /// 经典桌面侧栏承载角色编辑；移动端通过独立角色管理界面进入。
  final bool showCharacterEditor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final advancedOptionsExpanded = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => params.advancedOptionsExpanded,
      ),
    );
    final hasAdvancedOptions = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => params.hasAdvancedSamplingOptions,
      ),
    );
    final panelModules = ref.watch(webPanelModulesProvider);

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

        const _GenerationOutputSettingsSection(),

        const SizedBox(height: 16),

        // 种子
        const SeedSection(),

        const SizedBox(height: 16),

        // 角色编辑承接完整生成参数，并与下方辅助输入面板保持同级。
        if (showCharacterEditor &&
            (panelModules.showCharacter ||
                ref.watch(
                  characterPromptNotifierProvider.select(
                    (s) => s.characters.isNotEmpty,
                  ),
                ))) ...[
          const InlineCharacterSection(),
          const SizedBox(height: 8),
        ],

        // 反推面板
        if (panelModules.showTagExtraction ||
            ref.watch(
              reversePromptProvider.select((s) => s.images.isNotEmpty),
            )) ...[
          const ReversePromptPanel(),
          const SizedBox(height: 8),
        ],

        // 图生图面板
        const Img2ImgPanel(),

        // 风格迁移面板 (Vibe Transfer)
        if (panelModules.showVibeTransfer ||
            ref.watch(
              generationParamsNotifierProvider.select(
                (p) => p.vibeReferencesV4.isNotEmpty,
              ),
            )) ...[
          const SizedBox(height: 8),
          const UnifiedReferencePanel(),
        ],

        // Precise Reference 面板 (角色/风格参考)
        if (panelModules.showPreciseReference ||
            ref.watch(
              generationParamsNotifierProvider.select(
                (p) => p.preciseReferences.isNotEmpty,
              ),
            )) ...[
          const SizedBox(height: 8),
          const PreciseReferencePanel(),
        ],

        // 高级选项
        if (hasAdvancedOptions) ...[
          const SizedBox(height: 16),
          Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
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
              children: const [AdvancedSamplingOptions()],
            ),
          ),
        ],
      ],
    );
  }
}

class _GenerationOutputSettingsSection extends ConsumerWidget {
  const _GenerationOutputSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nSamples = ref.watch(
      generationParamsNotifierProvider.select((params) => params.nSamples),
    );
    final batchSize = ref.watch(imagesPerRequestProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamSectionTitle(context.l10n.generation_generate),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              label: context.l10n.batchSize_formula(
                nSamples,
                batchSize,
                nSamples * batchSize,
              ),
              child: DraggableNumberInput(
                value: nSamples,
                min: 1,
                prefix: '×',
                onChanged: (value) => ref
                    .read(generationParamsNotifierProvider.notifier)
                    .updateNSamples(value),
              ),
            ),
            const BatchSettingsButton(showLabel: true),
            const AutoSaveToggleChip(),
          ],
        ),
      ],
    );
  }
}
