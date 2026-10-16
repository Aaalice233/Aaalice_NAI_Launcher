import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/layout_state_provider.dart';
import 'fixed_tags_sidebar.dart';
import 'resize_handle.dart';

/// 固定标签侧栏插槽（经典布局与官网式布局共用）
///
/// 宽度由外层按侧栏宽度加 [ResizeHandle.extentOf] 预留；侧栏收起时渲染为空。
class FixedTagsSidebarSlot extends ConsumerWidget {
  const FixedTagsSidebarSlot({super.key});

  static const double _minWidth = 240;
  static const double _maxWidth = 400;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(
      layoutStateNotifierProvider.select(
        (state) => state.fixedTagsSidebarExpanded,
      ),
    );
    if (!expanded) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    // 侧栏吃掉手柄之外的全部宽度：外层预留偏窄时收窄侧栏，不把手柄挤出可视区。
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(right: BorderSide(color: theme.dividerColor)),
            ),
            child: const FixedTagsSidebar(),
          ),
        ),
        ResizeHandle(
          onDrag: (dx) {
            final currentWidth = ref
                .read(layoutStateNotifierProvider)
                .fixedTagsSidebarWidth;
            final newWidth = (currentWidth + dx).clamp(_minWidth, _maxWidth);
            ref
                .read(layoutStateNotifierProvider.notifier)
                .setFixedTagsSidebarWidth(newWidth.toDouble());
          },
        ),
      ],
    );
  }
}
