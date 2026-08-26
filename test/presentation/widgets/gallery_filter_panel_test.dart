import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/gallery_filter_panel.dart';

void main() {
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
