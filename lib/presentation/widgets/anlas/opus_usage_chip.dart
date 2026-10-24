import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/user/user_subscription.dart';
import '../../providers/cost_estimate_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../themes/core/legible_color.dart';

/// Opus 免费生成配额徽章（V5 起）
///
/// 百分比保留超过 100% 的真实配额，有额外用量时追加显示；悬浮显示两池合计的
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

    final colorScheme = Theme.of(context).colorScheme;
    // 与网页端一致只以服务端 isNegative 判定耗尽，额外用量不参与此判定。
    final exhausted = usage.isNegative;
    final showExtra = !exhausted && usage.hasExtraUsage;
    final accentColor = exhausted ? colorScheme.error : colorScheme.primary;
    final tint = accentColor.withValues(alpha: 0.1);
    final paintedSurface = Color.alphaBlend(tint, colorScheme.surface);
    final accentForeground = legibleForeground(accentColor, paintedSurface);

    return Tooltip(
      message: _buildTooltip(
        context,
        usage,
        exhausted: exhausted,
        showExtra: showExtra,
        quotaUnits: _quotaUnitsForArea(modelInfo.area),
      ),
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        ),
        // 窄屏大字号放不下时额外用量换到下一行，不裁切也不溢出。
        child: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  exhausted
                      ? Icons.hourglass_bottom_rounded
                      : Icons.bolt_rounded,
                  size: compact ? 12 : 14,
                  color: accentForeground,
                ),
                const SizedBox(width: 4),
                Text(
                  '${usage.regularDisplayPercent.round()}%',
                  style: _percentStyle(accentForeground),
                ),
              ],
            ),
            if (showExtra)
              Text(
                key: const ValueKey('opus-usage-extra-percent'),
                '+${usage.extraDisplayPercent}%',
                style: _percentStyle(
                  legibleForeground(colorScheme.tertiary, paintedSurface),
                ),
              ),
          ],
        ),
      ),
    );
  }

  TextStyle _percentStyle(Color color) => TextStyle(
    color: color,
    fontWeight: FontWeight.w600,
    fontSize: compact ? 11 : 12,
  );

  static String _buildTooltip(
    BuildContext context,
    OpusUsageInfo usage, {
    required bool exhausted,
    required bool showExtra,
    required int quotaUnits,
  }) {
    final l10n = context.l10n;
    if (exhausted) return l10n.generation_opusUsageExhausted;

    // 与网页端一致按两池合计估算；大图一张消耗多份配额，张数随之缩减。
    final estimatedImages =
        (usage.availablePercent * _imagesPerPercent / quotaUnits).round();
    final regularPercent = usage.regularDisplayPercent.round().toString();
    if (!showExtra) {
      return [
        l10n.generation_opusUsageRemaining(regularPercent),
        l10n.generation_opusUsageEstimate(estimatedImages.toString()),
        l10n.generation_opusUsageRefill,
      ].join('\n');
    }
    return [
      l10n.generation_opusUsagePoolsTitle,
      l10n.generation_opusUsageRegularPool(regularPercent),
      l10n.generation_opusUsageExtraPool(usage.extraDisplayPercent.toString()),
      l10n.generation_opusUsageCombinedEstimate(estimatedImages.toString()),
    ].join('\n');
  }
}
