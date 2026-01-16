import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 多选模式底部操作栏
class MultiSelectBottomBar extends ConsumerWidget {
  final int selectedCount;
  final VoidCallback onSendToHome;
  final VoidCallback onClear;

  const MultiSelectBottomBar({
    super.key,
    required this.selectedCount,
    required this.onSendToHome,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: selectedCount > 0 ? 56 : 0,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        elevation: 8,
        child: Row(
          children: [
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close),
              tooltip: '清除选择',
            ),
            Expanded(
              child: Text(
                '已选 $selectedCount 张',
                style: theme.textTheme.titleMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: onSendToHome,
              icon: const Icon(Icons.send),
              label: const Text('发送到主页'),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}
