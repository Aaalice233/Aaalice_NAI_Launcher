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
    this.height = 48,
  });

  bool get _canSkipCurrentBatch =>
      showCancel &&
      generationState.currentImage > 0 &&
      generationState.totalImages > generationState.currentImage;

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

    return SizedBox(
      height: height,
      child: _canSkipCurrentBatch
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ThemedButton(
                  onPressed: onSkipCurrent,
                  icon: const Icon(Icons.skip_next),
                  label: Text(
                    '${context.l10n.generation_skipCurrentBatch} ${_progressText()}',
                  ),
                  style: ThemedButtonStyle.outlined,
                ),
                const SizedBox(width: 8),
                primaryButton,
              ],
            )
          : primaryButton,
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
    final isLoading = isGenerating && !showCancel;

    return AnimatedTheme(
      data: showCancel ? cancelTheme : theme,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: ThemedButton(
        onPressed: showCancel
            ? onCancel
            : requiresLogin
            ? onGenerate
            : isGenerating || cooldownRemainingSeconds > 0
            ? null
            : onGenerate,
        isLoading: isLoading,
        label: IndexedStack(
          index: showCancel ? 1 : 0,
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
