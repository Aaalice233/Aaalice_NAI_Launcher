import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/time_condition.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../utils/single_line_text_width.dart';
import '../../../../widgets/common/elevated_card.dart';
import '../../../../widgets/common/surface_ink_well.dart';
import '../diy_panel_header.dart';
import '../diy_section_card.dart';
import '../diy_switch_card.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

/// 时间条件面板：词组只在指定的日期范围内参与抽取
class TimeConditionPanel extends StatefulWidget {
  final TimeCondition? condition;
  final ValueChanged<TimeCondition?> onConditionChanged;
  final bool readOnly;

  const TimeConditionPanel({
    super.key,
    this.condition,
    required this.onConditionChanged,
    this.readOnly = false,
  });

  @override
  State<TimeConditionPanel> createState() => _TimeConditionPanelState();
}

class _TimeConditionPanelState extends State<TimeConditionPanel> {
  late TimeCondition _condition;
  bool _hasCondition = false;
  bool _usesDefaultCondition = false;

  @override
  void initState() {
    super.initState();
    _hasCondition = widget.condition?.enabled ?? false;
    _usesDefaultCondition = widget.condition == null;
    _condition =
        widget.condition ??
        TimeCondition(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: '',
          startMonth: 12,
          startDay: 1,
          endMonth: 12,
          endDay: 31,
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_usesDefaultCondition && _condition.name.isEmpty) {
      _condition = _condition.copyWith(name: context.l10n.diy_timeDefaultName);
    }
  }

