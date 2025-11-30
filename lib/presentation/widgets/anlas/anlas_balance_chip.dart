import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/cost_estimate_provider.dart';
import '../../providers/subscription_provider.dart';

/// Anlas 余额显示芯片
///
/// 显示当前账户的 Anlas 余额，支持点击刷新
class AnlasBalanceChip extends ConsumerWidget {
  /// 紧凑模式（移动端使用）
  final bool compact;

  const AnlasBalanceChip({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionNotifierProvider);
    final estimatedCost = ref.watch(estimatedCostProvider);
    final theme = Theme.of(context);

    return subscriptionState.map(
      initial: (_) => _buildPlaceholder(theme, compact),
      loading: (_) => _buildLoading(theme, compact),
      loaded: (state) => _buildLoaded(
        context,
        ref,
        theme,
        state.subscription.anlasBalance,
        estimatedCost,
        compact,
      ),
      error: (state) => _buildError(context, ref, theme, compact),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, bool compact) {
    return _ChipContainer(
      compact: compact,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(theme, null),
          const SizedBox(width: 4),
          Text(
            '--',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(ThemeData theme, bool compact) {
    return _ChipContainer(
      compact: compact,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: compact ? 12 : 16,
            height: compact ? 12 : 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    int balance,
    int estimatedCost,
    bool compact,
  ) {
    final isInsufficient = balance < estimatedCost;
    final formatter = NumberFormat('#,###');

    Color textColor;
    Color? backgroundColor;

    if (isInsufficient) {
      textColor = theme.colorScheme.error;
      backgroundColor = theme.colorScheme.errorContainer.withOpacity(0.3);
    } else {
      textColor = theme.colorScheme.onSurfaceVariant;
      backgroundColor = null;
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(subscriptionNotifierProvider.notifier).refreshBalance();
      },
      borderRadius: BorderRadius.circular(16),
      child: _ChipContainer(
        compact: compact,
        backgroundColor: backgroundColor,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(theme, isInsufficient),
            const SizedBox(width: 4),
            Text(
              formatter.format(balance),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: compact ? 12 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    bool compact,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(subscriptionNotifierProvider.notifier).fetchSubscription();
      },
      borderRadius: BorderRadius.circular(16),
      child: Tooltip(
        message: '点击重试',
        child: _ChipContainer(
          compact: compact,
          backgroundColor: theme.colorScheme.errorContainer.withOpacity(0.3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: compact ? 14 : 16,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 4),
              Text(
                '--',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 12 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ThemeData theme, bool? isWarning) {
    return Icon(
      Icons.diamond_outlined,
      size: compact ? 14 : 16,
      color: isWarning == true
          ? theme.colorScheme.error
          : theme.colorScheme.primary,
    );
  }
}

class _ChipContainer extends StatelessWidget {
  final Widget child;
  final bool compact;
  final Color? backgroundColor;

  const _ChipContainer({
    required this.child,
    required this.compact,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
