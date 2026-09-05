import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/online_gallery/danbooru_post.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../providers/online_gallery_state.dart';

/// Structural toolbar widget. The four slots intentionally mirror the fixed
/// responsibilities of the gallery toolbar instead of grouping controls by
/// source.
class OnlineGalleryToolbar extends StatelessWidget {
  const OnlineGalleryToolbar({
    super.key,
    required this.leading,
    required this.query,
    required this.trailing,
    required this.secondary,
    required this.showQuery,
    required this.scrollPrimary,
    required this.collapseSecondary,
    required this.queryWidth,
    required this.queryRevealKey,
    required this.onShowSourceFilters,
    required this.filterLabel,
  });

  final Widget leading;
  final Widget query;
  final Widget trailing;
  final Widget secondary;
  final bool showQuery;
  final bool scrollPrimary;
  final bool collapseSecondary;
  final double queryWidth;
  final GlobalKey queryRevealKey;
  final VoidCallback onShowSourceFilters;
  final String filterLabel;

  @override
  Widget build(BuildContext context) {
    final primary = scrollPrimary
        ? LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              key: const ValueKey('online-gallery-primary-controls-scroll'),
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ToolbarLeading(child: leading),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showQuery) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            width: queryWidth,
                            child: _ToolbarQuery(
                              revealKey: queryRevealKey,
                              child: query,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        _ToolbarTrailing(child: trailing),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        : Row(
            children: [
              _ToolbarLeading(child: leading),
              if (showQuery) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    key: const ValueKey('online-gallery-primary-search'),
                    child: query,
                  ),
                ),
              ] else
                const Spacer(),
              const SizedBox(width: 8),
              _ToolbarTrailing(child: trailing),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const ValueKey('online-gallery-toolbar-primary-row'),
          height: galleryToolbarControlHeightFor(context),
          child: primary,
        ),
        const SizedBox(height: 8),
        _ToolbarSecondary(
          collapsed: collapseSecondary,
          onShowSourceFilters: onShowSourceFilters,
          filterLabel: filterLabel,
          child: secondary,
        ),
      ],
    );
  }
}

