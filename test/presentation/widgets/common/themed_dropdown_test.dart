import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_dropdown.dart';

void main() {
  testWidgets('shared surface is the only layer that paints the field fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.red,
          ),
        ),
        home: Scaffold(
          body: Column(
            children: [
              const ThemedTextField(),
              ThemedDropdown<String>(
                value: 'value',
                items: const [
                  DropdownMenuItem(value: 'value', child: Text('Value')),
                ],
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.filled,
      false,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .decoration
          .filled,
      false,
    );
  });
}
