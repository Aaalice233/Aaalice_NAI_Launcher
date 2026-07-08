import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/collapsible_model_selector.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(children: [child]),
    ),
  );
}

void main() {
  testWidgets('收起时显示当前模型名且不渲染子控件', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CollapsibleModelSelector(
          title: '模型',
          currentModelName: 'NAI Diffusion V4.5',
          initiallyExpanded: false,
          onExpansionChanged: (_) {},
          child: const Text('model-dropdown'),
        ),
      ),
    );

    expect(find.text('NAI Diffusion V4.5'), findsOneWidget);
    expect(find.text('model-dropdown'), findsNothing);
  });

  testWidgets('点击展开后渲染子控件并回调 true', (tester) async {
    bool? reported;
    await tester.pumpWidget(
      _wrap(
        CollapsibleModelSelector(
          title: '模型',
          currentModelName: 'NAI Diffusion V4.5',
          initiallyExpanded: false,
          onExpansionChanged: (value) => reported = value,
          child: const Text('model-dropdown'),
        ),
      ),
    );

    await tester.tap(find.text('模型'));
    await tester.pumpAndSettle();

    expect(find.text('model-dropdown'), findsOneWidget);
    expect(reported, isTrue);
  });

  testWidgets('initiallyExpanded 为 true 时直接渲染子控件', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CollapsibleModelSelector(
          title: '模型',
          currentModelName: 'NAI Diffusion V4.5',
          initiallyExpanded: true,
          onExpansionChanged: (_) {},
          child: const Text('model-dropdown'),
        ),
      ),
    );

    expect(find.text('model-dropdown'), findsOneWidget);
  });
}
