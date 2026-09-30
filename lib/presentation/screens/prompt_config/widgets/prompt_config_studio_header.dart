import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../themes/core/layered_surface_style.dart';
import '../../../widgets/prompt/random_manager/preset_selector_bar.dart';

/// 工作区标题栏：宽屏时标题与预设选择并排，紧凑时由预设选择栏承载标题
class PromptConfigStudioHeader extends StatelessWidget {
  const PromptConfigStudioHeader({super.key, required this.onImportExport});

  final VoidCallback onImportExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      color: sectionSurfaceColor(colors),
      padding: EdgeInsets.symmetric(
        horizontal: textScale > 1.5 ? 12 : 20,
        vertical: 8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 840 || textScale > 1.5;
          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.casino_outlined, size: 22, color: colors.primary),
              const SizedBox(width: 10),
              Text(
                context.l10n.randomManager_workspaceTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

          if (compact) {
            return PresetSelectorBar(
              onImportExport: onImportExport,
              showWorkspaceHeading: true,
            );
          }
          return Row(
            children: [
              title,
              const SizedBox(width: 12),
              Expanded(
                child: PresetSelectorBar(onImportExport: onImportExport),
              ),
            ],
          );
        },
      ),
    );
  }
}
