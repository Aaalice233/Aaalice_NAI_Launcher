import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../../providers/auth_provider.dart';
import '../../providers/generation/image_workflow_controller.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/prompt_maximize_provider.dart';
import '../../utils/asset_protection_guard.dart';
import '../../widgets/anlas/anlas_balance_chip.dart';
import '../../widgets/anlas/opus_usage_chip.dart';
import '../../widgets/common/themed_scaffold.dart';
import '../../widgets/common/themed_button.dart';
import 'widgets/prompt_input.dart';
import 'widgets/history_panel.dart';
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

class _MobileGenerationLayoutState extends ConsumerState<MobileGenerationLayout>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    // 外层导航 Scaffold 会移除后代 MediaQuery 的键盘 inset；监听原始
    // FlutterView 指标，确保嵌套生成工作台仍会随 IME 显隐重建。
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final cooldownState = ref.watch(generationCooldownProvider);
    final isAuthenticated = ref.watch(
      authNotifierProvider.select((state) => state.isAuthenticated),
    );
    final supportsKrita = PlatformCapabilities.current.supportsKritaBridge;
    final isKritaGenerating = supportsKrita
        ? ref.watch(kritaBridgeNotifierProvider).isBridgeGenerating
        : false;
    final isPromptMaximized = ref.watch(promptMaximizeNotifierProvider);
    final theme = Theme.of(context);
    // 导航 Shell 与页面都使用 Scaffold；任一外层 Scaffold 调整完约束后会
    // 移除后代 MediaQuery 的键盘 inset，因此同时读取未被过滤的 FlutterView。
    final keyboardVisible =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        View.of(context).viewInsets.bottom > 0;
    final isLauncherGenerating = generationState.isGenerating;
    final isGenerating = isLauncherGenerating || isKritaGenerating;
    final requiresLogin = !isAuthenticated && !isGenerating;
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);
    final isUpscaleMode = ref.watch(
      imageWorkflowControllerProvider.select((workflow) => workflow.isUpscale),
    );
    final randomModeEnabled = ref.watch(randomPromptModeProvider);

    return PopScope<void>(
      canPop: !isPromptMaximized,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isPromptMaximized) {
          unawaited(
            ref
                .read(promptMaximizeNotifierProvider.notifier)
                .setMaximized(false),
          );
        }
      },
      child: ThemedScaffold(
        scaffoldKey: _scaffoldKey,
        drawer: isPromptMaximized ? null : _buildParameterDrawer(context),
        endDrawer: isPromptMaximized ? null : _buildHistoryDrawer(context),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(context.l10n.generation_title),
          actions: isPromptMaximized
              ? null
              : [
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    tooltip: context.l10n.generation_paramsSettings,
                  ),
                  IconButton(
                    icon: const Icon(Icons.history_rounded),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                    tooltip: context.l10n.generation_history,
                  ),
                ],
        ),
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: isPromptMaximized
                  ? const Padding(
                      key: ValueKey('maximized-prompt'),
                      padding: EdgeInsets.all(12),
                      child: PromptInputWidget(isMaximized: true),
                    )
                  : LayoutBuilder(
                      key: const ValueKey('generation-workspace'),
                      builder: (context, constraints) {
                        final useHorizontalLayout =
                            constraints.maxWidth >= 640 &&
                            constraints.maxWidth > constraints.maxHeight * 1.15;
                        if (useHorizontalLayout) {
                          return Row(
                            children: [
                              const Expanded(
                                flex: 6,
                                child: ImagePreviewWidget(),
                              ),
                              VerticalDivider(
                                width: 1,
                                color: theme.dividerColor,
                              ),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    const Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: PromptInputWidget(compact: true),
                                      ),
                                    ),
                                    if (generationState.isGenerating)
                                      _GenerationProgress(
                                        progress: generationState.progress,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        final useCondensedWorkspace =
                            keyboardVisible || constraints.maxHeight < 420;
                        return Column(
                          children: [
                            Expanded(
                              flex: useCondensedWorkspace ? 1 : 42,
                              child: const Padding(
                                padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
                                child: PromptInputWidget(compact: true),
                              ),
                            ),
                            if (!useCondensedWorkspace)
                              const Expanded(
                                flex: 58,
                                child: ImagePreviewWidget(),
                              ),
                            if (generationState.isGenerating)
                              _GenerationProgress(
                                progress: generationState.progress,
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: keyboardVisible
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(top: BorderSide(color: theme.dividerColor)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final generateButton = _MobileGenerateButton(
                        isGenerating: isGenerating,
                        showCancel: isLauncherGenerating,
                        generationState: generationState,
                        cooldownRemainingSeconds:
                            cooldownState.remainingSeconds,
                        onGenerate: () => _handleGenerate(context, ref),
                        onCancel: () => ref
                            .read(imageGenerationNotifierProvider.notifier)
                            .cancel(),
                        onSkipCurrent: () => ref
                            .read(imageGenerationNotifierProvider.notifier)
                            .skipCurrentRequest(),
                        showCost: !isUpscaleMode,
                        requiresLogin: requiresLogin,
                      );
                      final randomToggle = _MobileRandomModeToggle(
                        enabled: randomModeEnabled,
                      );

                      if (constraints.maxWidth < 520) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  const OpusUsageChip(compact: true),
                                  const AnlasBalanceChip(compact: true),
                                  if (showRandomTools) randomToggle,
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            generateButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          const OpusUsageChip(compact: true),
                          const SizedBox(width: 6),
                          const AnlasBalanceChip(compact: true),
                          const SizedBox(width: 8),
                          if (showRandomTools) ...[
                            randomToggle,
                            const SizedBox(width: 8),
                          ],
                          Expanded(child: generateButton),
                        ],
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildParameterDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      width: (MediaQuery.sizeOf(context).width * 0.9)
          .clamp(280.0, 420.0)
          .toDouble(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _scaffoldKey.currentState?.closeDrawer(),
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      context.l10n.generation_paramsSettings,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            const Expanded(child: ParameterPanel()),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryDrawer(BuildContext context) {
    return Drawer(
      width: (MediaQuery.sizeOf(context).width * 0.9)
          .clamp(280.0, 440.0)
          .toDouble(),
      child: SafeArea(
        child: HistoryPanel(
          onClose: () => _scaffoldKey.currentState?.closeEndDrawer(),
        ),
      ),
    );
  }

  Future<void> _handleGenerate(BuildContext context, WidgetRef ref) async {
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      await context.pushNamed('login');
      return;
    }

    final params = ref.read(generationParamsNotifierProvider);
    if (PlatformCapabilities.current.supportsKritaBridge &&
        ref.read(kritaBridgeNotifierProvider).isBridgeGenerating) {
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

class _GenerationProgress extends StatelessWidget {
  const _GenerationProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: context.l10n.generation_progress(
        (progress * 100).toInt().toString(),
      ),
      value: '${(progress * 100).toInt()}%',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.generation_progress(
                (progress * 100).toInt().toString(),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// 移动端抽卡模式开关
class _MobileRandomModeToggle extends ConsumerWidget {
  final bool enabled;

  const _MobileRandomModeToggle({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final semanticLabel = enabled
        ? context.l10n.randomMode_enabledTip
        : context.l10n.randomMode_disabledTip;

    return Semantics(
      button: true,
      toggled: enabled,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
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
              curve: Curves.easeOutCubic,
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
  final bool requiresLogin;

  const _MobileGenerateButton({
    required this.isGenerating,
    required this.showCancel,
    required this.generationState,
    this.cooldownRemainingSeconds = 0,
    required this.onGenerate,
    required this.onCancel,
    required this.onSkipCurrent,
    this.showCost = true,
    this.requiresLogin = false,
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
            : requiresLogin
            ? onGenerate
            : isGenerating || cooldownRemainingSeconds > 0
            ? null
            : onGenerate,
        isLoading: isLoading,
        label: IndexedStack(
          index: showCancel ? 1 : 0,
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isLoading) ...[
                  Icon(
                    requiresLogin
                        ? Icons.login_rounded
                        : cooldownRemainingSeconds > 0
                        ? Icons.hourglass_bottom_outlined
                        : Icons.auto_awesome,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    showCancel
                        ? context.l10n.generation_generate
                        : requiresLogin
                        ? context.l10n.auth_login
                        : isGenerating
                        ? context.l10n.generation_generating
                        : cooldownRemainingSeconds > 0
                        ? context.l10n.generation_cooldownRemaining(
                            cooldownRemainingSeconds,
                          )
                        : context.l10n.generation_generate,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (showCost && !requiresLogin)
                  AnlasCostBadge(isGenerating: isLoading),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stop_circle_outlined),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.l10n.common_cancel,
                    textAlign: TextAlign.center,
                  ),
                ),
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
        textAlign: TextAlign.center,
      ),
      style: ThemedButtonStyle.outlined,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        if (largeText || constraints.maxWidth < 440) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: double.infinity, child: skipButton),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: primaryButton),
            ],
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
