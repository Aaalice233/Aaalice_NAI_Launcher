import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../data/models/prompt/random_tag_group.dart';

/// DIY 能力悬浮提示组件
///
/// 显示 RandomTagGroup 的 DIY 高级能力图标和提示
class DiyFeatureTooltip extends StatelessWidget {
  /// 标签组
  final RandomTagGroup tagGroup;

  /// 图标大小
  final double iconSize;

  /// 是否紧凑模式
  final bool compact;

  const DiyFeatureTooltip({
    super.key,
    required this.tagGroup,
    this.iconSize = 16,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!tagGroup.hasDiyFeatures) {
      return const SizedBox.shrink();
    }

    final icons = tagGroup.diyFeatureIcons;
    if (icons.isEmpty) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return _buildCompactView(context, icons);
    }

    return _buildExpandedView(context, icons);
  }

  Widget _buildCompactView(BuildContext context, List<String> icons) {
    return Tooltip(
      message: _buildTooltipMessage(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: iconSize,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 2),
          Text(
            '${icons.length}',
            style: TextStyle(
              fontSize: iconSize - 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedView(BuildContext context, List<String> icons) {
    return Tooltip(
      message: _buildTooltipMessage(context),
      child: Wrap(
        spacing: 4,
        children: icons.map((icon) {
          return Text(icon, style: TextStyle(fontSize: iconSize));
        }).toList(),
      ),
    );
  }

  String _buildTooltipMessage(BuildContext context) {
    final l10n = context.l10n;
    final features = <String>[];

    if (tagGroup.hasConditionalBranch) {
      features.add('🔀 ${l10n.diy_conditionalTitle}');
    }
    if (tagGroup.hasDependency) {
      features.add('🔗 ${l10n.diy_dependencyTitle}');
    }
    if (tagGroup.hasVisibilityRules) {
      features.add('👁️ ${l10n.diy_visibilityTitle}');
    }
    if (tagGroup.hasTimeCondition) {
      features.add('📅 ${l10n.diy_timeTitle}');
    }
    if (tagGroup.hasPostProcessRules) {
      features.add('🔧 ${l10n.diy_postProcessTitle}');
    }
    if (tagGroup.emphasisProbability > 0) {
      final percent = (tagGroup.emphasisProbability * 100).toStringAsFixed(0);
      features.add('⚡ ${l10n.diy_emphasisPercent(percent)}');
    }

    return features.join('\n');
  }
}

/// DIY 能力徽章
///
/// 显示在标签组卡片上的小徽章
class DiyFeatureBadge extends StatelessWidget {
  /// 标签组
  final RandomTagGroup tagGroup;

  const DiyFeatureBadge({super.key, required this.tagGroup});

  @override
  Widget build(BuildContext context) {
    if (!tagGroup.hasDiyFeatures) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 12,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            'DIY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
