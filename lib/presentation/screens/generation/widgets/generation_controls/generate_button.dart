import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_button.dart';
import 'package:nai_launcher/presentation/widgets/common/anlas_cost_badge.dart';

/// 集成价格徽章的生成按钮
class GenerateButtonWithCost extends ConsumerWidget {
  final bool isGenerating;
  final bool showCancel;
  final ImageGenerationState generationState;
  final int cooldownRemainingSeconds;
  final VoidCallback onGenerate;
  final VoidCallback onCancel;
  final VoidCallback onSkipCurrent;
  final bool showCost;
  final bool requiresLogin;
  final bool compact;

  /// 按钮高度（紧凑布局可压低）
  final double height;

  const GenerateButtonWithCost({
    super.key,
    required this.isGenerating,
    required this.showCancel,
    required this.generationState,
    this.cooldownRemainingSeconds = 0,
    required this.onGenerate,
    required this.onCancel,
    required this.onSkipCurrent,
    this.showCost = true,
    this.requiresLogin = false,
    this.compact = false,
    this.height = 48,
  });

  bool get _canSkipCurrentBatch =>
      showCancel &&
      generationState.currentImage > 0 &&
      generationState.totalImages > generationState.currentImage;

  /// 已提交但还没开跑，此时按钮必须立刻反馈，否则点击会被静默吞掉。
  bool get _isPreparing => generationState.isPreparing;

  bool get _showCancelAction => showCancel || _isPreparing;

  String _progressText() =>
      '${generationState.currentImage}/${generationState.totalImages}';

  String _generateLabelText(BuildContext context) {
    if (requiresLogin && !isGenerating) {
      return context.l10n.auth_login;
    }
    if (isGenerating) {
      return generationState.totalImages > 1
          ? _progressText()
          : context.l10n.generation_generating;
    }
    if (cooldownRemainingSeconds > 0) {
      return context.l10n.generation_cooldownRemaining(
        cooldownRemainingSeconds,
      );
    }
    return context.l10n.generation_generate;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryButton = _buildPrimaryButton(context);

    final skipButton = ThemedButton(
      onPressed: onSkipCurrent,
      icon: const Icon(Icons.skip_next),
      label: Text(
        '${context.l10n.generation_skipCurrentBatch} ${_progressText()}',
        textAlign: TextAlign.center,
      ),
      style: ThemedButtonStyle.outlined,
    );
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18.2;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: !_canSkipCurrentBatch
          ? primaryButton
          : largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [skipButton, const SizedBox(height: 8), primaryButton],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [skipButton, const SizedBox(width: 8), primaryButton],
            ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context) {
    final theme = Theme.of(context);
    final cancelTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: theme.colorScheme.errorContainer,
        onPrimary: theme.colorScheme.onErrorContainer,
        primaryContainer: theme.colorScheme.error,
        onPrimaryContainer: theme.colorScheme.onError,
      ),
    );
    // Krita 占用时启动器自身没有可取消的任务，只能转圈禁用等待。
    final isLoading = isGenerating && !_showCancelAction;

    final buttonTheme = _showCancelAction ? cancelTheme : theme;
    final effectiveTheme = compact
        ? buttonTheme.copyWith(
            filledButtonTheme: FilledButtonThemeData(
              style:
                  buttonTheme.filledButtonTheme.style?.copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ) ??
                  const ButtonStyle(
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
            ),
          )
        : buttonTheme;

    return AnimatedTheme(
      data: effectiveTheme,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: ThemedButton(
        onPressed: _showCancelAction
            ? onCancel
            : requiresLogin
            ? onGenerate
            : isGenerating || cooldownRemainingSeconds > 0
            ? null
            : onGenerate,
        isLoading: isLoading,
        label: IndexedStack(
          index: _showCancelAction ? 1 : 0,
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isLoading) ...[
                  Icon(
                    requiresLogin
                        ? Icons.login_rounded
                        : cooldownRemainingSeconds > 0
                        ? Icons.hourglass_bottom_outlined
                        : Icons.auto_awesome,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  showCancel
                      ? context.l10n.generation_generate
                      : _generateLabelText(context),
                ),
                if (showCost && !requiresLogin)
                  AnlasCostBadge(isGenerating: isLoading),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isPreparing)
                  const GenerateButtonSpinner()
                else
                  const Icon(Icons.stop_circle_outlined),
                const SizedBox(width: 8),
                Text(context.l10n.common_cancel),
              ],
            ),
          ],
        ),
        style: ThemedButtonStyle.filled,
      ),
    );
  }
}

/// 跟随按钮前景色的小转圈，供准备期的可取消态复用。
class GenerateButtonSpinner extends StatelessWidget {
  const GenerateButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: IconTheme.of(context).color,
      ),
    );
  }
}
