import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

import '../../statistics_state.dart';

/// Animated refresh button with hover effects and rotation animation
/// 带悬停效果和旋转动画的刷新按钮
class AnimatedRefreshButton extends ConsumerStatefulWidget {
  const AnimatedRefreshButton({super.key});

  @override
  ConsumerState<AnimatedRefreshButton> createState() =>
      _AnimatedRefreshButtonState();
}

class _AnimatedRefreshButtonState extends ConsumerState<AnimatedRefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _handleRefresh() {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (!reducedMotion) {
      _rotationController.repeat();
    }

    ref.read(statisticsNotifierProvider.notifier).refresh().then((_) {
      if (!mounted) return;
      _rotationController.stop();
      _rotationController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final data = ref.watch(statisticsNotifierProvider);
    final isLoading = data.isLoading;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    if (isLoading && !reducedMotion && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if ((reducedMotion || !isLoading) &&
        _rotationController.isAnimating) {
      _rotationController.stop();
      _rotationController.reset();
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isLoading ? null : _handleRefresh,
        child: AnimatedContainer(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          duration: reducedMotion ? Duration.zero : theme.appTheme.fastDuration,
          curve: theme.appTheme.standardCurve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            // 色差背景：比周围略深/浅
            color: _isHovered && !isLoading
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerHigh,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated rotating icon
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * 3.14159,
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: _isHovered && !isLoading
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              // Text with animated color
              AnimatedDefaultTextStyle(
                duration: reducedMotion
                    ? Duration.zero
                    : theme.appTheme.fastDuration,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: _isHovered && !isLoading
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                child: Text(l10n.statistics_refresh),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
