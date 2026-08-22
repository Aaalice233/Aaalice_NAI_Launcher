import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';

/// 与表单中其他分段选择器保持一致的前缀/后缀开关。
class PrefixSuffixSwitch extends StatelessWidget {
  final FixedTagPosition value;
  final ValueChanged<FixedTagPosition> onChanged;
  final String? prefixLabel;
  final String? suffixLabel;

  const PrefixSuffixSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.prefixLabel,
    this.suffixLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<FixedTagPosition>(
        segments: [
          ButtonSegment(
            value: FixedTagPosition.prefix,
            label: Text(prefixLabel ?? context.l10n.common_prefix),
          ),
          ButtonSegment(
            value: FixedTagPosition.suffix,
            label: Text(suffixLabel ?? context.l10n.common_suffix),
          ),
        ],
        selected: {value},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}
