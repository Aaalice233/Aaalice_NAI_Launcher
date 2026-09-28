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

  testWidgets('narrow safe area and large text do not overflow', (
    tester,
  ) async {
    const size = Size(360, 640);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(2),
              padding: EdgeInsets.fromLTRB(8, 20, 8, 24),
            ),
            child: SlideshowScreen(
              images: [
                LocalImageRecord(
                  path: 'C:/tmp/missing_slide.png',
                  size: 1,
                  modifiedAt: DateTime(2026),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('empty state scrolls with actions at 320px and 3x text', (
    tester,
  ) async {
    const size = Size(320, 180);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        const MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(3),
            padding: EdgeInsets.fromLTRB(8, 12, 8, 16),
          ),
          child: SlideshowScreen(images: []),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('slideshow_back')), findsOneWidget);
    expect(find.byKey(const ValueKey('slideshow_home')), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('slideshow_empty_scroll_view')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short landscape controls do not overflow at 3x text', (
    tester,
  ) async {
    const size = Size(568, 240);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        MediaQuery(
          data: const MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(3),
            padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
          ),
          child: SlideshowScreen(
            images: [
              LocalImageRecord(
                path: 'C:/tmp/missing_landscape_slide.png',
                size: 1,
                modifiedAt: DateTime(2026),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
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
