import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/director/director_tool_output.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/common/horizontal_segmented_control.dart';

/// 一次运行返回多张结果时，在其间切换当前使用的那张。
class DirectorResultVariantSelector extends StatelessWidget {
  const DirectorResultVariantSelector({
    super.key,
    required this.results,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<DirectorToolImage> results;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final minimumExtent = context.interactionPolicy.minimumControlExtent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.img2img_directorResult, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        HorizontalSegmentedControl(
          child: SegmentedButton<int>(
            segments: [
              for (final (index, image) in results.indexed)
                ButtonSegment(
                  value: index,
                  label: Text(image.label(l10n, index)),
                ),
            ],
            selected: {selectedIndex},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              minimumSize: Size(minimumExtent, minimumExtent),
            ),
            onSelectionChanged: (selection) => onSelected(selection.first),
          ),
        ),
      ],
    );
  }
}
