import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/windowing/workspace_side_panel_contract.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../agent_chat/providers/agent_chat_dock_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/generation/preview_selection_provider.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/layout_state_provider.dart';
import '../../providers/prompt_maximize_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../router/app_routes.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/owned_scroll_controller.dart';
import '../../widgets/shortcuts/shortcut_aware_widget.dart';
import '../../services/image_workflow_launcher.dart';
import 'handlers/generation_action_handlers.dart';
import 'widgets/resize_handle.dart';
import 'widgets/left_panel.dart';
import 'widgets/fixed_tags_sidebar_slot.dart';
import 'widgets/generation_workspace_row.dart';
import 'widgets/main_workspace.dart';
import 'widgets/prompt_input_controller.dart';
import 'widgets/right_panel.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

/// 桌面端三栏布局
class DesktopGenerationLayout extends ConsumerStatefulWidget {
  const DesktopGenerationLayout({
    super.key,
    required this.historyViewport,
    required this.promptInputController,
    required this.promptInputKey,
  });

  final OwnedViewportOffset historyViewport;
  final PromptInputController promptInputController;
  final GlobalKey promptInputKey;

  @override
  ConsumerState<DesktopGenerationLayout> createState() =>
      _DesktopGenerationLayoutState();
}

class _DesktopGenerationLayoutState
    extends ConsumerState<DesktopGenerationLayout> {
  // 面板宽度常量
  static const double _leftPanelMinWidth = 250;
  static const double _leftPanelMaxWidth = 450;
  static const double _rightPanelMinWidth = 200;

  // 拖拽状态（拖拽时禁用动画以避免粘滞感）
  bool _isResizingLeft = false;
  bool _isResizingRight = false;

  // 回调只在触发时取当前状态，快捷键表因此可以建一次复用，不随生成帧重建。
  late final Map<String, VoidCallback> _shortcuts = _buildShortcuts();

  /// 切换提示词区域最大化状态
  void _togglePromptMaximize() {
    final newValue = !ref.read(promptMaximizeNotifierProvider);
    ref.read(promptMaximizeNotifierProvider.notifier).setMaximized(newValue);
    AppLogger.d('Prompt area maximize toggled', 'DesktopLayout');
  }

  bool get _isBusy {
    final isKritaGenerating =
        PlatformCapabilities.current.supportsKritaBridge &&
        ref.read(kritaBridgeNotifierProvider).isBridgeGenerating;
    // 提交后到开跑之间同样不能再次触发，否则快捷键会被静默吞掉。
    return ref.read(imageGenerationNotifierProvider).isBusy ||
        isKritaGenerating;
  }

  /// 定义快捷键动作映射（使用 ShortcutIds 常量）
  Map<String, VoidCallback> _buildShortcuts() => <String, VoidCallback>{
    // 生成图像
    ShortcutIds.generateImage: () {
      if (!_isBusy && !ref.read(generationCooldownProvider).isActive) {
        unawaited(generateWithProtection(context, ref));
      }
    },
    // 取消生成
    ShortcutIds.cancelGeneration: () {
      if (ref.read(imageGenerationNotifierProvider).isGenerating) {
        ref.read(imageGenerationNotifierProvider.notifier).cancel();
      } else if (ref.read(generationPreviewSelectionProvider) != null) {
        ref.read(generationPreviewSelectionProvider.notifier).clear();
      }
    },
    // 加入队列
    ShortcutIds.addToQueue: () {
      final currentParams = ref.read(generationParamsNotifierProvider);
      if (currentParams.prompt.isNotEmpty) {
        final task = ReplicationTask.create(prompt: currentParams.prompt);
        ref.read(replicationQueueNotifierProvider.notifier).add(task);
        AppToast.success(context, context.l10n.queue_taskAdded);
      }
    },
    // 随机提示词
    ShortcutIds.randomPrompt: () {
      if (ref.read(randomPromptToolsVisibilityProvider)) {
        ref.read(randomPromptModeProvider.notifier).toggle();
      } else {
        AppToast.info(context, context.l10n.randomPromptToolsHiddenHint);
      }
    },
    // 清空提示词
    ShortcutIds.clearPrompt: () {
      ref.read(generationParamsNotifierProvider.notifier).updatePrompt('');
      ref
          .read(generationParamsNotifierProvider.notifier)
          .updateNegativePrompt('');
      ref.read(characterPromptNotifierProvider.notifier).clearAll();
    },
    // 切换正/负面模式
    ShortcutIds.togglePromptMode: () {
      ref.read(promptMaximizeNotifierProvider.notifier).toggle();
    },
    // 打开词库
    ShortcutIds.openTagLibrary: () {
      context.go(AppRoutes.tagLibraryPage);
    },
    // 放大图像
    ShortcutIds.upscaleImage: () {
      final displayImages = ref
          .read(imageGenerationNotifierProvider)
          .displayImages;
      if (displayImages.isNotEmpty) {
        ImageWorkflowLauncher.openUpscale(ref, displayImages.first.bytes);
        AppToast.info(context, context.l10n.img2img_upscalePanelOpened);
      }
    },
    // 已移除 Space 全屏预览快捷键，避免在提示词输入时误触发预览
  };

  @override
  Widget build(BuildContext context) {
    // 从 Provider 读取布局状态
    final layoutState = ref.watch(layoutStateNotifierProvider);

    final leftWidth = layoutState.leftPanelExpanded
        ? layoutState.leftPanelWidth
        : 40.0;
    final fixedTagsWidth = layoutState.fixedTagsSidebarExpanded
        ? layoutState.fixedTagsSidebarWidth + ResizeHandle.defaultWidth
        : 0.0;
    final occupiedLeadingWidth =
        leftWidth +
        (layoutState.leftPanelExpanded ? ResizeHandle.defaultWidth : 0.0);
    final sideBySideChatWidth = ref.watch(
      agentChatDockProvider.select((dock) => dock.sideBySideChatWidthDemand),
    );

    return GenerationWorkspaceRow(
      occupiedLeadingWidth: occupiedLeadingWidth,
      overlayableLeading: const FixedTagsSidebarSlot(),
      overlayableLeadingWidth: fixedTagsWidth,
      leading: [
        LeftPanel(isResizing: _isResizingLeft),
        if (layoutState.leftPanelExpanded)
          ResizeHandle(
            onDragStart: () => setState(() => _isResizingLeft = true),
            onDragEnd: () => setState(() => _isResizingLeft = false),
            onDrag: (dx) {
              final currentWidth = ref
                  .read(layoutStateNotifierProvider)
                  .leftPanelWidth;
              final newWidth = (currentWidth + dx).clamp(
                _leftPanelMinWidth,
                _leftPanelMaxWidth,
              );
              ref
                  .read(layoutStateNotifierProvider.notifier)
                  .setLeftPanelWidth(newWidth);
            },
          ),
      ],
      main: ShortcutAwareWidget(
        contextType: ShortcutContext.generation,
        shortcuts: _shortcuts,
        autofocus: true,
        child: MainWorkspace(
          onToggleMaximize: _togglePromptMaximize,
          promptInputController: widget.promptInputController,
          promptInputKey: widget.promptInputKey,
        ),
      ),
      rightPanelExpanded: layoutState.rightPanelExpanded,
      preferredRightPanelWidth: layoutState.rightPanelWidth,
      sideBySideChatWidth: sideBySideChatWidth,
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
      rightPanelBuilder: (allocation) => RightPanel(
        isResizing: _isResizingRight,
        allocation: allocation,
        historyViewport: widget.historyViewport,
      ),
    );
  }
}
