import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../providers/local_gallery_provider.dart';

/// Gallery Filter Panel Widget
/// 画廊筛选面板组件
///
/// Provides advanced filtering options for the local gallery
/// 为本地画廊提供高级筛选选项
class GalleryFilterPanel extends ConsumerStatefulWidget {
  const GalleryFilterPanel({super.key});

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

  @override
  void initState() {
    super.initState();
    // Initialize with current filter values
    final state = ref.read(localGalleryNotifierProvider);
    _modelController.text = state.filterModel ?? '';
    _samplerController.text = state.filterSampler ?? '';
    _minStepsController.text = state.filterMinSteps?.toString() ?? '';
    _maxStepsController.text = state.filterMaxSteps?.toString() ?? '';
    _minCfgController.text = state.filterMinCfg?.toString() ?? '';
    _maxCfgController.text = state.filterMaxCfg?.toString() ?? '';
    _resolutionController.text = state.filterResolution ?? '';
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

    // Close the panel if in a dialog
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

    // Clear text fields
    _modelController.clear();
    _samplerController.clear();
    _minStepsController.clear();
    _maxStepsController.clear();
    _minCfgController.clear();
    _maxCfgController.clear();
    _resolutionController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(
          color: theme.dividerColor.withOpacity(isDark ? 0.3 : 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.tune,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.localGallery_advancedFilters,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: l10n.common_close,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Filters
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Model filter
                  _buildFilterSection(
                    theme,
                    l10n.localGallery_filterByModel,
                    Icons.model_training,
                    _buildTextField(_modelController, 'e.g., NAI Diffusion V4'),
                  ),
                  const SizedBox(height: 16),

                  // Sampler filter
                  _buildFilterSection(
                    theme,
                    l10n.localGallery_filterBySampler,
                    Icons.tune,
                    _buildTextField(_samplerController, 'e.g., k_euler_a'),
                  ),
                  const SizedBox(height: 16),

                  // Steps filter
                  _buildFilterSection(
                    theme,
                    l10n.localGallery_filterBySteps,
                    Icons.stairs,
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _minStepsController,
                            l10n.common_clear, // Reuse as "Min"
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('~'),
                        ),
                        Expanded(
                          child: _buildTextField(
                            _maxStepsController,
                            'Max',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CFG filter
                  _buildFilterSection(
                    theme,
                    l10n.localGallery_filterByCfg,
                    Icons.tune_outlined,
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _minCfgController,
                            'Min',
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('~'),
                        ),
                        Expanded(
                          child: _buildTextField(
                            _maxCfgController,
                            'Max',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resolution filter
                  _buildFilterSection(
                    theme,
                    l10n.localGallery_filterByResolution,
                    Icons.aspect_ratio,
                    _buildTextField(_resolutionController, 'e.g., 1024x1024'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text(l10n.localGallery_resetAdvancedFilters),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(l10n.localGallery_applyFilters),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build a filter section with label and input
  Widget _buildFilterSection(
    ThemeData theme,
    String label,
    IconData icon,
    Widget input,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        input,
      ],
    );
  }

  /// Build a text input field
  Widget _buildTextField(TextEditingController controller, String hintText) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.6)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withOpacity(isDark ? 0.2 : 0.1),
        ),
      ),
      child: TextField(
        controller: controller,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(
              isDark ? 0.6 : 0.5,
            ),
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          isDense: true,
        ),
      ),
    );
  }
}

/// Show filter panel as a dialog
/// 以对话框形式显示筛选面板
void showGalleryFilterPanel(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const AlertDialog(
      backgroundColor: Colors.transparent,
      content: GalleryFilterPanel(),
      insetPadding: EdgeInsets.all(16),
    ),
  );
}
