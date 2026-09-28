import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_detail_loading_dialog.dart';

void main() {
  for (final size in [const Size(320, 480), const Size(1600, 900)]) {
    testWidgets('详情加载提示在 $size 和 3x 文本下保持有界且可取消', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var cancelled = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: OnlineGalleryDetailLoadingDialog(
                onCancel: () => cancelled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final surface = find.byKey(
        const Key('online-gallery-detail-loading-surface'),
      );
      final cancel = find.byKey(
        const Key('online-gallery-detail-loading-cancel'),
      );
      expect(surface, findsOneWidget);
      expect(tester.getSize(surface).width, lessThanOrEqualTo(size.width - 32));
      expect(tester.getSize(cancel).height, greaterThanOrEqualTo(44));
      expect(
        find.byKey(const Key('online-gallery-detail-loading-progress')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(cancel);
      await tester.pump();
      expect(cancelled, isTrue);
    });
  }
}
