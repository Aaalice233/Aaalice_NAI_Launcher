import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/cost_estimate_provider.dart';

/// 消耗徽章
///
/// 显示当前参数下预估的 Anlas 消耗
class CostBadge extends ConsumerWidget {
  /// 紧凑模式（移动端使用）
  final bool compact;

  const CostBadge({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cost = ref.watch(estimatedCostProvider);
    final isFree = ref.watch(isFreeGenerationProvider);
    final isInsufficient = ref.watch(isBalanceInsufficientProvider);
    final theme = Theme.of(context);

    // 颜色配置
    Color backgroundColor;
    Color textColor;
    String displayText;

    if (isFree) {
      backgroundColor = Colors.green.withOpacity(0.15);
      textColor = Colors.green;
      displayText = 'FREE';
    } else if (isInsufficient) {
      backgroundColor = theme.colorScheme.errorContainer.withOpacity(0.5);
      textColor = theme.colorScheme.error;
      displayText = cost.toString();
    } else {
      backgroundColor = theme.colorScheme.primaryContainer.withOpacity(0.5);
      textColor = theme.colorScheme.primary;
      displayText = cost.toString();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFree) ...[
            Icon(
              Icons.diamond_outlined,
              size: compact ? 10 : 12,
              color: textColor,
            ),
            SizedBox(width: compact ? 2 : 3),
          ],
          Text(
            displayText,
            style: TextStyle(
              color: textColor,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 带消耗显示的生成按钮包装器
///
/// 将生成按钮和消耗徽章组合在一起
class GenerateButtonWithCost extends StatelessWidget {
  final Widget button;
  final bool compact;

  const GenerateButtonWithCost({
    super.key,
    required this.button,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        SizedBox(width: compact ? 6 : 8),
        CostBadge(compact: compact),
      ],
    );
  }
}
