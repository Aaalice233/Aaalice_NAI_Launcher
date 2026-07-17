import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/layout_state_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../router/app_router.dart';
import '../../services/image_workflow_launcher.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/shortcuts/shortcut_aware_widget.dart';
import 'handlers/generation_action_handlers.dart';
import 'widgets/fixed_tags_sidebar_slot.dart';
import 'widgets/image_preview.dart';
import 'widgets/resize_handle.dart';
import 'widgets/right_panel.dart';
import 'widgets/web_left_panel.dart';

/// 官网式布局：提示词与设置固定在最左栏，中间为纯预览区
class WebStyleGenerationLayout extends ConsumerStatefulWidget {
  const WebStyleGenerationLayout({super.key});

  @override
  ConsumerState<WebStyleGenerationLayout> createState() =>
      _WebStyleGenerationLayoutState();
}

class _WebStyleGenerationLayoutState
    extends ConsumerState<WebStyleGenerationLayout> {
  static const double _leftPanelMinWidth = 320;
  static const double _leftPanelMaxWidth = 560;
  static const double _rightPanelMinWidth = 200;
  static const double _rightPanelMaxWidth = 400;

  final _negativeModeNotifier = ValueNotifier<bool>(false);

  bool _isResizingLeft = false;
  bool _isResizingRight = false;

  @override
  void dispose() {
    _negativeModeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layoutState = ref.watch(layoutStateNotifierProvider);
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final kritaBridgeState = ref.watch(kritaBridgeNotifierProvider);
    final isLauncherGenerating = generationState.isGenerating;
    final isGenerating =
        isLauncherGenerating || kritaBridgeState.isBridgeGenerating;

    final shortcuts = <String, VoidCallback>{
      ShortcutIds.generateImage: () {
        if (!isGenerating) {
          unawaited(generateWithProtection(context, ref));
        }
      },
      ShortcutIds.cancelGeneration: () {
        if (isLauncherGenerating) {
          ref.read(imageGenerationNotifierProvider.notifier).cancel();
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
        _negativeModeNotifier.value = !_negativeModeNotifier.value;
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

    return ShortcutAwareWidget(
      contextType: ShortcutContext.generation,
      shortcuts: shortcuts,
      autofocus: true,
      child: Row(
        children: [
          // 最左栏 - 提示词与设置
          WebLeftPanel(
            negativeModeNotifier: _negativeModeNotifier,
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

          // 固定标签侧栏（两种布局共享的插槽组件）
          const FixedTagsSidebarSlot(),

          // 中间 - 纯图像预览
          const Expanded(
            child: ImagePreviewWidget(),
          ),

          if (layoutState.rightPanelExpanded)
            ResizeHandle(
              onDragStart: () => setState(() => _isResizingRight = true),
              onDragEnd: () => setState(() => _isResizingRight = false),
              onDrag: (dx) {
                final currentWidth = ref
                    .read(layoutStateNotifierProvider)
                    .rightPanelWidth;
                final newWidth = (currentWidth - dx).clamp(
                  _rightPanelMinWidth,
                  _rightPanelMaxWidth,
                );
                ref
                    .read(layoutStateNotifierProvider.notifier)
                    .setRightPanelWidth(newWidth);
              },
            ),

          // 右侧栏 - 历史面板
          RightPanel(isResizing: _isResizingRight),
        ],
      ),
    );
  }
}
