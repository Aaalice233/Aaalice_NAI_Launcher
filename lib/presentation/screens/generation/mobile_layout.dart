import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/localization_extension.dart';
import '../../agent_chat/widgets/agent_chat_panel.dart';
import '../../providers/auth_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/generation/image_workflow_controller.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/mobile_shell_overlay_provider.dart';
import '../../providers/prompt_maximize_provider.dart';
import '../../providers/quality_preset_provider.dart';
import '../../providers/uc_preset_provider.dart';
import '../../themes/design_tokens.dart';
import '../../themes/theme_extension.dart';
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
  static const double _verticalShortcutDistance = 88;
  static const double _verticalShortcutVelocity = 900;
  static const double _verticalShortcutMinimumFlingDistance = 24;
  static const double _verticalAxisAdvantage = 1.35;
  static const double _maximumDragFeedbackOffset = 44;
  static const Duration _gestureHintDuration = Duration(milliseconds: 4500);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _embeddedPromptKey = GlobalKey();
  bool _agentFullScreen = false;
  bool _agentHasOpened = false;
  bool _showGestureHint = false;
  bool _workspacePointerActive = false;
  bool _workspaceChildScrolled = false;
  bool _workspaceThresholdHapticSent = false;
  bool _keyboardVisible = false;
  int? _workspacePointer;
  Offset? _workspacePointerStart;
  VelocityTracker? _workspaceVelocityTracker;
  double _workspaceDragFeedback = 0;
  Timer? _gestureHintTimer;
  late final MobileShellOverlayNotifier _shellOverlayNotifier;

  @override
  void initState() {
    super.initState();
    _shellOverlayNotifier = ref.read(
      mobileShellOverlayNotifierProvider.notifier,
    );
    WidgetsBinding.instance.addObserver(this);
    final storage = ref.read(localStorageServiceProvider);
    _showGestureHint =
        !(storage.getSetting<bool>(
              StorageKeys.mobileGenerationGestureHintCompleted,
              defaultValue: false,
            ) ??
            false);
    if (_showGestureHint) {
      _gestureHintTimer = Timer(_gestureHintDuration, () {
        if (mounted) setState(() => _showGestureHint = false);
      });
    }
    // Phone generation always opens in the image-first collapsed state. The
    // previous desktop-style persisted maximize flag must not summon the
    // keyboard or hide the preview during a later mobile launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(promptMaximizeNotifierProvider.notifier).setMaximized(false),
      );
    });
  }

  @override
  void didChangeMetrics() {
    // 外层导航 Scaffold 会移除后代 MediaQuery 的键盘 inset；监听原始
    // FlutterView 指标，确保嵌套生成工作台仍会随 IME 显隐重建。
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _gestureHintTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _shellOverlayNotifier.clearGenerationOverlays();
    super.dispose();
  }

  void _setShellOverlay(MobileShellOverlay overlay, bool active) {
    _shellOverlayNotifier.setActive(overlay, active);
  }

  void _openPromptEditor() {
    FocusManager.instance.primaryFocus?.unfocus();
    _setShellOverlay(MobileShellOverlay.promptEditor, true);
    unawaited(
      ref.read(promptMaximizeNotifierProvider.notifier).setMaximized(true),
    );
  }

  void _closePromptEditor() {
    FocusManager.instance.primaryFocus?.unfocus();
    _setShellOverlay(MobileShellOverlay.promptEditor, false);
    unawaited(
      ref.read(promptMaximizeNotifierProvider.notifier).setMaximized(false),
    );
  }

  void _openAgentChat() {
    FocusManager.instance.primaryFocus?.unfocus();
    _setShellOverlay(MobileShellOverlay.agentChat, true);
    setState(() {
      _agentHasOpened = true;
      _agentFullScreen = true;
    });
  }

  void _closeAgentChat() {
    FocusManager.instance.primaryFocus?.unfocus();
    _setShellOverlay(MobileShellOverlay.agentChat, false);
    setState(() => _agentFullScreen = false);
  }

  void _openAgentSettings() {
    _closeAgentChat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.goNamed(
        'settings',
        queryParameters: const {'section': 'integrations'},
      );
    });
  }

  void _openParameterDrawer() {
    FocusManager.instance.primaryFocus?.unfocus();
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openHistoryDrawer() {
    FocusManager.instance.primaryFocus?.unfocus();
    _scaffoldKey.currentState?.openEndDrawer();
  }

  bool _pointIsInside(GlobalKey key, Offset globalPosition) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final bounds = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return bounds.contains(globalPosition);
  }

  bool _canStartWorkspaceShortcut(PointerDownEvent event) {
    final scaffold = _scaffoldKey.currentState;
    return !_keyboardVisible &&
        !_agentFullScreen &&
        !ref.read(promptMaximizeNotifierProvider) &&
        ref.read(mobileShellOverlayNotifierProvider).isEmpty &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        scaffold?.isDrawerOpen != true &&
        scaffold?.isEndDrawerOpen != true &&
        !_pointIsInside(_embeddedPromptKey, event.position);
  }

  void _handleWorkspacePointerDown(PointerDownEvent event) {
    if (_workspacePointer != null) {
      _cancelWorkspacePointerFeedback();
      return;
    }
    if (!_canStartWorkspaceShortcut(event)) return;
    _workspacePointer = event.pointer;
    _workspacePointerStart = event.position;
    _workspaceVelocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _workspaceChildScrolled = false;
    _workspaceThresholdHapticSent = false;
    _workspacePointerActive = true;
  }

  void _handleWorkspacePointerMove(PointerMoveEvent event) {
    if (!_workspacePointerActive || event.pointer != _workspacePointer) return;
    _workspaceVelocityTracker?.addPosition(event.timeStamp, event.position);
    final delta = event.position - _workspacePointerStart!;
    final vertical = delta.dy.abs();
    final hasVerticalAdvantage =
        vertical >= delta.dx.abs() * _verticalAxisAdvantage;
    final nextFeedback = !_workspaceChildScrolled && hasVerticalAdvantage
        ? (delta.dy / 3).clamp(
            -_maximumDragFeedbackOffset,
            _maximumDragFeedbackOffset,
          )
        : 0.0;
    final reachedThreshold =
        !_workspaceChildScrolled &&
        hasVerticalAdvantage &&
        vertical >= _verticalShortcutDistance;
    if (reachedThreshold && !_workspaceThresholdHapticSent) {
      _workspaceThresholdHapticSent = true;
      unawaited(HapticFeedback.lightImpact());
    }
    if (nextFeedback != _workspaceDragFeedback && mounted) {
      setState(() => _workspaceDragFeedback = nextFeedback);
    }
  }

  void _handleWorkspacePointerUp(PointerUpEvent event) {
    if (!_workspacePointerActive || event.pointer != _workspacePointer) return;
    _workspaceVelocityTracker?.addPosition(event.timeStamp, event.position);
    final start = _workspacePointerStart!;
    final delta = event.position - start;
    final velocity =
        _workspaceVelocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    final hasVerticalAdvantage =
        delta.dy.abs() >= delta.dx.abs() * _verticalAxisAdvantage;
    final distanceCommitted = delta.dy.abs() >= _verticalShortcutDistance;
    final flingCommitted =
        delta.dy.abs() >= _verticalShortcutMinimumFlingDistance &&
        velocity.abs() >= _verticalShortcutVelocity &&
        velocity.sign == delta.dy.sign;
    final committed =
        !_workspaceChildScrolled &&
        hasVerticalAdvantage &&
        (distanceCommitted || flingCommitted);
    if (committed && !_workspaceThresholdHapticSent) {
      _workspaceThresholdHapticSent = true;
      unawaited(HapticFeedback.lightImpact());
    }
    _resetWorkspacePointer();
    if (!committed) return;
    _completeGestureHint();
    if (delta.dy.isNegative) {
      _openAgentChat();
    } else {
      _openPromptEditor();
    }
  }

  void _handleWorkspacePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _workspacePointer) _cancelWorkspacePointerFeedback();
  }

  void _cancelWorkspacePointerFeedback() {
    _resetWorkspacePointer();
  }

  void _resetWorkspacePointer() {
    _workspacePointer = null;
    _workspacePointerStart = null;
    _workspaceVelocityTracker = null;
    _workspacePointerActive = false;
    _workspaceChildScrolled = false;
    _workspaceThresholdHapticSent = false;
    if (_workspaceDragFeedback != 0 && mounted) {
      setState(() => _workspaceDragFeedback = 0);
    }
  }

  bool _handleWorkspaceScrollNotification(ScrollNotification notification) {
    if (_workspacePointerActive &&
        (notification is ScrollStartNotification ||
            notification is ScrollUpdateNotification ||
            notification is OverscrollNotification)) {
      _workspaceChildScrolled = true;
      if (_workspaceDragFeedback != 0) {
        setState(() => _workspaceDragFeedback = 0);
      }
    }
    return false;
  }

  void _completeGestureHint() {
    _gestureHintTimer?.cancel();
    if (_showGestureHint && mounted) setState(() => _showGestureHint = false);
    unawaited(
      ref
          .read(localStorageServiceProvider)
          .setSetting(StorageKeys.mobileGenerationGestureHintCompleted, true),
    );
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
    _keyboardVisible = keyboardVisible;
    final isLauncherGenerating = generationState.isGenerating;
    final isGenerating = isLauncherGenerating || isKritaGenerating;
    final requiresLogin = !isAuthenticated && !isGenerating;
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);
    final isUpscaleMode = ref.watch(
      imageWorkflowControllerProvider.select((workflow) => workflow.isUpscale),
    );
    final randomModeEnabled = ref.watch(randomPromptModeProvider);
    final promptSummary = ref.watch(
      generationParamsNotifierProvider.select((params) => params.prompt.trim()),
    );
    final enabledCharacterCount = ref.watch(
      characterPromptNotifierProvider.select(
        (config) =>
            config.characters.where((character) => character.enabled).length,
      ),
    );
    final qualityEnabled = ref.watch(
      qualityPresetNotifierProvider.select((state) => state.isEnabled),
    );
    final ucPresetState = ref.watch(ucPresetNotifierProvider);
    final fixedTagCount = ref.watch(
      fixedTagsNotifierProvider.select(
        (state) => state.enabledCount + state.negativeEnabledCount,
      ),
    );
    final negativePresetLabel = ucPresetState.isCustom
        ? context.l10n.ucPreset_label
        : switch (ucPresetState.presetType) {
            UcPresetType.heavy => context.l10n.ucPreset_heavy,
            UcPresetType.light => context.l10n.ucPreset_light,
            UcPresetType.furryFocus => context.l10n.ucPreset_furryFocus,
            UcPresetType.humanFocus => context.l10n.ucPreset_humanFocus,
            UcPresetType.none => null,
          };

    return PopScope<void>(
      canPop: !isPromptMaximized && !_agentFullScreen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_agentFullScreen) {
          _closeAgentChat();
        } else if (isPromptMaximized) {
          _closePromptEditor();
        }
      },
      child: ThemedScaffold(
        scaffoldKey: _scaffoldKey,
        drawer: isPromptMaximized || _agentFullScreen
            ? null
            : _buildParameterDrawer(context),
        endDrawer: isPromptMaximized || _agentFullScreen
            ? null
            : _buildHistoryDrawer(context),
        appBar: _agentFullScreen
            ? null
            : AppBar(
                automaticallyImplyLeading: false,
                leading: isPromptMaximized
                    ? IconButton(
                        key: const ValueKey('generation-prompt-editor-close'),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: context.l10n.toolbar_fullscreenEdit,
                        onPressed: _closePromptEditor,
                      )
                    : null,
                title: isPromptMaximized
                    ? _VerticalCloseGesture(
                        key: const ValueKey(
                          'generation-prompt-editor-drag-handle',
                        ),
                        closeDirection: AxisDirection.up,
                        onClose: _closePromptEditor,
                        child: _FullscreenHeaderTitle(
                          label: context.l10n.promptToken_prompt,
                        ),
                      )
                    : Text(context.l10n.generation_title),
                actions: isPromptMaximized
                    ? null
                    : [
                        IconButton(
                          key: const ValueKey(
                            'generation-parameters-drawer-action',
                          ),
                          icon: const Icon(Icons.tune_rounded),
                          onPressed: _openParameterDrawer,
                          tooltip: context.l10n.generation_paramsSettings,
                        ),
                        IconButton(
                          key: const ValueKey('generation-agent-drawer-action'),
                          icon: const Icon(Icons.smart_toy_outlined),
                          onPressed: _openAgentChat,
                          tooltip: context.l10n.agentChat_tab,
                        ),
                        IconButton(
                          key: const ValueKey(
                            'generation-history-drawer-action',
                          ),
                          icon: const Icon(Icons.history_rounded),
                          onPressed: _openHistoryDrawer,
                          tooltip: context.l10n.generation_history,
                        ),
                      ],
              ),
        body: Stack(
          key: const ValueKey('generation-mobile-primary-workspaces'),
          children: [
            _WorkspaceMotion(
              active: !_agentFullScreen,
              hiddenOffset: const Offset(0, -0.08),
              child: TickerMode(
                enabled: !_agentFullScreen,
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : theme.appTheme.normalDuration,
                  switchInCurve: theme.appTheme.enterCurve,
                  switchOutCurve: theme.appTheme.exitCurve,
                  transitionBuilder: (child, animation) {
                    final enteringPrompt =
                        child.key == const ValueKey('maximized-prompt');
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(0, enteringPrompt ? -0.08 : 0.08),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: isPromptMaximized
                      ? const Padding(
                          key: ValueKey('maximized-prompt'),
                          padding: EdgeInsets.all(12),
                          child: PromptInputWidget(
                            isMaximized: true,
                            showMaximizeButton: false,
                            autofocus: true,
                          ),
                        )
                      : Listener(
                          key: const ValueKey('generation-vertical-shortcuts'),
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: _handleWorkspacePointerDown,
                          onPointerMove: _handleWorkspacePointerMove,
                          onPointerUp: _handleWorkspacePointerUp,
                          onPointerCancel: _handleWorkspacePointerCancel,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: _handleWorkspaceScrollNotification,
                            child: AnimatedContainer(
                              duration:
                                  _workspacePointerActive ||
                                      MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : theme.appTheme.normalDuration,
                              curve: theme.appTheme.standardCurve,
                              transform: Matrix4.translationValues(
                                0,
                                MediaQuery.disableAnimationsOf(context)
                                    ? 0
                                    : _workspaceDragFeedback,
                                0,
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  LayoutBuilder(
                                    key: const ValueKey('generation-workspace'),
                                    builder: (context, constraints) {
                                      final useHorizontalLayout =
                                          constraints.maxWidth >= 640 &&
                                          constraints.maxWidth >
                                              constraints.maxHeight * 1.15;
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
                                                  Expanded(
                                                    child: Padding(
                                                      key: _embeddedPromptKey,
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12,
                                                          ),
                                                      child:
                                                          const PromptInputWidget(
                                                            compact: true,
                                                          ),
                                                    ),
                                                  ),
                                                  if (generationState
                                                      .isGenerating)
                                                    _GenerationProgress(
                                                      progress: generationState
                                                          .progress,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }

                                      return Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              12,
                                              12,
                                              12,
                                              8,
                                            ),
                                            child: _CollapsedPromptLauncher(
                                              prompt: promptSummary,
                                              characterCount:
                                                  enabledCharacterCount,
                                              qualityEnabled: qualityEnabled,
                                              negativePresetLabel:
                                                  negativePresetLabel,
                                              fixedTagCount: fixedTagCount,
                                              onTap: _openPromptEditor,
                                            ),
                                          ),
                                          const Expanded(
                                            child: ImagePreviewWidget(),
                                          ),
                                          if (generationState.isGenerating)
                                            _GenerationProgress(
                                              progress:
                                                  generationState.progress,
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                  _GestureFeedbackOverlay(
                                    dragOffset: _workspaceDragFeedback,
                                    showHint: _showGestureHint,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            _WorkspaceMotion(
              active: _agentFullScreen,
              hiddenOffset: const Offset(0, 0.08),
              child: TickerMode(
                enabled: _agentFullScreen,
                child: _agentHasOpened
                    ? SafeArea(
                        key: const ValueKey('generation-agent-fullscreen'),
                        child: AgentChatPanel(
                          mobile: true,
                          fullScreen: true,
                          onClose: _closeAgentChat,
                          onOpenSettings: _openAgentSettings,
                          mobileHeaderWrapper: (child) => _VerticalCloseGesture(
                            key: const ValueKey(
                              'generation-agent-close-drag-handle',
                            ),
                            closeDirection: AxisDirection.down,
                            onClose: _closeAgentChat,
                            child: child,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: keyboardVisible || _agentFullScreen
            ? null
            : SafeArea(
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
                          if (showRandomTools) ...[
                            const Spacer(),
                            _MobileRandomModeToggle(
                              enabled: randomModeEnabled,
                              showLabel: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      _MobileGenerateButton(
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
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildParameterDrawer(BuildContext context) {
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
                    onPressed: () => _scaffoldKey.currentState?.closeDrawer(),
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

  Widget _buildHistoryDrawer(BuildContext context) {
    return Drawer(
      key: const ValueKey('generation-history-drawer'),
      width: MediaQuery.sizeOf(context).width * 0.9,
      child: SafeArea(
        child: HistoryPanel(
          onClose: () => _scaffoldKey.currentState?.closeEndDrawer(),
        ),
      ),
    );
  }

  Future<void> _handleGenerate(BuildContext context, WidgetRef ref) async {
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

    if (ref.read(promptMaximizeNotifierProvider)) {
      _closePromptEditor();
      await Future<void>.delayed(Duration.zero);
      if (!context.mounted) return;
    }

    if (!ref.read(authNotifierProvider).isAuthenticated) {
      await context.pushNamed('login');
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

class _WorkspaceMotion extends StatelessWidget {
  const _WorkspaceMotion({
    required this.active,
    required this.hiddenOffset,
    required this.child,
  });

  final bool active;
  final Offset hiddenOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final appTheme = Theme.of(context).appTheme;
    final duration = disableAnimations
        ? Duration.zero
        : appTheme.normalDuration;
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: AnimatedSlide(
          offset: active || disableAnimations ? Offset.zero : hiddenOffset,
          duration: duration,
          curve: appTheme.standardCurve,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: duration,
            curve: appTheme.standardCurve,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GestureFeedbackOverlay extends StatelessWidget {
  const _GestureFeedbackOverlay({
    required this.dragOffset,
    required this.showHint,
  });

  final double dragOffset;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final duration = disableAnimations ? Duration.zero : appTheme.fastDuration;
    final progress = (dragOffset.abs() / 44).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              key: const ValueKey('generation-prompt-gesture-feedback'),
              opacity: dragOffset > 0 ? progress : 0,
              duration: duration,
              curve: appTheme.standardCurve,
              child: _GestureLabel(
                icon: Icons.keyboard_arrow_down_rounded,
                label: context.l10n.generation_gestureEditPrompt,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedOpacity(
              key: const ValueKey('generation-agent-gesture-feedback'),
              opacity: dragOffset < 0 ? progress : 0,
              duration: duration,
              curve: appTheme.standardCurve,
              child: _GestureLabel(
                icon: Icons.keyboard_arrow_up_rounded,
                label: context.l10n.generation_gestureOpenAgent,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.72),
            child: AnimatedOpacity(
              key: const ValueKey('generation-gesture-hint'),
              opacity: showHint && dragOffset == 0 ? 1 : 0,
              duration: duration,
              curve: appTheme.standardCurve,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacingSm,
                  vertical: DesignTokens.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.76,
                  ),
                  borderRadius: BorderRadius.circular(appTheme.controlRadius),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: DesignTokens.spacingSm,
                  runSpacing: DesignTokens.spacingXxs,
                  children: [
                    Text(
                      context.l10n.generation_gestureEditPrompt,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                    Text(
                      context.l10n.generation_gestureOpenAgent,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GestureLabel extends StatelessWidget {
  const _GestureLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      minimum: const EdgeInsets.all(DesignTokens.spacingXs),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingSm,
          vertical: DesignTokens.spacingXs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(theme.appTheme.controlRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: DesignTokens.spacingXxs),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
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

class _VerticalCloseGesture extends StatefulWidget {
  const _VerticalCloseGesture({
    super.key,
    required this.closeDirection,
    required this.onClose,
    required this.child,
  });

  final AxisDirection closeDirection;
  final VoidCallback onClose;
  final Widget child;

  @override
  State<_VerticalCloseGesture> createState() => _VerticalCloseGestureState();
}

class _VerticalCloseGestureState extends State<_VerticalCloseGesture> {
  static const double _distance = 88;
  static const double _velocity = 900;
  static const double _minimumFlingDistance = 24;
  static const double _axisAdvantage = 1.35;

  Offset? _start;
  Offset? _lastPosition;
  bool _hapticSent = false;

  bool _isClosingDirection(double value) =>
      widget.closeDirection == AxisDirection.up ? value < 0 : value > 0;

  bool _isCommitted(Offset delta, double velocity) {
    final vertical = delta.dy.abs();
    final verticalWins = vertical >= delta.dx.abs() * _axisAdvantage;
    final distanceCommitted = vertical >= _distance;
    final flingCommitted =
        vertical >= _minimumFlingDistance &&
        velocity.abs() >= _velocity &&
        velocity.sign == delta.dy.sign;
    return verticalWins &&
        _isClosingDirection(delta.dy) &&
        (distanceCommitted || flingCommitted);
  }

  void _handleUpdate(DragUpdateDetails details) {
    final start = _start;
    _lastPosition = details.globalPosition;
    if (start == null || _hapticSent) return;
    final delta = details.globalPosition - start;
    if (_isCommitted(delta, 0)) {
      _hapticSent = true;
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _handleEnd(DragEndDetails details) {
    final start = _start;
    final lastPosition = _lastPosition;
    if (start == null || lastPosition == null) return;
    final delta = lastPosition - start;
    final committed = _isCommitted(delta, details.primaryVelocity ?? 0);
    if (committed && !_hapticSent) {
      _hapticSent = true;
      unawaited(HapticFeedback.lightImpact());
    }
    _start = null;
    _lastPosition = null;
    if (committed) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragStart: (details) {
        _start = details.globalPosition;
        _lastPosition = details.globalPosition;
        _hapticSent = false;
      },
      onVerticalDragUpdate: _handleUpdate,
      onVerticalDragEnd: _handleEnd,
      onVerticalDragCancel: () {
        _start = null;
        _lastPosition = null;
        _hapticSent = false;
      },
      child: widget.child,
    );
  }
}

class _CollapsedPromptLauncher extends StatelessWidget {
  const _CollapsedPromptLauncher({
    required this.prompt,
    required this.characterCount,
    required this.qualityEnabled,
    required this.negativePresetLabel,
    required this.fixedTagCount,
    required this.onTap,
  });

  final String prompt;
  final int characterCount;
  final bool qualityEnabled;
  final String? negativePresetLabel;
  final int fixedTagCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasPrompt = prompt.isNotEmpty;
    final statusItems = <Widget>[
      if (characterCount > 0)
        _PromptOverviewItem(
          icon: Icons.people_alt_rounded,
          label: '${context.l10n.character_buttonLabel} $characterCount',
          color: colors.primary,
        ),
      if (qualityEnabled)
        _PromptOverviewItem(
          icon: Icons.auto_awesome_rounded,
          label: context.l10n.qualityTags_label,
          color: const Color(0xFF67A87A),
        ),
      if (negativePresetLabel case final label?)
        _PromptOverviewItem(
          icon: Icons.shield_rounded,
          label: label,
          color: colors.error.withValues(alpha: 0.82),
        ),
      if (fixedTagCount > 0)
        _PromptOverviewItem(
          icon: Icons.push_pin_rounded,
          label: '${context.l10n.fixedTags_label} $fixedTagCount',
          color: colors.onSurfaceVariant,
        ),
    ];

    return Semantics(
      button: true,
      label: context.l10n.promptToken_prompt,
      child: Material(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('generation-collapsed-prompt-launcher'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 17,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              context.l10n.promptToken_prompt,
                              maxLines: 1,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hasPrompt
                                    ? prompt.replaceAll(RegExp(r'\s+'), ' ')
                                    : context.l10n.prompt_describeImage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant.withValues(
                                    alpha: hasPrompt ? 0.8 : 0.56,
                                  ),
                                ),
                              ),
                            ),
                            if (hasPrompt) ...[
                              const SizedBox(width: 8),
                              Text(
                                context.l10n
                                    .generation_promptOverviewCharacters(
                                      prompt.runes.length,
                                    ),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Icon(
                              Icons.open_in_full_rounded,
                              size: 15,
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.68,
                              ),
                            ),
                          ],
                        ),
                        if (statusItems.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          SizedBox(
                            height: 17,
                            child: SingleChildScrollView(
                              key: const ValueKey(
                                'generation-prompt-overview-statuses',
                              ),
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (
                                    var index = 0;
                                    index < statusItems.length;
                                    index++
                                  ) ...[
                                    if (index > 0) const SizedBox(width: 11),
                                    statusItems[index],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptOverviewItem extends StatelessWidget {
  const _PromptOverviewItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: style?.copyWith(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
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
  final bool showLabel;

  const _MobileRandomModeToggle({
    required this.enabled,
    this.showLabel = false,
  });

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