  @override
  void didUpdateWidget(TimeConditionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condition != widget.condition) {
      _hasCondition = widget.condition?.enabled ?? false;
      _usesDefaultCondition = widget.condition == null;
      if (widget.condition != null) {
        _condition = widget.condition!;
      } else {
        _condition = _condition.copyWith(
          name: context.l10n.diy_timeDefaultName,
        );
      }
    }
  }

  void _updateCondition(TimeCondition newCondition) {
    setState(() {
      _condition = newCondition;
    });
    if (_hasCondition) {
      widget.onConditionChanged(newCondition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildEnableSwitch(),
        if (_hasCondition) ...[
          const SizedBox(height: 12),
          _buildPresetButtons(),
          const SizedBox(height: 12),
          _buildDateRangeEditor(),
          const SizedBox(height: 12),
          _buildOptionsSection(),
          const SizedBox(height: 12),
          _TimeConditionStatusCard(condition: _condition),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return DiyPanelHeader(
      icon: Icons.calendar_month_rounded,
      accent: Theme.of(context).colorScheme.primary,
      title: context.l10n.diy_timeTitle,
      subtitle: context.l10n.diy_timeSubtitle,
    );
  }

  Widget _buildEnableSwitch() {
    return DiySwitchCard(
      title: context.l10n.diy_enableTimeCondition,
      subtitle: context.l10n.diy_enableTimeConditionHint,
      value: _hasCondition,
      onChanged: widget.readOnly ? null : _setHasCondition,
    );
  }

  void _setHasCondition(bool value) {
    setState(() {
      _hasCondition = value;
      if (value) _condition = _condition.copyWith(enabled: true);
    });
    // 关闭时移除条件而不是写 enabled: false，旧版本会把停用的条件当作永不生效
    widget.onConditionChanged(value ? _condition : null);
  }

  Widget _buildPresetButtons() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final presets = [
      (
        '🎄',
        context.l10n.diy_christmas,
        TimeCondition.christmas().copyWith(
          name: context.l10n.diy_christmas,
          description: context.l10n.diy_christmasDescription,
        ),
        Colors.green,
      ),
      (
        '🎃',
        context.l10n.diy_halloween,
        TimeCondition.halloween().copyWith(
          name: context.l10n.diy_halloween,
          description: context.l10n.diy_halloweenDescription,
        ),
        Colors.orange,
      ),
      (
        '💕',
        context.l10n.diy_valentinesDay,
        TimeCondition.valentines().copyWith(
          name: context.l10n.diy_valentinesDay,
          description: context.l10n.diy_valentinesDescription,
        ),
        Colors.pink,
      ),
    ];

    return DiySectionCard(
      icon: Icons.auto_awesome_rounded,
      accent: colorScheme.secondary,
      accentContainer: colorScheme.secondaryContainer,
      title: context.l10n.diy_presetTemplates,
      child: Row(
        children: presets.map((preset) {
          final (emoji, label, condition, color) = preset;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SurfaceInkWell(
                borderRadius: BorderRadius.circular(10),
                color: colorScheme.surfaceContainerHighest,
                onTap: widget.readOnly
                    ? null
                    : () {
                        _updateCondition(condition.copyWith(id: _condition.id));
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateRangeEditor() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DiySectionCard(
      icon: Icons.date_range_rounded,
      accent: colorScheme.tertiary,
      accentContainer: colorScheme.tertiaryContainer,
      title: context.l10n.diy_dateRange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) =>
                _buildDateRange(constraints.maxWidth),
          ),
          if (_condition.isCrossYear) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.errorContainer.withValues(alpha: 0.8),
                    colorScheme.errorContainer.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.diy_crossYearUnsupported,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _selectorPadding = EdgeInsets.all(12);
  static const _fieldPadding = EdgeInsets.symmetric(horizontal: 10);
  static const _fieldGap = 8.0;
  static const _fieldIconSize = 24.0;
  static const _arrowPadding = EdgeInsets.all(8);
  static const _arrowIconSize = 16.0;
  static const _arrowGap = 12.0;

  // 起止日期与月/日按实测宽度决定并排还是上下排，窄屏或放大文字时不挤压下拉框
  Widget _buildDateRange(double maxWidth) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final valueStyle = theme.textTheme.titleMedium;
    final labelStyle = theme.textTheme.bodySmall;
    final fieldWidth =
        [
          singleLineTextWidth(context, '31', valueStyle) + _fieldIconSize,
          singleLineTextWidth(context, context.l10n.diy_month, labelStyle),
          singleLineTextWidth(context, context.l10n.diy_day, labelStyle),
        ].reduce(math.max) +
        _fieldPadding.horizontal;
    final selectorWidth =
        fieldWidth * 2 + _fieldGap + _selectorPadding.horizontal;
    final arrowWidth =
        _arrowIconSize + _arrowPadding.horizontal + _arrowGap * 2;
    final selectorsSideBySide = selectorWidth * 2 + arrowWidth <= maxWidth;
    final fieldsSideBySide = selectorWidth <= maxWidth;

    final start = _buildMonthDaySelector(
      label: context.l10n.diy_startDate,
      month: _condition.startMonth,
      day: _condition.startDay,
      color: colorScheme.primary,
      fieldsSideBySide: fieldsSideBySide,
      onMonthChanged: (month) {
        _updateCondition(_condition.copyWith(startMonth: month));
      },
      onDayChanged: (day) {
        _updateCondition(_condition.copyWith(startDay: day));
      },
    );
    final end = _buildMonthDaySelector(
      label: context.l10n.diy_endDate,
      month: _condition.endMonth,
      day: _condition.endDay,
      color: colorScheme.secondary,
      fieldsSideBySide: fieldsSideBySide,
      onMonthChanged: (month) {
        _updateCondition(_condition.copyWith(endMonth: month));
      },
      onDayChanged: (day) {
        _updateCondition(_condition.copyWith(endDay: day));
      },
    );
    final arrow = Container(
      padding: _arrowPadding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        selectorsSideBySide
            ? Icons.arrow_forward_rounded
            : Icons.arrow_downward_rounded,
        size: _arrowIconSize,
        color: colorScheme.onSurfaceVariant,
      ),
    );

    if (selectorsSideBySide) {
      return Row(
        spacing: _arrowGap,
        children: [
          Expanded(child: start),
          arrow,
          Expanded(child: end),
        ],
      );
    }
    return Column(spacing: _fieldGap, children: [start, arrow, end]);
  }

  Widget _buildMonthDaySelector({
    required String label,
    required int month,
    required int day,
    required Color color,
    required bool fieldsSideBySide,
    required ValueChanged<int> onMonthChanged,
    required ValueChanged<int> onDayChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final monthField = _buildNumberDropdown(
      label: context.l10n.diy_month,
      value: month,
      options: _monthOptions,
      onChanged: onMonthChanged,
    );
    final dayField = _buildNumberDropdown(
      label: context.l10n.diy_day,
      value: day,
      options: _dayOptions,
      onChanged: onDayChanged,
    );

    return Container(
      padding: _selectorPadding,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.07),
          colorScheme.surfaceContainerLowest,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (fieldsSideBySide)
            Row(
              spacing: _fieldGap,
              children: [
                Expanded(child: monthField),
                Expanded(child: dayField),
              ],
            )
          else
            Column(
              spacing: _fieldGap,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [monthField, dayField],
            ),
        ],
      ),
    );
  }

  static final _monthOptions = [
    for (var month = 1; month <= 12; month++) month,
  ];
  static final _dayOptions = [for (var day = 1; day <= 31; day++) day];
  static const _selectableYearsAhead = 10;

  /// 从今年起的可选年份；已保存的往年也列出，保证当前值可见
  List<int> _yearOptions() {
    final currentYear = DateTime.now().year;
    final savedYear = _condition.specificYear;
    return {
      if (savedYear != null) savedYear,
      for (var offset = 0; offset <= _selectableYearsAhead; offset++)
        currentYear + offset,
    }.toList()..sort();
  }

  Widget _buildNumberDropdown({
    required String label,
    required int? value,
    required List<int> options,
    required ValueChanged<int> onChanged,
    String? helperText,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      iconSize: _fieldIconSize,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: _fieldPadding,
        isDense: true,
        // 紧凑字段没有纵向内边距，命中区由交互策略的最小控件尺寸保证
        constraints: BoxConstraints(
          minHeight: context.interactionPolicy.minimumControlExtent,
        ),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text('$option')),
      ],
      onChanged: widget.readOnly ? null : (selected) => onChanged(selected!),
    );
  }

  Widget _buildOptionsSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DiySectionTitle(
                  icon: Icons.label_outline_rounded,
                  accent: colorScheme.primary,
                  container: colorScheme.primaryContainer,
                  title: context.l10n.diy_conditionName,
                ),
                const SizedBox(height: 12),
                ThemedFormInput(
                  initialValue: _condition.name,
                  decoration: InputDecoration(
                    hintText: context.l10n.diy_conditionNameHint,
                    prefixIcon: Icon(
                      Icons.edit_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  readOnly: widget.readOnly,
                  onChanged: (value) {
                    _updateCondition(_condition.copyWith(name: value));
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DiySwitchRow(
              title: context.l10n.diy_repeatYearly,
              subtitle: _condition.recurring
                  ? context.l10n.diy_repeatYearlyHint
                  : context.l10n.diy_repeatOnceHint,
              value: _condition.recurring,
              icon: Icons.repeat_rounded,
              onChanged: widget.readOnly ? null : _setRecurring,
            ),
          ),
          if (!_condition.recurring)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: _buildNumberDropdown(
                label: context.l10n.diy_year,
                value: _condition.specificYear,
                options: _yearOptions(),
                helperText: _condition.specificYear == null
                    ? context.l10n.diy_yearUnsetHint
                    : null,
                onChanged: (year) {
                  _updateCondition(_condition.copyWith(specificYear: year));
                },
              ),
            ),
        ],
      ),
    );
  }

  void _setRecurring(bool recurring) {
    _updateCondition(
      recurring
          ? _condition.copyWith(recurring: true)
          : _condition.copyWith(
              recurring: false,
              specificYear: _condition.specificYear ?? DateTime.now().year,
            ),
    );
  }
}

