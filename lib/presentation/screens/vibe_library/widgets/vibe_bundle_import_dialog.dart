import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_reference.dart';

enum BundleImportOption { keepAsBundle, split, importSelected }

class BundleImportResult {
  final BundleImportOption option;
  final List<int>? selectedIndices;
  final List<VibeReference>? configuredVibes;

  const BundleImportResult({
    required this.option,
    this.selectedIndices,
    this.configuredVibes,
  });
}

/// Vibe Bundle 导入选项对话框
class VibeBundleImportDialog extends StatefulWidget {
  final String bundleName;
  final List<String> vibeNames;
  final List<VibeReference>? vibeReferences;
  final List<Uint8List>? vibeThumbnails;
  final DateTime? createdAt;

  int get vibeCount => vibeNames.length;

  const VibeBundleImportDialog({
    super.key,
    required this.bundleName,
    required this.vibeNames,
    this.vibeReferences,
    this.vibeThumbnails,
    this.createdAt,
  });

  static Future<BundleImportResult?> show({
    required BuildContext context,
    required String bundleName,
    required List<String> vibeNames,
    List<VibeReference>? vibeReferences,
    List<Uint8List>? vibeThumbnails,
    DateTime? createdAt,
  }) {
    return showDialog<BundleImportResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VibeBundleImportDialog(
        bundleName: bundleName,
        vibeNames: vibeNames,
        vibeReferences: vibeReferences,
        vibeThumbnails: vibeThumbnails,
        createdAt: createdAt,
      ),
    );
  }

  @override
  State<VibeBundleImportDialog> createState() => _VibeBundleImportDialogState();
}

class _VibeBundleImportDialogState extends State<VibeBundleImportDialog> {
  BundleImportOption _selectedOption = BundleImportOption.keepAsBundle;
  final Set<int> _selectedIndices = {};
  late final List<double> _strengthValues;
  late final List<double> _infoExtractedValues;

  bool get _hasConfigurableVibes =>
      widget.vibeReferences != null &&
      widget.vibeReferences!.length == widget.vibeCount;

  @override
  void initState() {
    super.initState();
    _selectedIndices.addAll(List.generate(widget.vibeCount, (i) => i));
    _strengthValues = List<double>.generate(
      widget.vibeCount,
      (index) => _vibeAt(index)?.strength ?? 0.6,
    );
    _infoExtractedValues = List<double>.generate(
      widget.vibeCount,
      (index) => _vibeAt(index)?.infoExtracted ?? 0.7,
    );
    AppLogger.d(
      'VibeBundleImportDialog 初始化，bundle: ${widget.bundleName}, '
          'vibes: ${widget.vibeCount}',
      'VibeBundleImportDialog',
    );
  }

  VibeReference? _vibeAt(int index) {
    final references = widget.vibeReferences;
    if (references == null || index < 0 || index >= references.length) {
      return null;
    }
    return references[index];
  }

  List<VibeReference>? _buildConfiguredVibes() {
    if (!_hasConfigurableVibes) {
      return null;
    }

    return List<VibeReference>.generate(widget.vibeCount, (index) {
      return widget.vibeReferences![index].copyWith(
        strength: VibeReference.sanitizeStrength(_strengthValues[index]),
        infoExtracted: VibeReference.sanitizeInfoExtracted(
          _infoExtractedValues[index],
        ),
      );
    });
  }

  void _confirm() {
    final result = BundleImportResult(
      option: _selectedOption,
      selectedIndices: _selectedOption == BundleImportOption.importSelected
          ? (_selectedIndices.toList()..sort())
          : null,
      configuredVibes: _buildConfiguredVibes(),
    );

    AppLogger.i(
      'Bundle 导入确认: option=${_selectedOption.name}, '
          'selectedCount=${result.selectedIndices?.length ?? "N/A"}',
      'VibeBundleImportDialog',
    );

    Navigator.of(context).pop(result);
  }

  void _cancel() {
    AppLogger.i('Bundle 导入取消', 'VibeBundleImportDialog');
    Navigator.of(context).pop();
  }

