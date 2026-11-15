import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';

/// 马赛克编辑器底部操作栏（撤销/重做/重置/设为默认/保存副本）。
class MosaicEditorActionsBar extends StatelessWidget {
  const MosaicEditorActionsBar({
    super.key,
    required this.ready,
    required this.saving,
    required this.defaultsOnly,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onReset,
    required this.onSaveDefaults,
    required this.onSaveCopy,
  });

  final bool ready;
  final bool saving;
  final bool defaultsOnly;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onReset;
  final VoidCallback onSaveDefaults;
  final VoidCallback onSaveCopy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 650 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                IconButton(
                  tooltip: context.l10n.mosaic_undo,
                  onPressed: !canUndo || saving || !ready ? null : onUndo,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: context.l10n.mosaic_redo,
                  onPressed: !canRedo || saving || !ready ? null : onRedo,
                  icon: const Icon(Icons.redo),
                ),
                IconButton(
                  tooltip: context.l10n.mosaic_reset,
                  onPressed: saving || !ready ? null : onReset,
                  icon: const Icon(Icons.restart_alt),
                ),
                if (defaultsOnly)
                  FilledButton.icon(
                    onPressed: saving || !ready ? null : onSaveDefaults,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(context.l10n.mosaic_saveDefaults),
                  )
                else if (compact)
                  IconButton(
                    tooltip: context.l10n.mosaic_saveDefaults,
                    onPressed: saving || !ready ? null : onSaveDefaults,
                    icon: const Icon(Icons.bookmark_add_outlined),
                  )
                else
                  TextButton.icon(
                    onPressed: saving || !ready ? null : onSaveDefaults,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(context.l10n.mosaic_saveDefaults),
                  ),
                if (!defaultsOnly) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: saving || !ready ? null : onSaveCopy,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt),
                    label: Text(
                      compact
                          ? context.l10n.common_save
                          : saving
                          ? context.l10n.mosaic_saving
                          : context.l10n.mosaic_saveCopy,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
