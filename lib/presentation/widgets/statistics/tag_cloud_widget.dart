import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/gallery_statistics.dart';

/// 标签云组件
///
/// 用于展示标签使用频率统计的可视化组件，支持：
/// - 标签大小根据使用频率动态调整
/// - 点击标签触发回调
/// - 响应式布局
/// - 颜色区分
class TagCloudWidget extends StatelessWidget {
  /// 标签统计数据列表
  final List<TagStatistics> tags;

  /// 组件标题
  final String? title;

  /// 点击标签回调
  final void Function(TagStatistics tag)? onTagTap;

  /// 最大显示标签数量（null表示显示全部）
  final int? maxTags;

  /// 最小标签字体大小
  final double minFontSize;

  /// 最大标签字体大小
  final double maxFontSize;

  const TagCloudWidget({
    super.key,
    required this.tags,
    this.title,
    this.onTagTap,
    this.maxTags = 20,
    this.minFontSize = 12.0,
    this.maxFontSize = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // 处理空数据情况
    if (tags.isEmpty) {
      return _buildEmptyState(theme, l10n);
    }

    // 限制显示数量并按频率排序
    final displayTags = _prepareDisplayTags();

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            if (title != null) ...[
              _buildHeader(context, theme),
              const SizedBox(height: 16),
            ],

            // 标签云
            _buildTagCloud(displayTags, theme),
          ],
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tag_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.statistics_noData,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.statistics_noTagData,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.tag,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title!,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// 准备显示的标签数据
  List<TagStatistics> _prepareDisplayTags() {
    // 按使用频率排序
    final sortedTags = List<TagStatistics>.from(tags)
      ..sort((a, b) => b.count.compareTo(a.count));

    // 限制显示数量
    if (maxTags != null && sortedTags.length > maxTags!) {
      return sortedTags.take(maxTags!).toList();
    }

    return sortedTags;
  }

  /// 构建标签云
  Widget _buildTagCloud(List<TagStatistics> displayTags, ThemeData theme) {
    // 计算最大和最小频率，用于字体大小缩放
    final maxCount =
        displayTags.map((t) => t.count).reduce((a, b) => a > b ? a : b);
    final minCount =
        displayTags.map((t) => t.count).reduce((a, b) => a < b ? a : b);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: displayTags.map((tag) {
        // 计算字体大小
        final fontSize = _calculateFontSize(tag.count, minCount, maxCount);

        // 计算颜色
        final color = _getColorForTag(tag, theme);

        return _buildTagChip(tag, fontSize, color, theme);
      }).toList(),
    );
  }

  /// 计算标签字体大小
  double _calculateFontSize(int count, int minCount, int maxCount) {
    if (maxCount == minCount) {
      return (minFontSize + maxFontSize) / 2;
    }

    // 线性插值计算字体大小
    final ratio = (count - minCount) / (maxCount - minCount);
    return minFontSize + (maxFontSize - minFontSize) * ratio;
  }

  /// 获取标签颜色
  Color _getColorForTag(TagStatistics tag, ThemeData theme) {
    // 根据索引选择不同的颜色
    final index = tags.indexOf(tag);
    final colors = [
      theme.colorScheme.primary,
      Colors.blue.shade700,
      Colors.green.shade700,
      Colors.orange.shade700,
      Colors.purple.shade700,
      Colors.red.shade700,
      Colors.teal.shade700,
      Colors.indigo.shade700,
    ];

    return colors[index % colors.length];
  }

  /// 构建单个标签芯片
  Widget _buildTagChip(
    TagStatistics tag,
    double fontSize,
    Color color,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: () => onTagTap?.call(tag),
      borderRadius: BorderRadius.circular(16),
      child: Chip(
        label: Text(
          tag.tagName,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        avatar: CircleAvatar(
          backgroundColor: color,
          child: Text(
            '${tag.count}',
            style: TextStyle(
              fontSize: fontSize * 0.7,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// TagCloudWidget 的扩展方法
extension TagCloudWidgetExtensions on TagCloudWidget {
  /// 创建紧凑型标签云（更多标签，更小字体）
  static TagCloudWidget compact({
    Key? key,
    required List<TagStatistics> tags,
    String? title,
    void Function(TagStatistics tag)? onTagTap,
    int? maxTags,
  }) {
    return TagCloudWidget(
      key: key,
      tags: tags,
      title: title,
      onTagTap: onTagTap,
      maxTags: maxTags ?? 30,
      minFontSize: 10.0,
      maxFontSize: 18.0,
    );
  }

  /// 创建扩展型标签云（更少标签，更大字体）
  static TagCloudWidget expanded({
    Key? key,
    required List<TagStatistics> tags,
    String? title,
    void Function(TagStatistics tag)? onTagTap,
    int? maxTags,
  }) {
    return TagCloudWidget(
      key: key,
      tags: tags,
      title: title,
      onTagTap: onTagTap,
      maxTags: maxTags ?? 10,
      minFontSize: 14.0,
      maxFontSize: 28.0,
    );
  }

  /// 创建带统计的标签云（显示百分比）
  static Widget withPercentage({
    Key? key,
    required List<TagStatistics> tags,
    String? title,
    void Function(TagStatistics tag)? onTagTap,
    int? maxTags,
  }) {
    // 这里可以返回一个自定义的标签云，显示百分比信息
    // 暂时返回默认实现
    return TagCloudWidget(
      key: key,
      tags: tags,
      title: title,
      onTagTap: onTagTap,
      maxTags: maxTags,
    );
  }
}
