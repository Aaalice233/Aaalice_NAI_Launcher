import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../core/services/file_export_service.dart';
import '../../../data/models/gallery/gallery_statistics.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../common/app_toast.dart';

/// Statistics Export Dialog
///
/// Provides export options for gallery statistics data in JSON or CSV format.
/// Allows users to save comprehensive statistics including:
/// - Overview statistics (total images, size, favorites, etc.)
/// - Model distribution
/// - Resolution distribution
/// - Sampler distribution
/// - Tag distribution
/// - Parameter distribution
/// - Size distribution
class StatisticsExportDialog extends ConsumerStatefulWidget {
  /// The statistics data to export
  final GalleryStatistics statistics;

  const StatisticsExportDialog({super.key, required this.statistics});

  /// Show the export dialog
  static Future<void> show(
    BuildContext context, {
    required GalleryStatistics statistics,
  }) async {
    await AdaptivePresenter.showPanel<void>(
      context: context,
      title: context.l10n.common_export,
      initialChildSize: 0.62,
      minChildSize: 0.48,
      builder: (context, _) => StatisticsExportDialog(statistics: statistics),
    );
  }

  @override
  ConsumerState<StatisticsExportDialog> createState() =>
      _StatisticsExportDialogState();
}

class _StatisticsExportDialogState
    extends ConsumerState<StatisticsExportDialog> {
  String _selectedFormat = 'json';
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final scrollController = PrimaryScrollController.maybeOf(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.bulkExport_format,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFormatOption(
                  theme,
                  l10n.bulkExport_jsonFormat,
                  'json',
                  Icons.code,
                ),
                const SizedBox(height: 8),
                _buildFormatOption(
                  theme,
                  l10n.bulkExport_csvFormat,
                  'csv',
                  Icons.table_chart,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getExportInfo(l10n),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isExporting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(l10n.common_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isExporting ? null : _handleExport,
                  icon: _isExporting
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: Text(l10n.common_export),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build a format option radio button
  Widget _buildFormatOption(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    final isSelected = _selectedFormat == value;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFormat = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(
                  alpha: isDark ? 0.3 : 0.5,
                )
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.3 : 0.2,
                ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: isDark ? 0.2 : 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 20,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  /// Get export info text based on selected format
  String _getExportInfo(AppLocalizations l10n) {
    return _selectedFormat == 'json'
        ? l10n.statistics_exportJsonHint
        : l10n.statistics_exportCsvHint;
  }

  /// Handle export action
  Future<void> _handleExport() async {
    setState(() {
      _isExporting = true;
    });

    try {
      String fileContent;
      String fileName;

      if (_selectedFormat == 'json') {
        fileContent = _generateJsonExport();
        fileName = 'statistics_${_getDateTimeString()}.json';
      } else {
        fileContent = _generateCsvExport();
        fileName = 'statistics_${_getDateTimeString()}.csv';
      }

      final extension = _selectedFormat;
      final savedLocation = await FileExportService.saveText(
        text: fileContent,
        fileName: fileName,
        dialogTitle: context.l10n.common_export,
        mimeType: extension == 'json' ? 'application/json' : 'text/csv',
        allowedExtensions: [extension],
      );
      if (savedLocation == null || !mounted) return;

      Navigator.of(context).pop();
      AppToast.success(context, context.l10n.toast_savedTo(savedLocation));
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, context.l10n.toast_exportFailed(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  /// Generate JSON export
  String _generateJsonExport() {
    final jsonData = {
      'exportedAt': DateTime.now().toIso8601String(),
      'statistics': {
        'overview': {
          'totalImages': widget.statistics.totalImages,
          'totalSizeBytes': widget.statistics.totalSizeBytes,
          'averageFileSizeBytes': widget.statistics.averageFileSizeBytes,
          'favoriteCount': widget.statistics.favoriteCount,
          'favoritePercentage': widget.statistics.favoritePercentage,
          'taggedImageCount': widget.statistics.taggedImageCount,
          'taggedImagePercentage': widget.statistics.taggedImagePercentage,
          'imagesWithMetadata': widget.statistics.imagesWithMetadata,
          'metadataPercentage': widget.statistics.metadataPercentage,
          'calculatedAt': widget.statistics.calculatedAt.toIso8601String(),
        },
        'modelDistribution': widget.statistics.modelDistribution
            .map(
              (model) => {
                'modelName': model.modelName,
                'count': model.count,
                'percentage': model.percentage,
              },
            )
            .toList(),
        'resolutionDistribution': widget.statistics.resolutionDistribution
            .map(
              (res) => {
                'label': res.label,
                'count': res.count,
                'percentage': res.percentage,
              },
            )
            .toList(),
        'samplerDistribution': widget.statistics.samplerDistribution
            .map(
              (sampler) => {
                'samplerName': sampler.samplerName,
                'count': sampler.count,
                'percentage': sampler.percentage,
              },
            )
            .toList(),
        'tagDistribution': widget.statistics.tagDistribution
            .map(
              (tag) => {
                'tagName': tag.tagName,
                'count': tag.count,
                'percentage': tag.percentage,
              },
            )
            .toList(),
        'parameterDistribution': widget.statistics.parameterDistribution
            .map(
              (param) => {
                'parameterName': param.parameterName,
                'value': param.value,
                'count': param.count,
                'percentage': param.percentage,
              },
            )
            .toList(),
        'sizeDistribution': widget.statistics.sizeDistribution
            .map(
              (size) => {
                'label': size.label,
                'count': size.count,
                'percentage': size.percentage,
              },
            )
            .toList(),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(jsonData);
  }

  /// Generate CSV export
  String _generateCsvExport() {
    final buffer = StringBuffer();

    // Overview section
    buffer.writeln('Gallery Statistics Export');
    buffer.writeln('Exported At,${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('Overview');
    buffer.writeln('Total Images,${widget.statistics.totalImages}');
    buffer.writeln(
      'Total Size (${widget.statistics.totalSizeFormatted}),${widget.statistics.totalSizeBytes}',
    );
    buffer.writeln(
      'Average Size (${widget.statistics.averageSizeFormatted}),${widget.statistics.averageFileSizeBytes.toInt()}',
    );
    buffer.writeln('Favorite Count,${widget.statistics.favoriteCount}');
    buffer.writeln(
      'Favorite Percentage,${widget.statistics.favoritePercentage.toStringAsFixed(2)}%',
    );
    buffer.writeln('Tagged Image Count,${widget.statistics.taggedImageCount}');
    buffer.writeln(
      'Tagged Image Percentage,${widget.statistics.taggedImagePercentage.toStringAsFixed(2)}%',
    );
    buffer.writeln(
      'Images With Metadata,${widget.statistics.imagesWithMetadata}',
    );
    buffer.writeln(
      'Metadata Percentage,${widget.statistics.metadataPercentage.toStringAsFixed(2)}%',
    );
    buffer.writeln(
      'Calculated At,${widget.statistics.calculatedAt.toIso8601String()}',
    );
    buffer.writeln();

    // Model distribution
    if (widget.statistics.modelDistribution.isNotEmpty) {
      buffer.writeln('Model Distribution');
      buffer.writeln('Model Name,Count,Percentage');
      for (final model in widget.statistics.modelDistribution) {
        buffer.writeln(
          '${_escapeCsv(model.modelName)},${model.count},${model.percentage.toStringAsFixed(2)}%',
        );
      }
      buffer.writeln();
    }

    // Resolution distribution
    if (widget.statistics.resolutionDistribution.isNotEmpty) {
      buffer.writeln('Resolution Distribution');
      buffer.writeln('Resolution,Count,Percentage');
      for (final resolution in widget.statistics.resolutionDistribution) {
        buffer.writeln(
          '${_escapeCsv(resolution.label)},${resolution.count},${resolution.percentage.toStringAsFixed(2)}%',
        );
      }
      buffer.writeln();
    }

    // Sampler distribution
    if (widget.statistics.samplerDistribution.isNotEmpty) {
      buffer.writeln('Sampler Distribution');
      buffer.writeln('Sampler Name,Count,Percentage');
      for (final sampler in widget.statistics.samplerDistribution) {
        buffer.writeln(
          '${_escapeCsv(sampler.samplerName)},${sampler.count},${sampler.percentage.toStringAsFixed(2)}%',
        );
      }
      buffer.writeln();
    }

    // Tag distribution
    if (widget.statistics.tagDistribution.isNotEmpty) {
      buffer.writeln('Tag Distribution');
      buffer.writeln('Tag Name,Count,Percentage');
      for (final tag in widget.statistics.tagDistribution) {
        buffer.writeln(
          '${_escapeCsv(tag.tagName)},${tag.count},${tag.percentage.toStringAsFixed(2)}%',
        );
      }
      buffer.writeln();
    }

    // Parameter distribution
    if (widget.statistics.parameterDistribution.isNotEmpty) {
      buffer.writeln('Parameter Distribution');
      buffer.writeln('Parameter Name,Value,Count,Percentage');
      for (final param in widget.statistics.parameterDistribution) {
        buffer.writeln(
          '${_escapeCsv(param.parameterName)},${_escapeCsv(param.value)},${param.count},${param.percentage.toStringAsFixed(2)}%',
        );
      }
      buffer.writeln();
    }

    // Size distribution
    if (widget.statistics.sizeDistribution.isNotEmpty) {
      buffer.writeln('Size Distribution');
      buffer.writeln('Size Range,Count,Percentage');
      for (final size in widget.statistics.sizeDistribution) {
        buffer.writeln(
          '${_escapeCsv(size.label)},${size.count},${size.percentage.toStringAsFixed(2)}%',
        );
      }
    }

    return buffer.toString();
  }

  /// Escape CSV values that contain commas or quotes
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Get date time string for file naming
  String _getDateTimeString() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }
}