/// 当前是否处于生效日期内，以及剩余天数或日期范围摘要
class _TimeConditionStatusCard extends StatelessWidget {
  const _TimeConditionStatusCard({required this.condition});

  final TimeCondition condition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final isActive = condition.isActive();
    final remaining = condition.getRemainingDays();
    return ElevatedCard(
      elevation: CardElevation.level2,
      borderRadius: 12,
      gradientBorder: isActive
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withValues(alpha: 0.6),
                colorScheme.secondary.withValues(alpha: 0.4),
              ],
            )
          : null,
      gradientBorderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatusIcon(isActive: isActive),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? l10n.diy_currentlyActive : l10n.diy_inactive,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive && remaining != null
                      ? l10n.diy_daysRemaining(remaining)
                      : l10n.diy_timeRangeSummary(
                          condition.name,
                          condition.startMonth,
                          condition.startDay,
                          condition.endMonth,
                          condition.endDay,
                        ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                // 徽标跟随状态文字换行，不与其争抢同一行宽度
                if (isActive) ...[
                  const SizedBox(height: 8),
                  const _ActiveBadge(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.8),
                ],
              )
            : null,
        color: isActive ? null : colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Icon(
        isActive ? Icons.celebration_rounded : Icons.schedule_rounded,
        color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.2),
            colorScheme.primary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.l10n.diy_activeBadge,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
