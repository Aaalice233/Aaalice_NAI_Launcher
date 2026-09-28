import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/editable_double_field.dart';

void main() {
  testWidgets('读屏名称落在输入框节点上，读数即显示的数值', (tester) async {
    await _pumpField(
      tester,
      EditableDoubleField(value: 0.6, semanticLabel: '强度', onChanged: (_) {}),
    );

    final field = find.semantics.byPredicate(
      (node) => node.flagsCollection.isTextField,
    );
    expect(field, findsOne);
    final node = field.evaluate().single;
    expect(node.label, '强度');
    expect(node.value, '0.60');
    expect(find.text('0.60'), findsOneWidget);
  });

  testWidgets('不传读屏名称时输入框只朗读数值', (tester) async {
    await _pumpField(
      tester,
      EditableDoubleField(value: 0.6, onChanged: (_) {}),
    );

    final node = find.semantics
        .byPredicate((node) => node.flagsCollection.isTextField)
        .evaluate()
        .single;
    expect(node.label, isEmpty);
    expect(node.value, '0.60');
  });
}

Future<void> _pumpField(WidgetTester tester, Widget field) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: field)),
    ),
  );
}
