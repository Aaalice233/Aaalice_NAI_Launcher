import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/gallery_filter_panel.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('窄屏 ${width.toInt()}px 步数和 CFG 筛选独占一行', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _pumpFilterPanel(tester);

      expect(
        find.byKey(const ValueKey('galleryFilterNarrowRangeGroups')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('按 CFG 筛选')).dy,
        greaterThan(tester.getTopLeft(find.text('按步数筛选')).dy),
      );

      for (final hint in ['最小值', '最大值']) {
        expect(find.text(hint), findsNWidgets(2));
        for (final element in find.text(hint).evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          expect(paragraph.didExceedMaxLines, isFalse);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Medium 使用有界 bottom sheet 并保持双列', (tester) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpFilterPanel(tester);

    final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface).width, lessThanOrEqualTo(700));
    expect(tester.getRect(surface).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(surface).bottom, lessThanOrEqualTo(800));
    expect(
      find.byKey(const ValueKey('galleryFilterWideRangeGroups')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('按 CFG 筛选')).dy,
      tester.getTopLeft(find.text('按步数筛选')).dy,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px 与 3x 字号下筛选面板仍可滚动并操作', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpFilterPanel(tester, textScaler: const TextScaler.linear(3));

    final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(surface, findsOneWidget);
    expect(
      find.byKey(const ValueKey('galleryFilterScrollView')),
      findsOneWidget,
    );
    expect(find.text('应用筛选').hitTestable(), findsOneWidget);
    expect(find.byTooltip('关闭').hitTestable(), findsOneWidget);
    expect(tester.getRect(surface), const Rect.fromLTWH(0, 0, 320, 640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机键盘打开时筛选面板约束在可见区域内', (tester) async {
    tester.view.physicalSize = const Size(393, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showGalleryFilterPanel(context),
                  child: const Text('筛选'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();

    expect(find.byType(GalleryFilterPanel), findsOneWidget);
    final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(tester.getRect(surface).bottom, lessThanOrEqualTo(480));
    expect(find.text('应用筛选').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact 表单避开 SafeArea 且可由共享关闭入口关闭', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      left: 12,
      top: 24,
      right: 16,
      bottom: 20,
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await _pumpFilterPanel(tester);

    final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    final rect = tester.getRect(surface);
    expect(rect.left, greaterThanOrEqualTo(12));
    expect(rect.top, greaterThanOrEqualTo(24));
    expect(rect.right, lessThanOrEqualTo(304));
    expect(rect.bottom, lessThanOrEqualTo(700));

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryFilterPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFilterPanel(
  WidgetTester tester, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showGalleryFilterPanel(context),
                child: const Text('筛选'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('筛选'));
  await tester.pumpAndSettle();
}
