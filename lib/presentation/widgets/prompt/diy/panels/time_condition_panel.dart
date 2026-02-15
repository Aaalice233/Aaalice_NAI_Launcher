import 'package:flutter/material.dart';

import '../../../../../data/models/prompt/time_condition.dart';
import '../../../../widgets/common/elevated_card.dart';
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

  @override
  void initState() {
    super.initState();
    _hasCondition = widget.condition != null;
    _condition = widget.condition ??
        TimeCondition(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: '时间条件',
          startMonth: 12,
          startDay: 1,
          endMonth: 12,
          endDay: 31,
        );
  }

  @override
  void didUpdateWidget(TimeConditionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condition != widget.condition) {
      _hasCondition = widget.condition != null;
      if (widget.condition != null) {
        _condition = widget.condition!;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // 图标容器 - 渐变背景
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withOpacity(0.2),
                colorScheme.primary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.calendar_month_rounded,
            size: 20,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '时间条件',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '在特定日期范围内激活',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
                  '启用时间条件',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '只在特定日期范围内生效',
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
      ('🎄', '圣诞节', TimeCondition.christmas(), Colors.green),
      ('🎃', '万圣节', TimeCondition.halloween(), Colors.orange),
      ('💕', '情人节', TimeCondition.valentines(), Colors.pink),
    ];

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '预设模板',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: presets.map((preset) {
              final (emoji, label, condition, color) = preset;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.readOnly
                          ? null
                          : () {
                              _updateCondition(
                                condition.copyWith(id: _condition.id),
                              );
                            },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.date_range_rounded,
                  size: 14,
                  color: colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '日期范围',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMonthDaySelector(
                  label: '开始日期',
                  month: _condition.startMonth,
                  day: _condition.startDay,
                  color: colorScheme.primary,
                  onMonthChanged: (month) {
                    _updateCondition(_condition.copyWith(startMonth: month));
                  },
                  onDayChanged: (day) {
                    _updateCondition(_condition.copyWith(startDay: day));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: _buildMonthDaySelector(
                  label: '结束日期',
                  month: _condition.endMonth,
                  day: _condition.endDay,
                  color: colorScheme.secondary,
                  onMonthChanged: (month) {
                    _updateCondition(_condition.copyWith(endMonth: month));
                  },
                  onDayChanged: (day) {
                    _updateCondition(_condition.copyWith(endDay: day));
                  },
                ),
              ),
            ],
          ),
          if (_condition.isCrossYear) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.errorContainer.withOpacity(0.8),
                    colorScheme.errorContainer.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '首版不支持跨年日期范围',
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

  Widget _buildMonthDaySelector({
    required String label,
    required int month,
    required int day,
    required Color color,
    required ValueChanged<int> onMonthChanged,
    required ValueChanged<int> onDayChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: month,
                  decoration: InputDecoration(
                    labelText: '月',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    isDense: true,
                  ),
                  items: List.generate(12, (i) => i + 1).map((m) {
                    return DropdownMenuItem(value: m, child: Text('$m'));
                  }).toList(),
                  onChanged: widget.readOnly ? null : (v) => onMonthChanged(v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: day,
                  decoration: InputDecoration(
                    labelText: '日',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    isDense: true,
                  ),
                  items: List.generate(31, (i) => i + 1).map((d) {
                    return DropdownMenuItem(value: d, child: Text('$d'));
                  }).toList(),
                  onChanged: widget.readOnly ? null : (v) => onDayChanged(v!),
                ),
              ),
            ],
          ),
        ],
      ),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.label_outline_rounded,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '条件名称',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ThemedFormInput(
                  initialValue: _condition.name,
                  decoration: InputDecoration(
                    hintText: '输入条件名称',
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
          Divider(height: 1, color: colorScheme.outline.withOpacity(0.1)),
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
                        '每年重复',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '每年相同日期范围自动启用',
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
          Divider(height: 1, color: colorScheme.outline.withOpacity(0.1)),
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
                    '启用',
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
                colorScheme.primary.withOpacity(0.6),
                colorScheme.secondary.withOpacity(0.4),
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
                        colorScheme.primary.withOpacity(0.8),
                      ],
                    )
                  : null,
              color: isActive ? null : colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
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
                  isActive ? '当前激活' : '未激活',
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
                      ? '剩余 $remaining 天'
                      : _condition.displayText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.2),
                    colorScheme.primary.withOpacity(0.1),
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
                  Text(
                    'ACTIVE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
