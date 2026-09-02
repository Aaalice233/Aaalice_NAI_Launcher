import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../adaptive/interaction_policy.dart';
import '../../../providers/character_position_canvas_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/layout_state_provider.dart';
import '../../../providers/prompt_maximize_provider.dart';
import '../../../widgets/character/inline_character_row.dart';
import 'generation_controls/generation_controls.dart';
import 'image_preview.dart';
import 'prompt_input.dart';
import 'prompt_input_controller.dart';
import 'resize_handle.dart';

/// 主工作区组件
///
/// 显示提示词输入区、图像预览区和生成控制按钮。
/// 支持提示词区域最大化/还原功能。
class MainWorkspace extends ConsumerWidget {
  final VoidCallback onToggleMaximize;
  final PromptInputController promptInputController;
  final GlobalKey promptInputKey;

  const MainWorkspace({
    super.key,
    required this.onToggleMaximize,
    required this.promptInputController,
    required this.promptInputKey,
  });

  static const double _minPromptAreaHeight = 100.0;
  static const double _minPreviewAreaHeight = 280.0;
  static const double _resizeHandleHeight = 8.0;
  static const double _generationControlsReservedHeight = 88.0;
  static const double _promptOuterHorizontalPadding = 24.0;
  static const double _promptInputHorizontalPadding = 40.0;
  static const double _promptAreaChromeHeight = 132.0;
  static const double _promptTextSafetyPadding = 24.0;

  @visibleForTesting
  static double resolveClassicPromptAreaHeight({
    required double storedHeight,
    required double adaptiveHeight,
    required double heightCap,
  }) {
    final preferredHeight = storedHeight
        .clamp(_minPromptAreaHeight, heightCap)
        .toDouble();
    return preferredHeight > adaptiveHeight ? preferredHeight : adaptiveHeight;
  }

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
        final useScrollableWorkspace =
            !isPromptMaximized &&
            (constraints.maxHeight < 560 ||
                MediaQuery.textScalerOf(context).scale(14) > 18.2);
        final interactionPolicy = context.interactionPolicy;
        final resizeHandleHeight = interactionPolicy.prefersTouchPresentation
            ? interactionPolicy.minimumControlExtent
            : _resizeHandleHeight;
        final promptAreaHeight = _resolvePromptAreaHeight(
          context,
          layoutState,
          constraints.maxWidth,
          useScrollableWorkspace ? double.infinity : constraints.maxHeight,
          resizeHandleHeight,
          promptTexts.prompt,
          promptTexts.negativePrompt,
        );

        final workspace = Column(
          children: [
            // 画布只从布局中收起提示词区，不卸载编辑器。隐藏时仍按原始
            // 非零尺寸布局，避免 EditableText 丢失滚动、selection 与 IME 会话。
            if (isPromptMaximized)
              Expanded(
                child: _PreservedPromptArea(
                  hidden: canvasOpen,
                  child: _buildPromptInput(theme, isPromptMaximized),
                ),
              )
            else
              _PreservedPromptArea(
                hidden: canvasOpen,
                child: SizedBox(
                  height: promptAreaHeight,
                  child: _buildPromptInput(theme, isPromptMaximized),
                ),
              ),

            // 角色二级菜单：紧贴提示词区下方（画布模式收起，画布内有芯片条）
            if (!canvasOpen) const ClassicCharacterSection(),

            // 提示词区域拖拽分隔条（最大化/画布模式隐藏）
            if (!isPromptMaximized && !canvasOpen)
              VerticalResizeHandle(
                height: resizeHandleHeight,
                onDrag: (dy) {
                  final maxHeight = _resolvePromptAreaHeightCap(
                    constraints.maxHeight,
                    resizeHandleHeight,
                  );
                  // 存储值是用户设置的基础高度；内容超过该高度时仍会自然增高。
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
            if (!isPromptMaximized)
              if (useScrollableWorkspace)
                const SizedBox(
                  height: _minPreviewAreaHeight,
                  child: ImagePreviewWidget(),
                )
              else
                const Expanded(child: ImagePreviewWidget()),

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
        if (!useScrollableWorkspace) return workspace;
        return SingleChildScrollView(primary: false, child: workspace);
      },
    );
  }

  Widget _buildPromptInput(ThemeData theme, bool isPromptMaximized) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
      ),
      child: PromptInputWidget(
        key: promptInputKey,
        controller: promptInputController,
        onToggleMaximize: onToggleMaximize,
        isMaximized: isPromptMaximized,
      ),
    );
  }

  double _resolvePromptAreaHeight(
    BuildContext context,
    LayoutState layoutState,
    double maxWidth,
    double maxHeight,
    double resizeHandleHeight,
    String prompt,
    String negativePrompt,
  ) {
    final heightCap = _resolvePromptAreaHeightCap(
      maxHeight,
      resizeHandleHeight,
    );
    final storedHeight = layoutState.promptAreaHeight
        .clamp(_minPromptAreaHeight, heightCap)
        .toDouble();
    final adaptiveHeight = _estimatePromptAreaHeight(
      context,
      maxWidth,
      prompt,
      negativePrompt,
    ).clamp(_minPromptAreaHeight, heightCap).toDouble();

    // 用户设置值是基础高度，避免空提示词时编辑器默认缩成窄条；
    // 内容更多时仍允许区域自适应增高，但不会突破预览区安全上限。
    return resolveClassicPromptAreaHeight(
      storedHeight: storedHeight,
      adaptiveHeight: adaptiveHeight,
      heightCap: heightCap,
    );
  }

  double _resolvePromptAreaHeightCap(
    double availableHeight,
    double resizeHandleHeight,
  ) {
    if (!availableHeight.isFinite || availableHeight <= 0) {
      return double.infinity;
    }

    final maxByPreviewBudget =
        availableHeight -
        resizeHandleHeight -
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

class _PreservedPromptArea extends StatelessWidget {
  const _PreservedPromptArea({required this.hidden, required this.child});

  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: hidden,
      child: TickerMode(
        enabled: !hidden,
        child: IgnorePointer(ignoring: hidden, child: child),
      ),
    );
  }
}
