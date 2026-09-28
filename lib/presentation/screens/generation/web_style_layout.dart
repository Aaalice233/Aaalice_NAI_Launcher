import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/windowing/workspace_side_panel_contract.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/generation/preview_selection_provider.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/layout_state_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../router/app_routes.dart';
import '../../services/image_workflow_launcher.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/owned_scroll_controller.dart';
import '../../widgets/shortcuts/shortcut_aware_widget.dart';
import 'handlers/generation_action_handlers.dart';
import 'widgets/fixed_tags_sidebar_slot.dart';
import 'widgets/generation_workspace_row.dart';
import 'widgets/image_preview.dart';
import 'widgets/prompt_input_controller.dart';
import 'widgets/resize_handle.dart';
import 'widgets/right_panel.dart';
import 'widgets/web_left_panel.dart';

/// 官网式布局：提示词与设置固定在最左栏，中间为纯预览区
class WebStyleGenerationLayout extends ConsumerStatefulWidget {
  const WebStyleGenerationLayout({
    super.key,
    required this.historyViewport,
    required this.negativeModeNotifier,
    required this.promptInputController,
    required this.promptInputKey,
  });

  final OwnedViewportOffset historyViewport;
  final ValueNotifier<bool> negativeModeNotifier;
  final PromptInputController promptInputController;
  final GlobalKey promptInputKey;

  @override
  ConsumerState<WebStyleGenerationLayout> createState() =>
      _WebStyleGenerationLayoutState();
}

class _WebStyleGenerationLayoutState
    extends ConsumerState<WebStyleGenerationLayout> {
  static const double _leftPanelMinWidth = 320;
  static const double _leftPanelMaxWidth = 560;
  static const double _rightPanelMinWidth = 200;

  bool _isResizingLeft = false;
  bool _isResizingRight = false;

  @override
  Widget build(BuildContext context) {
    final layoutState = ref.watch(layoutStateNotifierProvider);
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final cooldownState = ref.watch(generationCooldownProvider);
    final isKritaGenerating =
        PlatformCapabilities.current.supportsKritaBridge &&
        ref.watch(kritaBridgeNotifierProvider).isBridgeGenerating;
    final isLauncherGenerating = generationState.isGenerating;
    // 提交后到开跑之间同样不能再次触发，否则快捷键会被静默吞掉。
    final isBusy = generationState.isBusy || isKritaGenerating;

    final shortcuts = <String, VoidCallback>{
      ShortcutIds.generateImage: () {
        if (!isBusy && !cooldownState.isActive) {
          unawaited(generateWithProtection(context, ref));
        }
      },
      ShortcutIds.cancelGeneration: () {
        if (isLauncherGenerating) {
          ref.read(imageGenerationNotifierProvider.notifier).cancel();
        } else if (ref.read(generationPreviewSelectionProvider) != null) {
          ref.read(generationPreviewSelectionProvider.notifier).clear();
        }
      },
      ShortcutIds.addToQueue: () {
        final currentParams = ref.read(generationParamsNotifierProvider);
        if (currentParams.prompt.isNotEmpty) {
          final task = ReplicationTask.create(prompt: currentParams.prompt);
          ref.read(replicationQueueNotifierProvider.notifier).add(task);
          AppToast.success(context, context.l10n.queue_taskAdded);
        }
      },
      ShortcutIds.randomPrompt: () {
        if (ref.read(randomPromptToolsVisibilityProvider)) {
          ref.read(randomPromptModeProvider.notifier).toggle();
        } else {
          AppToast.info(context, context.l10n.randomPromptToolsHiddenHint);
        }
      },
      ShortcutIds.clearPrompt: () {
        ref.read(generationParamsNotifierProvider.notifier).updatePrompt('');
        ref
            .read(generationParamsNotifierProvider.notifier)
            .updateNegativePrompt('');
        ref.read(characterPromptNotifierProvider.notifier).clearAll();
      },
      // 官网式布局没有全屏编辑，该快捷键改为切换正/负输入
      ShortcutIds.togglePromptMode: () {
        widget.negativeModeNotifier.value = !widget.negativeModeNotifier.value;
      },
      ShortcutIds.openTagLibrary: () {
        context.go(AppRoutes.tagLibraryPage);
      },
      ShortcutIds.upscaleImage: () {
        if (generationState.displayImages.isNotEmpty) {
          ImageWorkflowLauncher.openUpscale(
            ref,
            generationState.displayImages.first.bytes,
          );
          AppToast.info(context, context.l10n.img2img_upscalePanelOpened);
        }
      },
    };

    final leftWidth = layoutState.webLeftPanelExpanded
        ? layoutState.webLeftPanelWidth
        : 40.0;
    final fixedTagsWidth = layoutState.fixedTagsSidebarExpanded
        ? layoutState.fixedTagsSidebarWidth + ResizeHandle.defaultWidth
        : 0.0;
    final occupiedLeadingWidth =
        leftWidth +
        (layoutState.webLeftPanelExpanded ? ResizeHandle.defaultWidth : 0.0);

    return ShortcutAwareWidget(
      contextType: ShortcutContext.generation,
      shortcuts: shortcuts,
      autofocus: true,
      child: GenerationWorkspaceRow(
        occupiedLeadingWidth: occupiedLeadingWidth,
        overlayableLeading: const FixedTagsSidebarSlot(),
        overlayableLeadingWidth: fixedTagsWidth,
        leading: [
          WebLeftPanel(
            negativeModeNotifier: widget.negativeModeNotifier,
            promptInputController: widget.promptInputController,
            promptInputKey: widget.promptInputKey,
            isResizing: _isResizingLeft,
          ),
          if (layoutState.webLeftPanelExpanded)
            ResizeHandle(
              onDragStart: () => setState(() => _isResizingLeft = true),
              onDragEnd: () => setState(() => _isResizingLeft = false),
              onDrag: (dx) {
                final currentWidth = ref
                    .read(layoutStateNotifierProvider)
                    .webLeftPanelWidth;
                final newWidth = (currentWidth + dx).clamp(
                  _leftPanelMinWidth,
                  _leftPanelMaxWidth,
                );
                ref
                    .read(layoutStateNotifierProvider.notifier)
                    .setWebLeftPanelWidth(newWidth.toDouble());
              },
            ),
        ],
        main: const ImagePreviewWidget(),
        rightPanelExpanded: layoutState.rightPanelExpanded,
        preferredRightPanelWidth: layoutState.rightPanelWidth,
        rightHandle: ResizeHandle(
          onDragStart: () => setState(() => _isResizingRight = true),
          onDragEnd: () => setState(() => _isResizingRight = false),
          onDrag: (dx) {
            final currentWidth = ref
                .read(layoutStateNotifierProvider)
                .rightPanelWidth;
            final newWidth = (currentWidth - dx).clamp(
              _rightPanelMinWidth,
              WorkspaceSidePanelContract.maximumWidth,
            );
            ref
                .read(layoutStateNotifierProvider.notifier)
                .setRightPanelWidth(newWidth);
          },
        ),
        rightPanelBuilder: (width, expanded) => RightPanel(
          isResizing: _isResizingRight,
          width: width,
          expanded: expanded,
          historyViewport: widget.historyViewport,
        ),
      ),
    );
  }
}
