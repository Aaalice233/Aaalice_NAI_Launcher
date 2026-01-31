import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    // Start rotation animation
    _rotationController.repeat();

    // Trigger refresh
    ref.read(statisticsNotifierProvider.notifier).refresh().then((_) {
      // Stop rotation when refresh completes
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

    // Auto-rotate when loading
    if (isLoading && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!isLoading && _rotationController.isAnimating) {
      _rotationController.stop();
      _rotationController.reset();
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: isLoading ? null : _handleRefresh,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            // 色差背景：比周围略深/浅
            color: _isHovered && !isLoading
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerHigh,
            // 边缘阴影
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.12 : 0.08),
                blurRadius: _isHovered ? 8 : 4,
                offset: Offset(0, _isHovered ? 2 : 1),
              ),
              // 内发光效果
              BoxShadow(
                color: Colors.white.withOpacity(0.03),
                blurRadius: 1,
                spreadRadius: 0,
                offset: const Offset(0, -1),
              ),
            ],
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
                duration: const Duration(milliseconds: 200),
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
