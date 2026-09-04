import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_prompt_projection.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/gallery_prompt_copy_dialog.dart';

void main() {
  testWidgets('options and copy footer fit 320x568 with 3x text and IME', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const projection = GalleryPromptCopyProjection(
      mainPositive: '1girl, blue hair',
      mainNegative: 'lowres',
      categorizedPrompts: {
        GalleryPromptCopyCategory.artist: 'artist:name',
        GalleryPromptCopyCategory.general: 'detailed background',
      },
    );
    final selection = projection.defaultSelection();
    GalleryPromptCopySelection? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(3),
            padding: const EdgeInsets.fromLTRB(12, 16, 14, 20),
            viewPadding: const EdgeInsets.fromLTRB(12, 16, 14, 20),
            viewInsets: const EdgeInsets.only(bottom: 240),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await GalleryPromptCopyDialog.show(
                context,
                projection: projection,
                initialSelection: selection,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(surface, findsOneWidget);
    final rect = tester.getRect(surface);
    expect(rect.left, greaterThanOrEqualTo(12));
    expect(rect.top, greaterThanOrEqualTo(16));
    expect(rect.right, lessThanOrEqualTo(320 - 14));
    expect(rect.bottom, lessThanOrEqualTo(568 - 240));
    final listView = tester.widget<ListView>(find.byType(ListView));
    final scrollController = listView.controller!;
    expect(scrollController.hasClients, isTrue);
    for (var i = 0; i < 20 && find.text('Copy').evaluate().isEmpty; i++) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pump();
    }
    expect(find.text('Copy'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Copy'));
    await tester.pumpAndSettle();
    expect(result, selection);
    expect(surface, findsNothing);
  });
}
