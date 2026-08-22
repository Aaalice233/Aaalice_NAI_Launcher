import 'package:flutter/widgets.dart';

class AppBranchVisibility extends InheritedWidget {
  const AppBranchVisibility({
    super.key,
    required this.isVisible,
    required super.child,
  });

  final bool isVisible;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AppBranchVisibility>()
            ?.isVisible ??
        true;
  }

  @override
  bool updateShouldNotify(AppBranchVisibility oldWidget) {
    return isVisible != oldWidget.isVisible;
  }
}
