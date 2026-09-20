import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/window_size_class.dart';
import '../../agent_chat/widgets/agent_chat_entry_button.dart';
import '../../providers/image_generation_provider.dart';
import '../../services/mobile_image_metadata_importer.dart';
import '../../themes/design_tokens.dart';
import '../../widgets/anlas/anlas_balance_chip.dart';
import '../../widgets/anlas/opus_usage_chip.dart';
import '../../widgets/common/anlas_cost_badge.dart';
import '../../widgets/common/draggable_number_input.dart';
import '../../widgets/common/owned_scroll_controller.dart';
import '../../widgets/common/themed_button.dart';
import '../../widgets/common/themed_scaffold.dart';
import 'mobile_generation_controller.dart';
import 'mobile_generation_gestures.dart';
import 'mobile_generation_view_data.dart';
import 'widgets/parameter_panel.dart';
import 'widgets/quick_tools_drawer.dart';
import 'widgets/generation_controls/generate_button.dart';
import 'widgets/generation_controls/random_mode_toggle.dart';

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

  PreferredSizeWidget? _buildAppBar(BuildContext context, WidgetRef ref) {
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
          // 偏离上游：上游这里是空的（左抽屉是参数面板，只靠边缘侧滑打开）。
          // 左抽屉换成快捷工具后必须有一击可达的入口。
          : IconButton(
              key: const ValueKey('generation-quick-tools-drawer-action'),
              icon: const Icon(Icons.style_outlined),
              tooltip: context.l10n.generation_quickTools,
              onPressed: controller.openQuickToolsDrawer,
            ),
      title: data.isPromptMaximized
          ? MobileVerticalCloseGesture(
              key: const ValueKey('generation-prompt-editor-drag-handle'),
              closeDirection: AxisDirection.up,
              onClose: controller.closePromptEditor,
              child: _FullscreenHeaderTitle(
                label: context.l10n.promptToken_prompt,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.brush_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(context.l10n.nav_canvas)),
              ],
            ),
      actions: data.isPromptMaximized
          ? null
          : [
              IconButton(
                key: const ValueKey('generation-parameters-drawer-action'),
                icon: const Icon(Icons.tune_rounded),
                onPressed: controller.openParameterDrawer,
                tooltip: context.l10n.generation_paramsSettings,
              ),
              // 桌面端靠把图拖进窗口解析元数据，移动端没有拖放，这是等价入口。
              IconButton(
                key: const ValueKey('generation-import-metadata-action'),
                icon: const Icon(Icons.document_scanner_outlined),
                onPressed: () => showMobileImageMetadataImportSheet(
                  context: context,
                  ref: ref,
                ),
                tooltip: context.l10n.metadataImport_readImageMetadata,
              ),
              AgentChatEntryButton(onPressed: controller.openAgentChat),
              IconButton(
                key: const ValueKey('generation-history-panel-action'),
                icon: const Icon(Icons.history_rounded),
                onPressed: () =>
                    controller.openHistoryPanel(context, historyViewport),
                tooltip: context.l10n.generation_history,
              ),
            ],
    );
  }

  /// 左抽屉：固定词 / 角色的快捷开关列表（用户点名保留的入口）。
  ///
  /// 偏离上游：上游 v4.2.1 的 `drawer` 是参数面板，见
  /// [GenerationQuickToolsDrawer] 的文件头注释。
  Widget? _buildQuickToolsDrawer() {
    if (data.isPromptMaximized || controller.agentFullScreen) return null;
    return const GenerationQuickToolsDrawer();
  }

  /// 右抽屉：参数面板。
  ///
  /// 偏离上游：上游把它放在左 `drawer` 且宽度取 usableWidth*0.9（上限 520），
  /// 手机上几乎盖满屏幕。我们挪到 `endDrawer` 并收到 300pt + 紧凑密度 +
  /// 字号 0.92，保证左边还露着预览，可以一边调参数一边看图。
  Widget? _buildParameterDrawer(BuildContext context) {
    if (data.isPromptMaximized || controller.agentFullScreen) return null;
    final theme = Theme.of(context);
    return Drawer(
      key: const ValueKey('generation-parameters-drawer'),
      width: (AdaptiveWindowMetrics.of(context).usableSize.width * 0.9).clamp(
        0.0,
        300.0,
      ),
      child: Theme(
        data: theme.copyWith(
          visualDensity: VisualDensity.compact,
          textTheme: theme.textTheme.apply(fontSizeFactor: 0.92),
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            isDense: true,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.generation_paramsSettings,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: const ValueKey('generation-parameters-drawer-close'),
                      onPressed: controller.closeParameterDrawer,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
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
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              key: const ValueKey('generation-mobile-status-row'),
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                const Wrap(
                  key: ValueKey('generation-mobile-balance-group'),
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OpusUsageChip(compact: true),
                    AnlasBalanceChip(compact: true),
                  ],
                ),
                Row(
                  key: const ValueKey('generation-mobile-queue-actions'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 偏离上游：上游的移动端底栏没有 nSamples，连续生成张数只能
                    // 进参数抽屉改。它是每次生成前都要动的高频项，必须留在底栏。
                    DraggableNumberInput(
                      key: const ValueKey('generation-mobile-batch-count'),
                      value: ref.watch(
                        generationParamsNotifierProvider.select(
                          (params) => params.nSamples,
                        ),
                      ),
                      min: 1,
                      prefix: '×',
                      onChanged: (value) => ref
                          .read(generationParamsNotifierProvider.notifier)
                          .updateNSamples(value),
                    ),
                    const SizedBox(width: 4),
                    if (data.showRandomTools)
                      SizedBox.square(
                        dimension: 44,
                        child: RandomModeToggle(
                          enabled: data.randomModeEnabled,
                          compact: true,
                        ),
                      ),
                    IconButton(
                      key: const ValueKey('generation-add-current-to-queue'),
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(44),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.standard,
                      ),
                      onPressed: () =>
                          controller.addCurrentPromptToQueue(context),
                      icon: const Icon(Icons.playlist_add_rounded),
                      tooltip: context.l10n.queue_addCurrentTask,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 2),
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
      // 左 = 快捷工具（固定词 / 角色开关），右 = 参数面板。
      // 上游是左 = 参数面板 / 右 = 历史，历史见 controller.openHistoryPanel。
      drawer: _buildQuickToolsDrawer(),
      endDrawer: _buildParameterDrawer(context),
      appBar: _buildAppBar(context, ref),
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

  /// 已提交但还没开跑，此时按钮必须立刻反馈，否则点击会被静默吞掉。
  bool get _isPreparing => generationState.isPreparing;

  bool get _showCancelAction => showCancel || _isPreparing;

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
    // Krita 占用时启动器自身没有可取消的任务，只能转圈禁用等待。
    final isLoading = isGenerating && !_showCancelAction;
    final primaryButton = AnimatedTheme(
      data: _showCancelAction ? cancelTheme : theme,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: ThemedButton(
        onPressed: _showCancelAction
            ? onCancel
            : requiresLogin
            ? onGenerate
            : isGenerating || cooldownRemainingSeconds > 0
            ? null
            : onGenerate,
        isLoading: isLoading,
        label: IndexedStack(
          index: _showCancelAction ? 1 : 0,
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
                if (_isPreparing)
                  const GenerateButtonSpinner()
                else
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
