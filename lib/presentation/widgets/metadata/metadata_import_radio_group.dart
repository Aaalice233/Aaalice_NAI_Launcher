import 'package:flutter/material.dart';

class MetadataImportRadioGroup<T extends Object> extends StatelessWidget {
  const MetadataImportRadioGroup({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.contentPadding,
  });

  final String label;
  final T value;
  final Map<T, String> choices;
  final ValueChanged<T>? onChanged;

  /// 选项行的内边距；为空时沿用 [RadioListTile] 默认值。
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      RadioGroup<T>(
        groupValue: value,
        onChanged: (choice) => onChanged?.call(choice!),
        child: Column(
          children: [
            for (final choice in choices.entries)
              RadioListTile<T>(
                dense: true,
                contentPadding: contentPadding,
                enabled: onChanged != null,
                value: choice.key,
                title: Text(choice.value),
              ),
          ],
        ),
      ),
    ],
  );
}
