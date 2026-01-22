import 'package:flutter/material.dart';

import '../../../../../data/models/prompt/time_condition.dart';

/// 时间条件面板
///
/// 用于配置特定日期范围启用的规则
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
        const SizedBox(height: 16),
        _buildEnableSwitch(),
        if (_hasCondition) ...[
          const SizedBox(height: 16),
          _buildPresetButtons(),
          const SizedBox(height: 16),
          _buildDateRangeEditor(),
          const SizedBox(height: 16),
          _buildOptionsSection(),
          const SizedBox(height: 16),
          _buildStatusCard(),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.calendar_month),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '时间条件',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildEnableSwitch() {
    return Card(
      child: SwitchListTile(
        title: const Text('启用时间条件'),
        subtitle: const Text('只在特定日期范围内生效'),
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
    );
  }

  Widget _buildPresetButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '预设模板',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip(
                  label: '🎄 圣诞节',
                  condition: TimeCondition.christmas(),
                ),
                _buildPresetChip(
                  label: '🎃 万圣节',
                  condition: TimeCondition.halloween(),
                ),
                _buildPresetChip(
                  label: '💕 情人节',
                  condition: TimeCondition.valentines(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required TimeCondition condition,
  }) {
    return ActionChip(
      label: Text(label),
      onPressed: widget.readOnly
          ? null
          : () {
              _updateCondition(condition.copyWith(id: _condition.id));
            },
    );
  }

  Widget _buildDateRangeEditor() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '日期范围',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMonthDaySelector(
                    label: '开始日期',
                    month: _condition.startMonth,
                    day: _condition.startDay,
                    onMonthChanged: (month) {
                      _updateCondition(_condition.copyWith(startMonth: month));
                    },
                    onDayChanged: (day) {
                      _updateCondition(_condition.copyWith(startDay: day));
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.arrow_forward),
                ),
                Expanded(
                  child: _buildMonthDaySelector(
                    label: '结束日期',
                    month: _condition.endMonth,
                    day: _condition.endDay,
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '首版不支持跨年日期范围',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
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
    );
  }

  Widget _buildMonthDaySelector({
    required String label,
    required int month,
    required int day,
    required ValueChanged<int> onMonthChanged,
    required ValueChanged<int> onDayChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: month,
                decoration: const InputDecoration(
                  labelText: '月',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(value: m, child: Text('$m 月'));
                }).toList(),
                onChanged: widget.readOnly ? null : (v) => onMonthChanged(v!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: day,
                decoration: const InputDecoration(
                  labelText: '日',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                items: List.generate(31, (i) => i + 1).map((d) {
                  return DropdownMenuItem(value: d, child: Text('$d 日'));
                }).toList(),
                onChanged: widget.readOnly ? null : (v) => onDayChanged(v!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Card(
      child: Column(
        children: [
          TextFormField(
            initialValue: _condition.name,
            decoration: const InputDecoration(
              labelText: '条件名称',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(16),
            ),
            readOnly: widget.readOnly,
            onChanged: (value) {
              _updateCondition(_condition.copyWith(name: value));
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('每年重复'),
            subtitle: const Text('每年相同日期范围自动启用'),
            value: _condition.recurring,
            onChanged: widget.readOnly
                ? null
                : (value) {
                    _updateCondition(_condition.copyWith(recurring: value));
                  },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('启用'),
            value: _condition.enabled,
            onChanged: widget.readOnly
                ? null
                : (value) {
                    _updateCondition(_condition.copyWith(enabled: value));
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isActive = _condition.isActive();
    final remaining = _condition.getRemainingDays();

    return Card(
      color: isActive
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.check_circle : Icons.schedule,
              color: isActive
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? '当前激活' : '未激活',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    isActive && remaining != null
                        ? '剩余 $remaining 天'
                        : _condition.displayText,
                    style: TextStyle(
                      color: isActive
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
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
}
