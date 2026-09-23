import 'package:flutter/widgets.dart';

/// 语义标题。
///
/// 桌面端无障碍桥只读取 header，Android/iOS 只读取 headingLevel，两者必须同时设置。
class HeadingSemantics extends StatelessWidget {
  const HeadingSemantics({super.key, required this.level, required this.child})
    : assert(level >= 1 && level <= 6);

  final int level;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(header: true, headingLevel: level, child: child);
  }
}
