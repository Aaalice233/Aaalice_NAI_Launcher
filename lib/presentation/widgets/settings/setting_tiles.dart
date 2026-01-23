import 'package:flutter/material.dart';

/// 滑块设置项
///
/// 用于显示带有标题、描述和滑块的设置项
class SliderSettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double)? valueFormatter;
  final ValueChanged<double>? onChanged;
  final Widget? leading;

  const SliderSettingTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    this.valueFormatter,
    required this.onChanged,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = valueFormatter?.call(value) ?? value.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                displayValue,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// 整数滑块设置项
///
/// SliderSettingTile 的整数版本
class IntSliderSettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int value;
  final int min;
  final int max;
  final String Function(int)? valueFormatter;
  final ValueChanged<int>? onChanged;
  final Widget? leading;

  const IntSliderSettingTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.valueFormatter,
    required this.onChanged,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return SliderSettingTile(
      title: title,
      subtitle: subtitle,
      value: value.toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: max - min,
      valueFormatter: (v) => valueFormatter?.call(v.round()) ?? v.round().toString(),
      onChanged: onChanged != null ? (v) => onChanged!(v.round()) : null,
      leading: leading,
    );
  }
}

/// 范围滑块设置项
///
/// 用于设置最小值和最大值范围
class RangeSliderSettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int start;
  final int end;
  final int min;
  final int max;
  final String Function(int, int)? valueFormatter;
  final void Function(int start, int end)? onChanged;
  final Widget? leading;

  const RangeSliderSettingTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.start,
    required this.end,
    required this.min,
    required this.max,
    this.valueFormatter,
    required this.onChanged,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = valueFormatter?.call(start, end) ?? '$start - $end';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                displayValue,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
            ),
            child: RangeSlider(
              values: RangeValues(
                start.toDouble().clamp(min.toDouble(), max.toDouble()),
                end.toDouble().clamp(min.toDouble(), max.toDouble()),
              ),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: onChanged != null
                  ? (range) {
                      onChanged!(range.start.round(), range.end.round());
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip 选择器设置项
///
/// 用于从多个选项中选择一个
class ChipSelectTile<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final T value;
  final List<T> options;
  final String Function(T) labelBuilder;
  final ValueChanged<T>? onChanged;
  final Widget? leading;

  const ChipSelectTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = value == option;
              return FilterChip(
                label: Text(labelBuilder(option)),
                selected: isSelected,
                onSelected: onChanged != null
                    ? (selected) {
                        if (selected) {
                          onChanged!(option);
                        }
                      }
                    : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 设置分组标题
class SettingSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SettingSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}
