import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/prompt_maximize_provider.dart';
import '../../utils/asset_protection_guard.dart';
import '../../widgets/anlas/anlas_balance_chip.dart';
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
    final kritaBridgeState = ref.watch(kritaBridgeNotifierProvider);
    final isPromptMaximized = ref.watch(promptMaximizeNotifierProvider);
    final theme = Theme.of(context);
    final isLauncherGenerating = generationState.isGenerating;
    final isGenerating =
        isLauncherGenerating || kritaBridgeState.isBridgeGenerating;
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);

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
        width: 300,
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
          child: Row(
            children: [
              // Anlas 余额显示
              const AnlasBalanceChip(compact: true),
              const SizedBox(width: 8),
              // 抽卡模式开关
              if (showRandomTools) ...[
                _MobileRandomModeToggle(
                  enabled: ref.watch(randomPromptModeProvider),
                ),
                const SizedBox(width: 8),
              ],
              // 生成按钮（集成价格徽章）
              Expanded(
                child: _MobileGenerateButton(
                  isGenerating: isGenerating,
                  showCancel: isLauncherGenerating,
                  generationState: generationState,
                  onGenerate: () => _handleGenerate(context, ref),
                  onCancel: () => ref
                      .read(imageGenerationNotifierProvider.notifier)
                      .cancel(),
                  onSkipCurrent: () => ref
                      .read(imageGenerationNotifierProvider.notifier)
                      .skipCurrentRequest(),
                ),
              ),
            ],
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
      child: GestureDetector(
        onTap: () {
          ref.read(randomPromptModeProvider.notifier).toggle();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: enabled
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Icon(
            Icons.casino_outlined,
            size: 22,
            color: enabled
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
  final VoidCallback onGenerate;
  final VoidCallback onCancel;
  final VoidCallback onSkipCurrent;

  const _MobileGenerateButton({
    required this.isGenerating,
    required this.showCancel,
    required this.generationState,
    required this.onGenerate,
    required this.onCancel,
    required this.onSkipCurrent,
  });

  bool get _canSkipCurrentBatch =>
      showCancel &&
      generationState.currentImage > 0 &&
      generationState.totalImages > generationState.currentImage;

  String _progressText() =>
      '${generationState.currentImage}/${generationState.totalImages}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (showCancel) {
      return Row(
        children: [
          if (_canSkipCurrentBatch) ...[
            Expanded(
              child: ThemedButton(
                onPressed: onSkipCurrent,
                icon: const Icon(Icons.skip_next),
                label: Text(
                  '${context.l10n.generation_skipCurrentBatch} ${_progressText()}',
                ),
                style: ThemedButtonStyle.outlined,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ThemedButton(
              onPressed: onCancel,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(context.l10n.generation_stopAllGeneration),
              style: ThemedButtonStyle.outlined,
            ),
          ),
        ],
      );
    }

    return ThemedButton(
      onPressed: isGenerating ? null : onGenerate,
      icon: isGenerating ? null : const Icon(Icons.auto_awesome),
      isLoading: isGenerating,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isGenerating
                ? context.l10n.generation_generating
                : context.l10n.generation_generate,
          ),
          AnlasCostBadge(isGenerating: isGenerating),
        ],
      ),
      style: ThemedButtonStyle.filled,
    );
  }
}
