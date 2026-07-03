import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/slideshow_screen.dart';

void main() {
  test('slideshow image provider caps decode size', () {
    final provider = buildSlideshowImageProvider('C:\\tmp\\slide.png');

    expect(provider, isA<ResizeImage>());
    final resized = provider as ResizeImage;
    expect(resized.width, 4096);
    expect(resized.height, 4096);
    expect(resized.policy, ResizeImagePolicy.fit);
  });

  testWidgets('dispose does not call setState', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SlideshowScreen(
          images: [
            LocalImageRecord(
              path: 'C:\\tmp\\missing_slide.png',
              size: 1,
              modifiedAt: DateTime(2026),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}
