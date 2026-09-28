import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/searchable_model_picker.dart';

void main() {
  testWidgets(
    'large model lists stay searchable on compact and expanded panes',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final options = [
        for (var index = 0; index < 1000; index++)
          ModelPickerOption(
            id: 'model-$index',
            value: 'model-$index',
            title: index == 731 ? 'Aurora Reasoner' : 'Model $index',
            subtitle: 'Provider ${index % 8} · model-$index',
            searchTerms: ['alias-$index'],
          ),
      ];
      var selected = 'model-0';

      Widget buildApp(Size size) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: size),
          child: child!,
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SizedBox(
                width: 460,
                child: SearchableModelPickerField<String>(
                  keyPrefix: 'test-model',
                  pickerTitle: 'Select model',
                  searchLabel: 'Search models',
                  searchHint: 'Name, model ID, or provider',
                  clearSearchTooltip: 'Clear search',
                  emptyMessage: 'No matching models',
                  options: options,
                  selectedId: selected,
                  onSelected: (value) => setState(() => selected = value),
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
              ),
            ),
          ),
        ),
      );

      for (final scenario in <({Size size, String surface})>[
        (size: const Size(360, 640), surface: 'adaptive-bottom-sheet'),
        (size: const Size(1180, 760), surface: 'adaptive-centered-form'),
      ]) {
        await tester.binding.setSurfaceSize(scenario.size);
        await tester.pumpWidget(buildApp(scenario.size));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('test-model-field')));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey(scenario.surface)), findsOneWidget);

        final search = find.byKey(const ValueKey('test-model-search'));
        expect(search, findsOneWidget);
        await tester.enterText(search, 'aurora');
        await tester.pump();
        final results = find.byKey(const ValueKey('test-model-results'));
        expect(
          find.descendant(of: results, matching: find.text('Aurora Reasoner')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: results, matching: find.text('Model 0')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.byKey(const ValueKey('test-model-option-model-731')),
        );
        await tester.pumpAndSettle();
        expect(selected, 'model-731');
        expect(find.text('Aurora Reasoner'), findsOneWidget);
        expect(find.byKey(ValueKey(scenario.surface)), findsNothing);
      }
    },
  );
}
