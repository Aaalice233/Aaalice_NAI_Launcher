import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../widgets/common/hover_image_preview.dart';

/// Vibe 卡片组件
///
/// 用于在生成页面显示单个 Vibe 的详细信息，包括：
/// - 缩略图预览（支持悬浮放大）
/// - 编码状态标签（已编码/待编码/预编码文件）
/// - Bundle 来源标识
/// - Reference Strength 滑条
/// - Information Extracted 滑条
/// - 删除按钮
class VibeCard extends StatelessWidget {
  final int index;
  final VibeReference vibe;
  final String? bundleSource;
  final VoidCallback onRemove;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onInfoExtractedChanged;
  final bool showBackground;

  const VibeCard({
    super.key,
    required this.index,
    required this.vibe,
    this.bundleSource,
    required this.onRemove,
    required this.onStrengthChanged,
    required this.onInfoExtractedChanged,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：缩略图（占满剩余高度）
          _buildThumbnail(theme),
          const SizedBox(width: 12),

          // 右侧：滑条和源类型
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部行：编码状态标签 + Bundle 来源 + 删除按钮
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 编码状态标签
                    _buildEncodingStatusChip(context, theme),
                    // Bundle 来源标识
                    if (bundleSource != null) ...[
                      const SizedBox(width: 8),
                      _buildBundleSourceChip(context, theme),
                    ],
                    const Spacer(),
                    // 删除按钮（右上角）
                    SizedBox(
                      height: 28,
                      width: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: onRemove,
                        tooltip: context.l10n.vibe_remove,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Reference Strength 滑条
                _buildSliderRow(
                  context,
                  theme,
                  label: context.l10n.vibe_referenceStrength,
                  value: vibe.strength,
                  onChanged: onStrengthChanged,
                ),

                // Information Extracted 滑条
                _buildSliderRow(
                  context,
                  theme,
                  label: context.l10n.vibe_infoExtraction,
                  value: vibe.infoExtracted,
                  onChanged: onInfoExtractedChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    final thumbnailBytes = vibe.thumbnail ?? vibe.rawImageData;

    // 悬浮预览使用原始图片数据或缩略图
    final previewBytes = vibe.rawImageData ?? vibe.thumbnail;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 100,
        height: 100,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: thumbnailBytes != null
              ? (previewBytes != null
                  ? HoverImagePreview(
                      imageBytes: previewBytes,
                      child: Image.memory(
                        thumbnailBytes,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholder(theme);
                        },
                      ),
                    )
                  : Image.memory(
                      thumbnailBytes,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder(theme);
                      },
                    ))
              : _buildPlaceholder(theme),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.auto_awesome,
        size: 24,
        color: theme.colorScheme.outline,
      ),
    );
  }

  /// 构建编码状态标签
  Widget _buildEncodingStatusChip(BuildContext context, ThemeData theme) {
    final isEncoded = vibe.vibeEncoding.isNotEmpty;
    final needsEncoding = vibe.sourceType == VibeSourceType.rawImage;

    if (isEncoded) {
      // 已编码状态
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.green.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              size: 12,
              color: Colors.green,
            ),
            const SizedBox(width: 4),
            Text(
              '已编码',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (needsEncoding) {
      // 需要编码状态
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.pending,
              size: 12,
              color: Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              '待编码',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(2 Anlas)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.orange.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    } else {
      // 预编码文件状态
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.blue.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.file_present,
              size: 12,
              color: Colors.blue,
            ),
            const SizedBox(width: 4),
            Text(
              vibe.sourceType.displayLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// 构建 Bundle 来源标识
  Widget _buildBundleSourceChip(BuildContext context, ThemeData theme) {
    if (bundleSource == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_zip,
            size: 10,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 3),
          Text(
            bundleSource!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签 + 数值
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        // 滑条
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
