import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/image/image_params.dart';
import '../../providers/cost_estimate_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/subscription_provider.dart';

/// Opus 免费生成配额徽章（V5 起）
///
/// 网页端在 Opus 订阅下展示 "[0]% of Opus Generations remaining" 横条；
/// 启动器做成余额芯片旁的紧凑徽章：迷你进度条 + 百分比，悬浮显示
/// 估算张数与回充说明，配额透支时转为警示色。
///
/// 仅当满足全部条件时显示：Opus 订阅、订阅响应携带 usage 字段、
/// 当前模型受配额池限制（V5）。
class OpusUsageChip extends ConsumerWidget {
  /// 紧凑模式（移动端使用）
  final bool compact;

  const OpusUsageChip({super.key, this.compact = false});

  /// 网页端按 1% ≈ 17.3 张估算剩余可生成数（1MP 以内 1 份/张口径）。
  static const double _imagesPerPercent = 17.3;

  /// 网页端的面积扣份档位：大图一张消耗多份配额。
  static const List<(int, int)> _quotaUnitTiers = [
    (1048576, 1),
    (1747627, 2),
    (2446678, 3),
    (3145728, 4),
  ];

  static int _quotaUnitsForArea(int area) {
    for (final (maxArea, units) in _quotaUnitTiers) {
      if (area <= maxArea) return units;
    }
    return _quotaUnitTiers.last.$2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(
      subscriptionNotifierProvider.select(
        (state) => state.subscription?.isOpus == true
            ? state.subscription?.usage
            : null,
      ),
    );
    final modelInfo = ref.watch(
      generationParamsNotifierProvider.select((params) {
        final billingSize = resolveGenerationBillingSize(
          width: params.width,
          height: params.height,
          maxEnhance: params.effectiveUpscaledEnhance,
        );
        return (
          hasOpusUsageLimit: params.capabilities.hasOpusUsageLimit,
          area: billingSize.width * billingSize.height,
        );
      }),
    );
    if (usage == null || !modelInfo.hasOpusUsageLimit) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = context.l10n;
    final exhausted = usage.isNegative;
    // 服务端允许回充后的额度超过 100%；仅进度条封顶，文本与张数保留真实值。
    final percent = exhausted ? 0.0 : usage.percent.clamp(0.0, double.infinity);
    final progress = (percent / 100).clamp(0.0, 1.0);
    final accentColor = exhausted
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    // 按当前生成尺寸折算：大图一张消耗多份配额，估算张数随之缩减。
    final quotaUnits = _quotaUnitsForArea(modelInfo.area);
    final estimatedImages = (percent * _imagesPerPercent / quotaUnits).round();

    final tooltip = exhausted
        ? l10n.generation_opusUsageExhausted
        : '${l10n.generation_opusUsageRemaining(percent.round().toString())}\n'
              '${l10n.generation_opusUsageEstimate(estimatedImages.toString())}\n'
              '${l10n.generation_opusUsageRefill}';

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              exhausted ? Icons.hourglass_bottom_rounded : Icons.bolt_rounded,
              size: compact ? 12 : 14,
              color: accentColor,
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: compact ? 28 : 36,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: accentColor.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${percent.round()}%',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
                fontSize: compact ? 11 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
