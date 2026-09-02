import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_card.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_actions.dart';

void main() {
  tearDown(() => PlatformCapabilities.debugOverride = null);

  test('悬浮大图按比例适配且不会随高窗口无限增高', () {
    expect(
      computeVibeHoverPreviewBounds(const Size(700, 520)),
      const Size(380, 500),
    );
    expect(
      computeVibeHoverPreviewBounds(const Size(1200, 1000)),
      const Size(380, 680),
    );
    expect(
      computeVibeHoverImageSize(aspectRatio: 2, maxWidth: 380, maxHeight: 500),
      const Size(380, 190),
    );
    expect(
      computeVibeHoverImageSize(
        aspectRatio: 0.5,
        maxWidth: 380,
        maxHeight: 500,
      ),
      const Size(250, 500),
    );
  });

  testWidgets('Vibe 卡片悬浮显示高清图和关键信息且不会被窗口截断', (tester) async {
    tester.view.physicalSize = const Size(700, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final thumbnail = _onePixelPng;
    final highResolutionImage = Uint8List.fromList(_onePixelPng);
    final entry = _entry(rawImageData: highResolutionImage);
    final storage = _HoverStorage(entry, thumbnail);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vibeLibraryStorageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: VibeCard(entry: entry.toDisplayEntry(), width: 150),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final card = find.byType(VibeCard);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 281));
    await tester.pump();

    final preview = find.byKey(const ValueKey('vibe-hover-preview'));
    expect(preview, findsOneWidget);
    final rect = tester.getRect(preview);
    expect(rect.left, greaterThanOrEqualTo(10));
    expect(rect.top, greaterThanOrEqualTo(10));
    expect(rect.right, lessThanOrEqualTo(690));
    expect(rect.bottom, lessThanOrEqualTo(510));

    expect(find.text('Portrait Study'), findsWidgets);
    expect(find.text('强度 62%'), findsOneWidget);
    expect(find.text('信息提取 74%'), findsOneWidget);
    expect(find.text('使用次数 8'), findsOneWidget);
    final statCenters = [
      tester.getCenter(find.text('强度 62%')).dy,
      tester.getCenter(find.text('信息提取 74%')).dy,
      tester.getCenter(find.text('使用次数 8')).dy,
    ];
    expect(statCenters.toSet(), hasLength(1));
    expect(find.text('#portrait  #dramatic_light'), findsOneWidget);

    final hoverMedia = find.byKey(const ValueKey('vibe-hover-media'));
    final image = tester.widget<Image>(
      find.descendant(of: hoverMedia, matching: find.byType(Image)),
    );
    final resized = image.image as ResizeImage;
    expect(
      (resized.imageProvider as MemoryImage).bytes,
      same(highResolutionImage),
    );
  });

  testWidgets('Vibe 卡片悬浮操作可发送到智能体', (tester) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    var addCount = 0;
    final entry = _entry(rawImageData: _onePixelPng);
    final storage = _HoverStorage(entry, _onePixelPng);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vibeLibraryStorageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ImageCardActionScope(
                onAddToAgent: () => addCount++,
                child: VibeCard(entry: entry.toDisplayEntry(), width: 180),
              ),
            ),
          ),
        ),
      ),
    );

    final hoverRegion = tester.widget<MouseRegion>(
      find.byWidgetPredicate(
        (widget) =>
            widget is MouseRegion &&
            widget.cursor == SystemMouseCursors.click &&
            widget.onEnter != null,
      ),
    );
    hoverRegion.onEnter!(const PointerEnterEvent());
    await tester.pump();

    final action = find.byIcon(Icons.auto_awesome_outlined);
    expect(action, findsOneWidget);
    await tester.tap(action);
    expect(addCount, 1);
  });

  testWidgets('Vibe 卡片触屏菜单可发送到智能体', (tester) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    var addCount = 0;
    final entry = _entry(rawImageData: _onePixelPng);
    final storage = _HoverStorage(entry, _onePixelPng);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vibeLibraryStorageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ImageCardActionScope(
                onAddToAgent: () => addCount++,
                child: VibeCard(entry: entry.toDisplayEntry(), width: 180),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    final action = find.text('发送到智能体');
    expect(action, findsOneWidget);
    await tester.tap(action);
    expect(addCount, 1);
  });
}

VibeLibraryEntry _entry({required Uint8List rawImageData}) {
  return VibeLibraryEntry(
    id: 'hover-vibe',
    name: 'Portrait Study',
    vibeDisplayName: 'Portrait Study',
    vibeEncoding: 'encoded',
    rawImageData: rawImageData,
    strength: 0.62,
    infoExtracted: 0.74,
    sourceTypeIndex: VibeSourceType.naiv4vibe.index,
    tags: const ['portrait', 'dramatic_light'],
    usedCount: 8,
    createdAt: DateTime(2026, 4, 16),
    encodingModel: 'nai-diffusion-4-full',
  );
}

class _HoverStorage extends VibeLibraryStorageService {
  _HoverStorage(this.entry, this.thumbnail);

  final VibeLibraryEntry entry;
  final Uint8List thumbnail;

  @override
  Future<Uint8List?> getDisplayThumbnail(String id) async => thumbnail;

  @override
  Future<VibeLibraryDetailData?> getDetailData(String id) async =>
      VibeLibraryDetailData(entry: entry);
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
