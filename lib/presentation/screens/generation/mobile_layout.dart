import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/generation/image_workflow_controller.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/prompt_maximize_provider.dart';
import '../../utils/asset_protection_guard.dart';
import '../../widgets/anlas/anlas_balance_chip.dart';
import '../../widgets/anlas/opus_usage_chip.dart';
import '../../widgets/common/themed_divider.dart';
import '../../widgets/common/themed_scaffold.dart';
import '../../widgets/common/themed_button.dart';
import 'widgets/prompt_input.dart';
import 'widgets/image_preview.dart';
import '../../widgets/common/anlas_cost_badge.dart';
import 'widgets/parameter_panel.dart';

import '../../widgets/common/app_toast.dart';

/// 移动端单栏布局
class MobileGenerationLayout extends ConsumerStatefulWidget {
  const MobileGenerationLayout({super.key});

  @override
  ConsumerState<MobileGenerationLayout> createState() =>
      _MobileGenerationLayoutState();
}

class _MobileGenerationLayoutState
    extends ConsumerState<MobileGenerationLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final cooldownState = ref.watch(generationCooldownProvider);
    final kritaBridgeState = ref.watch(kritaBridgeNotifierProvider);
    final isPromptMaximized = ref.watch(promptMaximizeNotifierProvider);
    final theme = Theme.of(context);
    final isLauncherGenerating = generationState.isGenerating;
    final isGenerating =
        isLauncherGenerating || kritaBridgeState.isBridgeGenerating;
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);
    final isUpscaleMode = ref.watch(
      imageWorkflowControllerProvider.select((workflow) => workflow.isUpscale),
    );
    final drawerWidth = math.max(
      160.0,
      math.min(300.0, MediaQuery.sizeOf(context).width - 24),
    );

    Widget buildResourceControls() {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const OpusUsageChip(compact: true),
          const AnlasBalanceChip(compact: true),
          if (showRandomTools)
            _MobileRandomModeToggle(
              enabled: ref.watch(randomPromptModeProvider),
            ),
        ],
      );
    }

    Widget buildGenerateButton() {
      return _MobileGenerateButton(
        isGenerating: isGenerating,
        showCancel: isLauncherGenerating,
        generationState: generationState,
        cooldownRemainingSeconds: cooldownState.remainingSeconds,
        onGenerate: () => _handleGenerate(context, ref),
        onCancel: () =>
            ref.read(imageGenerationNotifierProvider.notifier).cancel(),
        onSkipCurrent: () => ref
            .read(imageGenerationNotifierProvider.notifier)
            .skipCurrentRequest(),
        showCost: !isUpscaleMode,
      );
    }

    return ThemedScaffold(
      // 使用 GlobalKey 来控制 Drawer
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(context.l10n.generation_title),
        actions: [
          // 参数设置按钮 (打开侧边抽屉)
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
            tooltip: context.l10n.generation_paramsSettings,
          ),
        ],
      ),
      endDrawer: Drawer(
        width: drawerWidth,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.generation_paramsSettings,
                      style: theme.textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const ThemedDivider(),
              const Expanded(child: ParameterPanel()),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Prompt 输入区（最大化时占满空间）
          isPromptMaximized
              ? Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: PromptInputWidget(isMaximized: isPromptMaximized),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(12),
                  child: const PromptInputWidget(compact: true),
                ),

          // 图像预览区（最大化时隐藏）
          if (!isPromptMaximized) const Expanded(child: ImagePreviewWidget()),

          // 生成状态和进度（最大化时隐藏）
          if (!isPromptMaximized && generationState.isGenerating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: generationState.progress,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.generation_progress(
                      (generationState.progress * 100).toInt().toString(),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),

      // 底部生成按钮
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 520) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: buildResourceControls(),
                    ),
                    const SizedBox(height: 10),
                    buildGenerateButton(),
                  ],
                );
              }

              return Row(
                children: [
                  buildResourceControls(),
                  const SizedBox(width: 8),
                  Expanded(child: buildGenerateButton()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleGenerate(BuildContext context, WidgetRef ref) async {
    final params = ref.read(generationParamsNotifierProvider);
    if (ref.read(kritaBridgeNotifierProvider).isBridgeGenerating) {
      AppToast.warning(context, context.l10n.toast_kritaBusy);
      return;
    }
    if (params.prompt.isEmpty) {
      AppToast.info(context, context.l10n.generation_pleaseInputPrompt);
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

/// 移动端抽卡模式开关
class _MobileRandomModeToggle extends ConsumerWidget {
  final bool enabled;

  const _MobileRandomModeToggle({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Tooltip(
      message: enabled
          ? context.l10n.randomMode_enabledTip
          : context.l10n.randomMode_disabledTip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ref.read(randomPromptModeProvider.notifier).toggle(),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 140),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: enabled
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.casino_outlined,
              size: 22,
              color: enabled
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// 移动端生成按钮（集成价格徽章）
class _MobileGenerateButton extends ConsumerWidget {
  final bool isGenerating;
  final bool showCancel;
  final ImageGenerationState generationState;
  final int cooldownRemainingSeconds;
  final VoidCallback onGenerate;
  final VoidCallback onCancel;
  final VoidCallback onSkipCurrent;
  final bool showCost;

  const _MobileGenerateButton({
    required this.isGenerating,
    required this.showCancel,
    required this.generationState,
    this.cooldownRemainingSeconds = 0,
    required this.onGenerate,
    required this.onCancel,
    required this.onSkipCurrent,
    this.showCost = true,
  });

  bool get _canSkipCurrentBatch =>
      showCancel &&
      generationState.currentImage > 0 &&
      generationState.totalImages > generationState.currentImage;

  String _progressText() =>
      '${generationState.currentImage}/${generationState.totalImages}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cancelTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: theme.colorScheme.errorContainer,
        onPrimary: theme.colorScheme.onErrorContainer,
        primaryContainer: theme.colorScheme.error,
        onPrimaryContainer: theme.colorScheme.onError,
      ),
    );
    final isLoading = isGenerating && !showCancel;
    final primaryButton = AnimatedTheme(
      data: showCancel ? cancelTheme : theme,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: ThemedButton(
        onPressed: showCancel
            ? onCancel
            : isGenerating || cooldownRemainingSeconds > 0
            ? null
            : onGenerate,
        isLoading: isLoading,
        label: IndexedStack(
          index: showCancel ? 1 : 0,
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isLoading) ...[
                  Icon(
                    cooldownRemainingSeconds > 0
                        ? Icons.hourglass_bottom_outlined
                        : Icons.auto_awesome,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  showCancel
                      ? context.l10n.generation_generate
                      : isGenerating
                      ? context.l10n.generation_generating
                      : cooldownRemainingSeconds > 0
                      ? context.l10n.generation_cooldownRemaining(
                          cooldownRemainingSeconds,
                        )
                      : context.l10n.generation_generate,
                ),
                if (showCost) AnlasCostBadge(isGenerating: isLoading),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stop_circle_outlined),
                const SizedBox(width: 8),
                Text(context.l10n.common_cancel),
              ],
            ),
          ],
        ),
        style: ThemedButtonStyle.filled,
      ),
    );

    if (!_canSkipCurrentBatch) {
      return primaryButton;
    }

    final skipButton = ThemedButton(
      onPressed: onSkipCurrent,
      icon: const Icon(Icons.skip_next),
      label: Text(
        '${context.l10n.generation_skipCurrentBatch} ${_progressText()}',
      ),
      style: ThemedButtonStyle.outlined,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 440) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [skipButton, const SizedBox(height: 8), primaryButton],
          );
        }

        return Row(
          children: [
            Expanded(child: skipButton),
            const SizedBox(width: 8),
            Expanded(child: primaryButton),
          ],
        );
      },
    );
  }
}
