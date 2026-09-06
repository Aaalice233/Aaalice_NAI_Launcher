import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../widgets/common/image_viewport_surface.dart';
import '../../core/utils/localization_extension.dart';
import '../../data/models/gallery/local_image_record.dart';
import '../adaptive/adaptive_layout.dart';
import '../router/app_routes.dart';

/// 图片对比屏幕
///
/// 支持并排对比2-4张图片，每张图片独立缩放
class ImageComparisonScreen extends ConsumerStatefulWidget {
  /// 图片列表（2-4张）
  final List<LocalImageRecord> images;

  const ImageComparisonScreen({super.key, required this.images});

  @override
  ConsumerState<ImageComparisonScreen> createState() =>
      _ImageComparisonScreenState();
}

class _ImageComparisonScreenState extends ConsumerState<ImageComparisonScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // 验证图片数量
    if (widget.images.isEmpty) {
      return _ComparisonMessageScreen(
        icon: Icons.image_not_supported,
        iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        title: l10n.comparison_noImages,
      );
    }

    if (widget.images.length > 4) {
      return _ComparisonMessageScreen(
        icon: Icons.error_outline,
        iconColor: theme.colorScheme.error,
        title: l10n.comparison_tooManyImages,
        description: l10n.comparison_maxImages,
      );
    }

    return Scaffold(
      backgroundColor: ImageViewportSurface.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compareSideBySide =
                widget.images.length == 2 && constraints.maxWidth >= 600;
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 56),
                  child: compareSideBySide
                      ? _buildHorizontalLayout(theme, l10n)
                      : _buildGridLayout(theme, l10n, constraints),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface,
                      ),
                      tooltip: l10n.comparison_close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 12,
                  right: 12,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            l10n.comparison_zoomHint,
                            textAlign: TextAlign.center,
                            softWrap: true,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建水平布局（2张图片）
  Widget _buildHorizontalLayout(ThemeData theme, AppLocalizations l10n) {
    return Row(
      children: widget.images.asMap().entries.map((entry) {
        final index = entry.key;
        final image = entry.value;
        return Expanded(
          child: _buildImageContainer(
            theme,
            image,
            index,
            widget.images.length,
          ),
        );
      }).toList(),
    );
  }

  /// 构建网格布局（3-4张图片）
  Widget _buildGridLayout(
    ThemeData theme,
    AppLocalizations l10n,
    BoxConstraints constraints,
  ) {
    final imageCount = widget.images.length;
    final crossAxisCount = constraints.maxWidth >= 600 ? 2 : 1;
    final rows = (imageCount / crossAxisCount).ceil();
    final availableHeight = math.max(1.0, constraints.maxHeight - 72);
    final tileWidth =
        (constraints.maxWidth - 16 - (crossAxisCount - 1) * 8) / crossAxisCount;
    final tileHeight = math.max(180.0, availableHeight / rows);

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: tileWidth / tileHeight,
      ),
      itemCount: imageCount,
      itemBuilder: (context, index) {
        return _buildImageContainer(
          theme,
          widget.images[index],
          index,
          imageCount,
        );
      },
    );
  }

  /// 构建单个图片容器
  Widget _buildImageContainer(
    ThemeData theme,
    LocalImageRecord image,
    int index,
    int total,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: ImageViewportSurface.background,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 图片显示区域 - 支持独立缩放
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(image.path),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: ImageViewportSurface.background,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.comparison_loadError,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: ImageViewportSurface.mutedForeground,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 图片编号标签
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonMessageScreen extends StatelessWidget {
  const _ComparisonMessageScreen({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: ImageViewportSurface.background,
      body: SafeArea(
        child: AdaptiveSlotLayout(
          builder: (context, areas) => SingleChildScrollView(
            key: const ValueKey('comparison_message_scroll_view'),
            padding: EdgeInsets.symmetric(
              horizontal: areas.horizontalPadding,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (areas.constraints.maxHeight - 48)
                    .clamp(0.0, double.infinity)
                    .toDouble(),
              ),
              child: AdaptiveContentBounds(
                maxWidth: 640,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 64, color: iconColor),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        description!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        TextButton.icon(
                          key: const ValueKey('comparison_back'),
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              context.go(AppRoutes.localGallery);
                            }
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: Text(context.l10n.editor_back),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('comparison_home'),
                          onPressed: () => context.go(AppRoutes.home),
                          icon: const Icon(Icons.home_outlined),
                          label: Text(
                            context.l10n.shortcut_action_send_to_home,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
