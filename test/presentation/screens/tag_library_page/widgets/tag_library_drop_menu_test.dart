import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/tag_library_drop_menu.dart';

import '../../../../helpers/flutter_error_collector.dart';

void main() {
  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      '$width short drop menu leaves no empty viewport below actions',
      (tester) async {
        await _setViewport(tester, Size(width, 1000));
        TagLibraryDropAction? result;
        await tester.pumpWidget(
          _harness(
            textScaler: TextScaler.noScaling,
            onResult: (value) => result = value,
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open-drop-menu')));
        await tester.pumpAndSettle();
        final panel = find.byKey(
          ValueKey(
            width < 600 ? 'adaptive-bottom-sheet' : 'adaptive-centered-form',
          ),
        );
        expect(tester.getSize(panel).height, lessThan(450));
        expect(
          tester.getRect(panel).bottom - tester.getRect(find.text('取消')).bottom,
          lessThan(60),
        );
        expect(find.text('创建新词条').hitTestable(), findsOneWidget);
        expect(find.text('更新现有词条预览图').hitTestable(), findsOneWidget);
        await tester.tap(find.text('创建新词条'));
        await tester.pumpAndSettle();
        expect(result, TagLibraryDropAction.create);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    '320x568 3x SafeArea/IME uses a full-screen scrollable form and returns selection',
    (tester) async {
      final errors = FlutterErrorCollector.install(tester);
      addTearDown(errors.restoreAndAssertNoErrors);
      await _setCompactImeViewport(tester);
      TagLibraryDropAction? result;
      var completed = false;
      await tester.pumpWidget(
        _harness(
          onResult: (value) {
            result = value;
            completed = true;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-drop-menu')));
      await tester.pumpAndSettle();

      final panel = find.byKey(const ValueKey('adaptive-bottom-sheet'));
      expect(panel, findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(
        find.byKey(const ValueKey('tag-library-drop-menu-scroll')),
        findsOneWidget,
      );
      final panelRect = tester.getRect(panel);
      expect(panelRect.top, greaterThanOrEqualTo(20));
      expect(panelRect.bottom, lessThanOrEqualTo(568 - 240));
      expect(find.text('拖入图片'), findsOneWidget);
      expect(find.text('创建新词条'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('tag-library-drop-menu-scroll')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final update = find.text('更新现有词条预览图');
      expect(update, findsOneWidget);
      final updateCenter = tester.getCenter(update);
      expect(updateCenter.dy, greaterThanOrEqualTo(panelRect.top));
      expect(updateCenter.dy, lessThanOrEqualTo(panelRect.bottom));
      await tester.tap(update);
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, TagLibraryDropAction.updateThumbnail);
      expect(panel, findsNothing);
      errors.expectNoErrors(reason: 'compact tag-library drop menu');
    },
  );

  testWidgets('explicit cancel preserves the cancel action result', (
    tester,
  ) async {
    await _setViewport(tester, const Size(700, 800));
    TagLibraryDropAction? result;
    var completed = false;
    await tester.pumpWidget(
      _harness(
        onResult: (value) {
          result = value;
          completed = true;
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-drop-menu')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, TagLibraryDropAction.cancel);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back dismisses without selecting an action', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 568));
    TagLibraryDropAction? result = TagLibraryDropAction.create;
    var completed = false;
    await tester.pumpWidget(
      _harness(
        onResult: (value) {
          result = value;
          completed = true;
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-drop-menu')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setCompactImeViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(960, 1704);
  tester.view.padding = const FakeViewPadding(top: 60, bottom: 90);
  tester.view.viewInsets = const FakeViewPadding(bottom: 720);
  addTearDown(tester.view.reset);
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Widget _harness({
  required ValueChanged<TagLibraryDropAction?> onResult,
  TextScaler textScaler = const TextScaler.linear(3),
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            key: const ValueKey('open-drop-menu'),
            onPressed: () async {
              onResult(
                await TagLibraryDropMenu.show(
                  context,
                  fileName:
                      'very-long-dropped-image-file-name-for-responsive-test.png',
                  prompt:
                      'masterpiece, best quality, extremely detailed, cinematic lighting',
                ),
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
}
