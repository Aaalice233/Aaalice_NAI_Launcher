import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../../data/models/vibe/vibe_reference.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../themes/design_tokens.dart';
import '../../../../widgets/common/animated_favorite_button.dart';

/// Vibe 详情毛玻璃参数面板
///
/// 从原 _buildParamPanel 提取并升级：
/// - BackdropFilter 毛玻璃效果
/// - AnimatedFavoriteButton 可交互收藏
/// - 标签编辑区（Wrap + Chip + ActionChip）
class VibeDetailParamPanel extends StatelessWidget {
  final VibeLibraryEntry entry;
  final double strength;
  final double infoExtracted;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onInfoExtractedChanged;
  final VoidCallback? onSendToGeneration;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onToggleFavorite;
  final ValueChanged<List<String>>? onTagsChanged;
  final bool isRenaming;

  const VibeDetailParamPanel({
    super.key,
    required this.entry,
    required this.strength,
    required this.infoExtracted,
    required this.onStrengthChanged,
    required this.onInfoExtractedChanged,
    this.onSendToGeneration,
    this.onExport,
    this.onDelete,
    this.onRename,
    this.onToggleFavorite,
    this.onTagsChanged,
    this.isRenaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(DesignTokens.radiusXl),
        bottomLeft: Radius.circular(DesignTokens.radiusXl),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: DesignTokens.glassBlurRadius,
          sigmaY: DesignTokens.glassBlurRadius,
        ),
        child: Container(
          color: theme.colorScheme.surface
              .withOpacity(DesignTokens.glassOpacity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              _buildTitleBar(theme),

              // 参数滑块区域（使用 Flexible 避免无界高度约束崩溃）
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(DesignTokens.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSliderSection(
                        context,
                        labelKey: 'strength',
                        value: strength,
                        onChanged: onStrengthChanged,
                        description: '控制 Vibe 对生成结果的影响强度',
                      ),
                      const SizedBox(height: DesignTokens.spacingLg),
                      _buildSliderSection(
                        context,
                        labelKey: 'infoExtracted',
                        value: infoExtracted,
                        onChanged: onInfoExtractedChanged,
                        description: '控制从原始图片提取的信息量（消耗 2 Anlas）',
                      ),
                      const SizedBox(height: DesignTokens.spacingLg),
                      // 统计信息
                      _buildStatsSection(theme),
                    ],
                  ),
                ),
              ),

              // 操作按钮区域
              _buildActionBar(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 标题栏：名称 + 来源类型 + 收藏按钮
  Widget _buildTitleBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: DesignTokens.spacingXxs),
                _buildSourceTypeChip(theme),
              ],
            ),
          ),
          AnimatedFavoriteButton(
            isFavorite: entry.isFavorite,
            onToggle: onToggleFavorite,
            size: 22,
          ),
        ],
      ),
    );
  }

  /// 来源类型标签
  Widget _buildSourceTypeChip(ThemeData theme) {
    final color = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.label_outline,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            entry.sourceType.displayLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 滑块区域
  Widget _buildSliderSection(
    BuildContext context, {
    required String labelKey,
    required double value,
    required ValueChanged<double> onChanged,
    required String description,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final labelText = switch (labelKey) {
      'strength' => l10n.vibe_strength,
      'infoExtracted' => l10n.vibe_infoExtracted,
      _ => labelKey,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                labelText,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
              child: Text(
                value.toStringAsFixed(2),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spacingXxs),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DesignTokens.spacingXs),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
            thumbColor: theme.colorScheme.primary,
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['0.0', '0.5', '1.0']
              .map(
                (v) => Text(
                  v,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /// 统计信息
  Widget _buildStatsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingSm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: DesignTokens.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '统计信息',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          _buildStatRow(theme, '使用次数', '${entry.usedCount} 次'),
          _buildStatRow(
            theme,
            '最后使用',
            entry.lastUsedAt != null
                ? _formatDateTime(entry.lastUsedAt!)
                : '从未使用',
          ),
          _buildStatRow(theme, '创建时间', _formatDateTime(entry.createdAt)),
        ],
      ),
    );
  }

  Widget _buildStatRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  /// 操作按钮区域
  Widget _buildActionBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSendToGeneration,
              icon: const Icon(Icons.send),
              label: const Text('发送到生成'),
            ),
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isRenaming ? null : onRename,
                  icon: isRenaming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.drive_file_rename_outline),
                  label: const Text('重命名'),
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('导出'),
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 6) {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
    if (diff.inDays > 1) return '${diff.inDays} 天前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inHours > 0) return '${diff.inHours} 小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes} 分钟前';
    return '刚刚';
  }
}
