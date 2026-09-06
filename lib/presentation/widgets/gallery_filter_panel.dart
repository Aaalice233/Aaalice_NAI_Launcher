import 'package:flutter/material.dart';
import 'common/model_family_icon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

import '../providers/local_gallery_provider.dart';

/// Gallery Filter Panel Widget - Modern UI Design
/// 画廊筛选面板组件 - 现代化UI设计
///
/// Provides advanced filtering options for the local gallery
/// 为本地画廊提供高级筛选选项
class GalleryFilterPanel extends ConsumerStatefulWidget {
  const GalleryFilterPanel({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  ConsumerState<GalleryFilterPanel> createState() => _GalleryFilterPanelState();
}

class _GalleryFilterPanelState extends ConsumerState<GalleryFilterPanel> {
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _samplerController = TextEditingController();
  final TextEditingController _minStepsController = TextEditingController();
  final TextEditingController _maxStepsController = TextEditingController();
  final TextEditingController _minCfgController = TextEditingController();
  final TextEditingController _maxCfgController = TextEditingController();
  final TextEditingController _resolutionController = TextEditingController();

  // 常用预设
  static const List<String> _commonResolutions = [
    '832x1216',
    '1216x832',
    '1024x1024',
    '1024x1536',
    '1536x1024',
    '640x640',
  ];

  static const List<String> _commonSamplers = [
    'k_euler',
    'k_euler_ancestral',
    'k_dpmpp_2m',
    'k_dpmpp_sde',
    'k_dpmpp_2s_ancestral',
  ];

  static const List<String> _commonModels = [
    'nai-diffusion-4-curated-preview',
    'nai-diffusion-3',
    'nai-diffusion-furry-3',
  ];

  @override
  void initState() {
    super.initState();

    // Initialize with current filter values
    final state = ref.read(localGalleryNotifierProvider);
    _modelController.text = state.filterCriteria.filterModel ?? '';
    _samplerController.text = state.filterCriteria.filterSampler ?? '';
    _minStepsController.text =
        state.filterCriteria.filterMinSteps?.toString() ?? '';
    _maxStepsController.text =
        state.filterCriteria.filterMaxSteps?.toString() ?? '';
    _minCfgController.text =
        state.filterCriteria.filterMinCfg?.toString() ?? '';
    _maxCfgController.text =
        state.filterCriteria.filterMaxCfg?.toString() ?? '';
    _resolutionController.text = state.filterCriteria.filterResolution ?? '';
  }

  @override
  void dispose() {
    _modelController.dispose();
    _samplerController.dispose();
    _minStepsController.dispose();
    _maxStepsController.dispose();
    _minCfgController.dispose();
    _maxCfgController.dispose();
    _resolutionController.dispose();
    super.dispose();
  }

  /// Apply all filters
  void _applyFilters() {
    final notifier = ref.read(localGalleryNotifierProvider.notifier);

    // Parse values
    final model = _modelController.text.trim().isEmpty
        ? null
        : _modelController.text.trim();
    final sampler = _samplerController.text.trim().isEmpty
        ? null
        : _samplerController.text.trim();
    final minSteps = _minStepsController.text.trim().isEmpty
        ? null
        : int.tryParse(_minStepsController.text.trim());
    final maxSteps = _maxStepsController.text.trim().isEmpty
        ? null
        : int.tryParse(_maxStepsController.text.trim());
    final minCfg = _minCfgController.text.trim().isEmpty
        ? null
        : double.tryParse(_minCfgController.text.trim());
    final maxCfg = _maxCfgController.text.trim().isEmpty
        ? null
        : double.tryParse(_maxCfgController.text.trim());
    final resolution = _resolutionController.text.trim().isEmpty
        ? null
        : _resolutionController.text.trim();

    // Apply filters
    notifier.setFilterModel(model);
    notifier.setFilterSampler(sampler);
    notifier.setFilterSteps(minSteps, maxSteps);
    notifier.setFilterCfg(minCfg, maxCfg);
    notifier.setFilterResolution(resolution);

    Navigator.of(context).pop();
  }

  /// Reset all advanced filters
  void _resetFilters() {
    final notifier = ref.read(localGalleryNotifierProvider.notifier);

    notifier.setFilterModel(null);
    notifier.setFilterSampler(null);
    notifier.setFilterSteps(null, null);
    notifier.setFilterCfg(null, null);
    notifier.setFilterResolution(null);

    // Clear text fields with animation
    setState(() {
      _modelController.clear();
      _samplerController.clear();
      _minStepsController.clear();
      _maxStepsController.clear();
      _minCfgController.clear();
      _maxCfgController.clear();
      _resolutionController.clear();
    });
  }

  /// Check if any filter is active
  bool get _hasActiveFilters {
    return _modelController.text.isNotEmpty ||
        _samplerController.text.isNotEmpty ||
        _minStepsController.text.isNotEmpty ||
        _maxStepsController.text.isNotEmpty ||
        _minCfgController.text.isNotEmpty ||
        _maxCfgController.text.isNotEmpty ||
        _resolutionController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('galleryFilterScrollView'),
            controller: widget.scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.localGallery_filterSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                // Model filter card
                _buildFilterCard(
                  theme: theme,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  icon: Icons.auto_awesome,
                  iconColor: Colors.purple,
                  title: l10n.localGallery_filterByModel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModernTextField(
                        controller: _modelController,
                        isModel: true,
                        hintText: l10n.localGallery_modelHint,
                        theme: theme,
                        isDark: isDark,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 10),
                      _buildPresetChips(
                        presets: _commonModels,
                        isModel: true,
                        controller: _modelController,
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sampler filter card
                _buildFilterCard(
                  theme: theme,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  icon: Icons.timeline,
                  iconColor: Colors.blue,
                  title: l10n.localGallery_filterBySampler,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModernTextField(
                        controller: _samplerController,
                        hintText: l10n.localGallery_samplerHint,
                        theme: theme,
                        isDark: isDark,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 10),
                      _buildPresetChips(
                        presets: _commonSamplers,
                        controller: _samplerController,
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Keep each numeric range readable on narrow dialogs.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stepsFilter = _buildFilterCard(
                      theme: theme,
                      isDark: isDark,
                      colorScheme: colorScheme,
                      icon: Icons.layers,
                      iconColor: Colors.orange,
                      title: l10n.localGallery_filterBySteps,
                      compact: true,
                      child: _buildRangeInput(
                        minController: _minStepsController,
                        maxController: _maxStepsController,
                        theme: theme,
                        isDark: isDark,
                        colorScheme: colorScheme,
                        isInteger: true,
                      ),
                    );
                    final cfgFilter = _buildFilterCard(
                      theme: theme,
                      isDark: isDark,
                      colorScheme: colorScheme,
                      icon: Icons.tune,
                      iconColor: Colors.teal,
                      title: l10n.localGallery_filterByCfg,
                      compact: true,
                      child: _buildRangeInput(
                        minController: _minCfgController,
                        maxController: _maxCfgController,
                        theme: theme,
                        isDark: isDark,
                        colorScheme: colorScheme,
                        isInteger: false,
                      ),
                    );

                    if (constraints.maxWidth < 360) {
                      return Column(
                        key: const ValueKey('galleryFilterNarrowRangeGroups'),
                        children: [
                          stepsFilter,
                          const SizedBox(height: 12),
                          cfgFilter,
                        ],
                      );
                    }

                    return Row(
                      key: const ValueKey('galleryFilterWideRangeGroups'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: stepsFilter),
                        const SizedBox(width: 12),
                        Expanded(child: cfgFilter),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Resolution filter card
                _buildFilterCard(
                  theme: theme,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  icon: Icons.aspect_ratio,
                  iconColor: Colors.green,
                  title: l10n.localGallery_filterByResolution,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModernTextField(
                        controller: _resolutionController,
                        hintText: l10n.localGallery_resolutionHint,
                        theme: theme,
                        isDark: isDark,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 10),
                      _buildPresetChips(
                        presets: _commonResolutions,
                        controller: _resolutionController,
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildActionButtons(theme, l10n, isDark, colorScheme),
      ],
    );
  }

  /// Build a grouped filter surface.
  Widget _buildFilterCard({
    required ThemeData theme,
    required bool isDark,
    required ColorScheme colorScheme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          child,
        ],
      ),
    );
  }

  /// Build a filter text field.
  Widget _buildModernTextField({
    bool isModel = false,
    required TextEditingController controller,
    required String hintText,
    required ThemeData theme,
    required bool isDark,
    required ColorScheme colorScheme,
  }) {
    return ThemedInput(
      controller: controller,
      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      decoration: InputDecoration(
        prefixIcon: isModel && controller.text.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: ModelFamilyIcon(modelId: controller.text),
              )
            : null,
        hintText: hintText,
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          fontSize: 13,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  setState(() {
                    controller.clear();
                  });
                },
              )
            : null,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  /// Build range input (min ~ max)
  Widget _buildRangeInput({
    required TextEditingController minController,
    required TextEditingController maxController,
    required ThemeData theme,
    required bool isDark,
    required ColorScheme colorScheme,
    required bool isInteger,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildCompactTextField(
            controller: minController,
            hintText: context.l10n.common_minimum,
            theme: theme,
            isDark: isDark,
            colorScheme: colorScheme,
            isNumber: true,
            isInteger: isInteger,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.remove,
            size: 16,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        Expanded(
          child: _buildCompactTextField(
            controller: maxController,
            hintText: context.l10n.common_maximum,
            theme: theme,
            isDark: isDark,
            colorScheme: colorScheme,
            isNumber: true,
            isInteger: isInteger,
          ),
        ),
      ],
    );
  }

  /// Build compact text field for number inputs
  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String hintText,
    required ThemeData theme,
    required bool isDark,
    required ColorScheme colorScheme,
    bool isNumber = false,
    bool isInteger = true,
  }) {
    final policyExtent = context.interactionPolicy.minimumControlExtent;
    final minimumHeight = policyExtent < 44 ? 44.0 : policyExtent;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minimumHeight),
      child: ThemedInput(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: isNumber
            ? TextInputType.numberWithOptions(decimal: !isInteger)
            : TextInputType.text,
        inputFormatters: isNumber
            ? [
                FilteringTextInputFormatter.allow(
                  isInteger ? RegExp(r'[0-9]') : RegExp(r'[0-9.]'),
                ),
              ]
            : null,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  /// Build preset chips
  Widget _buildPresetChips({
    bool isModel = false,
    required List<String> presets,
    required TextEditingController controller,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: presets.map((preset) {
        final isSelected = controller.text == preset;
        return InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                controller.clear();
              } else {
                controller.text = preset;
              }
            });
          },
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: isModel
                ? ModelNameLabel(
                    modelId: preset,
                    iconSize: 14,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  )
                : Text(
                    preset,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
          ),
        );
      }).toList(),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons(
    ThemeData theme,
    AppLocalizations l10n,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final stackActions = constraints.maxWidth < 400 || textScale > 1.5;
          final activeIndicator = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.tertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: stackActions ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(Icons.filter_alt, size: 14, color: colorScheme.tertiary),
                const SizedBox(width: 4),
                if (stackActions)
                  Expanded(
                    child: Text(
                      l10n.localGallery_activeFiltersSet,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  Text(
                    l10n.localGallery_activeFiltersSet,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          );
          final resetButton = TextButton.icon(
            onPressed: _hasActiveFilters ? _resetFilters : null,
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: _hasActiveFilters
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            label: Text(
              l10n.localGallery_resetAdvancedFilters,
              style: TextStyle(
                color: _hasActiveFilters
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          );
          final applyButton = FilledButton.icon(
            onPressed: _applyFilters,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(l10n.localGallery_applyFilters),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          if (stackActions) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_hasActiveFilters) ...[
                  activeIndicator,
                  const SizedBox(height: 8),
                ],
                resetButton,
                const SizedBox(height: 8),
                applyButton,
              ],
            );
          }

          return Row(
            children: [
              if (_hasActiveFilters) activeIndicator,
              const Spacer(),
              resetButton,
              const SizedBox(width: 12),
              applyButton,
            ],
          );
        },
      ),
    );
  }
}

/// Show the filters through the shared adaptive form presenter.
Future<void> showGalleryFilterPanel(BuildContext context) {
  return AdaptivePresenter.showForm<void>(
    context: context,
    title: context.l10n.localGallery_advancedFilters,
    dialogWidth: 460,
    builder: (context, scrollController) =>
        GalleryFilterPanel(scrollController: scrollController),
  );
}
