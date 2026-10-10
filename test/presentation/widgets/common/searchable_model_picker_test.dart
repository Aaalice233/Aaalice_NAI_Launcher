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

      expect(
        find.byKey(const ValueKey('grouped-group-deepseek')),
        findsNothing,
      );
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

    testWidgets('multi-select trailing slots and group actions', (
      tester,
    ) async {
      String? groupAction;
      ModelPickerGroup group(ModelPickerGroup base) => ModelPickerGroup(
        id: base.id,
        label: base.label,
        trailing: IconButton(
          key: ValueKey('action-${base.id}'),
          tooltip: 'Add all ${base.label}',
          icon: const Icon(Icons.playlist_add_rounded),
          onPressed: () => groupAction = base.id,
        ),
      );
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 640,
              child: SearchableModelPickerBody<String>(
                title: 'Manage models',
                searchLabel: 'Search models',
                searchHint: 'Name or model ID',
                clearSearchTooltip: 'Clear search',
                emptyMessage: 'No matching models',
                options: [
                  for (final base in [deepSeek, relay])
                    for (var index = 0; index < 30; index++)
                      ModelPickerOption(
                        id: '${base.id}-$index',
                        value: '${base.id}-$index',
                        title: '${base.label} $index',
                        group: group(base),
                        trailing: Icon(
                          index.isEven
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          key: ValueKey('trailing-${base.id}-$index'),
                        ),
                      ),
                ],
                selectedId: null,
                selectedIds: const {'deepseek-0'},
                scrollController: controller,
                keyPrefix: 'grouped',
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 自定义尾部替换勾号，多选状态仍通过语义暴露给读屏。
      expect(find.byKey(const ValueKey('trailing-deepseek-0')), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      bool? selected(String id) => tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.byKey(ValueKey('grouped-option-$id')),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Semantics &&
                        widget.properties.selected != null,
                  ),
                )
                .first,
          )
          .properties
          .selected;
      expect(selected('deepseek-0'), isTrue);
      expect(selected('deepseek-1'), isFalse);

      await tester.tap(find.byKey(const ValueKey('action-deepseek')));
      expect(groupAction, 'deepseek');
      final header = tester.getRect(
        find.byKey(const ValueKey('grouped-group-deepseek')),
      );
      final action = tester.getRect(
        find.byKey(const ValueKey('action-deepseek')),
      );
      expect(header.top, lessThanOrEqualTo(action.top));
      expect(header.bottom, greaterThanOrEqualTo(action.bottom));

      // 带操作的组标题更高，定高计算必须与实际布局一致，End 才能准确滚到底。
      await tester.tap(find.byKey(const ValueKey('grouped-search')));
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      final last = find.byKey(const ValueKey('grouped-option-relay-29'));
      expect(last, findsOneWidget);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('grouped-results')))
            .contains(tester.getCenter(last)),
        isTrue,
      );
      expect(tester.takeException(), isNull);
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

  group('header actions', () {
    Future<void> pumpHeader(
      WidgetTester tester, {
      required double width,
      double textScale = 1,
    }) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 700),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: SizedBox(
                width: width,
                height: 700,
                child: SearchableModelPickerBody<String>(
                  title: 'yuan 的模型',
                  titleBadge: '16',
                  headerActions: [
                    TextButton.icon(
                      key: const ValueKey('clean'),
                      onPressed: () {},
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('清理失效模型'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('add-all'),
                      onPressed: () {},
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: const Text('添加全部模型'),
                    ),
                  ],
                  searchLabel: '搜索模型',
                  searchHint: '模型名称、ID 或提供商',
                  clearSearchTooltip: '清除搜索',
                  emptyMessage: '没有匹配的模型',
                  options: const [
                    ModelPickerOption(id: 'a', value: 'a', title: 'Model A'),
                  ],
                  selectedId: null,
                  scrollController: controller,
                  keyPrefix: 'header',
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Rect rectOf(WidgetTester tester, String key) =>
        tester.getRect(find.byKey(ValueKey(key)));

    void expectSingleActionRow(WidgetTester tester) {
      final clean = rectOf(tester, 'clean');
      final addAll = rectOf(tester, 'add-all');
      expect(clean.center.dy, closeTo(addAll.center.dy, 0.5));
      expect(addAll.left, greaterThan(clean.right));
    }

    for (final textScale in [1.0, 1.3]) {
      testWidgets('620 宽 ${textScale}x 时按钮单行靠右，与标题和关闭按钮同排', (tester) async {
        await pumpHeader(tester, width: 620, textScale: textScale);

        expectSingleActionRow(tester);
        final title = rectOf(tester, 'header-title');
        final actions = rectOf(tester, 'header-actions');
        final close = rectOf(tester, 'header-close');
        expect(actions.left, greaterThan(title.right));
        expect(actions.right, lessThanOrEqualTo(close.left));
        expect(actions.center.dy, closeTo(close.center.dy, 0.5));
        expect(find.text('16'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('手机宽度时按钮整组换到标题下一行并保持单行', (tester) async {
      await pumpHeader(tester, width: 390);

      expectSingleActionRow(tester);
      expect(
        rectOf(tester, 'header-actions').top,
        greaterThanOrEqualTo(rectOf(tester, 'header-close').bottom),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('320 宽 3x 文本时按钮仍完整可见且不溢出', (tester) async {
      await pumpHeader(tester, width: 320, textScale: 3);

      final title = rectOf(tester, 'header-title');
      final actions = rectOf(tester, 'header-actions');
      expect(actions.top, greaterThanOrEqualTo(title.bottom));
      expect(actions.right, lessThanOrEqualTo(320));
      expect(find.byKey(const ValueKey('clean')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-all')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
