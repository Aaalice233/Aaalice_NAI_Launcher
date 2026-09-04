import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_card.dart';
import 'package:nai_launcher/presentation/widgets/common/card_action_buttons.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_actions.dart';
import 'package:nai_launcher/presentation/widgets/common/library_card_badges.dart';

void main() {
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

  testWidgets('Vibe 卡片仅在有分类时显示类别，并为收藏条目显示常驻徽章', (tester) async {
    final favoriteEntry = _entry(
      rawImageData: _onePixelPng,
    ).copyWith(isFavorite: true);

    Future<void> pumpCard({String? categoryLabel}) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          vibeLibraryStorageServiceProvider.overrideWithValue(
            _HoverStorage(favoriteEntry, _onePixelPng),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: VibeCard(
                entry: favoriteEntry.toDisplayEntry(),
                width: 180,
                categoryLabel: categoryLabel,
              ),
            ),
          ),
        ),
      ),
    );

    await pumpCard(categoryLabel: '人物 / 女性角色');
    expect(find.text('人物 / 女性角色'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vibe-card-category-hover-vibe')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vibe-card-favorite-badge-hover-vibe')),
      findsOneWidget,
    );
    expect(find.byType(LibraryCardFavoriteBadge), findsOneWidget);

    await pumpCard();
    expect(find.text('人物 / 女性角色'), findsNothing);
    expect(
      find.byKey(const ValueKey('vibe-card-category-hover-vibe')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Vibe 卡片悬浮操作复用图片卡片双列操作轨', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final thumbnail = _onePixelPng;
    final entry = _entry(rawImageData: Uint8List.fromList(thumbnail));
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
            body: Align(
              alignment: Alignment.topLeft,
              child: ImageCardActionScope(
                onAddToAgent: () {},
                child: VibeCard(
                  entry: entry.toDisplayEntry(),
                  width: 170,
                  height: computeVibeCardHeight(170),
                  onFavoriteToggle: () {},
                  onSendToGeneration: () {},
                  onExport: () {},
                  onEdit: () {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final cardFinder = find.byType(VibeCard);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(cardFinder));
    await tester.pump();

    final cardRect = tester.getRect(cardFinder);
    expect(find.byType(CardActionButtons), findsOneWidget);
    final actionKeys = [
      for (final action in [
        'favorite',
        'agent',
        'send',
        'export',
        'edit',
        'delete',
      ])
        ValueKey('vibe-card-$action-${entry.id}'),
    ];
    final actionRects = [
      for (final key in actionKeys) tester.getRect(find.byKey(key)),
    ];

    for (final rect in actionRects) {
      expect(cardRect.contains(rect.topLeft), isTrue);
      expect(cardRect.contains(rect.bottomRight), isTrue);
    }
    expect(actionRects.take(3).map((rect) => rect.left).toSet(), hasLength(1));
    expect(actionRects.skip(3).map((rect) => rect.left).toSet(), hasLength(1));
    expect(actionRects[3].left, greaterThan(actionRects[0].left));
    expect(actionRects[0].top, closeTo(actionRects[3].top, 0.01));

    final sendButton = tester.widget<IconButton>(
      find.byKey(ValueKey('vibe-card-send-${entry.id}')),
    );
    final deleteButton = tester.widget<IconButton>(
      find.byKey(ValueKey('vibe-card-delete-${entry.id}')),
    );
    expect(
      sendButton.style!.backgroundColor!.resolve(const {}),
      ImageOverlayControlStyle.surface,
    );
    expect(
      deleteButton.style!.backgroundColor!.resolve(const {}),
      ImageOverlayControlStyle.surface,
    );
    expect(sendButton.style!.shape!.resolve(const {}), isA<CircleBorder>());
    expect(deleteButton.style!.shape!.resolve(const {}), isA<CircleBorder>());
    expect(
      sendButton.style!.foregroundColor!.resolve(const {}),
      ImageOverlayControlStyle.foreground,
    );
    expect(
      deleteButton.style!.foregroundColor!.resolve(const {}),
      Theme.of(tester.element(find.byIcon(Icons.delete))).colorScheme.error,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Vibe 卡片桌面与触屏操作均可发送到智能体', (tester) async {
    var addCount = 0;
    var classifyCount = 0;
    final entry = _entry(rawImageData: _onePixelPng);
    final storage = _HoverStorage(entry, _onePixelPng);

    Future<void> pumpCard(InteractionPolicy policy) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          vibeLibraryStorageServiceProvider.overrideWithValue(storage),
        ],
        child: InteractionPolicyScope(
          initialPolicy: policy,
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ImageCardActionScope(
                onAddToAgent: () => addCount++,
                child: VibeCard(
                  entry: entry.toDisplayEntry(),
                  width: 180,
                  onClassify: () => classifyCount++,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await pumpCard(
      const InteractionPolicy(
        modality: InteractionModality.pointer,
        touchAvailable: false,
        precisePointerAvailable: true,
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(VibeCard)));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    expect(addCount, 1);

    await pumpCard(
      const InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: false,
      ),
    );
    await tester.tap(
      find.byIcon(Icons.more_vert_rounded),
      kind: PointerDeviceKind.touch,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送到智能体'), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(addCount, 2);

    await tester.tap(
      find.byIcon(Icons.more_vert_rounded),
      kind: PointerDeviceKind.touch,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('移动到分类'), kind: PointerDeviceKind.touch);
    expect(classifyCount, 1);
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
