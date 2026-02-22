import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../themes/design_tokens.dart';

/// Bundle 画廊条
///
/// 底部横向子 vibe 缩略图列表，支持：
/// - 左侧固定"使用全部"按钮
/// - 选中项 primary 边框 + 放大 + 发光
/// - 长按设为合集封面
class BundleGalleryStrip extends StatelessWidget {
  /// 子 vibe 名称列表
  final List<String> vibeNames;

  /// 子 vibe 缩略图列表
  final List<Uint8List>? vibePreviews;

  /// 当前选中索引（-1 表示"使用全部"）
  final int selectedIndex;

  /// 选中回调
  final ValueChanged<int> onSelected;

  /// 长按设为封面回调
  final ValueChanged<int>? onLongPressSetCover;

  /// "使用全部"回调
  final VoidCallback? onUseAll;

  const BundleGalleryStrip({
    super.key,
    required this.vibeNames,
    this.vibePreviews,
    required this.selectedIndex,
    required this.onSelected,
    this.onLongPressSetCover,
    this.onUseAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: DesignTokens.glassBlurRadius,
          sigmaY: DesignTokens.glassBlurRadius,
        ),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.6),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              // 左侧固定"使用全部"按钮
              _buildUseAllButton(theme),

              // 分隔线
              Container(
                width: 1,
                height: 64,
                color: theme.colorScheme.outlineVariant.withOpacity(0.3),
              ),

              // 横向子 vibe 列表
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacingSm,
                  ),
                  itemCount: vibeNames.length,
                  itemBuilder: _buildVibeItem,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "使用全部"按钮
  Widget _buildUseAllButton(ThemeData theme) {
    final isSelected = selectedIndex == -1;

    return GestureDetector(
      onTap: onUseAll,
      child: AnimatedContainer(
        duration: DesignTokens.animationNormal,
        curve: DesignTokens.curveStandard,
        width: 72,
        margin: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingXs,
          vertical: DesignTokens.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.5)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: DesignTokens.borderRadiusLg,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.select_all,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: DesignTokens.spacingXxs),
            Text(
              '全部',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 子 vibe 缩略图项
  Widget _buildVibeItem(BuildContext context, int index) {
    final theme = Theme.of(context);
    final isSelected = selectedIndex == index;
    final preview =
        vibePreviews != null && index < vibePreviews!.length
            ? vibePreviews![index]
            : null;

    return GestureDetector(
      onTap: () => onSelected(index),
      onLongPress: onLongPressSetCover != null
          ? () => onLongPressSetCover!(index)
          : null,
      child: Tooltip(
        message: vibeNames[index] +
            (onLongPressSetCover != null ? '\n长按设为封面' : ''),
        child: AnimatedContainer(
          duration: DesignTokens.animationNormal,
          curve: DesignTokens.curveStandard,
          width: isSelected ? 70 : 64,
          height: isSelected ? 70 : 64,
          margin: EdgeInsets.symmetric(
            horizontal: DesignTokens.spacingXxs,
            vertical: isSelected ? 11 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: DesignTokens.borderRadiusLg,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: DesignTokens.borderRadiusMd,
            child: preview != null
                ? Image.memory(
                    preview,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildItemPlaceholder(theme, index),
                  )
                : _buildItemPlaceholder(theme, index),
          ),
        ),
      ),
    );
  }

  /// 缩略图占位符
  Widget _buildItemPlaceholder(ThemeData theme, int index) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          '${index + 1}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
