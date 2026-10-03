import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('provider groups', () {
    const deepSeek = ModelPickerGroup(id: 'deepseek', label: 'DeepSeek');
    const relay = ModelPickerGroup(id: 'relay', label: 'Relay station');

    ModelPickerOption<String> option(
      String id,
      String title, {
      ModelPickerGroup? group,
    }) => ModelPickerOption(
      id: id,
      value: id,
      title: title,
      tooltip: id,
      group: group,
    );

    Future<void> pumpBody(
      WidgetTester tester,
      List<ModelPickerOption<String>> options, {
      ValueChanged<String>? onSelected,
      double width = 460,
      double height = 640,
      double textScale = 1,
    }) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, height),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: SizedBox(
                width: width,
                height: height,
                child: SearchableModelPickerBody<String>(
                  title: 'Select model',
                  searchLabel: 'Search models',
                  searchHint: 'Name, model ID, or provider',
                  clearSearchTooltip: 'Clear search',
                  emptyMessage: 'No matching models',
                  options: options,
                  selectedId: null,
                  scrollController: controller,
                  keyPrefix: 'grouped',
                  onSelected: (picked) => onSelected?.call(picked.value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    double top(WidgetTester tester, String key) =>
        tester.getTopLeft(find.byKey(ValueKey(key))).dy;

    testWidgets('cluster options under their provider header', (tester) async {
      await pumpBody(tester, [
        option('deepseek-flash', 'DeepSeek V4.1 Flash', group: deepSeek),
        option('claude-opus-4-8', 'Claude Opus 4.8', group: relay),
        option('deepseek-v4-pro', 'DeepSeek V4 Pro', group: deepSeek),
      ]);

      final order = [
        top(tester, 'grouped-group-deepseek'),
        top(tester, 'grouped-option-deepseek-flash'),
        top(tester, 'grouped-option-deepseek-v4-pro'),
        top(tester, 'grouped-group-relay'),
        top(tester, 'grouped-option-claude-opus-4-8'),
      ];
      expect(order, orderedEquals([...order]..sort()));
      expect(find.text('DeepSeek'), findsOneWidget);
      expect(find.text('Relay station'), findsOneWidget);
    });

    testWidgets('a single provider shows no redundant header', (tester) async {
      await pumpBody(tester, [
        option('deepseek-flash', 'DeepSeek V4.1 Flash', group: deepSeek),
        option('deepseek-v4-pro', 'DeepSeek V4 Pro', group: deepSeek),
      ]);

      expect(find.byKey(const ValueKey('grouped-group-deepseek')), findsNothing);
      expect(find.text('DeepSeek V4.1 Flash'), findsOneWidget);
    });

    testWidgets('rows show only the name and keep the model ID in a tooltip', (
      tester,
    ) async {
      await pumpBody(tester, [
        option('deepseek-flash', 'DeepSeek V4.1 Flash', group: deepSeek),
        option('claude-opus-4-8', 'Claude Opus 4.8', group: relay),
      ]);

      expect(find.text('deepseek-flash'), findsNothing);
      expect(find.byTooltip('deepseek-flash'), findsOneWidget);
      final row = tester.getSize(
        find.byKey(const ValueKey('grouped-option-deepseek-flash')),
      );
      expect(row.height, greaterThanOrEqualTo(44));
    });

    testWidgets('search matches the provider label', (tester) async {
      await pumpBody(tester, [
        option('deepseek-flash', 'DeepSeek V4.1 Flash', group: deepSeek),
        option('claude-opus-4-8', 'Claude Opus 4.8', group: relay),
      ]);

      await tester.enterText(
        find.byKey(const ValueKey('grouped-search')),
        'relay',
      );
      await tester.pump();

      expect(find.text('Claude Opus 4.8'), findsOneWidget);
      expect(find.text('DeepSeek V4.1 Flash'), findsNothing);
    });

    testWidgets('arrow keys follow the grouped visual order', (tester) async {
      String? picked;
      await pumpBody(tester, [
        option('deepseek-flash', 'DeepSeek V4.1 Flash', group: deepSeek),
        option('claude-opus-4-8', 'Claude Opus 4.8', group: relay),
        option('deepseek-v4-pro', 'DeepSeek V4 Pro', group: deepSeek),
      ], onSelected: (value) => picked = value);

      await tester.tap(find.byKey(const ValueKey('grouped-search')));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(picked, 'deepseek-v4-pro');
    });

    testWidgets('End scrolls the last grouped option into view', (
      tester,
    ) async {
      await pumpBody(tester, [
        for (final group in [deepSeek, relay])
          for (var index = 0; index < 40; index++)
            option('${group.id}-$index', '${group.label} $index', group: group),
      ]);

      await tester.tap(find.byKey(const ValueKey('grouped-search')));
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();

      final last = find.byKey(const ValueKey('grouped-option-relay-39'));
      expect(last, findsOneWidget);
      final results = tester.getRect(
        find.byKey(const ValueKey('grouped-results')),
      );
      expect(results.contains(tester.getCenter(last)), isTrue);
    });

    testWidgets('compact width with 3x text keeps headers and rows intact', (
      tester,
    ) async {
      await pumpBody(
        tester,
        [
          option('deepseek-flash', 'DeepSeek V4.1 Flash', group: deepSeek),
          option('claude-opus-4-8', 'Claude Opus 4.8', group: relay),
        ],
        width: 320,
        height: 900,
        textScale: 3,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('grouped-group-deepseek')), findsOne);
      expect(
        find.byKey(const ValueKey('grouped-option-deepseek-flash')),
        findsOne,
      );
    });
  });
}
