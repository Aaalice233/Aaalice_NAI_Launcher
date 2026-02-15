import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// Gallery Filter Panel Widget - Modern UI Design
/// 画廊筛选面板组件 - 现代化UI设计
///
/// Provides advanced filtering options for the local gallery
/// 为本地画廊提供高级筛选选项
class GalleryFilterPanel extends ConsumerStatefulWidget {
  const GalleryFilterPanel({super.key});

  @override
  ConsumerState<GalleryFilterPanel> createState() => _GalleryFilterPanelState();
}

class _GalleryFilterPanelState extends ConsumerState<GalleryFilterPanel>
    with SingleTickerProviderStateMixin {
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _samplerController = TextEditingController();
  final TextEditingController _minStepsController = TextEditingController();
  final TextEditingController _maxStepsController = TextEditingController();
  final TextEditingController _minCfgController = TextEditingController();
  final TextEditingController _maxCfgController = TextEditingController();
  final TextEditingController _resolutionController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    // 动画控制器
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();

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
    _animController.dispose();
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

    // Close the panel with animation
    _animController.reverse().then((_) {
      Navigator.of(context).pop();
    });
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

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: 460,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color:
                isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? colorScheme.outline.withOpacity(0.2)
                  : colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              _buildHeader(theme, l10n, isDark, colorScheme),

              // Filters content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              hintText: '输入模型名称...',
                              theme: theme,
                              isDark: isDark,
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 10),
                            _buildPresetChips(
                              presets: _commonModels,
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
                              hintText: '输入采样器名称...',
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

                      // Steps and CFG in a row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Steps filter
                          Expanded(
                            child: _buildFilterCard(
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
                            ),
                          ),
                          const SizedBox(width: 12),
                          // CFG filter
                          Expanded(
                            child: _buildFilterCard(
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
                            ),
                          ),
                        ],
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
                              hintText: '宽度x高度 (如: 1024x1024)',
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

              // Action buttons
              _buildActionButtons(theme, l10n, isDark, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  /// Build header with gradient background
  Widget _buildHeader(
    ThemeData theme,
    AppLocalizations l10n,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colorScheme.primary.withOpacity(0.15),
                  colorScheme.secondary.withOpacity(0.1),
                ]
              : [
                  colorScheme.primary.withOpacity(0.08),
                  colorScheme.secondary.withOpacity(0.05),
                ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.filter_list_rounded,
              color: colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.localGallery_advancedFilters,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '精确筛选您的图片集合',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              _animController.reverse().then((_) {
                Navigator.of(context).pop();
              });
            },
            tooltip: l10n.common_close,
            style: IconButton.styleFrom(
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a modern filter card
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
            ? colorScheme.surfaceContainerHighest.withOpacity(0.4)
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outline.withOpacity(isDark ? 0.15 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: iconColor,
                ),
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

  /// Build a modern text field
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hintText,
    required ThemeData theme,
    required bool isDark,
    required ColorScheme colorScheme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withOpacity(0.5)
            : colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outline.withOpacity(isDark ? 0.2 : 0.1),
        ),
      ),
      child: ThemedInput(
        controller: controller,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
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
      ),
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
            hintText: 'Min',
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
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
        ),
        Expanded(
          child: _buildCompactTextField(
            controller: maxController,
            hintText: 'Max',
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
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withOpacity(0.5)
            : colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withOpacity(isDark ? 0.2 : 0.1),
        ),
      ),
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
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
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
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withOpacity(0.15)
                  : colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withOpacity(0.5)
                    : colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Text(
              preset,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
            ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
            : colorScheme.surfaceContainerLowest.withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          // Active filter indicator
          if (_hasActiveFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.tertiary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_alt,
                    size: 14,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '已设置筛选',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Reset button
          TextButton.icon(
            onPressed: _hasActiveFilters ? _resetFilters : null,
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: _hasActiveFilters
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            label: Text(
              l10n.localGallery_resetAdvancedFilters,
              style: TextStyle(
                color: _hasActiveFilters
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Apply button
          FilledButton.icon(
            onPressed: _applyFilters,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(l10n.localGallery_applyFilters),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Show filter panel as a dialog
/// 以对话框形式显示筛选面板
void showGalleryFilterPanel(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => const Center(
      child: Material(
        color: Colors.transparent,
        child: GalleryFilterPanel(),
      ),
    ),
  );
}
