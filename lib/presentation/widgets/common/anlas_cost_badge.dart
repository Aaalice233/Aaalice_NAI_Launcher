import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/cost_estimate_provider.dart';

/// Anlas 成本徽章
///
/// 显示当前生成配置的预计 Anlas 消耗
/// 根据余额状态显示不同颜色
class AnlasCostBadge extends ConsumerWidget {
  final bool isGenerating;

  const AnlasCostBadge({
    super.key,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFree = ref.watch(isFreeGenerationProvider);

    // 生成中或免费时不显示
    if (isGenerating || isFree) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cost = ref.watch(estimatedCostProvider);
    final isInsufficient = ref.watch(isBalanceInsufficientProvider);

    // 价格徽章颜色
    Color badgeColor;
    Color badgeTextColor;
    
    if (isInsufficient) {
      badgeColor = theme.colorScheme.error;
      badgeTextColor = Colors.white;
    } else {
      badgeColor = theme.colorScheme.primaryContainer;
      badgeTextColor = theme.colorScheme.onPrimaryContainer;
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
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
    );
  }
}
