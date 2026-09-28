import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/models/queue/replication_task_generation_snapshot.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/mobile_shell_overlay_provider.dart';
import '../../providers/prompt_maximize_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../utils/asset_protection_guard.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/owned_scroll_controller.dart';
import 'widgets/history_panel.dart';
import 'widgets/image_preview.dart';

class MobileGenerationController extends ChangeNotifier
    with WidgetsBindingObserver {
  MobileGenerationController(this.ref)
    : shellOverlayNotifier = ref.read(
        mobileShellOverlayNotifierProvider.notifier,
      ) {
    WidgetsBinding.instance.addObserver(this);
    // 手机上参数面板在抽屉里，点「放大 / 增强」后屏幕上不会出现任何东西，
    // 看起来就是按钮坏了（上游至今如此：image_workflow_launcher 只调
    // setPanelExpanded，那在桌面常驻面板上才看得见）。image_preview 那边
    // 只留注册点、不写死侧别，因为左右抽屉的分工被我们换过（左=快捷工具、
    // 右=参数面板），写死会在分工再变时静默失效。
    // 存成字段是为了 dispose 时 identical 比对得上。
    _revealWorkflowPanel = openParameterDrawer;
    MobileWorkflowPanelReveal.register(_revealWorkflowPanel);
    final storage = ref.read(localStorageServiceProvider);
    showGestureHint =
        !(storage.getSetting<bool>(
              StorageKeys.mobileGenerationGestureHintCompleted,
              defaultValue: false,
            ) ??
            false);
    if (showGestureHint) {
      gestureHintTimer = Timer(gestureHintDuration, () {
        if (_disposed) return;
        showGestureHint = false;
        notifyListeners();
      });
    }
  }

  static const double verticalShortcutDistance = 88;
  static const double verticalShortcutVelocity = 900;
  static const double verticalShortcutMinimumFlingDistance = 24;
  static const double verticalAxisAdvantage = 1.35;
  static const double maximumDragFeedbackOffset = 44;
  static const Duration gestureHintDuration = Duration(milliseconds: 4500);

  final WidgetRef ref;
  final MobileShellOverlayNotifier shellOverlayNotifier;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  late final VoidCallback _revealWorkflowPanel;
  final GlobalKey embeddedPromptKey = GlobalKey();
  final FocusScopeNode agentFocusScope = FocusScopeNode(
    debugLabel: 'Mobile agent chat',
  );

  bool agentFullScreen = false;
  bool agentHasOpened = false;
  bool showGestureHint = false;
  bool keyboardVisible = false;
  bool workspacePointerActive = false;
  bool workspaceChildScrolled = false;
  bool workspaceThresholdHapticSent = false;
  int? workspacePointer;
  Offset? workspacePointerStart;
  VelocityTracker? workspaceVelocityTracker;
  double workspaceDragFeedback = 0;
  Timer? gestureHintTimer;
  bool _disposed = false;

  @override
  void didChangeMetrics() {
    if (!_disposed) notifyListeners();
  }

  void updateKeyboardVisibility(bool visible) {
    keyboardVisible = visible;
  }

  void _setOverlay(MobileShellOverlay overlay, bool active) {
    shellOverlayNotifier.setActive(overlay, active);
  }

  void openPromptEditor() {
    FocusManager.instance.primaryFocus?.unfocus();
    _setOverlay(MobileShellOverlay.agentChat, false);
    _setOverlay(MobileShellOverlay.promptEditor, true);
    unawaited(
      ref.read(promptMaximizeNotifierProvider.notifier).setMaximized(true),
    );
  }

  void closePromptEditor() {
    FocusManager.instance.primaryFocus?.unfocus();
    _setOverlay(MobileShellOverlay.promptEditor, false);
    unawaited(
      ref.read(promptMaximizeNotifierProvider.notifier).setMaximized(false),
    );
  }

  void openAgentChat() {
    FocusManager.instance.primaryFocus?.unfocus();
    _setOverlay(MobileShellOverlay.promptEditor, false);
    _setOverlay(MobileShellOverlay.agentChat, true);
    agentHasOpened = true;
    agentFullScreen = true;
    notifyListeners();
  }

  void closeAgentChat() {
    FocusManager.instance.primaryFocus?.unfocus();
    _setOverlay(MobileShellOverlay.agentChat, false);
    agentFullScreen = false;
    notifyListeners();
  }

  void handleBack(bool isPromptMaximized) {
    if (agentFullScreen) {
      handleAgentBack();
    } else if (isPromptMaximized) {
      closePromptEditor();
    }
  }

  void handleAgentBack() {
    if (agentFocusScope.hasFocus && !agentFocusScope.hasPrimaryFocus) {
      agentFocusScope.unfocus();
      return;
    }
    closeAgentChat();
  }

  void openAgentSettings(BuildContext context) {
    closeAgentChat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !context.mounted) return;
      context.goNamed('settings', queryParameters: const {'section': 'agent'});
    });
  }

  /// 偏离上游：上游 v4.2.1 的槽位是 `drawer` = 参数面板 / `endDrawer` = 历史
  /// （mobile_generation_chrome.dart:239-240）。我们把左 `drawer` 让给快捷工具
  /// 抽屉（固定词 / 角色开关），参数面板因此挪到右 `endDrawer`，历史降级成
  /// [openHistoryPanel]。三块面板放不进同一组 slot，这是有意的取舍。
  void openQuickToolsDrawer() {
    // 先收键盘再开抽屉：抽屉盖在提示词输入框上时软键盘不会自己退，
    // 抽屉会被顶掉半屏。
    FocusManager.instance.primaryFocus?.unfocus();
    scaffoldKey.currentState?.openDrawer();
  }

  void openParameterDrawer() {
    FocusManager.instance.primaryFocus?.unfocus();
    scaffoldKey.currentState?.openEndDrawer();
  }

  /// 历史记录：上游放在 `endDrawer`，我们改成顶栏按钮弹底部面板。
  ///
  /// 内容仍然是上游那个非嵌入模式的 [HistoryPanel]（自带 WorkspacePanelHeader
  /// 与折叠按钮），所以 `showPanel` 关掉自己的标题栏，避免出现两行标题。
  Future<void> openHistoryPanel(
    BuildContext context,
    OwnedViewportOffset viewport,
  ) {
    FocusManager.instance.primaryFocus?.unfocus();
    return AdaptivePresenter.showPanel<void>(
      context: context,
      showHeader: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (panelContext, _) => HistoryPanel(
        key: const ValueKey('generation-history-panel'),
        onClose: () => Navigator.of(panelContext).pop(),
        viewportOffset: viewport,
      ),
    );
  }

  void closeParameterDrawer() => scaffoldKey.currentState?.closeEndDrawer();

  bool _pointIsInside(GlobalKey key, Offset globalPosition) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final bounds = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return bounds.contains(globalPosition);
  }

  bool _canStartWorkspaceShortcut(
    BuildContext context,
    PointerDownEvent event,
  ) {
    final scaffold = scaffoldKey.currentState;
    return !keyboardVisible &&
        !agentFullScreen &&
        !ref.read(promptMaximizeNotifierProvider) &&
        ref.read(mobileShellOverlayNotifierProvider).isEmpty &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        scaffold?.isDrawerOpen != true &&
        scaffold?.isEndDrawerOpen != true &&
        !_pointIsInside(embeddedPromptKey, event.position);
  }

  void handleWorkspacePointerDown(
    BuildContext context,
    PointerDownEvent event,
  ) {
    if (workspacePointer != null) {
      cancelWorkspacePointerFeedback();
      return;
    }
    if (!_canStartWorkspaceShortcut(context, event)) return;
    workspacePointer = event.pointer;
    workspacePointerStart = event.position;
    workspaceVelocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    workspaceChildScrolled = false;
    workspaceThresholdHapticSent = false;
    workspacePointerActive = true;
    notifyListeners();
  }

  void handleWorkspacePointerMove(PointerMoveEvent event) {
    if (!workspacePointerActive || event.pointer != workspacePointer) return;
    workspaceVelocityTracker?.addPosition(event.timeStamp, event.position);
    final delta = event.position - workspacePointerStart!;
    final vertical = delta.dy.abs();
    final hasVerticalAdvantage =
        vertical >= delta.dx.abs() * verticalAxisAdvantage;
    final nextFeedback = !workspaceChildScrolled && hasVerticalAdvantage
        ? (delta.dy / 3).clamp(
            -maximumDragFeedbackOffset,
            maximumDragFeedbackOffset,
          )
        : 0.0;
    final reachedThreshold =
        !workspaceChildScrolled &&
        hasVerticalAdvantage &&
        vertical >= verticalShortcutDistance;
    if (reachedThreshold && !workspaceThresholdHapticSent) {
      workspaceThresholdHapticSent = true;
      unawaited(HapticFeedback.lightImpact());
    }
    if (nextFeedback != workspaceDragFeedback) {
      workspaceDragFeedback = nextFeedback;
      notifyListeners();
    }
  }

  void handleWorkspacePointerUp(PointerUpEvent event) {
    if (!workspacePointerActive || event.pointer != workspacePointer) return;
    workspaceVelocityTracker?.addPosition(event.timeStamp, event.position);
    final delta = event.position - workspacePointerStart!;
    final velocity =
        workspaceVelocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    final hasVerticalAdvantage =
        delta.dy.abs() >= delta.dx.abs() * verticalAxisAdvantage;
    final distanceCommitted = delta.dy.abs() >= verticalShortcutDistance;
    final flingCommitted =
        delta.dy.abs() >= verticalShortcutMinimumFlingDistance &&
        velocity.abs() >= verticalShortcutVelocity &&
        velocity.sign == delta.dy.sign;
    final committed =
        !workspaceChildScrolled &&
        hasVerticalAdvantage &&
        (distanceCommitted || flingCommitted);
    if (committed && !workspaceThresholdHapticSent) {
      workspaceThresholdHapticSent = true;
      unawaited(HapticFeedback.lightImpact());
    }
    _resetWorkspacePointer();
    if (!committed) return;
    completeGestureHint();
    if (delta.dy.isNegative) {
      openAgentChat();
    } else {
      openPromptEditor();
    }
  }

  void handleWorkspacePointerCancel(PointerCancelEvent event) {
    if (event.pointer == workspacePointer) cancelWorkspacePointerFeedback();
  }

  void cancelWorkspacePointerFeedback() => _resetWorkspacePointer();

  void _resetWorkspacePointer() {
    workspacePointer = null;
    workspacePointerStart = null;
    workspaceVelocityTracker = null;
    workspacePointerActive = false;
    workspaceChildScrolled = false;
    workspaceThresholdHapticSent = false;
    workspaceDragFeedback = 0;
    if (!_disposed) notifyListeners();
  }

  bool handleWorkspaceScrollNotification(ScrollNotification notification) {
    if (workspacePointerActive &&
        (notification is ScrollStartNotification ||
            notification is ScrollUpdateNotification ||
            notification is OverscrollNotification)) {
      workspaceChildScrolled = true;
      workspaceDragFeedback = 0;
      notifyListeners();
    }
    return false;
  }

  void completeGestureHint() {
    gestureHintTimer?.cancel();
    if (showGestureHint) {
      showGestureHint = false;
      notifyListeners();
    }
    unawaited(
      ref
          .read(localStorageServiceProvider)
          .setSetting(StorageKeys.mobileGenerationGestureHintCompleted, true),
    );
  }

  Future<void> generate(BuildContext context) async {
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
    if (ref.read(promptMaximizeNotifierProvider)) {
      closePromptEditor();
      await Future<void>.delayed(Duration.zero);
      if (_disposed || !context.mounted) return;
    }
    final confirmed = await AssetProtectionGuard.confirmHighAnlasCost(
      context: context,
      ref: ref,
    );
    if (!confirmed || _disposed || !context.mounted) return;
    ref.read(imageGenerationNotifierProvider.notifier).generate(params);
  }

  void cancelGeneration() =>
      ref.read(imageGenerationNotifierProvider.notifier).cancel();

  void skipCurrentRequest() =>
      ref.read(imageGenerationNotifierProvider.notifier).skipCurrentRequest();

  Future<void> addCurrentPromptToQueue(BuildContext context) async {
    final params = ref.read(generationParamsNotifierProvider);
    if (params.prompt.isEmpty) {
      AppToast.info(context, context.l10n.generation_pleaseInputPrompt);
      return;
    }
    final queuedParams = params.copyWith(nSamples: 1);
    final task = ReplicationTask.create(
      prompt: params.prompt,
      negativePrompt: params.negativePrompt,
      applyNegativePrompt: true,
      characterPrompts: params.characters
          .map(
            (character) => ReplicationCharacterPromptSnapshot(
              prompt: character.prompt,
              negativePrompt: character.negativePrompt,
              positionX: params.useCoords ? character.positionX : null,
              positionY: params.useCoords ? character.positionY : null,
            ),
          )
          .toList(growable: false),
      generationSnapshot: ReplicationTaskGenerationSnapshot.encode(
        queuedParams,
        batchSize: ref.read(imagesPerRequestProvider),
      ),
      source: ReplicationTaskSource.local,
      seed: params.seed,
      sampler: params.sampler,
      steps: params.steps,
      cfgScale: params.scale,
      model: params.model,
      width: params.width,
      height: params.height,
    );
    final added = await ref
        .read(replicationQueueNotifierProvider.notifier)
        .add(task);
    if (_disposed || !context.mounted) return;
    if (!added) {
      AppToast.warning(context, context.l10n.onlineGallery_queueFullMax);
      return;
    }
    AppToast.success(context, context.l10n.queue_taskAdded);
  }

  @override
  void dispose() {
    MobileWorkflowPanelReveal.unregister(_revealWorkflowPanel);
    agentFocusScope.dispose();
    _disposed = true;
    gestureHintTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    shellOverlayNotifier.clearGenerationOverlays();
    super.dispose();
  }
}