class _ToolbarLeading extends StatelessWidget {
  const _ToolbarLeading({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _ToolbarQuery extends StatelessWidget {
  const _ToolbarQuery({required this.revealKey, required this.child});

  final GlobalKey revealKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('online-gallery-primary-search'),
      child: KeyedSubtree(key: revealKey, child: child),
    );
  }
}

class _ToolbarTrailing extends StatelessWidget {
  const _ToolbarTrailing({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _ToolbarSecondary extends StatelessWidget {
  const _ToolbarSecondary({
    required this.collapsed,
    required this.onShowSourceFilters,
    required this.filterLabel,
    required this.child,
  });

  final bool collapsed;
  final VoidCallback onShowSourceFilters;
  final String filterLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('online-gallery-toolbar-secondary-row'),
      height: gallerySecondaryToolbarHeightFor(context),
      child: Row(
        children: [
          if (collapsed) ...[
            const Spacer(),
            FilledButton.tonalIcon(
              key: const ValueKey('online-gallery-source-filters'),
              onPressed: onShowSourceFilters,
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: Text(filterLabel),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity:
                    context.interactionPolicy.prefersTouchPresentation
                    ? VisualDensity.standard
                    : VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ] else
            Flexible(
              flex: 6,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}

double galleryToolbarControlHeightFor(BuildContext context) => max(
  context.interactionPolicy.minimumControlExtent,
  MediaQuery.textScalerOf(context).scale(16) + 20,
);

double gallerySearchFieldHeightFor(BuildContext context) => max(
  context.interactionPolicy.minimumControlExtent,
  MediaQuery.textScalerOf(context).scale(16) + 16,
);

double gallerySecondaryToolbarHeightFor(BuildContext context) => max(
  context.interactionPolicy.minimumControlExtent,
  MediaQuery.textScalerOf(context).scale(16) + 20,
);

/// 模式切换按钮
class OnlineGalleryModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;
  final bool compact;
  final String? disabledHint;
  final Color selectedBackgroundColor;
  final Color selectedForegroundColor;

  const OnlineGalleryModeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
    this.compact = false,
    this.disabledHint,
    required this.selectedBackgroundColor,
    required this.selectedForegroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(8) : Radius.zero,
      right: isLast ? const Radius.circular(8) : Radius.zero,
    );
    final enabled = onTap != null;
    final foregroundColor = !enabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
        : isSelected
        ? selectedForegroundColor
        : theme.colorScheme.onSurfaceVariant;

    final tooltip = disabledHint ?? label;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: isSelected,
        child: Material(
          color: isSelected ? selectedBackgroundColor : Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            hoverColor: isSelected
                ? Colors.transparent
                : selectedBackgroundColor.withValues(alpha: 0.08),
            focusColor: selectedBackgroundColor.withValues(alpha: 0.14),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: galleryToolbarControlHeightFor(context),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!compact) ...[
                      Icon(icon, size: 18, color: foregroundColor),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: foregroundColor,
                      ),
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

/// 数据源下拉
class OnlineGallerySourceDropdown extends StatelessWidget {
  final GallerySourceId selected;
  final Map<GallerySourceId, String> sources;
  final String? selectedLabel;
  final double maxLabelWidth;
  final bool expandLabel;
  final ValueChanged<GallerySourceId> onChanged;

  const OnlineGallerySourceDropdown({
    super.key,
    required this.selected,
    required this.sources,
    this.selectedLabel,
    this.maxLabelWidth = 150,
    this.expandLabel = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<GallerySourceId>(
      key: const ValueKey('online-gallery-source-selector'),
      tooltip: sources[selected] ?? selected.label,
      onSelected: onChanged,
      offset: Offset(0, galleryToolbarControlHeightFor(context) + 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => sources.entries.map((e) {
        final isSelected = selected == e.key;
        return PopupMenuItem<GallerySourceId>(
          value: e.key,
          child: Row(
            children: [
              Text(
                e.value,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: galleryToolbarControlHeightFor(context),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (expandLabel)
              Expanded(
                child: Text(
                  selectedLabel ?? sources[selected] ?? selected.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxLabelWidth),
                child: Text(
                  selectedLabel ?? sources[selected] ?? selected.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 模糊匹配开关
class OnlineGalleryFuzzySearchToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const OnlineGalleryFuzzySearchToggle({
    super.key,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilterChip(
      selected: enabled,
      showCheckmark: false,
      avatar: Icon(
        Icons.manage_search_rounded,
        size: 16,
        color: enabled
            ? theme.colorScheme.secondary
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(
        context.l10n.onlineGallery_fuzzySearch,
        style: const TextStyle(fontSize: 12),
      ),
      tooltip: context.l10n.onlineGallery_fuzzySearchTooltip,
      onSelected: onChanged,
      visualDensity: context.interactionPolicy.prefersTouchPresentation
          ? VisualDensity.standard
          : VisualDensity.compact,
      materialTapTargetSize:
          context.interactionPolicy.shouldExposeTouchAlternatives
          ? MaterialTapTargetSize.padded
          : MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      selectedColor: theme.colorScheme.secondaryContainer,
      backgroundColor: Colors.transparent,
      side: BorderSide.none,
    );
  }
}

class OnlineGalleryDateRangePopup extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;
  final void Function(DateTime start, DateTime end) onApply;
  final VoidCallback onClear;
  final VoidCallback onClose;

  const OnlineGalleryDateRangePopup({
    super.key,
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
    required this.onApply,
    required this.onClear,
    required this.onClose,
  });

  @override
  State<OnlineGalleryDateRangePopup> createState() =>
      OnlineGalleryDateRangePopupState();
}

class OnlineGalleryDateRangePopupState
    extends State<OnlineGalleryDateRangePopup> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = _clampDate(
      widget.initialStart ?? widget.lastDate.subtract(const Duration(days: 30)),
    );
    _end = _clampDate(widget.initialEnd ?? widget.lastDate);
    _normalizeRange();
  }

  DateTime _clampDate(DateTime date) {
    if (date.isBefore(widget.firstDate)) return widget.firstDate;
    if (date.isAfter(widget.lastDate)) return widget.lastDate;
    return DateTime(date.year, date.month, date.day);
  }

  void _normalizeRange() {
    if (_start.isAfter(_end)) {
      final previousStart = _start;
      _start = _end;
      _end = previousStart;
    }
  }

  void _setLast30Days() {
    setState(() {
      _start = _clampDate(widget.lastDate.subtract(const Duration(days: 30)));
      _end = _clampDate(widget.lastDate);
    });
  }

  void _apply() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    form.save();
    _normalizeRange();
    widget.onApply(_start, _end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 340,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.onlineGallery_dateRange,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity:
                        context.interactionPolicy.prefersTouchPresentation
                        ? VisualDensity.standard
                        : VisualDensity.compact,
                    tooltip: context.l10n.common_close,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InputDatePickerFormField(
                key: ValueKey('start_${_start.toIso8601String()}'),
                initialDate: _start,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                fieldLabelText: context.l10n.onlineGallery_startDate,
                fieldHintText: 'yyyy-mm-dd',
                errorFormatText: context.l10n.onlineGallery_invalidDateFormat,
                errorInvalidText: context.l10n.onlineGallery_dateOutOfRange,
                onDateSaved: (date) => _start = _clampDate(date),
              ),
              const SizedBox(height: 10),
              InputDatePickerFormField(
                key: ValueKey('end_${_end.toIso8601String()}'),
                initialDate: _end,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                fieldLabelText: context.l10n.onlineGallery_endDate,
                fieldHintText: 'yyyy-mm-dd',
                errorFormatText: context.l10n.onlineGallery_invalidDateFormat,
                errorInvalidText: context.l10n.onlineGallery_dateOutOfRange,
                onDateSaved: (date) => _end = _clampDate(date),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: _setLast30Days,
                      child: Text(context.l10n.onlineGallery_last30Days),
                    ),
                    TextButton(
                      onPressed: widget.onClear,
                      child: Text(context.l10n.onlineGallery_clear),
                    ),
                    FilledButton(
                      onPressed: _apply,
                      child: Text(context.l10n.common_apply),
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
}

/// 评级下拉
class OnlineGalleryRatingDropdown extends StatelessWidget {
  final Set<String> selectedRatings;
  final ValueChanged<String> onToggle;
  final Set<String> availableRatings;
  final bool compact;

  const OnlineGalleryRatingDropdown({
    super.key,
    required this.selectedRatings,
    required this.onToggle,
    this.availableRatings = kAllRatings,
    this.compact = false,
  });

  List<(String, String, Color?)> _getRatings(BuildContext context) => [
    ('all', context.l10n.onlineGallery_all, null),
    if (availableRatings.contains('g'))
      ('g', context.l10n.onlineGallery_ratingGeneral, Colors.green),
    if (availableRatings.contains('s'))
      ('s', context.l10n.onlineGallery_ratingSensitive, Colors.amber),
    if (availableRatings.contains('q'))
      ('q', context.l10n.onlineGallery_ratingQuestionable, Colors.orange),
    if (availableRatings.contains('e'))
      ('e', context.l10n.onlineGallery_ratingExplicit, Colors.red),
  ];

  Color _ratingColor(String ratingCode) {
    switch (ratingCode) {
      case 'g':
        return Colors.green;
      case 's':
        return Colors.amber;
      case 'q':
        return Colors.orange;
      case 'e':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRatingIndicator(ThemeData theme, List<String> selectedCodes) {
    if (selectedCodes.isEmpty) return const SizedBox.shrink();

    final visibleCount = min(3, selectedCodes.length);
    final hasMore = selectedCodes.length > visibleCount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(visibleCount, (index) {
          final code = selectedCodes[index];
          return Padding(
            padding: EdgeInsets.only(right: index == visibleCount - 1 ? 0 : 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _ratingColor(code),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
        if (hasMore) ...[
          const SizedBox(width: 4),
          Text(
            '+${selectedCodes.length - visibleCount}',
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratings = _getRatings(context);
    final isAllSelected = selectedRatings.containsAll(availableRatings);
    final selectedCodesInOrder = [
      'g',
      's',
      'q',
      'e',
    ].where(availableRatings.contains).where(selectedRatings.contains).toList();
    final selectedSpecific = ratings
        .where((r) => r.$1 != 'all' && selectedRatings.contains(r.$1))
        .toList();
    final current = isAllSelected
        ? ratings.first
        : (selectedSpecific.isNotEmpty
              ? selectedSpecific.first
              : ratings.first);

    String buttonText() {
      if (isAllSelected) return current.$2;
      if (selectedSpecific.length == 1) return selectedSpecific.first.$2;
      if (selectedSpecific.length > 1) {
        return '${selectedSpecific.first.$2} +${selectedSpecific.length - 1}';
      }
      return current.$2;
    }

    return PopupMenuButton<String>(
      key: const ValueKey('online-gallery-rating-filter'),
      onSelected: onToggle,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (menuContext) => ratings.map((r) {
        final isSelected = r.$1 == 'all'
            ? isAllSelected
            : selectedRatings.contains(r.$1);
        return PopupMenuItem<String>(
          value: r.$1,
          child: Row(
            children: [
              if (r.$3 != null)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: r.$3,
                    shape: BoxShape.circle,
                  ),
                ),
              if (r.$3 != null) const SizedBox(width: 8),
              Text(
                r.$2,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
              ],
            ],
          ),
        );
      }).toList(),
      tooltip: buttonText(),
      child: Container(
        height: galleryToolbarControlHeightFor(context),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current.$3 != null) ...[
              _buildRatingIndicator(theme, selectedCodesInOrder),
              const SizedBox(width: 6),
            ],
            Text(
              compact
                  ? (isAllSelected || selectedCodesInOrder.isEmpty
                        ? current.$2
                        : selectedCodesInOrder
                              .map((code) => code.toUpperCase())
                              .join('/'))
                  : buttonText(),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: compact ? 2 : 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