  void _toggleVibeSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
    AppLogger.d(
      'Vibe 选择改变: index=$index, selected=${_selectedIndices.contains(index)}',
      'VibeBundleImportDialog',
    );
  }

  void _selectAll() {
    setState(() {
      _selectedIndices.addAll(List.generate(widget.vibeCount, (i) => i));
    });
  }

  void _selectNone() {
    setState(() => _selectedIndices.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          minWidth: 400,
          maxHeight: 850,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 20),
              _buildBundleInfo(theme),
              const SizedBox(height: 20),
              _buildImportOptions(theme),
              if (_hasConfigurableVibes) ...[
                const SizedBox(height: 16),
                _buildParameterHeader(theme),
                const SizedBox(height: 12),
                Flexible(child: _buildVibeParameterList(theme)),
              ] else if (_selectedOption ==
                  BundleImportOption.importSelected) ...[
                const SizedBox(height: 16),
                _buildSelectionHeader(theme),
                const SizedBox(height: 12),
                Flexible(child: _buildVibeSelectionList(theme)),
              ],
              const SizedBox(height: 20),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.folder_zip, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.l10n.vibe_import_bundleTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancel,
          tooltip: context.l10n.common_cancel,
        ),
      ],
    );
  }

  Widget _buildBundleInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.bundleName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                theme,
                icon: Icons.waves,
                label: context.l10n.vibeLibrary_totalCount(widget.vibeCount),
              ),
              const SizedBox(width: 12),
              if (widget.createdAt != null)
                _buildInfoChip(
                  theme,
                  icon: Icons.calendar_today,
                  label: _formatDate(widget.createdAt!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildImportOptions(ThemeData theme) {
    return RadioGroup<BundleImportOption>(
      groupValue: _selectedOption,
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedOption = value);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.vibe_import_bundleChooseMethod,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildOptionTile(
            theme,
            option: BundleImportOption.keepAsBundle,
            icon: Icons.folder_zip,
            title: context.l10n.vibe_import_bundleAsWhole,
            subtitle: context.l10n.vibe_import_bundleAsWholeDescription,
          ),
          const SizedBox(height: 8),
          _buildOptionTile(
            theme,
            option: BundleImportOption.split,
            icon: Icons.splitscreen,
            title: context.l10n.vibe_import_bundleSplitEntries,
            subtitle: context.l10n.vibe_import_bundleSplitEntriesDescription,
          ),
          const SizedBox(height: 8),
          _buildOptionTile(
            theme,
            option: BundleImportOption.importSelected,
            icon: Icons.checklist,
            title: context.l10n.vibe_import_bundleSelectVibes,
            subtitle: context.l10n.vibe_import_bundleSelectVibesDescription,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    ThemeData theme, {
    required BundleImportOption option,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedOption == option;

    return InkWell(
      onTap: () => setState(() => _selectedOption = option),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
        ),
        child: Row(
          children: [
            Radio<BundleImportOption>(value: option),
            const SizedBox(width: 8),
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionHeader(ThemeData theme) {
    final allSelected = _selectedIndices.length == widget.vibeCount;
    final noneSelected = _selectedIndices.isEmpty;

    return Row(
      children: [
        Text(
          context.l10n.vibe_import_bundleSelectVibes,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: allSelected ? null : _selectAll,
          child: Text(context.l10n.common_selectAll),
        ),
        TextButton(
          onPressed: noneSelected ? null : _selectNone,
          child: Text(context.l10n.common_deselectAll),
        ),
      ],
    );
  }

  Widget _buildParameterHeader(ThemeData theme) {
    final isSelectable = _selectedOption == BundleImportOption.importSelected;
    final allSelected = _selectedIndices.length == widget.vibeCount;
    final noneSelected = _selectedIndices.isEmpty;

    return Row(
      children: [
        Expanded(
          child: Text(
            isSelectable
                ? context.l10n.vibe_import_bundleSelectAndConfigureEachVibe
                : context.l10n.vibe_import_bundleConfigureEachVibe,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (isSelectable) ...[
          TextButton(
            onPressed: allSelected ? null : _selectAll,
            child: Text(context.l10n.common_selectAll),
          ),
          TextButton(
            onPressed: noneSelected ? null : _selectNone,
            child: Text(context.l10n.common_deselectAll),
          ),
        ],
      ],
    );
  }

  Widget _buildVibeParameterList(ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: widget.vibeCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final vibeName = widget.vibeNames[index];
        final thumbnail =
            widget.vibeThumbnails != null &&
                index < widget.vibeThumbnails!.length
            ? widget.vibeThumbnails![index]
            : _vibeAt(index)?.thumbnail;
        final isImportSelected =
            _selectedOption == BundleImportOption.importSelected;
        final isSelected =
            !isImportSelected || _selectedIndices.contains(index);

        return _buildVibeParameterCard(
          theme,
          index: index,
          name: vibeName,
          thumbnail: thumbnail,
          isSelected: isSelected,
          showSelection: isImportSelected,
        );
      },
    );
  }

  Widget _buildVibeParameterCard(
    ThemeData theme, {
    required int index,
    required String name,
    Uint8List? thumbnail,
    required bool isSelected,
    required bool showSelection,
  }) {
    final opacity = isSelected ? 1.0 : 0.45;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.35)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSelection)
              Checkbox(
                value: _selectedIndices.contains(index),
                onChanged: (_) => _toggleVibeSelection(index),
                visualDensity: VisualDensity.compact,
              ),
            _buildParameterThumbnail(theme, index, thumbnail),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _buildParamSlider(
                    theme,
                    label: context.l10n.vibe_strength,
                    value: _strengthValues[index],
                    min: VibeReference.minStrength,
                    max: VibeReference.maxStrength,
                    divisions: 200,
                    enabled: isSelected,
                    onChanged: (value) {
                      setState(() => _strengthValues[index] = value);
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildParamSlider(
                    theme,
                    label: context.l10n.vibe_infoExtracted,
                    value: _infoExtractedValues[index],
                    min: VibeReference.minInfoExtracted,
                    max: VibeReference.maxInfoExtracted,
                    divisions: 100,
                    enabled: isSelected,
                    onChanged: (value) {
                      setState(() => _infoExtractedValues[index] = value);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterThumbnail(
    ThemeData theme,
    int index,
    Uint8List? thumbnail,
  ) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: thumbnail != null
          ? Image.memory(
              thumbnail,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildItemPlaceholder(theme, index),
            )
          : _buildItemPlaceholder(theme, index),
    );
  }

  Widget _buildItemPlaceholder(ThemeData theme, int index) {
    return Center(
      child: Text(
        '${index + 1}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildParamSlider(
    ThemeData theme, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.end,
            style: theme.textTheme.labelSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVibeSelectionList(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double minItemWidth = 100;
        final crossAxisCount = (constraints.maxWidth / minItemWidth)
            .floor()
            .clamp(2, 4);

        return GridView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: widget.vibeCount,
          itemBuilder: (context, index) {
            final vibeName = widget.vibeNames[index];
            final thumbnail =
                widget.vibeThumbnails != null &&
                    index < widget.vibeThumbnails!.length
                ? widget.vibeThumbnails![index]
                : null;
            final isSelected = _selectedIndices.contains(index);

            return _buildVibeGridCard(
              theme,
              index: index,
              name: vibeName,
              thumbnail: thumbnail,
              isSelected: isSelected,
            );
          },
        );
      },
    );
  }

  Widget _buildVibeGridCard(
    ThemeData theme, {
    required int index,
    required String name,
    Uint8List? thumbnail,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleVibeSelection(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: isSelected ? 2.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                : theme.colorScheme.surface,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      thumbnail != null
                          ? Image.memory(
                              thumbnail,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 28,
                                    color: theme.colorScheme.outline,
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Icon(
                                Icons.image,
                                size: 28,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                      if (isSelected)
                        Container(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      if (isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.shadow.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontSize: 12,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${index + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    final canConfirm =
        _selectedOption != BundleImportOption.importSelected ||
        _selectedIndices.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_selectedOption == BundleImportOption.importSelected) ...[
          Text(
            context.l10n.vibe_import_bundleSelectedCount(
              _selectedIndices.length,
              widget.vibeCount,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 16),
        ],
        TextButton(onPressed: _cancel, child: Text(context.l10n.common_cancel)),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: canConfirm ? _confirm : null,
          icon: const Icon(Icons.download),
          label: Text(context.l10n.common_import),
        ),
      ],
    );
  }
}
