import 'package:flutter/material.dart';

import '../../../adaptive/adaptive_pinned_header_sliver.dart';

/// 页面顶部区域：高度允许时固定在滚动视图顶端，否则随内容一起滚动
class PromptConfigChromeSliver extends StatelessWidget {
  const PromptConfigChromeSliver({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AdaptivePinnedHeaderSliver(
      // 固定时内容从下方滚过，用画布色遮住间距处的内容
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: child,
      ),
    );
  }
}

/// 分区的唯一纵向滚动视图，拖动时收起软键盘
class PromptConfigSectionScrollView extends StatelessWidget {
  const PromptConfigSectionScrollView({super.key, required this.slivers});

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: slivers,
    );
  }
}

/// 词库加载中、出错或未选预设时占满剩余视口的提示
class PromptConfigUnavailableSliver extends StatelessWidget {
  const PromptConfigUnavailableSliver({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(hasScrollBody: false, child: child);
  }
}
