import 'package:flutter/material.dart';

/// 子树的墨水宿主。
///
/// 放在不透明底色内部，悬停、焦点与按压反馈才会画在底色之上；
/// 外层文字样式原样转交，不被 Material 重置为 bodyMedium。
class InkHost extends StatelessWidget {
  const InkHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inherited = DefaultTextStyle.of(context);
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: inherited.style,
        textAlign: inherited.textAlign,
        softWrap: inherited.softWrap,
        overflow: inherited.overflow,
        maxLines: inherited.maxLines,
        textWidthBasis: inherited.textWidthBasis,
        textHeightBehavior: inherited.textHeightBehavior,
        child: child,
      ),
    );
  }
}
