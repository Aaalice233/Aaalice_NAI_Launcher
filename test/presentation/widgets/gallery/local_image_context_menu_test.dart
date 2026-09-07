import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_context_menu.dart';

void main() {
  setUp(() {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
  });

  tearDown(() => PlatformCapabilities.debugOverride = null);

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
      LocalImageContextAction.addToAgent,
      LocalImageContextAction.moveToCategory,
      LocalImageContextAction.sendToTextToImage,
      LocalImageContextAction.sendToImg2Img,
      LocalImageContextAction.sendToReversePrompt,
      LocalImageContextAction.sendToStyleTransfer,
      LocalImageContextAction.sendToPreciseReference,
      LocalImageContextAction.saveToPreciseRefLibrary,
      LocalImageContextAction.sendToKrita,
      LocalImageContextAction.upscale,
      LocalImageContextAction.dlssEnhance,
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

  testWidgets('shows the watermark command when the tool is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _MenuHarness(isKritaConnected: true, watermarkEnabled: true),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Create watermarked copy…'), findsOneWidget);
    final item = tester
        .widgetList<PopupMenuItem<LocalImageContextAction>>(
          find.byType(PopupMenuItem<LocalImageContextAction>),
        )
        .singleWhere(
          (item) => item.value == LocalImageContextAction.createWatermark,
        );
    expect(item.enabled, isTrue);
  });

  testWidgets('Android menu exposes system photo gallery export', (
    tester,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    await tester.pumpWidget(const _MenuHarness(isKritaConnected: false));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Save to photo gallery'), findsOneWidget);
    final item = tester
        .widgetList<PopupMenuItem<LocalImageContextAction>>(
          find.byType(PopupMenuItem<LocalImageContextAction>),
        )
        .singleWhere(
          (entry) => entry.value == LocalImageContextAction.saveToSystemGallery,
        );
    expect(item.enabled, isTrue);
  });

  testWidgets('opens without an expand animation', (tester) async {
    await tester.pumpWidget(const _MenuHarness(isKritaConnected: true));

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(find.text('Share to Discord'), findsOneWidget);
  });

  testWidgets(
    'fits the complete menu inside a 320dp safe area at an edge anchor',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const _MenuHarness(
          isKritaConnected: true,
          position: Offset(319, 100),
          safePadding: EdgeInsets.symmetric(horizontal: 24),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final items = find.byType(PopupMenuItem<LocalImageContextAction>);
      expect(items, findsNWidgets(17));
      for (final element in items.evaluate()) {
        final rect = tester.getRect(
          find.byElementPredicate((candidate) => candidate == element),
        );
        expect(rect.left, greaterThanOrEqualTo(32));
        expect(rect.right, lessThanOrEqualTo(288));
      }
      expect(tester.takeException(), isNull);
    },
  );

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
      const _MenuHarness(
        isKritaConnected: true,
        sendOnly: true,
        watermarkEnabled: true,
      ),
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
      LocalImageContextAction.dlssEnhance,
      LocalImageContextAction.shareToDiscord,
      LocalImageContextAction.createWatermark,
    ]);
    expect(find.text('Create watermarked copy…'), findsOneWidget);
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
    this.watermarkEnabled = false,
    this.position = const Offset(20, 20),
    this.safePadding = EdgeInsets.zero,
    this.onSelected,
  });

  final bool hasImportableMetadata;
  final bool hasPrompt;
  final bool hasSeed;
  final bool isKritaConnected;
  final bool sendOnly;
  final bool watermarkEnabled;
  final Offset position;
  final EdgeInsets safePadding;
  final ValueChanged<LocalImageContextAction?>? onSelected;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: safePadding),
        child: child!,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final selected = sendOnly
                  ? await LocalImageContextMenu.showSendActions(
                      context,
                      position: position,
                      isKritaConnected: isKritaConnected,
                      watermarkEnabled: watermarkEnabled,
                    )
                  : await LocalImageContextMenu.show(
                      context,
                      position: position,
                      hasImportableMetadata: hasImportableMetadata,
                      hasPrompt: hasPrompt,
                      hasSeed: hasSeed,
                      isKritaConnected: isKritaConnected,
                      watermarkEnabled: watermarkEnabled,
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
