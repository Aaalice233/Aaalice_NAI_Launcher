import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/gallery_filter_panel.dart';

void main() {
  for (final width in [360.0, 390.0]) {
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

  testWidgets('宽屏步数和 CFG 筛选保持双列', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpFilterPanel(tester);

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
    expect(
      tester.getSize(find.byType(GalleryFilterPanel)).height,
      lessThanOrEqualTo(432),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFilterPanel(WidgetTester tester) async {
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
}
