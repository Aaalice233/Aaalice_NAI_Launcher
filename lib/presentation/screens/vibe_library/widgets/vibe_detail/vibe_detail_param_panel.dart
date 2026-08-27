import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../../data/models/vibe/vibe_reference.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../themes/design_tokens.dart';
import '../../../../widgets/common/animated_favorite_button.dart';
import '../../../../widgets/common/editable_double_field.dart';

enum _VibeDetailAction { save, rename, export, delete }

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
  final VoidCallback? onSaveParams;
  final VoidCallback? onToggleFavorite;
  final ValueChanged<List<String>>? onTagsChanged;
  final bool canSaveParams;
  final bool showInfoExtractedControl;
  final bool parametersEditable;
  final String? parameterHint;
  final bool isRenaming;
  final bool isSavingParams;

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
    this.onSaveParams,
    this.onToggleFavorite,
    this.onTagsChanged,
    this.canSaveParams = false,
    this.showInfoExtractedControl = true,
    this.parametersEditable = true,
    this.parameterHint,
    this.isRenaming = false,
    this.isSavingParams = false,
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
          color: theme.colorScheme.surface.withValues(
            alpha: DesignTokens.glassOpacity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              _buildTitleBar(context, theme),

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
                        enabled: parametersEditable,
                        description:
                            context.l10n.vibeDetail_strengthDescription,
                      ),
                      if (showInfoExtractedControl) ...[
                        const SizedBox(height: DesignTokens.spacingLg),
                        _buildSliderSection(
                          context,
                          labelKey: 'infoExtracted',
                          value: infoExtracted,
                          onChanged: onInfoExtractedChanged,
                          enabled: parametersEditable,
                          description:
                              context.l10n.vibeDetail_infoExtractedDescription,
                        ),
                      ],
                      if (parameterHint != null) ...[
                        const SizedBox(height: DesignTokens.spacingMd),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(DesignTokens.spacingSm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.2),
                            borderRadius: DesignTokens.borderRadiusMd,
                          ),
                          child: Text(
                            parameterHint!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: DesignTokens.spacingLg),
                      // 统计信息
                      _buildStatsSection(context, theme),
                    ],
                  ),
                ),
              ),

              // 操作按钮区域
              _buildActionBar(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 标题栏：名称 + 来源类型 + 收藏按钮
  Widget _buildTitleBar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
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
                _buildSourceTypeChip(context, theme),
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
  Widget _buildSourceTypeChip(BuildContext context, ThemeData theme) {
    final color = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_outline, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            context.vibeSourceTypeLabel(entry.sourceType),
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
    required bool enabled,
    required String description,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final labelText = switch (labelKey) {
      'strength' => l10n.vibe_strength,
      'infoExtracted' => l10n.vibe_infoExtracted,
      _ => labelKey,
    };

    final isInfoExtracted = labelKey == 'infoExtracted';
    final double? fieldMin = isInfoExtracted
        ? VibeReference.minInfoExtracted
        : null;
    final double? fieldMax = isInfoExtracted
        ? VibeReference.maxInfoExtracted
        : null;
    final sliderMin = isInfoExtracted
        ? VibeReference.minInfoExtracted
        : VibeReference.minSliderStrength;
    final sliderMax = isInfoExtracted
        ? VibeReference.maxInfoExtracted
        : VibeReference.maxSliderStrength;
    final sliderValue = value.clamp(sliderMin, sliderMax).toDouble();

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
            EditableDoubleField(
              value: value,
              min: fieldMin,
              max: fieldMax,
              width: 72,
              onChanged: onChanged,
              enabled: enabled,
              textStyle: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
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
            value: sliderValue,
            min: sliderMin,
            max: sliderMax,
            divisions: 99,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  /// 统计信息
  Widget _buildStatsSection(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingSm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: DesignTokens.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.vibeDetail_statistics,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          _buildStatRow(
            theme,
            l10n.vibeDetail_usageCount,
            l10n.vibeDetail_timesUsed(entry.usedCount),
          ),
          _buildStatRow(
            theme,
            l10n.vibeDetail_lastUsed,
            entry.lastUsedAt != null
                ? _formatDateTime(l10n, entry.lastUsedAt!)
                : l10n.vibeDetail_neverUsed,
          ),
          _buildStatRow(
            theme,
            l10n.vibeDetail_createdAt,
            _formatDateTime(l10n, entry.createdAt),
          ),
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
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  /// 操作按钮区域
  Widget _buildActionBar(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 420) {
            return Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSendToGeneration,
                    icon: const Icon(Icons.send),
                    label: Text(l10n.vibeLibrary_sendToGeneration),
                  ),
                ),
                const SizedBox(width: DesignTokens.spacingSm),
                PopupMenuButton<_VibeDetailAction>(
                  tooltip: l10n.common_moreActions,
                  constraints: const BoxConstraints(minWidth: 220),
                  onSelected: (action) {
                    switch (action) {
                      case _VibeDetailAction.save:
                        onSaveParams?.call();
                        break;
                      case _VibeDetailAction.rename:
                        onRename?.call();
                        break;
                      case _VibeDetailAction.export:
                        onExport?.call();
                        break;
                      case _VibeDetailAction.delete:
                        onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _VibeDetailAction.save,
                      enabled:
                          onSaveParams != null &&
                          canSaveParams &&
                          !isSavingParams,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: isSavingParams
                            ? const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        title: Text(l10n.vibeDetail_saveParameters),
                      ),
                    ),
                    PopupMenuItem(
                      value: _VibeDetailAction.rename,
                      enabled: onRename != null && !isRenaming,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.drive_file_rename_outline),
                        title: Text(l10n.common_rename),
                      ),
                    ),
                    PopupMenuItem(
                      value: _VibeDetailAction.export,
                      enabled: onExport != null,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.file_download_outlined),
                        title: Text(l10n.common_export),
                      ),
                    ),
                    PopupMenuItem(
                      value: _VibeDetailAction.delete,
                      enabled: onDelete != null,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          l10n.common_delete,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: canSaveParams && !isSavingParams
                      ? onSaveParams
                      : null,
                  icon: isSavingParams
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(l10n.vibeDetail_saveParameters),
                ),
              ),
              const SizedBox(height: DesignTokens.spacingSm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSendToGeneration,
                  icon: const Icon(Icons.send),
                  label: Text(l10n.vibeLibrary_sendToGeneration),
                ),
              ),
              const SizedBox(height: DesignTokens.spacingSm),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: isRenaming ? null : onRename,
                      icon: isRenaming
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.drive_file_rename_outline),
                      label: Text(l10n.common_rename),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacingSm),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.file_download_outlined),
                      label: Text(l10n.common_export),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacingSm),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.common_delete),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDateTime(AppLocalizations l10n, DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 6) {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
    if (diff.inDays > 1) return l10n.common_daysAgo(diff.inDays);
    if (diff.inDays == 1) return l10n.common_yesterday;
    if (diff.inHours > 0) return l10n.common_hoursAgo(diff.inHours);
    if (diff.inMinutes > 0) return l10n.common_minutesAgo(diff.inMinutes);
    return l10n.common_justNow;
  }
}
