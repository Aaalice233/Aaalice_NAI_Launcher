import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/generation/image_card_selection_provider.dart';

/// 系统返回先退出预览与历史共用的多选，再交还给路由。
class GenerationSelectionBackScope extends ConsumerWidget {
  const GenerationSelectionBackScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelectionMode = ref.watch(
      generationImageCardSelectionProvider.select((state) => state.isActive),
    );
    return PopScope<void>(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isSelectionMode) {
          ref.read(generationImageCardSelectionProvider.notifier).exit();
        }
      },
      child: child,
    );
  }
}
