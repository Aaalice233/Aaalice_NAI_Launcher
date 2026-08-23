import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/krita/krita_bridge_notifier.dart';
import 'package:nai_launcher/presentation/utils/asset_protection_guard.dart';
import 'package:nai_launcher/presentation/widgets/common/app_toast.dart';
import 'package:nai_launcher/presentation/widgets/common/draggable_number_input.dart';
import 'package:nai_launcher/presentation/widgets/generation/auto_save_toggle_chip.dart';
import 'package:nai_launcher/presentation/widgets/anlas/anlas_balance_chip.dart';
import 'package:nai_launcher/presentation/widgets/anlas/opus_usage_chip.dart';
import 'batch_settings_button.dart';
import 'generate_button.dart';
import 'random_mode_toggle.dart';

/// 生成控制按钮
class GenerationControls extends ConsumerStatefulWidget {
  /// 紧凑模式：用于官网式布局的钉底控制条——
  /// 强制窄排布、追加批次大小按钮、压低生成按钮高度。
  final bool compact;

  const GenerationControls({super.key, this.compact = false});

  @override
  ConsumerState<GenerationControls> createState() => _GenerationControlsState();
}

class _GenerationControlsState extends ConsumerState<GenerationControls> {
  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final cooldownState = ref.watch(generationCooldownProvider);
    final kritaBridgeState = ref.watch(kritaBridgeNotifierProvider);
    final nSamples = ref.watch(
      generationParamsNotifierProvider.select((params) => params.nSamples),
    );
    final isLauncherGenerating = generationState.isGenerating;
    final isGenerating =
        isLauncherGenerating || kritaBridgeState.isBridgeGenerating;

    // 生成中常驻显示取消入口（与移动端一致）
    final showCancel = isLauncherGenerating;

    final randomMode = ref.watch(randomPromptModeProvider);
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);

    // 快捷键已由父级 DesktopGenerationLayout 统一处理
    // 这里只负责布局
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = widget.compact || constraints.maxWidth < 500;

        // 生成按钮几何居中：左右两个等宽弹性区吸收其余控件，
        // 按钮位置不随随机工具等元素的显隐漂移
        final generateButton = GenerateButtonWithCost(
          height: widget.compact ? 40 : 48,
          isGenerating: isGenerating,
          showCancel: showCancel,
          generationState: generationState,
          cooldownRemainingSeconds: cooldownState.remainingSeconds,
          onGenerate: () => unawaited(_handleGenerate(context, ref)),
          onCancel: () =>
              ref.read(imageGenerationNotifierProvider.notifier).cancel(),
          onSkipCurrent: () => ref
              .read(imageGenerationNotifierProvider.notifier)
              .skipCurrentRequest(),
        );

        if (isNarrow) {
          final rightGroup = <Widget>[
            // 紧凑模式生成中隐藏批量调节（此时批量参数不可变更），
            // 为跳过/停止按钮腾出宽度
            if (!(widget.compact && showCancel))
              DraggableNumberInput(
                value: nSamples,
                min: 1,
                prefix: '×',
                onChanged: (value) {
                  ref
                      .read(generationParamsNotifierProvider.notifier)
                      .updateNSamples(value);
                },
              ),
            // 紧凑模式补上第二种批量控制：批次大小（每次请求张数）
            if (widget.compact && !showCancel) ...[
              const SizedBox(width: 4),
              const BatchSettingsButton(),
            ],
          ];

          if (widget.compact) {
            // 官网钉底条单行：自动保存放右侧空位，左组只剩点数与骰子，
            // 两侧内容变均衡后不再需要把字缩小
            return Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const OpusUsageChip(compact: true),
                          const SizedBox(width: 6),
                          const AnlasBalanceChip(compact: true),
                          if (showRandomTools) ...[
                            const SizedBox(width: 8),
                            RandomModeToggle(enabled: randomMode),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                generateButton,
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...rightGroup,
                          const SizedBox(width: 8),
                          const AutoSaveToggleChip(compact: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // 经典布局窄宽：单行三段，生成按钮居中
          return Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: showRandomTools
                      ? RandomModeToggle(enabled: randomMode)
                      : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 8),
              generateButton,
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: rightGroup,
                  ),
                ),
              ),
            ],
          );
        }

        // 正常布局 - 自动保存锚最左，点数/随机贴按钮左，批量控件贴按钮右；
        // 左右组空间不足时内部等比缩小，避免溢出叠到生成按钮上
        return Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const AutoSaveToggleChip(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const OpusUsageChip(),
                            const SizedBox(width: 8),
                            const AnlasBalanceChip(),
                            const SizedBox(width: 16),
                            if (showRandomTools) ...[
                              RandomModeToggle(enabled: randomMode),
                              const SizedBox(width: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            generateButton,
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 12),
                      DraggableNumberInput(
                        value: nSamples,
                        min: 1,
                        prefix: '×',
                        onChanged: (value) {
                          ref
                              .read(generationParamsNotifierProvider.notifier)
                              .updateNSamples(value);
                        },
                      ),
                      const SizedBox(width: 16),
                      const BatchSettingsButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleGenerate(BuildContext context, WidgetRef ref) async {
    final params = ref.read(generationParamsNotifierProvider);
    if (params.prompt.isEmpty) {
      AppToast.warning(context, context.l10n.generation_pleaseInputPrompt);
      return;
    }

    final confirmed = await AssetProtectionGuard.confirmHighAnlasCost(
      context: context,
      ref: ref,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    // 生成（抽卡模式逻辑在 generate 方法内部处理）
    ref.read(imageGenerationNotifierProvider.notifier).generate(params);
  }
}
