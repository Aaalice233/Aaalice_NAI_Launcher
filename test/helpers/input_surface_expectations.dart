import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';

/// 放输入框的可滚动页面，可放大文字
Widget inputTestApp(Widget child, {double textScale = 1}) {
  return MaterialApp(
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

/// 共享输入色面里的 [target]
Finder insideInputSurface(Finder target) =>
    find.descendant(of: find.byType(InputSurfaceContainer), matching: target);

/// [field] 所在的输入色面，不传时取页面上唯一的一个
InputSurfaceContainer inputSurfaceOf(WidgetTester tester, [Finder? field]) =>
    tester.widget<InputSurfaceContainer>(
      field == null
          ? find.byType(InputSurfaceContainer)
          : find.descendant(
              of: field,
              matching: find.byType(InputSurfaceContainer),
            ),
    );

/// 色面里 TextField 实际使用的装饰，不传 [field] 时取第一个
InputDecoration innerDecorationOf(WidgetTester tester, [Finder? field]) =>
    tester
        .widget<TextField>(
          field == null
              ? find.byType(TextField).first
              : find.descendant(of: field, matching: find.byType(TextField)),
        )
        .decoration!;
