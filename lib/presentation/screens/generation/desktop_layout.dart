import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/services/metadata/unified_metadata_parser.dart';
import '../../../data/services/image_metadata_service.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../../data/services/alias_resolver_service.dart';
import '../../providers/character_panel_dock_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/layout_state_provider.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/prompt_maximize_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/anlas/anlas_balance_chip.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/generation/auto_save_toggle_chip.dart';
import '../../widgets/common/draggable_number_input.dart';
import '../../widgets/common/themed_button.dart';
import '../../widgets/common/anlas_cost_badge.dart';
import '../../widgets/common/themed_divider.dart';
import '../../widgets/shortcuts/shortcut_aware_widget.dart';
import 'widgets/parameter_panel.dart';
import 'widgets/prompt_input.dart';
import 'widgets/image_preview.dart';
import 'widgets/history_panel.dart';
import 'widgets/upscale_dialog.dart';
import 'services/generation_save_service.dart';
import 'widgets/generation_controls/index.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

/// 桌面端三栏布局
class DesktopGenerationLayout extends ConsumerStatefulWidget {
  const DesktopGenerationLayout({super.key});

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
  static const double _rightPanelMaxWidth = 400;
  static const double _promptAreaMinHeight = 100;
  static const double _promptAreaMaxHeight = 500;

  // 拖拽状态（拖拽时禁用动画以避免粘滞感）
  bool _isResizingLeft = false;
  bool _isResizingRight = false;

  /// 切换提示词区域最大化状态
  void _togglePromptMaximize() {
    final newValue = !ref.read(promptMaximizeNotifierProvider);

    // 如果即将最大化，自动退出停靠模式（两者互斥）
    if (newValue) {
      final isDocked = ref.read(characterPanelDockProvider);
      if (isDocked) {
        ref.read(characterPanelDockProvider.notifier).undock();
        AppLogger.d('Auto-undocked character panel on maximize', 'DesktopLayout');
      }
    }

    ref.read(promptMaximizeNotifierProvider.notifier).setMaximized(newValue);
    AppLogger.d('Prompt area maximize toggled', 'DesktopLayout');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 从 Provider 读取布局状态
    final layoutState = ref.watch(layoutStateNotifierProvider);
    // 从 Provider 读取最大化状态（确保主题切换时状态不丢失）
    final isPromptMaximized = ref.watch(promptMaximizeNotifierProvider);
    // 从 Provider 读取生成状态和参数（用于快捷键回调）
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final params = ref.watch(generationParamsNotifierProvider);
    final isGenerating = generationState.isGenerating;

    // 定义快捷键动作映射（使用 ShortcutIds 常量）
    final shortcuts = <String, VoidCallback>{
      // 生成图像
      ShortcutIds.generateImage: () {
        if (!isGenerating && params.prompt.isNotEmpty) {
          ref.read(imageGenerationNotifierProvider.notifier).generate(params);
        }
      },
      // 取消生成
      ShortcutIds.cancelGeneration: () {
        if (isGenerating) {
          ref.read(imageGenerationNotifierProvider.notifier).cancel();
        }
      },
      // 加入队列
      ShortcutIds.addToQueue: () {
        if (params.prompt.isNotEmpty) {
          final task = ReplicationTask.create(prompt: params.prompt);
          ref.read(replicationQueueNotifierProvider.notifier).add(task);
          AppToast.success(context, context.l10n.queue_taskAdded);
        }
      },
      // 随机提示词
      ShortcutIds.randomPrompt: () {
        ref.read(randomPromptModeProvider.notifier).toggle();
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
        if (generationState.displayImages.isNotEmpty) {
          UpscaleDialog.show(
            context,
            image: generationState.displayImages.first.bytes,
          );
        }
      },
      // 全屏预览
      ShortcutIds.fullscreenPreview: () {
        if (generationState.displayImages.isNotEmpty) {
          GenerationSaveService.showFullscreenPreview(
            context,
            ref,
            generationState.displayImages,
          );
        }
      },
    };

    return Row(
      children: [
        // 左侧栏 - 参数面板
        _buildLeftPanel(theme, layoutState),

        // 左侧拖拽分隔条
        if (layoutState.leftPanelExpanded)
          _buildResizeHandle(
            theme,
            onDragStart: () => setState(() => _isResizingLeft = true),
            onDragEnd: () => setState(() => _isResizingLeft = false),
            onDrag: (dx) {
              // 读取最新的宽度值，避免闭包捕获旧值导致不跟手
              final currentWidth =
                  ref.read(layoutStateNotifierProvider).leftPanelWidth;
              final newWidth = (currentWidth + dx)
                  .clamp(_leftPanelMinWidth, _leftPanelMaxWidth);
              ref
                  .read(layoutStateNotifierProvider.notifier)
                  .setLeftPanelWidth(newWidth);
            },
          ),

        // 中间 - 主工作区（包裹在 ShortcutAwareWidget 中，确保整个区域都支持快捷键）
        Expanded(
          child: ShortcutAwareWidget(
            contextType: ShortcutContext.generation,
            shortcuts: shortcuts,
            autofocus: true,
            child: Column(
              children: [
                // 顶部 Prompt 输入区（最大化时占满空间）
                isPromptMaximized
                    ? Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.5),
                          ),
                          child: PromptInputWidget(
                            onToggleMaximize: _togglePromptMaximize,
                            isMaximized: isPromptMaximized,
                          ),
                        ),
                      )
                    : SizedBox(
                        height: layoutState.promptAreaHeight,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.5),
                          ),
                          child: PromptInputWidget(
                            onToggleMaximize: _togglePromptMaximize,
                            isMaximized: isPromptMaximized,
                          ),
                        ),
                      ),

