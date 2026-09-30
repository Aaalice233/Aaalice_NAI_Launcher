import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/time_condition.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../utils/single_line_text_width.dart';
import '../../../../widgets/common/elevated_card.dart';
import '../../../../widgets/common/surface_ink_well.dart';
import '../diy_panel_header.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

/// 时间条件面板
///
/// 用于配置特定日期范围启用的规则
/// 采用 Dimensional Layering 设计风格
class TimeConditionPanel extends StatefulWidget {
  /// 当前时间条件
  final TimeCondition? condition;

  /// 条件变更回调
  final ValueChanged<TimeCondition?> onConditionChanged;

  /// 是否只读
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
    _hasCondition = widget.condition != null;
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
      _hasCondition = widget.condition != null;
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
          _buildStatusCard(),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            _hasCondition ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 20,
            color: _hasCondition ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.diy_enableTimeCondition,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  context.l10n.diy_enableTimeConditionHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _hasCondition,
            onChanged: widget.readOnly
                ? null
                : (value) {
                    setState(() {
                      _hasCondition = value;
                    });
                    widget.onConditionChanged(value ? _condition : null);
                  },
          ),
        ],
      ),
    );
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

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DiySectionTitle(
            icon: Icons.auto_awesome_rounded,
            accent: colorScheme.secondary,
            container: colorScheme.secondaryContainer,
            title: context.l10n.diy_presetTemplates,
          ),
          const SizedBox(height: 12),
          Row(
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
                            _updateCondition(
                              condition.copyWith(id: _condition.id),
                            );
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
        ],
      ),
    );
  }

  Widget _buildDateRangeEditor() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DiySectionTitle(
            icon: Icons.date_range_rounded,
            accent: colorScheme.tertiary,
            container: colorScheme.tertiaryContainer,
            title: context.l10n.diy_dateRange,
          ),
          const SizedBox(height: 16),
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
      count: 12,
      onChanged: onMonthChanged,
    );
    final dayField = _buildNumberDropdown(
      label: context.l10n.diy_day,
      value: day,
      count: 31,
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

  Widget _buildNumberDropdown({
    required String label,
    required int value,
    required int count,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      iconSize: _fieldIconSize,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: _fieldPadding,
        isDense: true,
        // 紧凑字段没有纵向内边距，命中区由交互策略的最小控件尺寸保证
        constraints: BoxConstraints(
          minHeight: context.interactionPolicy.minimumControlExtent,
        ),
      ),
      items: [
        for (var number = 1; number <= count; number++)
          DropdownMenuItem(value: number, child: Text('$number')),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
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
          // 每年重复开关
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.repeat_rounded,
                  size: 20,
                  color: _condition.recurring
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.diy_repeatYearly,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        context.l10n.diy_repeatYearlyHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _condition.recurring,
                  onChanged: widget.readOnly
                      ? null
                      : (value) {
                          _updateCondition(
                            _condition.copyWith(recurring: value),
                          );
                        },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),
          // 启用开关
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _condition.enabled
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 20,
                  color: _condition.enabled
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.common_enabled,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Switch(
                  value: _condition.enabled,
                  onChanged: widget.readOnly
                      ? null
                      : (value) {
                          _updateCondition(_condition.copyWith(enabled: value));
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = _condition.isActive();
    final remaining = _condition.getRemainingDays();

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
          // 状态图标
          Container(
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
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive
                      ? context.l10n.diy_currentlyActive
                      : context.l10n.diy_inactive,
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
                      ? context.l10n.diy_daysRemaining(remaining)
                      : context.l10n.diy_timeRangeSummary(
                          _condition.name,
                          _condition.startMonth,
                          _condition.startDay,
                          _condition.endMonth,
                          _condition.endDay,
                        ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                // 徽标跟随状态文字换行，不与其争抢同一行宽度
                if (isActive) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
                        Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
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
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
