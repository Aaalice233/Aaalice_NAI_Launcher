import 'package:flutter/material.dart';

import 'inset_shadow_container.dart';

/// 安全的下拉框 - 自动验证value是否在items中
/// 包装InsetShadowContainer提供立体感
class SafeDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final bool isExpanded;
  final double borderRadius;
  final Widget? icon;

  const SafeDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.hintText,
    this.isExpanded = true,
    this.borderRadius = 8.0,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 验证value是否在items中
    final validValue = _validateValue();

    return InsetShadowContainer(
      borderRadius: borderRadius,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: validValue,
          items: items,
          onChanged: onChanged,
          isExpanded: isExpanded,
          hint: hintText != null
              ? Text(
                  hintText!,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 14,
                  ),
                )
              : null,
          icon: icon ??
              Icon(
                Icons.keyboard_arrow_down,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
          dropdownColor: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(borderRadius),
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  T? _validateValue() {
    if (value == null) return null;

    // 检查value是否在items中
    final itemValues = items.map((item) => item.value).toList();
    if (itemValues.contains(value)) {
      return value;
    }

    // 如果不在，返回null (显示hint或第一个item)
    return null;
  }
}

/// 安全的表单下拉框 - 用于表单验证场景
class SafeDropdownFormField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? hintText;
  final bool isExpanded;
  final double borderRadius;
  final FormFieldValidator<T>? validator;

  const SafeDropdownFormField({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.isExpanded = true,
    this.borderRadius = 8.0,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 验证value是否在items中
    final validValue = _validateValue();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 6),
        ],
        InsetShadowContainer(
          borderRadius: borderRadius,
          child: DropdownButtonFormField<T>(
            value: validValue,
            items: items,
            onChanged: onChanged,
            isExpanded: isExpanded,
            validator: validator,
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            dropdownColor: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ],
    );
  }

  T? _validateValue() {
    if (value == null) return null;

    // 检查value是否在items中
    final itemValues = items.map((item) => item.value).toList();
    if (itemValues.contains(value)) {
      return value;
    }

    // 如果不在，返回null
    return null;
  }
}
