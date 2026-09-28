import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/enums/precise_ref_type.dart';
import '../../../../core/extensions/precise_ref_type_extensions.dart';

/// 精准参考类型过滤 chips（全部 / 角色 / 风格 / 角色+风格）
///
/// 库页面与选择器对话框共用；[value] 为 null 表示全部类型。
class PreciseRefTypeFilterChips extends StatelessWidget {
  const PreciseRefTypeFilterChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PreciseRefType? value;
  final ValueChanged<PreciseRefType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          key: const Key('precise-ref-type-filter-all'),
          label: Text(l10n.preciseRefLib_typeFilterAll),
          selected: value == null,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => onChanged(null),
        ),
        for (final type in PreciseRefType.values)
          ChoiceChip(
            key: Key('precise-ref-type-filter-${type.name}'),
            avatar: Icon(
              type.icon,
              size: 14,
              color: value == type
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            label: Text(
              type.getDisplayName(
                character: l10n.preciseRef_typeCharacter,
                style: l10n.preciseRef_typeStyle,
                characterAndStyle: l10n.preciseRef_typeCharacterAndStyle,
              ),
            ),
            selected: value == type,
            visualDensity: VisualDensity.compact,
            // 再次点击已选中的类型时回到「全部」
            onSelected: (selected) => onChanged(selected ? type : null),
          ),
      ],
    );
  }
}
