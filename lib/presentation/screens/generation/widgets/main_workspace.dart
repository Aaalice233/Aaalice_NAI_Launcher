import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/character_position_canvas_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/layout_state_provider.dart';
import '../../../providers/prompt_maximize_provider.dart';
import '../../../widgets/character/inline_character_row.dart';
import 'generation_controls/generation_controls.dart';
import 'image_preview.dart';
import 'prompt_input.dart';
import 'resize_handle.dart';

/// 主工作区组件
///
/// 显示提示词输入区、图像预览区和生成控制按钮。
/// 支持提示词区域最大化/还原功能。
class MainWorkspace extends ConsumerWidget {
  final VoidCallback onToggleMaximize;

  const MainWorkspace({super.key, required this.onToggleMaximize});

  static const double _minPromptAreaHeight = 100.0;
  static const double _minPreviewAreaHeight = 280.0;
  static const double _resizeHandleHeight = 8.0;
  static const double _generationControlsReservedHeight = 88.0;
  static const double _promptOuterHorizontalPadding = 24.0;
  static const double _promptInputHorizontalPadding = 40.0;
  static const double _promptAreaChromeHeight = 132.0;
  static const double _promptTextSafetyPadding = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final layoutState = ref.watch(layoutStateNotifierProvider);
    final isPromptMaximized = ref.watch(promptMaximizeNotifierProvider);
    // 位置画布打开时临时收起提示词区与角色行，画布独占中间区域；
    // 摆位置是短暂的专注操作，关闭画布即恢复
    final canvasOpen = ref.watch(characterPositionCanvasProvider);
    final promptTexts = ref.watch(
      generationParamsNotifierProvider.select(
        (params) =>
            (prompt: params.prompt, negativePrompt: params.negativePrompt),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final promptAreaHeight = _resolvePromptAreaHeight(
          context,
          layoutState,
          constraints.maxWidth,
          constraints.maxHeight,
          promptTexts.prompt,
          promptTexts.negativePrompt,
        );

        return Column(
          children: [
            // 顶部 Prompt 输入区（最大化时占满空间；画布模式收起）
            if (canvasOpen)
              const SizedBox.shrink()
            else if (isPromptMaximized)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                  ),
                  child: PromptInputWidget(
                    onToggleMaximize: onToggleMaximize,
                    isMaximized: isPromptMaximized,
                  ),
                ),
              )
            else
              SizedBox(
                height: promptAreaHeight,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                  ),
                  child: PromptInputWidget(
                    onToggleMaximize: onToggleMaximize,
                    isMaximized: isPromptMaximized,
                  ),
                ),
              ),

            // 角色行：紧贴提示词区下方（画布模式收起，画布内有芯片条）
            if (!canvasOpen) const InlineCharacterRow(),

            // 提示词区域拖拽分隔条（最大化/画布模式隐藏）
            if (!isPromptMaximized && !canvasOpen)
              VerticalResizeHandle(
                onDrag: (dy) {
                  final maxHeight = _resolvePromptAreaHeightCap(
                    constraints.maxHeight,
                  );
                  // 拖动调整的是「高度上限」，以存储值为基准；
                  // 若基于显示高度（内容少时贴内容），一拖就会把上限意外缩小
                  final storedHeight = ref
                      .read(layoutStateNotifierProvider)
                      .promptAreaHeight;
                  final newHeight = (storedHeight + dy)
                      .clamp(_minPromptAreaHeight, maxHeight)
                      .toDouble();
                  ref
                      .read(layoutStateNotifierProvider.notifier)
                      .setPromptAreaHeight(newHeight);
                },
              ),

            // 中间图像预览区（最大化时隐藏）
            if (!isPromptMaximized) const Expanded(child: ImagePreviewWidget()),

            // 底部生成控制区
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                border: Border(
                  top: BorderSide(color: theme.dividerColor, width: 1),
                ),
              ),
              child: const GenerationControls(),
            ),
          ],
        );
      },
    );
  }

  double _resolvePromptAreaHeight(
    BuildContext context,
    LayoutState layoutState,
    double maxWidth,
    double maxHeight,
    String prompt,
    String negativePrompt,
  ) {
    final heightCap = _resolvePromptAreaHeightCap(maxHeight);
    final storedHeight = layoutState.promptAreaHeight
        .clamp(_minPromptAreaHeight, heightCap)
        .toDouble();
    final adaptiveHeight = _estimatePromptAreaHeight(
      context,
      maxWidth,
      prompt,
      negativePrompt,
    ).clamp(_minPromptAreaHeight, heightCap).toDouble();

    // 内容自适应为主，用户拖动的高度作为上限：
    // 内容少时框贴内容收缩（不再留大片空白），超过上限时框内滚动
    return storedHeight < adaptiveHeight ? storedHeight : adaptiveHeight;
  }

  double _resolvePromptAreaHeightCap(double availableHeight) {
    if (!availableHeight.isFinite || availableHeight <= 0) {
      return double.infinity;
    }

    final maxByPreviewBudget =
        availableHeight -
        _resizeHandleHeight -
        _generationControlsReservedHeight -
        _minPreviewAreaHeight;
    final cappedHeight = maxByPreviewBudget
        .clamp(_minPromptAreaHeight, double.infinity)
        .toDouble();
    return cappedHeight;
  }

  double _estimatePromptAreaHeight(
    BuildContext context,
    double maxWidth,
    String prompt,
    String negativePrompt,
  ) {
    final safeMaxWidth = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 800.0;
    final textWidth =
        (safeMaxWidth -
                _promptOuterHorizontalPadding -
                _promptInputHorizontalPadding)
            .clamp(120.0, 2000.0);
    final promptHeight = _measurePromptTextHeight(context, prompt, textWidth);
    final negativeHeight = _measurePromptTextHeight(
      context,
      negativePrompt,
      textWidth,
    );
    final textHeight = promptHeight > negativeHeight
        ? promptHeight
        : negativeHeight;

    return _promptAreaChromeHeight + textHeight + _promptTextSafetyPadding;
  }

  double _measurePromptTextHeight(
    BuildContext context,
    String text,
    double maxWidth,
  ) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium ?? const TextStyle();
    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);

    return painter.height;
  }
}
