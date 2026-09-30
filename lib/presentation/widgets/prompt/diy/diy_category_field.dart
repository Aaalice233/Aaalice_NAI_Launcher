import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

/// DIY 规则可引用的类别：规则里保存 [id]，界面显示 [label]
@immutable
class DiyCategoryOption {
  const DiyCategoryOption({required this.id, required this.label, this.key});

  final String id;
  final String label;

  /// 类别键名，供按键名定义目标的预设规则定位到本预设中的类别
  final String? key;

  @override
  bool operator ==(Object other) =>
      other is DiyCategoryOption &&
      other.id == id &&
      other.label == label &&
      other.key == key;

  @override
  int get hashCode => Object.hash(id, label, key);
}

/// 单选类别引用；存量值不在候选中时显示为已失效且不可再选
class DiyCategoryDropdown extends StatelessWidget {
  const DiyCategoryDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.readOnly = false,
  });

  final String value;
  final List<DiyCategoryOption> options;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isUnavailable =
        value.isNotEmpty && options.every((option) => option.id != value);

    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      isExpanded: true,
      // 放大文字后选项需要按内容增高，固定行高会让文字溢出
      itemHeight: null,
      decoration: decoration.copyWith(
        hintText: decoration.hintText ?? l10n.diy_notSet,
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option.id,
            child: _CategoryLabel(option.label),
          ),
        if (isUnavailable)
          DropdownMenuItem(
            value: value,
            enabled: false,
            child: _CategoryLabel(
              l10n.diy_categoryUnavailable(value),
              unavailable: true,
            ),
          ),
      ],
      onChanged: readOnly
          ? null
          : (selected) {
              if (selected != null && selected != value) onChanged(selected);
            },
    );
  }
}

/// 多选类别引用；已失效的存量值以可移除条目保留，便于用户看见并清理
class DiyCategoryMultiSelect extends StatelessWidget {
  const DiyCategoryMultiSelect({
    super.key,
    required this.values,
    required this.options,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.readOnly = false,
    this.disabledIds = const {},
    this.disabledReason,
  });

  final List<String> values;
  final List<DiyCategoryOption> options;
  final ValueChanged<List<String>> onChanged;
  final InputDecoration decoration;
  final bool readOnly;

  /// 不可新选的候选；已选中的仍可取消，悬停时显示 [disabledReason]
  final Set<String> disabledIds;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final knownIds = {for (final option in options) option.id};
    final unavailable = values.where((id) => !knownIds.contains(id)).toList();
    final isEmpty = options.isEmpty && unavailable.isEmpty;

    return InputDecorator(
      decoration: decoration.copyWith(
        hintText: decoration.hintText ?? l10n.diy_notSet,
        enabled: !readOnly,
      ),
      isEmpty: isEmpty,
      child: isEmpty
          ? null
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options) _optionChip(option),
                for (final id in unavailable)
                  InputChip(
                    label: _CategoryLabel(
                      l10n.diy_categoryUnavailable(id),
                      unavailable: true,
                    ),
                    deleteButtonTooltipMessage: l10n.common_delete,
                    onDeleted: readOnly
                        ? null
                        : () => onChanged(
                            values.where((value) => value != id).toList(),
                          ),
                  ),
              ],
            ),
    );
  }

  Widget _optionChip(DiyCategoryOption option) {
    final selected = values.contains(option.id);
    final blocked = !selected && disabledIds.contains(option.id);
    final chip = FilterChip(
      label: _CategoryLabel(option.label),
      selected: selected,
      onSelected: readOnly || blocked
          ? null
          : (selected) => onChanged(
              selected
                  ? [...values, option.id]
                  : values.where((id) => id != option.id).toList(),
            ),
    );
    final reason = disabledReason;
    return blocked && reason != null
        ? Tooltip(message: reason, child: chip)
        : chip;
  }
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel(this.text, {this.unavailable = false});

  final String text;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      softWrap: true,
      maxLines: null,
      overflow: TextOverflow.visible,
      style: unavailable
          ? TextStyle(color: Theme.of(context).colorScheme.error)
          : null,
    );
  }
}
