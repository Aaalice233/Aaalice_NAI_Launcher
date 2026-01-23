import 'package:flutter/material.dart';

class ProScrollbar extends StatelessWidget {
  final Widget child;

  const ProScrollbar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final color = Theme.of(context).colorScheme.onSurface;
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged)) {
            return color.withOpacity(0.3);
          }
          return color.withOpacity(0.2);
        }),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        thickness: WidgetStateProperty.all(4.0),
        radius: const Radius.circular(2.0),
        thumbVisibility: WidgetStateProperty.all(true),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: child,
      ),
    );
  }
}
