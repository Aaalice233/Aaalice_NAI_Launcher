import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_context_menu.dart';

void main() {
  testWidgets('shows direct send actions in the agreed order', (tester) async {
    LocalImageContextAction? selected;

    await tester.pumpWidget(
      _MenuHarness(
        isKritaConnected: false,
        onSelected: (value) => selected = value,
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final items = tester
        .widgetList<PopupMenuItem<LocalImageContextAction>>(
          find.byWidgetPredicate(
            (widget) => widget is PopupMenuItem<LocalImageContextAction>,
          ),
        )
        .toList();

    expect(items.map((item) => item.value).toList(), const [
      LocalImageContextAction.sendToTextToImage,
      LocalImageContextAction.sendToImg2Img,
      LocalImageContextAction.sendToReversePrompt,
      LocalImageContextAction.sendToStyleTransfer,
      LocalImageContextAction.sendToPreciseReference,
      LocalImageContextAction.saveToPreciseRefLibrary,
      LocalImageContextAction.sendToKrita,
      LocalImageContextAction.upscale,
      LocalImageContextAction.shareToDiscord,
      LocalImageContextAction.importMetadata,
      LocalImageContextAction.copyPrompt,
      LocalImageContextAction.copySeed,
      LocalImageContextAction.showInFolder,
      LocalImageContextAction.delete,
    ]);
    expect(find.text('Send to...'), findsNothing);
    expect(find.text('Send to Text to Image'), findsOneWidget);
    expect(find.text('Send to Image2Image'), findsOneWidget);
    expect(find.text('Send to Reverse Prompt'), findsOneWidget);
    expect(find.text('Send to Vibe Transfer'), findsOneWidget);
    expect(find.text('Send to Precise Reference'), findsOneWidget);
    expect(find.text('Upscale'), findsOneWidget);
    expect(find.text('Share to Discord'), findsOneWidget);
    expect(find.text('Import Image Metadata'), findsOneWidget);

    final kritaItem = items.singleWhere(
      (item) => item.value == LocalImageContextAction.sendToKrita,
    );
    expect(kritaItem.enabled, isFalse);

    await tester.tap(find.text('Send to Krita'));
    await tester.pump();
    expect(selected, isNull);
    expect(find.text('Send to Krita'), findsOneWidget);

    await tester.tap(find.text('Send to Vibe Transfer'));
    await tester.pumpAndSettle();
    expect(selected, LocalImageContextAction.sendToStyleTransfer);
  });

  testWidgets('opens without an expand animation', (tester) async {
    await tester.pumpWidget(const _MenuHarness(isKritaConnected: true));

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(find.text('Share to Discord'), findsOneWidget);
  });

  testWidgets('hides image information actions when metadata is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _MenuHarness(
        hasImportableMetadata: false,
        hasPrompt: false,
        hasSeed: false,
        isKritaConnected: true,
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Import Image Metadata'), findsNothing);
    expect(find.text('Copy Prompt'), findsNothing);
    expect(find.text('Copy Seed'), findsNothing);

    final kritaItem = tester
        .widgetList<PopupMenuItem<LocalImageContextAction>>(
          find.byWidgetPredicate(
            (widget) => widget is PopupMenuItem<LocalImageContextAction>,
          ),
        )
        .singleWhere(
          (item) => item.value == LocalImageContextAction.sendToKrita,
        );
    expect(kritaItem.enabled, isTrue);
  });

  testWidgets('send button menu reuses the context menu send action group', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _MenuHarness(isKritaConnected: true, sendOnly: true),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final actions = tester
        .widgetList<PopupMenuItem<LocalImageContextAction>>(
          find.byWidgetPredicate(
            (widget) => widget is PopupMenuItem<LocalImageContextAction>,
          ),
        )
        .map((item) => item.value)
        .toList();

    expect(actions, const [
      LocalImageContextAction.sendToTextToImage,
      LocalImageContextAction.sendToImg2Img,
      LocalImageContextAction.sendToReversePrompt,
      LocalImageContextAction.sendToStyleTransfer,
      LocalImageContextAction.sendToPreciseReference,
      LocalImageContextAction.saveToPreciseRefLibrary,
      LocalImageContextAction.sendToKrita,
      LocalImageContextAction.upscale,
      LocalImageContextAction.shareToDiscord,
    ]);
    expect(find.text('Import Image Metadata'), findsNothing);
    expect(find.text('Show in Folder'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });
}

class _MenuHarness extends StatelessWidget {
  const _MenuHarness({
    this.hasImportableMetadata = true,
    this.hasPrompt = true,
    this.hasSeed = true,
    required this.isKritaConnected,
    this.sendOnly = false,
    this.onSelected,
  });

  final bool hasImportableMetadata;
  final bool hasPrompt;
  final bool hasSeed;
  final bool isKritaConnected;
  final bool sendOnly;
  final ValueChanged<LocalImageContextAction?>? onSelected;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final selected = sendOnly
                  ? await LocalImageContextMenu.showSendActions(
                      context,
                      position: const Offset(20, 20),
                      isKritaConnected: isKritaConnected,
                    )
                  : await LocalImageContextMenu.show(
                      context,
                      position: const Offset(20, 20),
                      hasImportableMetadata: hasImportableMetadata,
                      hasPrompt: hasPrompt,
                      hasSeed: hasSeed,
                      isKritaConnected: isKritaConnected,
                    );
              onSelected?.call(selected);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }
}
