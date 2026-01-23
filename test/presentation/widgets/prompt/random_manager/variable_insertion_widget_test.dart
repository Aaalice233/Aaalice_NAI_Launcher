import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/variable_insertion_widget.dart';

void main() {
  group('VariableInsertionWidget', () {
    testWidgets('should display variable chips', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VariableInsertionWidget(controller: controller),
            ),
          ),
        ),
      );

      // Verify default variables are displayed
      expect(find.text('hair'), findsOneWidget);
      expect(find.text('eye'), findsOneWidget);
      expect(find.text('pose'), findsOneWidget);
    });

    testWidgets('should display custom variables', (tester) async {
      final controller = TextEditingController();
      const customVariables = ['custom1', 'custom2', 'special'];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VariableInsertionWidget(
                controller: controller,
                variables: customVariables,
              ),
            ),
          ),
        ),
      );

      expect(find.text('custom1'), findsOneWidget);
      expect(find.text('custom2'), findsOneWidget);
      expect(find.text('special'), findsOneWidget);
    });

    testWidgets('should insert variable on tap', (tester) async {
      final controller = TextEditingController();
      controller.text = 'Hello ';

      // Set cursor position after "Hello "
      controller.selection = const TextSelection.collapsed(offset: 7);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VariableInsertionWidget(controller: controller),
            ),
          ),
        ),
      );

      // Tap on hair variable chip
      await tester.tap(find.text('hair'));
      await tester.pump();

      // Verify text was inserted with __variable__ syntax
      expect(controller.text, 'Hello __hair__');
    });

    testWidgets('should insert at cursor position', (tester) async {
      final controller = TextEditingController();
      controller.text = 'Start End';
      
      // Set cursor position after "Start "
      controller.selection = const TextSelection.collapsed(offset: 6);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VariableInsertionWidget(controller: controller),
            ),
          ),
        ),
      );

      await tester.tap(find.text('eye'));
      await tester.pump();

      expect(controller.text, 'Start __eye__End');
    });

    testWidgets('should insert at end when cursor at end', (tester) async {
      final controller = TextEditingController();
      controller.text = 'Hello';
      
      // Set cursor at the end
      controller.selection = const TextSelection.collapsed(offset: 5);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VariableInsertionWidget(controller: controller),
            ),
          ),
        ),
      );

      await tester.tap(find.text('pose'));
      await tester.pump();

      expect(controller.text, 'Hello__pose__');
    });

    testWidgets('should have tooltips on chips', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VariableInsertionWidget(controller: controller),
            ),
          ),
        ),
      );

      // Find the tooltip for hair variable
      expect(find.byType(Tooltip), findsWidgets);
    });

    testWidgets('should handle empty variable list', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VariableInsertionWidget(
                controller: controller,
                variables: const [],
              ),
            ),
          ),
        ),
      );

      // No variable chips should be displayed
      expect(find.byType(ActionChip), findsNothing);
    });
  });
}