                // 提示词区域拖拽分隔条（最大化时隐藏）
                if (!isPromptMaximized)
                  _buildVerticalResizeHandle(theme, layoutState),

                // 中间图像预览区（最大化时隐藏）
                if (!isPromptMaximized)
                  const Expanded(
                    child: ImagePreviewWidget(),
                  ),

                // 底部生成控制区
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.5),
                    border: Border(
                      top: BorderSide(
                        color: theme.dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: const GenerationControls(),
                ),
              ],
            ),
          ),
        ),

        // 右侧拖拽分隔条
        if (layoutState.rightPanelExpanded)
          _buildResizeHandle(
            theme,
            onDragStart: () => setState(() => _isResizingRight = true),
            onDragEnd: () => setState(() => _isResizingRight = false),
            onDrag: (dx) {
              // 读取最新的宽度值，避免闭包捕获旧值导致不跟手
              final currentWidth =
                  ref.read(layoutStateNotifierProvider).rightPanelWidth;
              final newWidth = (currentWidth - dx)
                  .clamp(_rightPanelMinWidth, _rightPanelMaxWidth);
              ref
                  .read(layoutStateNotifierProvider.notifier)
                  .setRightPanelWidth(newWidth);
            },
          ),

        // 右侧栏 - 历史面板
        _buildRightPanel(theme, layoutState),
      ],
    );
  }

  Widget _buildLeftPanel(ThemeData theme, LayoutState layoutState) {
    final width =
        layoutState.leftPanelExpanded ? layoutState.leftPanelWidth : 40.0;
    final decoration = BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border(
        right: BorderSide(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
    );
    final child = layoutState.leftPanelExpanded
        ? Stack(
            children: [
              const ParameterPanel(),
              // 折叠按钮
              Positioned(
                top: 8,
                right: 8,
                child: _buildCollapseButton(
                  theme,
                  icon: Icons.chevron_left,
                  onTap: () => ref
                      .read(layoutStateNotifierProvider.notifier)
                      .setLeftPanelExpanded(false),
                ),
              ),
            ],
          )
        : _buildCollapsedPanel(
            theme,
            icon: Icons.tune,
            label: context.l10n.generation_params,
            onTap: () => ref
                .read(layoutStateNotifierProvider.notifier)
                .setLeftPanelExpanded(true),
          );

    // 拖拽时不使用动画，避免粘滞感
    if (_isResizingLeft) {
      return Container(
        width: width,
        decoration: decoration,
        child: child,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: decoration,
      child: child,
    );
  }

  Widget _buildRightPanel(ThemeData theme, LayoutState layoutState) {
    final width =
        layoutState.rightPanelExpanded ? layoutState.rightPanelWidth : 40.0;
    final decoration = BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border(
        left: BorderSide(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
    );
    final child = layoutState.rightPanelExpanded
        ? const HistoryPanel()
        : _buildCollapsedPanel(
            theme,
            icon: Icons.history,
            label: context.l10n.generation_history,
            onTap: () => ref
                .read(layoutStateNotifierProvider.notifier)
                .setRightPanelExpanded(true),
          );

    // 拖拽时不使用动画，避免粘滞感
    if (_isResizingRight) {
      return Container(
        width: width,
        decoration: decoration,
        child: child,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: decoration,
      child: child,
    );
  }

  Widget _buildCollapseButton(
    ThemeData theme, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedPanel(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(height: 8),
            RotatedBox(
              quarterTurns: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResizeHandle(
    ThemeData theme, {
    required void Function(double) onDrag,
    VoidCallback? onDragStart,
    VoidCallback? onDragEnd,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart:
            onDragStart != null ? (_) => onDragStart() : null,
        onHorizontalDragEnd: onDragEnd != null ? (_) => onDragEnd() : null,
        onHorizontalDragUpdate: (details) {
          final delta = details.primaryDelta ?? details.delta.dx;
          if (delta == 0) return;
          onDrag(delta);
        },
        child: Container(
          width: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalResizeHandle(ThemeData theme, LayoutState layoutState) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (_) {
          // 开始拖拽时标记，避免其他组件干扰
        },
        onVerticalDragUpdate: (details) {
          // 使用 primaryDelta 提高精度，直接更新避免延迟
          final delta = details.primaryDelta ?? details.delta.dy;
          if (delta == 0) return;
          
          final currentHeight = ref.read(layoutStateNotifierProvider).promptAreaHeight;
          final newHeight = (currentHeight + delta)
              .clamp(_promptAreaMinHeight, _promptAreaMaxHeight);
          
          // 使用 notifier 直接设置，避免重复读取 state
          ref
              .read(layoutStateNotifierProvider.notifier)
              .setPromptAreaHeight(newHeight);
        },
        child: Container(
          height: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

