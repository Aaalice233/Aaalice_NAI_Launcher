import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
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
    final isAuthenticated = ref.watch(
      authNotifierProvider.select((state) => state.isAuthenticated),
    );
    final isKritaGenerating =
        PlatformCapabilities.current.supportsKritaBridge &&
        ref.watch(kritaBridgeNotifierProvider).isBridgeGenerating;
    final nSamples = ref.watch(
      generationParamsNotifierProvider.select((params) => params.nSamples),
    );
    final isLauncherGenerating = generationState.isGenerating;
    final isGenerating = isLauncherGenerating || isKritaGenerating;

    // 生成中常驻显示取消入口（与移动端一致）
    final showCancel = isLauncherGenerating;

    final randomMode = ref.watch(randomPromptModeProvider);
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);
    final isUpscaleMode = ref.watch(
      imageWorkflowControllerProvider.select((workflow) => workflow.isUpscale),
    );

    // 快捷键已由父级 DesktopGenerationLayout 统一处理
    // 这里只负责布局
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 18.2;
        final isNarrow =
            widget.compact || constraints.maxWidth < 720 || largeText;

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
          showCost: !isUpscaleMode,
          requiresLogin: !isAuthenticated && !isGenerating,
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
            if (widget.compact && !showCancel) const BatchSettingsButton(),
          ];

          final compact = widget.compact;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: constraints.maxWidth.clamp(0.0, 190.0),
                  child: generateButton,
                ),
                if (rightGroup.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ...rightGroup,
                ],
                const SizedBox(width: 8),
                OpusUsageChip(compact: compact),
                const SizedBox(width: 8),
                AnlasBalanceChip(compact: compact),
                if (showRandomTools) ...[
                  const SizedBox(width: 8),
                  RandomModeToggle(enabled: randomMode),
                ],
                if (compact) ...[
                  const SizedBox(width: 8),
                  const AutoSaveToggleChip(compact: true),
                ],
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  const OpusUsageChip(),
                  const AnlasBalanceChip(),
                  if (showRandomTools) RandomModeToggle(enabled: randomMode),
                ],
              ),
            ),
            const SizedBox(width: 12),
            generateButton,
            const SizedBox(width: 12),
            const Spacer(),
          ],
        );
      },
    );
  }

  Future<void> _handleGenerate(BuildContext context, WidgetRef ref) async {
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      await context.pushNamed('login');
      return;
    }

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
