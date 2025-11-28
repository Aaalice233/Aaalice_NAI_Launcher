import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/image_generation_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/themed_button.dart';
import 'widgets/parameter_panel.dart';
import 'widgets/prompt_input.dart';
import 'widgets/image_preview.dart';
import 'widgets/history_panel.dart';

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
              label: '参数',
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
                  top: 10,
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
              label: '历史',
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

  Widget _buildResizeHandle(ThemeData theme,
      {required void Function(double) onDrag}) {
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
class GenerationControls extends ConsumerWidget {
  const GenerationControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final params = ref.watch(generationParamsNotifierProvider);
    final isGenerating = generationState.isGenerating;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 生成按钮
        SizedBox(
          width: 200,
          height: 48,
          child: ThemedButton(
            onPressed: isGenerating
                ? null
                : () {
                    if (params.prompt.isEmpty) {
                      AppToast.warning(context, '请输入提示词');
                      return;
                    }
                    ref
                        .read(imageGenerationNotifierProvider.notifier)
                        .generate(params);
                  },
            icon: isGenerating ? null : const Icon(Icons.auto_awesome),
            isLoading: isGenerating,
            label: Text(isGenerating ? '生成中...' : '生成'),
            style: ThemedButtonStyle.filled,
          ),
        ),

        const SizedBox(width: 16),

        // 取消按钮 (仅在生成中显示)
        if (isGenerating)
          ThemedButton(
            onPressed: () {
              ref.read(imageGenerationNotifierProvider.notifier).cancel();
            },
            icon: const Icon(Icons.stop),
            label: const Text('取消'),
            style: ThemedButtonStyle.outlined,
          ),

        // 保存按钮 (仅在有图像时显示)
        if (!isGenerating && generationState.hasImages)
          ThemedButton(
            onPressed: () {
              // TODO: 实现保存功能
              AppToast.info(context, '保存功能开发中...');
            },
            icon: const Icon(Icons.save_alt),
            label: const Text('保存'),
            style: ThemedButtonStyle.outlined,
          ),
      ],
    );
  }
}
