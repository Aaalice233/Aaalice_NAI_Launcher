import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/adaptive_dialog_frame.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/add_tag_group_dialog.dart';

import '../../../../helpers/flutter_error_collector.dart';

void main() {
  const category = RandomCategory(
    id: 'test-category',
    name: 'Test category',
    key: 'testCategory',
  );

  testWidgets('320dp 3x text with IME and SafeArea uses full-screen form', (
    tester,
  ) async {
    final errors = FlutterErrorCollector.install(tester);
    addTearDown(errors.restoreAndAssertNoErrors);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(960, 1704);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpHost(
      tester,
      category: category,
      mediaQuery: (data) => data.copyWith(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
        viewPadding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
        viewInsets: const EdgeInsets.only(bottom: 240),
        textScaler: const TextScaler.linear(3),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-full-screen-form'));
    expect(surface, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AdaptiveDialogFrame), findsNothing);

    final surfaceRect = tester.getRect(surface);
    expect(surfaceRect.left, greaterThanOrEqualTo(12));
    expect(surfaceRect.top, greaterThanOrEqualTo(24));
    expect(surfaceRect.right, lessThanOrEqualTo(320 - 12));
    expect(surfaceRect.bottom, lessThanOrEqualTo(568 - 240));

    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isTrue,
    );

    final formScroll = find.byKey(const ValueKey('add-tag-group-form-scroll'));
    final scrollableFinder = find
        .descendant(of: formScroll, matching: find.byType(Scrollable))
        .first;
    final scrollable = tester.state<ScrollableState>(scrollableFinder);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final cancel = find.text('Cancel');
    expect(cancel, findsOneWidget);
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    expect(cancel.hitTestable(), findsOneWidget);
    errors.expectNoErrors(reason: 'compact tag group form');
  });

  testWidgets(
    'wide presentation stays bounded and preserves all source modes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpHost(tester, category: category);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final surface = find.byKey(const ValueKey('adaptive-side-sheet'));
      expect(surface, findsOneWidget);
      final surfaceRect = tester.getRect(surface);
      expect(surfaceRect.width, lessThanOrEqualTo(580));
      expect(surfaceRect.right, 1200);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Tag Group'), findsOneWidget);
      expect(find.text('Danbooru Pool'), findsOneWidget);
      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Cancel'), findsOneWidget);
      final addButton = find.ancestor(
        of: find.text('Add'),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(addButton).onPressed, isNull);
      await tester.enterText(find.byType(TextFormField).first, 'My group');
      await tester.pump();
      expect(tester.widget<FilledButton>(addButton).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required RandomCategory category,
  MediaQueryData Function(MediaQueryData data)? mediaQuery,
}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: mediaQuery == null
            ? null
            : (context, child) => MediaQuery(
                data: mediaQuery(MediaQuery.of(context)),
                child: child!,
              ),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => AddTagGroupDialog.show(
                context,
                category: category,
                presetId: 'test-preset',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}
