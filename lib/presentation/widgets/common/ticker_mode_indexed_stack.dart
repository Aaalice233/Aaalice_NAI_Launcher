import 'package:flutter/widgets.dart';

class TickerModeIndexedStack extends StatelessWidget {
  const TickerModeIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: index,
    children: [
      for (var childIndex = 0; childIndex < children.length; childIndex++)
        TickerMode(enabled: childIndex == index, child: children[childIndex]),
    ],
  );
}
