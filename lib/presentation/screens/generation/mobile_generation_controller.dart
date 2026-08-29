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
import '../../providers/auth_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/mobile_shell_overlay_provider.dart';
import '../../providers/prompt_maximize_provider.dart';
import '../../utils/asset_protection_guard.dart';
import '../../widgets/common/app_toast.dart';

class MobileGenerationController extends ChangeNotifier
    with WidgetsBindingObserver {
  MobileGenerationController(this.ref)
    : shellOverlayNotifier = ref.read(
        mobileShellOverlayNotifierProvider.notifier,
      ) {
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      unawaited(
        ref.read(promptMaximizeNotifierProvider.notifier).setMaximized(false),
      );
    });
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
  final GlobalKey embeddedPromptKey = GlobalKey();

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
      closeAgentChat();
    } else if (isPromptMaximized) {
      closePromptEditor();
    }
  }

  void openAgentSettings(BuildContext context) {
    closeAgentChat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !context.mounted) return;
      context.goNamed('settings', queryParameters: const {'section': 'agent'});
    });
  }

  void openParameterDrawer() {
    FocusManager.instance.primaryFocus?.unfocus();
    scaffoldKey.currentState?.openDrawer();
  }

  void openHistoryDrawer() {
    FocusManager.instance.primaryFocus?.unfocus();
    scaffoldKey.currentState?.openEndDrawer();
  }

  void closeParameterDrawer() => scaffoldKey.currentState?.closeDrawer();
  void closeHistoryDrawer() => scaffoldKey.currentState?.closeEndDrawer();

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

  @override
  void dispose() {
    _disposed = true;
    gestureHintTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    shellOverlayNotifier.clearGenerationOverlays();
    super.dispose();
  }
}
