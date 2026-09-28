import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_action.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_context_menu.dart';
import 'package:nai_launcher/presentation/widgets/common/pro_context_menu.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_context_menu.dart';

List<ProMenuItem> menuItems(WidgetTester tester) => tester
    .widget<ProContextMenu>(find.byType(ProContextMenu))
    .items
    .where((i) => !i.isDivider)
    .toList();

void main() {
  setUp(
    () => PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    ),
  );
  tearDown(() => PlatformCapabilities.debugOverride = null);

  testWidgets(
    'single descriptor set retains every local action and disables disconnected Krita',
    (tester) async {
      LocalImageContextAction? selected;
      await tester.pumpWidget(
        _MenuHarness(onSelected: (value) => selected = value),
      );
      await tester.tap(find.text('Open'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      final items = menuItems(tester);
      final expected = LocalImageContextAction.values
          .where(
            (action) => !{
              LocalImageContextAction.createWatermark,
              LocalImageContextAction.createMosaic,
              LocalImageContextAction.saveToSystemGallery,
            }.contains(action),
          )
          .map(LocalImageContextMenu.idFor)
          .map((id) => id.name);
      expect(items.map((i) => i.id), unorderedEquals(expected));
      expect(items.last.id, ImageCardActionId.delete.name);
      expect(
        items
            .singleWhere((i) => i.id == ImageCardActionId.sendToKrita.name)
            .enabled,
        isFalse,
      );
      await tester.ensureVisible(find.text('Send to Krita'));
      await tester.tap(find.text('Send to Krita'));
      await tester.pump();
      expect(selected, isNull);
      expect(find.byType(ProContextMenu), findsOneWidget);
      await tester.ensureVisible(find.text('Send to Vibe Transfer'));
      await tester.tap(find.text('Send to Vibe Transfer'));
      await tester.pumpAndSettle();
      expect(selected, LocalImageContextAction.sendToStyleTransfer);
    },
  );

  testWidgets(
    'metadata availability and optional watermark affect the same descriptor set',
    (tester) async {
      await tester.pumpWidget(
        const _MenuHarness(metadata: false, watermark: true, krita: true),
      );
      await tester.tap(find.text('Open'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      final items = menuItems(tester);
      final ids = items.map((i) => i.id).toSet();
      expect(ids, isNot(contains(ImageCardActionId.importMetadata.name)));
      expect(ids, isNot(contains(ImageCardActionId.copyPrompt.name)));
      expect(ids, isNot(contains(ImageCardActionId.copySeed.name)));
      expect(
        items
            .singleWhere((i) => i.id == ImageCardActionId.createWatermark.name)
            .enabled,
        isTrue,
      );
      expect(
        items
            .singleWhere((i) => i.id == ImageCardActionId.sendToKrita.name)
            .enabled,
        isTrue,
      );
    },
  );

  testWidgets(
    'send menu reuses business descriptors without information or delete actions',
    (tester) async {
      await tester.pumpWidget(
        const _MenuHarness(sendOnly: true, watermark: true),
      );
      await tester.tap(find.text('Open'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      final ids = menuItems(tester).map((i) => i.id).toSet();
      expect(
        ids,
        containsAll([
          ImageCardActionId.sendToGeneration.name,
          ImageCardActionId.imageToImage.name,
          ImageCardActionId.reversePrompt.name,
          ImageCardActionId.vibeTransfer.name,
          ImageCardActionId.preciseReference.name,
          ImageCardActionId.saveToPreciseRefLibrary.name,
          ImageCardActionId.sendToKrita.name,
          ImageCardActionId.upscale.name,
          ImageCardActionId.dlssEnhance.name,
          ImageCardActionId.shareDiscord.name,
          ImageCardActionId.createWatermark.name,
        ]),
      );
      expect(ids.length, 11);
    },
  );

  testWidgets('Android touch menu keeps system gallery export reachable', (
    tester,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    await tester.pumpWidget(const _MenuHarness(touch: true));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save to photo gallery'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      tester
          .widget<ListTile>(
            find.ancestor(
              of: find.text('Save to photo gallery'),
              matching: find.byType(ListTile),
            ),
          )
          .enabled,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      'pointer menu fits safe bounds and reaches last action at $width and 3x',
      (tester) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _MenuHarness(
            position: Offset(width - 1, 620),
            safePadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            scale: 3,
          ),
        );
        await tester.tap(find.text('Open'), kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.byType(ProContextMenu));
        // ProContextMenu owns a Positioned child; inspect the actual material surface.
        final surface = find
            .descendant(
              of: find.byType(ProContextMenu),
              matching: find.byType(Material),
            )
            .first;
        final bounds = tester.getRect(surface);
        expect(bounds.left, greaterThanOrEqualTo(24));
        expect(bounds.right, lessThanOrEqualTo(width - 24));
        expect(rect.size.isEmpty, isFalse);
        await tester.ensureVisible(find.text('Delete'));
        expect(find.text('Delete').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _MenuHarness extends StatelessWidget {
  const _MenuHarness({
    this.metadata = true,
    this.krita = false,
    this.watermark = false,
    this.sendOnly = false,
    this.touch = false,
    this.position = const Offset(20, 20),
    this.safePadding = EdgeInsets.zero,
    this.scale = 1,
    this.onSelected,
  });
  final bool metadata, krita, watermark, sendOnly, touch;
  final Offset position;
  final EdgeInsets safePadding;
  final double scale;
  final ValueChanged<LocalImageContextAction?>? onSelected;

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => InteractionPolicyScope(
      initialPolicy: InteractionPolicy(
        modality: touch
            ? InteractionModality.touch
            : InteractionModality.pointer,
        touchAvailable: touch,
        precisePointerAvailable: !touch,
      ),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(padding: safePadding, textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            if (sendOnly) {
              await ImageCardContextMenu.show(
                context: context,
                position: position,
                actions: LocalImageContextMenu.buildSendActions(
                  context,
                  onAction: (value) async => onSelected?.call(value),
                  isKritaConnected: krita,
                  watermarkEnabled: watermark,
                ),
              );
            } else {
              final selected = await LocalImageContextMenu.show(
                context,
                position: position,
                hasImportableMetadata: metadata,
                hasPrompt: metadata,
                hasSeed: metadata,
                isKritaConnected: krita,
                watermarkEnabled: watermark,
              );
              onSelected?.call(selected);
            }
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
}
