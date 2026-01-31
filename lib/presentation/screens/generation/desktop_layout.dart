import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../providers/cost_estimate_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/layout_state_provider.dart';
import '../../providers/prompt_maximize_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/anlas/anlas_balance_chip.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/generation/auto_save_toggle_chip.dart';
import '../../widgets/common/draggable_number_input.dart';
import '../../widgets/common/themed_button.dart';
import '../../widgets/common/themed_divider.dart';
import 'widgets/parameter_panel.dart';
import 'widgets/prompt_input.dart';
import 'widgets/image_preview.dart';
import 'widgets/history_panel.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    ref.read(promptMaximizeNotifierProvider.notifier).toggle();
    AppLogger.d('Prompt area maximize toggled', 'DesktopLayout');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 从 Provider 读取布局状态
    final layoutState = ref.watch(layoutStateNotifierProvider);
    // 从 Provider 读取最大化状态（确保主题切换时状态不丢失）
    final isPromptMaximized = ref.watch(promptMaximizeNotifierProvider);

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

        // 中间 - 主工作区
        Expanded(
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
        onHorizontalDragStart:
            onDragStart != null ? (_) => onDragStart() : null,
        onHorizontalDragEnd: onDragEnd != null ? (_) => onDragEnd() : null,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: Container(
          width: 6,
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
        onVerticalDragUpdate: (details) {
          final newHeight = (layoutState.promptAreaHeight + details.delta.dy)
              .clamp(_promptAreaMinHeight, _promptAreaMaxHeight);
          ref
              .read(layoutStateNotifierProvider.notifier)
              .setPromptAreaHeight(newHeight);
        },
        child: Container(
          height: 6,
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

/// 生成控制按钮
class GenerationControls extends ConsumerStatefulWidget {
  const GenerationControls({super.key});

  @override
  ConsumerState<GenerationControls> createState() => _GenerationControlsState();
}

class _GenerationControlsState extends ConsumerState<GenerationControls> {
  bool _isHovering = false;
  bool _showAddToQueueButton = false;

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final params = ref.watch(generationParamsNotifierProvider);
    final isGenerating = generationState.isGenerating;

    // 悬浮时显示取消，否则显示生成中
    final showCancel = isGenerating && _isHovering;

    final randomMode = ref.watch(randomPromptModeProvider);

    // 监听队列执行状态
    final queueExecutionState = ref.watch(queueExecutionNotifierProvider);
    final queueState = ref.watch(replicationQueueNotifierProvider);

    // 检查悬浮球是否被手动关闭
    final isFloatingButtonClosed = ref.watch(floatingButtonClosedProvider);

    // 判断悬浮球是否可见（队列有任务或正在执行，且未被手动关闭）
    final shouldShowFloatingButton = !isFloatingButtonClosed &&
        !(queueState.isEmpty &&
            queueState.failedTasks.isEmpty &&
            queueExecutionState.isIdle &&
            !queueExecutionState.hasFailedTasks);

    // 监听队列状态变化，当变为 ready 时自动触发生成
    ref.listen<QueueExecutionState>(
      queueExecutionNotifierProvider,
      (previous, next) {
        // 从非 ready 状态变为 ready 状态，且当前没有在生成
        if (previous?.status != QueueExecutionStatus.ready &&
            next.status == QueueExecutionStatus.ready) {
          final currentGenerationState =
              ref.read(imageGenerationNotifierProvider);
          if (!currentGenerationState.isGenerating) {
            // 延迟一帧确保提示词已填充
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final currentParams = ref.read(generationParamsNotifierProvider);
              if (currentParams.prompt.isNotEmpty) {
                ref
                    .read(imageGenerationNotifierProvider.notifier)
                    .generate(currentParams);
              }
            });
          }
        }
      },
    );

    // Enter 键处理函数
    KeyEventResult handleEnterKey(FocusNode node, KeyEvent event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter) {
        // Shift+Enter 不处理（留给输入框换行）
        if (HardwareKeyboard.instance.isShiftPressed) {
          return KeyEventResult.ignored;
        }

        if (params.prompt.isEmpty) {
          AppToast.warning(context, context.l10n.generation_pleaseInputPrompt);
          return KeyEventResult.handled;
        }
        if (isGenerating) return KeyEventResult.handled;

        // 悬浮球存在时加入队列，否则生图
        if (shouldShowFloatingButton) {
          _handleAddToQueue(context, ref, params);
        } else {
          _handleGenerate(context, ref, params, randomMode);
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    return Focus(
      autofocus: true,
      onKeyEvent: handleEnterKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;

          if (isNarrow) {
            // 窄屏布局：只显示核心组件
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RandomModeToggle(enabled: randomMode),
                const SizedBox(width: 8),
                // 生成按钮区域 - 悬浮球存在时hover显示"加入队列"
                _buildGenerateButtonWithHover(
                  context: context,
                  ref: ref,
                  params: params,
                  isGenerating: isGenerating,
                  showCancel: showCancel,
                  generationState: generationState,
                  randomMode: randomMode,
                  shouldShowFloatingButton: shouldShowFloatingButton,
                ),
                const SizedBox(width: 8),
                DraggableNumberInput(
                  value: params.nSamples,
                  min: 1,
                  prefix: '×',
                  onChanged: (value) {
                    ref
                        .read(generationParamsNotifierProvider.notifier)
                        .updateNSamples(value);
                  },
                ),
              ],
            );
          }

          // 正常布局 - 自动保存靠左，其他元素居中
          return Row(
            children: [
              // 左侧 - 自动保存靠左
              const AutoSaveToggleChip(),

              const SizedBox(width: 16),

              // 中间 - 其他元素居中
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AnlasBalanceChip(),
                    const SizedBox(width: 16),

                    // 生成按钮区域 - 悬浮球存在时hover显示"加入队列"
                    _RandomModeToggle(enabled: randomMode),
                    const SizedBox(width: 12),
                    _buildGenerateButtonWithHover(
                      context: context,
                      ref: ref,
                      params: params,
                      isGenerating: isGenerating,
                      showCancel: showCancel,
                      generationState: generationState,
                      randomMode: randomMode,
                      shouldShowFloatingButton: shouldShowFloatingButton,
                    ),
                    const SizedBox(width: 12),
                    DraggableNumberInput(
                      value: params.nSamples,
                      min: 1,
                      prefix: '×',
                      onChanged: (value) {
                        ref
                            .read(generationParamsNotifierProvider.notifier)
                            .updateNSamples(value);
                      },
                    ),
                    const SizedBox(width: 16),

                    // 批量设置
                    _BatchSettingsButton(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建带有hover显示"加入队列"功能的生成按钮
  Widget _buildGenerateButtonWithHover({
    required BuildContext context,
    required WidgetRef ref,
    required ImageParams params,
    required bool isGenerating,
    required bool showCancel,
    required ImageGenerationState generationState,
    required bool randomMode,
    required bool shouldShowFloatingButton,
  }) {
    // 使用 Row 横向布局，hover时"加入队列"按钮从左侧弹出
    return MouseRegion(
      onEnter: (_) {
        if (!_showAddToQueueButton) {
          setState(() {
            _isHovering = true;
            _showAddToQueueButton = true;
          });
        }
      },
      onExit: (_) {
        if (_showAddToQueueButton) {
          setState(() {
            _isHovering = false;
            _showAddToQueueButton = false;
          });
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 悬浮球存在 + hover时 → 左侧横向弹出"加入队列"按钮
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.centerRight,
            child: shouldShowFloatingButton && _showAddToQueueButton
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          alignment: Alignment.centerRight,
                          child: Opacity(
                            opacity: value.clamp(0.0, 1.0),
                            child: _AddToQueueButton(
                              onPressed: () =>
                                  _handleAddToQueue(context, ref, params),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // 生图按钮（始终显示）
          _GenerateButtonWithCost(
            isGenerating: isGenerating,
            showCancel: showCancel,
            generationState: generationState,
            onGenerate: () => _handleGenerate(context, ref, params, randomMode),
            onCancel: () =>
                ref.read(imageGenerationNotifierProvider.notifier).cancel(),
          ),
        ],
      ),
    );
  }

  void _handleAddToQueue(
    BuildContext context,
    WidgetRef ref,
    ImageParams params,
  ) {
    if (params.prompt.isEmpty) {
      AppToast.warning(context, context.l10n.generation_pleaseInputPrompt);
      return;
    }

    // 创建任务并添加到队列
    final task = ReplicationTask.create(
      prompt: params.prompt,
      // 不需要 negativePrompt，执行时会使用主界面设置
    );

    ref.read(replicationQueueNotifierProvider.notifier).add(task);
    AppToast.success(context, context.l10n.queue_taskAdded);
  }

  void _handleGenerate(
    BuildContext context,
    WidgetRef ref,
    ImageParams params,
    bool randomMode,
  ) {
    if (params.prompt.isEmpty) {
      AppToast.warning(context, context.l10n.generation_pleaseInputPrompt);
      return;
    }

    // 生成（抽卡模式逻辑在 generate 方法内部处理）
    ref.read(imageGenerationNotifierProvider.notifier).generate(params);
  }
}

/// 抽卡模式开关
class _RandomModeToggle extends ConsumerStatefulWidget {
  final bool enabled;

  const _RandomModeToggle({required this.enabled});

  @override
  ConsumerState<_RandomModeToggle> createState() => _RandomModeToggleState();
}

class _RandomModeToggleState extends ConsumerState<_RandomModeToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotateAnimation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_RandomModeToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.enabled
            ? context.l10n.randomMode_enabledTip
            : context.l10n.randomMode_disabledTip,
        preferBelow: true,
        child: GestureDetector(
          onTap: () {
            ref.read(randomPromptModeProvider.notifier).toggle();
            if (!widget.enabled) {
              _controller.forward(from: 0);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.enabled
                  ? (_isHovering
                      ? theme.colorScheme.primary.withOpacity(0.25)
                      : theme.colorScheme.primary.withOpacity(0.15))
                  : (_isHovering
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.enabled
                    ? theme.colorScheme.primary.withOpacity(0.5)
                    : theme.colorScheme.outline.withOpacity(0.3),
                width: widget.enabled ? 1.5 : 1,
              ),
            ),
            child: AnimatedBuilder(
              animation: _rotateAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotateAnimation.value * 3.14159,
                  child: child,
                );
              },
              child: Icon(
                Icons.casino_outlined,
                size: 20,
                color: widget.enabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 批量设置按钮（批次大小）
class _BatchSettingsButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final batchSize = ref.watch(imagesPerRequestProvider);
    final batchCount = ref.watch(generationParamsNotifierProvider).nSamples;
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      tooltip: l10n.batchSize_tooltip(batchSize),
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$batchSize',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      onPressed: () => _showBatchSettingsDialog(
        context,
        ref,
        theme,
        l10n,
        batchSize,
        batchCount,
      ),
    );
  }

  void _showBatchSettingsDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppLocalizations l10n,
    int currentBatchSize,
    int batchCount,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final totalImages = batchCount * currentBatchSize;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.burst_mode, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(l10n.batchSize_title),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.batchSize_description,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),

                  // 批次大小选择
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (int i = 1; i <= 4; i++)
                        _buildBatchOption(theme, i, currentBatchSize, () {
                          ref.read(imagesPerRequestProvider.notifier).set(i);
                          setState(() => currentBatchSize = i);
                        }),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const ThemedDivider(),
                  const SizedBox(height: 12),

                  // 计算公式
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.batchSize_formula(
                            batchCount,
                            currentBatchSize,
                            totalImages,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    l10n.batchSize_hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  if (currentBatchSize > 1) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.batchSize_costWarning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.common_close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBatchOption(
    ThemeData theme,
    int value,
    int current,
    VoidCallback onTap,
  ) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// 集成价格徽章的生成按钮
class _GenerateButtonWithCost extends ConsumerWidget {
  final bool isGenerating;
  final bool showCancel;
  final ImageGenerationState generationState;
  final VoidCallback onGenerate;
  final VoidCallback onCancel;

  const _GenerateButtonWithCost({
    required this.isGenerating,
    required this.showCancel,
    required this.generationState,
    required this.onGenerate,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cost = ref.watch(estimatedCostProvider);
    final isFree = ref.watch(isFreeGenerationProvider);
    final isInsufficient = ref.watch(isBalanceInsufficientProvider);

    // 价格徽章颜色
    Color badgeColor;
    Color badgeTextColor;
    if (isFree) {
      badgeColor = Colors.green;
      badgeTextColor = Colors.white;
    } else if (isInsufficient) {
      badgeColor = theme.colorScheme.error;
      badgeTextColor = Colors.white;
    } else {
      badgeColor = theme.colorScheme.primaryContainer;
      badgeTextColor = theme.colorScheme.onPrimaryContainer;
    }

    return SizedBox(
      height: 48,
      child: ThemedButton(
        onPressed: isGenerating ? onCancel : onGenerate,
        icon: showCancel
            ? const Icon(Icons.stop)
            : (isGenerating ? null : const Icon(Icons.auto_awesome)),
        isLoading: isGenerating && !showCancel,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              showCancel
                  ? context.l10n.generation_cancel
                  : (isGenerating
                      ? (generationState.totalImages > 1
                          ? '${generationState.currentImage}/${generationState.totalImages}'
                          : context.l10n.generation_generating)
                      : context.l10n.generation_generate),
            ),
            // 价格徽章（仅在非生成状态且非免费时显示）
            if (!isGenerating && !isFree) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$cost',
                  style: TextStyle(
                    color: badgeTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        style:
            showCancel ? ThemedButtonStyle.outlined : ThemedButtonStyle.filled,
      ),
    );
  }
}

/// 加入队列按钮
class _AddToQueueButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddToQueueButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ThemedButton(
        onPressed: onPressed,
        icon: const Icon(Icons.playlist_add),
        label: Text(context.l10n.queue_addToQueue),
        style: ThemedButtonStyle.filled,
      ),
    );
  }
}
