import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/prompt/random_preset.dart';
import '../../../providers/random_preset_provider.dart';
import '../../common/elevated_card.dart';

/// 预设对比视图组件
///
/// 用于并排对比两个预设的配置差异
class PresetCompareView extends ConsumerStatefulWidget {
  const PresetCompareView({
    super.key,
    required this.leftPresetId,
    required this.rightPresetId,
  });

  final String leftPresetId;
  final String rightPresetId;

  static Future<void> show(
    BuildContext context, {
    required String leftPresetId,
    required String rightPresetId,
  }) {
    return showDialog(
      context: context,
      builder: (context) => PresetCompareView(
        leftPresetId: leftPresetId,
        rightPresetId: rightPresetId,
      ),
    );
  }

  @override
  ConsumerState<PresetCompareView> createState() => _PresetCompareViewState();
}

class _PresetCompareViewState extends ConsumerState<PresetCompareView> {
  late String _leftPresetId;
  late String _rightPresetId;

  @override
  void initState() {
    super.initState();
    _leftPresetId = widget.leftPresetId;
    _rightPresetId = widget.rightPresetId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presetState = ref.watch(randomPresetNotifierProvider);

    final leftPreset = presetState.presets.firstWhere(
      (p) => p.id == _leftPresetId,
      orElse: () => presetState.presets.first,
    );
    final rightPreset = presetState.presets.firstWhere(
      (p) => p.id == _rightPresetId,
      orElse: () => presetState.presets.first,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 900,
        height: 650,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            // 标题栏
            _buildHeader(context),
            // 对比内容
            Expanded(
              child: Row(
                children: [
                  // 左侧预设
                  Expanded(
                    child: _PresetPane(
                      preset: leftPreset,
                      allPresets: presetState.presets,
                      onPresetChanged: (id) {
                        setState(() => _leftPresetId = id);
                      },
                      side: _CompareSide.left,
                    ),
                  ),
                  // 中间分隔线
                  _buildDivider(context),
                  // 右侧预设
                  Expanded(
                    child: _PresetPane(
                      preset: rightPreset,
                      allPresets: presetState.presets,
                      onPresetChanged: (id) {
                        setState(() => _rightPresetId = id);
                      },
                      side: _CompareSide.right,
                    ),
                  ),
                ],
              ),
            ),
            // 差异摘要
            _DifferenceSummary(
              leftPreset: leftPreset,
              rightPreset: rightPreset,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.2),
            colorScheme.secondaryContainer.withOpacity(0.15),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.compare_arrows,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '预设对比',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            colorScheme.outlineVariant.withOpacity(0.5),
            colorScheme.outlineVariant.withOpacity(0.5),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

enum _CompareSide { left, right }

/// 预设面板
class _PresetPane extends StatelessWidget {
  const _PresetPane({
    required this.preset,
    required this.allPresets,
    required this.onPresetChanged,
    required this.side,
  });

  final RandomPreset preset;
  final List<RandomPreset> allPresets;
  final ValueChanged<String> onPresetChanged;
  final _CompareSide side;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sideColor =
        side == _CompareSide.left ? colorScheme.primary : colorScheme.tertiary;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 预设选择器
          _PresetSelector(
            preset: preset,
            allPresets: allPresets,
            onChanged: onPresetChanged,
            color: sideColor,
          ),
          const SizedBox(height: 16),
          // 统计概览
          _StatisticsOverview(preset: preset, color: sideColor),
          const SizedBox(height: 16),
          // 类别列表
          Expanded(
            child: _CategoryList(preset: preset, color: sideColor),
          ),
        ],
      ),
    );
  }
}

/// 预设选择器
class _PresetSelector extends StatelessWidget {
  const _PresetSelector({
    required this.preset,
    required this.allPresets,
    required this.onChanged,
    required this.color,
  });

  final RandomPreset preset;
  final List<RandomPreset> allPresets;
  final ValueChanged<String> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: preset.id,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.arrow_drop_down, color: color),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        items: allPresets.map((p) {
          return DropdownMenuItem(
            value: p.id,
            child: Text(p.name),
          );
        }).toList(),
        onChanged: (id) {
          if (id != null) onChanged(id);
        },
      ),
    );
  }
}

/// 统计概览
class _StatisticsOverview extends StatelessWidget {
  const _StatisticsOverview({
    required this.preset,
    required this.color,
  });

  final RandomPreset preset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 10,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.category_outlined,
            label: '类别',
            value: '${preset.categories.length}',
            color: color,
          ),
          _StatItem(
            icon: Icons.layers_outlined,
            label: '词组',
            value:
                '${preset.categories.fold<int>(0, (sum, c) => sum + c.groups.length)}',
            color: color,
          ),
          _StatItem(
            icon: Icons.tag,
            label: '标签',
            value: '${preset.totalTagCount}',
            color: color,
          ),
        ],
      ),
    );
  }
}

/// 统计项
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 类别列表
class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.preset,
    required this.color,
  });

  final RandomPreset preset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: preset.categories.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 12,
            endIndent: 12,
            color: colorScheme.outlineVariant.withOpacity(0.2),
          ),
          itemBuilder: (context, index) {
            final category = preset.categories[index];
            return _CategoryItem(
              name: category.name,
              groupCount: category.groups.length,
              enabled: category.enabled,
              color: color,
            );
          },
        ),
      ),
    );
  }
}

/// 类别项
class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.name,
    required this.groupCount,
    required this.enabled,
    required this.color,
  });

  final String name;
  final int groupCount;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: enabled ? color : colorScheme.outlineVariant,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: enabled ? null : colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$groupCount',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 差异摘要
class _DifferenceSummary extends StatelessWidget {
  const _DifferenceSummary({
    required this.leftPreset,
    required this.rightPreset,
  });

  final RandomPreset leftPreset;
  final RandomPreset rightPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 计算差异
    final categoryDiff =
        rightPreset.categories.length - leftPreset.categories.length;
    final leftGroupCount =
        leftPreset.categories.fold<int>(0, (sum, c) => sum + c.groups.length);
    final rightGroupCount =
        rightPreset.categories.fold<int>(0, (sum, c) => sum + c.groups.length);
    final groupDiff = rightGroupCount - leftGroupCount;
    final tagDiff = rightPreset.totalTagCount - leftPreset.totalTagCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '差异: ',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          _DiffBadge(label: '类别', diff: categoryDiff),
          const SizedBox(width: 12),
          _DiffBadge(label: '词组', diff: groupDiff),
          const SizedBox(width: 12),
          _DiffBadge(label: '标签', diff: tagDiff),
        ],
      ),
    );
  }
}

/// 差异徽章
class _DiffBadge extends StatelessWidget {
  const _DiffBadge({
    required this.label,
    required this.diff,
  });

  final String label;
  final int diff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final color = diff > 0
        ? Colors.green
        : diff < 0
            ? Colors.red
            : colorScheme.onSurfaceVariant;

    final prefix = diff > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$prefix$diff',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
