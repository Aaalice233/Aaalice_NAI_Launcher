import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_reference.dart';

/// 库操作按钮行（保存到库、从库导入）
class LibraryActionsRow extends StatelessWidget {
  final List<VibeReference> vibes;
  final VoidCallback onSaveToLibrary;
  final VoidCallback onImportFromLibrary;

  const LibraryActionsRow({
    super.key,
    required this.vibes,
    required this.onSaveToLibrary,
    required this.onImportFromLibrary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: vibes.isNotEmpty ? onSaveToLibrary : null,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: Text(context.l10n.vibeLibrary_save),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onImportFromLibrary,
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: Text(context.l10n.vibe_addFromLibraryTitle),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }
}
