import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/image_generation_provider.dart';
import '../../themes/design_tokens.dart';
import '../../widgets/anlas/anlas_balance_chip.dart';
import '../../widgets/anlas/opus_usage_chip.dart';
import '../../widgets/common/anlas_cost_badge.dart';
import '../../widgets/common/owned_scroll_controller.dart';
import '../../widgets/common/themed_button.dart';
import '../../widgets/common/themed_scaffold.dart';
import 'mobile_generation_controller.dart';
import 'mobile_generation_gestures.dart';
import 'mobile_generation_view_data.dart';
import 'widgets/history_panel.dart';
import 'widgets/parameter_panel.dart';

class MobileGenerationChrome extends ConsumerWidget {
  const MobileGenerationChrome({
    super.key,
    required this.controller,
    required this.data,
    required this.historyViewport,
    required this.body,
  });

  final MobileGenerationController controller;
  final MobileGenerationViewData data;
  final OwnedViewportOffset historyViewport;
  final Widget body;

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    if (controller.agentFullScreen) return null;
    return AppBar(
      automaticallyImplyLeading: false,
      leading: data.isPromptMaximized
          ? IconButton(
              key: const ValueKey('generation-prompt-editor-close'),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: context.l10n.toolbar_fullscreenEdit,
              onPressed: controller.closePromptEditor,
            )
          : null,
      title: data.isPromptMaximized
          ? MobileVerticalCloseGesture(
              key: const ValueKey('generation-prompt-editor-drag-handle'),
              closeDirection: AxisDirection.up,
              onClose: controller.closePromptEditor,
              child: _FullscreenHeaderTitle(
                label: context.l10n.promptToken_prompt,
              ),
            )
          : Text(context.l10n.generation_title),
      actions: data.isPromptMaximized
          ? null
          : [
              IconButton(
                key: const ValueKey('generation-parameters-drawer-action'),
                icon: const Icon(Icons.tune_rounded),
                onPressed: controller.openParameterDrawer,
                tooltip: context.l10n.generation_paramsSettings,
              ),
              IconButton(
                key: const ValueKey('generation-agent-drawer-action'),
                icon: const Icon(Icons.smart_toy_outlined),
                onPressed: controller.openAgentChat,
                tooltip: context.l10n.agentChat_tab,
              ),
              IconButton(
                key: const ValueKey('generation-history-drawer-action'),
                icon: const Icon(Icons.history_rounded),
                onPressed: controller.openHistoryDrawer,
                tooltip: context.l10n.generation_history,
              ),
            ],
    );
  }

  Widget? _buildParameterDrawer(BuildContext context) {
    if (data.isPromptMaximized || controller.agentFullScreen) return null;
    final theme = Theme.of(context);
    return Drawer(
      key: const ValueKey('generation-parameters-drawer'),
      width: MediaQuery.sizeOf(context).width * 0.9,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: controller.closeParameterDrawer,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
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

  Widget? _buildHistoryDrawer(BuildContext context) {
    if (data.isPromptMaximized || controller.agentFullScreen) return null;
    return Drawer(
      key: const ValueKey('generation-history-drawer'),
      width: MediaQuery.sizeOf(context).width * 0.9,
      child: SafeArea(
        child: HistoryPanel(
          onClose: controller.closeHistoryDrawer,
          viewportOffset: historyViewport,
        ),
      ),
    );
  }

  Widget? _buildBottomBar(BuildContext context, WidgetRef ref) {
    if (data.keyboardVisible || controller.agentFullScreen) return null;
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('generation-mobile-bottom-bar'),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const OpusUsageChip(compact: true),
                const SizedBox(width: 4),
                const AnlasBalanceChip(compact: true),
                if (data.showRandomTools) ...[
                  const Spacer(),
                  _MobileRandomModeToggle(
                    enabled: data.randomModeEnabled,
                    showLabel: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            _MobileGenerateButton(
              isGenerating: data.isGenerating,
              showCancel: data.isLauncherGenerating,
              generationState: data.generationState,
              cooldownRemainingSeconds: data.cooldownRemainingSeconds,
              onGenerate: () => controller.generate(context),
              onCancel: controller.cancelGeneration,
              onSkipCurrent: controller.skipCurrentRequest,
              showCost: !data.isUpscaleMode,
              requiresLogin: data.requiresLogin,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ThemedScaffold(
      scaffoldKey: controller.scaffoldKey,
      drawer: _buildParameterDrawer(context),
      endDrawer: _buildHistoryDrawer(context),
      appBar: _buildAppBar(context),
      body: body,
      bottomNavigationBar: _buildBottomBar(context, ref),
    );
  }
}

class _FullscreenHeaderTitle extends StatelessWidget {
  const _FullscreenHeaderTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: DesignTokens.spacingXxs),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _MobileRandomModeToggle extends ConsumerWidget {
  const _MobileRandomModeToggle({
    required this.enabled,
    this.showLabel = false,
  });

  final bool enabled;
  final bool showLabel;

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
              width: showLabel ? null : 44,
              height: 44,
              padding: showLabel
                  ? const EdgeInsets.symmetric(horizontal: 12)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: enabled
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.casino_outlined,
                    size: 20,
                    color: enabled
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  if (showLabel) ...[
                    const SizedBox(width: 7),
                    Text(
                      context.l10n.toolbar_randomPrompt,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: enabled
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileGenerateButton extends StatelessWidget {
  const _MobileGenerateButton({
    required this.isGenerating,
    required this.showCancel,
    required this.generationState,
    required this.cooldownRemainingSeconds,
    required this.onGenerate,
    required this.onCancel,
    required this.onSkipCurrent,
    required this.showCost,
    required this.requiresLogin,
  });

  final bool isGenerating;
  final bool showCancel;
  final ImageGenerationState generationState;
  final int cooldownRemainingSeconds;
  final VoidCallback onGenerate;
  final VoidCallback onCancel;
  final VoidCallback onSkipCurrent;
  final bool showCost;
  final bool requiresLogin;

  bool get _canSkipCurrentBatch =>
      showCancel &&
      generationState.currentImage > 0 &&
      generationState.totalImages > generationState.currentImage;

  @override
  Widget build(BuildContext context) {
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
    if (!_canSkipCurrentBatch) return primaryButton;
    final progress =
        '${generationState.currentImage}/${generationState.totalImages}';
    final skipButton = ThemedButton(
      onPressed: onSkipCurrent,
      icon: const Icon(Icons.skip_next),
      label: Text(
        '${context.l10n.generation_skipCurrentBatch} $progress',
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
