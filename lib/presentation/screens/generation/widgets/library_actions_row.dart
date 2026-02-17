import 'package:flutter/material.dart';

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
        // 保存到库按钮
        Expanded(
          child: OutlinedButton.icon(
            onPressed: vibes.isNotEmpty ? onSaveToLibrary : null,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('保存到库'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 从库导入按钮
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onImportFromLibrary,
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('从库导入'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }
}
