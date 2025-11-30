import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/image/image_params.dart';
import '../../providers/cost_estimate_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../widgets/anlas/anlas_balance_chip.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/draggable_number_input.dart';
import '../../widgets/common/themed_button.dart';
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
  // 左侧面板状态
  bool _leftPanelExpanded = true;
  double _leftPanelWidth = 300;
  static const double _leftPanelMinWidth = 250;
  static const double _leftPanelMaxWidth = 450;

  // 右侧面板状态
  bool _rightPanelExpanded = true;
  double _rightPanelWidth = 280;
  static const double _rightPanelMinWidth = 200;
  static const double _rightPanelMaxWidth = 400;

  // 提示词区域高度
  double _promptAreaHeight = 200;
  static const double _promptAreaMinHeight = 100;
  static const double _promptAreaMaxHeight = 500;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // 左侧栏 - 参数面板
        _buildLeftPanel(theme),

        // 左侧拖拽分隔条
        if (_leftPanelExpanded)
          _buildResizeHandle(
            theme,
            onDrag: (dx) {
              setState(() {
                _leftPanelWidth = (_leftPanelWidth + dx)
                    .clamp(_leftPanelMinWidth, _leftPanelMaxWidth);
              });
            },
          ),

        // 中间 - 主工作区
        Expanded(
          child: Column(
            children: [
              // 顶部 Prompt 输入区
              SizedBox(
                height: _promptAreaHeight,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.5),
                  ),
                  child: const PromptInputWidget(),
                ),
              ),

              // 提示词区域拖拽分隔条
              _buildVerticalResizeHandle(theme),

              // 中间图像预览区
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
        if (_rightPanelExpanded)
          _buildResizeHandle(
            theme,
            onDrag: (dx) {
              setState(() {
                _rightPanelWidth = (_rightPanelWidth - dx)
                    .clamp(_rightPanelMinWidth, _rightPanelMaxWidth);
              });
            },
          ),

        // 右侧栏 - 历史面板
        _buildRightPanel(theme),
      ],
    );
  }

  Widget _buildLeftPanel(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _leftPanelExpanded ? _leftPanelWidth : 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: _leftPanelExpanded
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
                    onTap: () => setState(() => _leftPanelExpanded = false),
                  ),
                ),
              ],
            )
          : _buildCollapsedPanel(
              theme,
              icon: Icons.tune,
              label: context.l10n.generation_params,
              onTap: () => setState(() => _leftPanelExpanded = true),
            ),
    );
  }

  Widget _buildRightPanel(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _rightPanelExpanded ? _rightPanelWidth : 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: _rightPanelExpanded
          ? Stack(
              children: [
                const HistoryPanel(),
                // 折叠按钮
                Positioned(
                  top: 14,
                  left: 8,
                  child: _buildCollapseButton(
                    theme,
                    icon: Icons.chevron_right,
                    onTap: () => setState(() => _rightPanelExpanded = false),
                  ),
                ),
              ],
            )
          : _buildCollapsedPanel(
              theme,
              icon: Icons.history,
              label: context.l10n.generation_history,
              onTap: () => setState(() => _rightPanelExpanded = true),
            ),
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
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
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

  Widget _buildVerticalResizeHandle(ThemeData theme) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _promptAreaHeight = (_promptAreaHeight + details.delta.dy)
                .clamp(_promptAreaMinHeight, _promptAreaMaxHeight);
          });
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

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final params = ref.watch(generationParamsNotifierProvider);
    final isGenerating = generationState.isGenerating;

    // 悬浮时显示取消，否则显示生成中
    final showCancel = isGenerating && _isHovering;

    final randomMode = ref.watch(randomPromptModeProvider);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Anlas 余额显示（移到抽卡按钮左边）
        const AnlasBalanceChip(),

        const SizedBox(width: 8),

        // 抽卡模式开关
        _RandomModeToggle(enabled: randomMode),

        const SizedBox(width: 12),

        // 生成按钮 (包含价格徽章)
        MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: _GenerateButtonWithCost(
            isGenerating: isGenerating,
            showCancel: showCancel,
            generationState: generationState,
            onGenerate: () => _handleGenerate(context, ref, params, randomMode),
            onCancel: () => ref.read(imageGenerationNotifierProvider.notifier).cancel(),
          ),
        ),

        const SizedBox(width: 12),

        // 生成数量选择器（移到按钮右边）
        DraggableNumberInput(
          value: params.nSamples,
          min: 1,
          prefix: '×',
          onChanged: (value) {
            ref.read(generationParamsNotifierProvider.notifier).updateNSamples(value);
          },
        ),

        const SizedBox(width: 8),

        // 批量设置按钮
        _BatchSettingsButton(),
      ],
    );
  }

  void _handleGenerate(BuildContext context, WidgetRef ref, ImageParams params, bool randomMode) {
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
      onPressed: () => _showBatchSettingsDialog(context, ref, theme, l10n, batchSize, batchCount),
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
                  const Divider(),
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
                          l10n.batchSize_formula(batchCount, currentBatchSize, totalImages),
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
  
  Widget _buildBatchOption(ThemeData theme, int value, int current, VoidCallback onTap) {
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
            Text(showCancel
                ? context.l10n.generation_cancel
                : (isGenerating
                    ? (generationState.totalImages > 1
                        ? '${generationState.currentImage}/${generationState.totalImages}'
                        : context.l10n.generation_generating)
                    : context.l10n.generation_generate)),
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
        style: showCancel ? ThemedButtonStyle.outlined : ThemedButtonStyle.filled,
      ),
    );
  }
}
