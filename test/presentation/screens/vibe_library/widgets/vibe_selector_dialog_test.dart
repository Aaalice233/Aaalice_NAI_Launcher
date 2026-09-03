import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_selector_dialog.dart';

void main() {
  testWidgets('手机宽度下筛选工具栏完整布局且不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vibeLibraryNotifierProvider.overrideWith(
            _EmptyVibeLibraryNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => VibeSelectorDialog.show(context: context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('全部类型'), findsOneWidget);
    expect(find.text('创建时间'), findsOneWidget);
    for (final control in [
      find.byType(FilterChip),
      find.widgetWithText(Chip, '全部类型'),
      find.widgetWithText(Chip, '创建时间'),
    ]) {
      expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('$width 宽度按局部空间使用可容纳列数且不溢出', (tester) async {
      await _openDialog(
        tester,
        size: Size(width, 800),
        entries: _buildEntries(8),
      );

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, width == 320 ? 1 : 2);
      expect(find.text('选择 Vibe'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('320px 与 3x 文本缩放下标题、计数和选择操作完整且不溢出', (tester) async {
    await _openDialog(
      tester,
      size: const Size(320, 800),
      entries: _buildEntries(4),
      textScaler: const TextScaler.linear(3),
    );

    await tester.tap(find.text('全选'));
    await tester.pump();

    expect(find.text('4 项'), findsWidgets);
    expect(find.textContaining('确认选择'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('短高窗口保留关闭和选择功能且不溢出', (tester) async {
    await _openDialog(
      tester,
      size: const Size(360, 420),
      entries: _buildEntries(8),
    );

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);
    expect(find.textContaining('确认选择'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('IME 与 SafeArea 生效时搜索可见、内容可滚动且不溢出', (tester) async {
    await _openDialog(
      tester,
      size: const Size(320, 800),
      entries: _buildEntries(12),
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 20),
      viewInsets: const EdgeInsets.only(bottom: 280),
    );

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'entry-11');
    await tester.pump();

    expect(find.text('entry-11'), findsNWidgets(2));
    expect(find.text('entry-0'), findsNothing);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('adaptive-full-screen-form')))
          .dy,
      greaterThanOrEqualTo(24),
    );
    expect(
      tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
    expect(tester.takeException(), isNull);
  });

  for (final (width, surfaceKey) in [
    (700.0, 'adaptive-centered-form'),
    (1200.0, 'adaptive-centered-form'),
  ]) {
    testWidgets('$width 宽度使用 AdaptivePresenter 有界选择面', (tester) async {
      await _openDialog(
        tester,
        size: Size(width, 900),
        entries: _buildEntries(4),
      );

      final surface = find.byKey(ValueKey(surfaceKey));
      expect(surface, findsOneWidget);
      expect(tester.getSize(surface).width, lessThan(width));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('过滤、排序和替换选择返回语义保持完整', (tester) async {
    VibeSelectionResult? selection;
    await _pumpSelectorHost(
      tester,
      size: const Size(700, 900),
      entries: _buildEntries(4),
      onResult: (result) => selection = result,
    );

    await tester.enterText(find.byType(TextField), 'entry-2');
    await tester.pump();
    expect(find.text('entry-2'), findsNWidgets(2));
    expect(find.text('entry-0'), findsNothing);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final sortButton = find.byType(PopupMenuButton<VibeLibrarySortOrder>);
    await tester.ensureVisible(sortButton);
    await tester.tap(sortButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('名称').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('entry-2').last);
    await tester.pump();
    await tester.tap(find.text('替换现有'));
    await tester.pump();
    await tester.tap(find.textContaining('确认选择'));
    await tester.pumpAndSettle();

    expect(selection?.selectedEntries.single.id, 'entry-2');
    expect(selection?.shouldReplace, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('热门标签只基于有限样本计算，避免打开选择器时整库聚合', () {
    final entries = [
      for (var i = 0; i < 80; i++)
        _buildEntry(
          id: 'entry-$i',
          tags: i < 40 ? ['focus', 'common'] : ['late-$i'],
        ),
    ];

    final topTags = computeInitialTopTags(entries);

    expect(topTags, containsAll(['focus', 'common']));
    expect(
      topTags.any((tag) => tag.startsWith('late-')),
      isFalse,
      reason: '首屏热门标签不应为整库扫描所有条目付出同步开销',
    );
  });
}

Future<void> _openDialog(
  WidgetTester tester, {
  required Size size,
  required List<VibeLibraryEntry> entries,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) => _pumpSelectorHost(
  tester,
  size: size,
  entries: entries,
  textScaler: textScaler,
  padding: padding,
  viewInsets: viewInsets,
);

Future<void> _pumpSelectorHost(
  WidgetTester tester, {
  required Size size,
  required List<VibeLibraryEntry> entries,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  ValueChanged<VibeSelectionResult?>? onResult,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vibeLibraryNotifierProvider.overrideWith(
          () => _PopulatedVibeLibraryNotifier(entries),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            padding: padding,
            viewPadding: padding,
            viewInsets: viewInsets,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await VibeSelectorDialog.show(context: context);
                onResult?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump();
}

class _EmptyVibeLibraryNotifier extends VibeLibraryNotifier {
  @override
  VibeLibraryState build() => const VibeLibraryState();

  @override
  Future<void> loadFromCache({bool showLoading = false}) async {}
}

class _PopulatedVibeLibraryNotifier extends VibeLibraryNotifier {
  _PopulatedVibeLibraryNotifier(this.entries);

  final List<VibeLibraryEntry> entries;

  @override
  VibeLibraryState build() => VibeLibraryState(entries: entries);
}

List<VibeLibraryEntry> _buildEntries(int count) => [
  for (var index = 0; index < count; index++)
    _buildEntry(id: 'entry-$index', tags: const []),
];

VibeLibraryEntry _buildEntry({required String id, required List<String> tags}) {
  return VibeLibraryEntry(
    id: id,
    name: id,
    vibeDisplayName: id,
    vibeEncoding: 'encoding-$id',
    strength: 0.6,
    infoExtracted: 0.7,
    sourceTypeIndex: VibeSourceType.naiv4vibe.index,
    tags: tags,
    createdAt: DateTime(2026, 4, 14),
  );
}
