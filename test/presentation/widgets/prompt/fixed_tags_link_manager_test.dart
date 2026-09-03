import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_link.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/adaptive_dialog_frame.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tags_link_manager.dart';

void main() {
  testWidgets('Expanded 短高度下联动列表可滚动并保留删除语义', (tester) async {
    final fixture = _linkFixture(linkCount: 12);
    final notifier = _TestFixedTagsNotifier(fixture.state);
    await _pumpLauncher(
      tester,
      size: const Size(900, 240),
      notifier: notifier,
      entry: fixture.positive,
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-side-sheet')), findsOneWidget);
    final listFinder = find.descendant(
      of: find.byType(AdaptiveDialogFrame),
      matching: find.byType(ListView),
    );
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: listFinder, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    await tester.drag(listFinder, const Offset(0, -1000));
    await tester.pumpAndSettle();

    final lastEntry = fixture.negatives.last;
    final lastOption = find.byKey(
      ValueKey('fixed-tag-linked-entry-${lastEntry.id}'),
    );
    expect(lastOption, findsOneWidget);
    await tester.tap(lastOption);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-side-sheet')), findsNothing);
    expect(notifier.removedPair, (fixture.positive.id, lastEntry.id));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact 320 宽 3x 字体及 IME SafeArea 下列表可滚动无溢出', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(() => tester.view.padding = FakeViewPadding.zero);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);

    final fixture = _linkFixture(linkCount: 16, linkedCount: 2);
    await _pumpLauncher(
      tester,
      size: const Size(320, 760),
      notifier: _TestFixedTagsNotifier(fixture.state),
      entry: fixture.positive,
      textScaleFactor: 3,
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(surface, findsOneWidget);
    final listFinder = find.descendant(
      of: find.byType(AdaptiveDialogFrame),
      matching: find.byType(ListView),
    );
    final scrollableFinder = find.descendant(
      of: listFinder,
      matching: find.byType(Scrollable),
    );
    final scrollable = tester.state<ScrollableState>(scrollableFinder);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    final lastOption = find.byKey(
      ValueKey('fixed-tag-link-option-${fixture.negatives.last.id}'),
    );
    await tester.scrollUntilVisible(
      lastOption,
      800,
      scrollable: scrollableFinder,
    );
    await tester.pumpAndSettle();

    expect(lastOption, findsOneWidget);
    expect(tester.getTopLeft(surface).dy, greaterThanOrEqualTo(24));
    expect(tester.getBottomRight(surface).dy, lessThanOrEqualTo(540));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Medium 使用有界 AdaptivePresenter 内容并可关闭', (tester) async {
    final fixture = _linkFixture(linkCount: 4);
    await _pumpLauncher(
      tester,
      size: const Size(700, 700),
      notifier: _TestFixedTagsNotifier(fixture.state),
      entry: fixture.positive,
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    final frame = find.byType(AdaptiveDialogFrame);
    expect(frame, findsOneWidget);
    expect(tester.getSize(frame).width, lessThanOrEqualTo(420));
    expect(tester.getSize(frame).height, lessThanOrEqualTo(480));

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required Size size,
  required _TestFixedTagsNotifier notifier,
  required FixedTagEntry entry,
  double textScaleFactor = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [fixedTagsNotifierProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        ),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => FilledButton(
              onPressed: () => showFixedTagLinkManager(
                context: context,
                ref: ref,
                entry: entry,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
}

({FixedTagEntry positive, List<FixedTagEntry> negatives, FixedTagsState state})
_linkFixture({required int linkCount, int? linkedCount}) {
  final positive = _entry(
    id: 'positive',
    name: '很长的正向固定词名称',
    promptType: FixedTagPromptType.positive,
  );
  final negatives = [
    for (var index = 0; index < linkCount; index++)
      _entry(
        id: 'negative-$index',
        name: '负向固定词 $index',
        promptType: FixedTagPromptType.negative,
      ),
  ];
  final linked = linkedCount ?? linkCount;
  return (
    positive: positive,
    negatives: negatives,
    state: FixedTagsState(
      entries: [positive, ...negatives],
      links: [
        for (final negative in negatives.take(linked))
          FixedTagLink(
            id: 'link-${negative.id}',
            positiveEntryId: positive.id,
            negativeEntryId: negative.id,
          ),
      ],
    ),
  );
}

FixedTagEntry _entry({
  required String id,
  required String name,
  required FixedTagPromptType promptType,
}) {
  return FixedTagEntry.create(
    name: name,
    content: '$name content',
    promptType: promptType,
  ).copyWith(id: id);
}

class _TestFixedTagsNotifier extends FixedTagsNotifier {
  _TestFixedTagsNotifier(this.initialState);

  final FixedTagsState initialState;
  (String, String)? removedPair;

  @override
  FixedTagsState build() => initialState;

  @override
  Future<void> removeLinkByPair({
    required String positiveEntryId,
    required String negativeEntryId,
  }) async {
    removedPair = (positiveEntryId, negativeEntryId);
    state = state.copyWith(
      links: state.links
          .where(
            (link) =>
                link.positiveEntryId != positiveEntryId ||
                link.negativeEntryId != negativeEntryId,
          )
          .toList(),
    );
  }
}
