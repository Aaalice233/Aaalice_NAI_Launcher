import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/cache/local_gallery_thumbnail_provider.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/watermark/watermark_settings.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/card_action_buttons.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_hover_motion.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_card_3d.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_context_menu.dart';

void main() {
  late Directory hiveDirectory;
  late LocalStorageService storage;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'nai_local_card_hive_',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    storage = LocalStorageService();
  });

  setUp(() => Hive.box<dynamic>(StorageKeys.settingsBox).clear());

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('卡片按实际 DPR 更新动态解码目标', (tester) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    final tempDirectory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('nai_local_card_thumbnail_'),
    ))!;
    addTearDown(() async {
      LocalGalleryThumbnailMemoryCache.instance.clear();
      PlatformCapabilities.debugOverride = null;
      tester.view.resetDevicePixelRatio();
      await tempDirectory.delete(recursive: true);
    });
    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}source.png',
    );
    await tester.runAsync(
      () => file.writeAsBytes(
        img.encodePng(img.Image(width: 800, height: 600)),
        flush: true,
      ),
    );
    final stat = (await tester.runAsync(file.stat))!;
    final record = LocalImageRecord(
      path: file.path,
      size: stat.size,
      modifiedAt: stat.modified,
    );
    final actions = <LocalImageContextAction>[];

    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: LocalImageCard3D(
              record: record,
              width: 180,
              height: 220,
              onTap: () {},
              onSendAction: (action) async => actions.add(action),
            ),
          ),
        ),
      ),
    );
    var provider =
        tester.widget<Image>(find.byType(Image)).image
            as LocalGalleryThumbnailProvider;
    expect(
      provider.target,
      const LocalGalleryThumbnailTarget(width: 192, height: 224),
    );

    final motion = find.byType(ImageCardHoverMotion);
    expect(motion, findsOneWidget);
    expect(tester.widget<ImageCardHoverMotion>(motion).enabled, isTrue);

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
    final agentAction = find.byTooltip('Send to Agent');
    expect(agentAction, findsOneWidget);
    expect(find.byTooltip('More image actions'), findsOneWidget);
    expect(find.byTooltip('Send to Image2Image'), findsNothing);
    final portraitActionRects = [
      for (
        var index = 0;
        index < find.byType(IconButton).evaluate().length;
        index++
      )
        tester.getRect(find.byType(IconButton).at(index)),
    ];
    final portraitColumns = portraitActionRects
        .map((rect) => rect.left.round())
        .toSet();
    expect(portraitColumns, hasLength(2));
    final columnTops = portraitColumns.map(
      (left) => portraitActionRects
          .where((rect) => rect.left.round() == left)
          .map((rect) => rect.top.round())
          .reduce(math.min),
    );
    expect(columnTops.toSet(), hasLength(1));
    await tester.tap(agentAction);
    expect(actions, [LocalImageContextAction.addToAgent]);

    tester.view.devicePixelRatio = 2;
    await tester.pump();
    provider =
        tester.widget<Image>(find.byType(Image)).image
            as LocalGalleryThumbnailProvider;
    expect(
      provider.target,
      const LocalGalleryThumbnailTarget(width: 384, height: 448),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('横向窄卡片保留全部悬浮操作', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InteractionPolicyScope(
            initialPolicy: const InteractionPolicy(
              modality: InteractionModality.pointer,
              touchAvailable: false,
              precisePointerAvailable: true,
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: LocalImageCard3D(
                  record: LocalImageRecord(
                    path: 'missing-landscape.png',
                    size: 0,
                    modifiedAt: DateTime(2026, 9, 3),
                  ),
                  width: 180,
                  height: 120,
                  onTap: () {},
                  onFavoriteToggle: () {},
                  onSendAction: (_) async {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final cardFinder = find.byType(LocalImageCard3D);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(cardFinder));
    await tester.pump();

    final cardRect = tester.getRect(cardFinder);
    final actionsFinder = find.descendant(
      of: find.byType(CardActionButtons),
      matching: find.byType(IconButton),
    );
    final actionRects = [
      for (var index = 0; index < actionsFinder.evaluate().length; index++)
        tester.getRect(actionsFinder.at(index)),
    ];

    expect(actionRects, hasLength(6));
    for (final rect in actionRects) {
      expect(cardRect.contains(rect.topLeft), isTrue);
      expect(cardRect.contains(rect.bottomRight), isTrue);
    }
    expect(actionRects.last.top, greaterThan(actionRects.first.top));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('纵向卡片将六个悬浮操作排成完整两列', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InteractionPolicyScope(
            initialPolicy: const InteractionPolicy(
              modality: InteractionModality.pointer,
              touchAvailable: false,
              precisePointerAvailable: true,
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: LocalImageCard3D(
                  record: LocalImageRecord(
                    path: 'missing-portrait.png',
                    size: 0,
                    modifiedAt: DateTime(2026, 9, 3),
                  ),
                  width: 180,
                  height: 220,
                  onTap: () {},
                  onFavoriteToggle: () {},
                  onSendAction: (_) async {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final cardFinder = find.byType(LocalImageCard3D);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(cardFinder));
    await tester.pump();

    final cardRect = tester.getRect(cardFinder);
    final actionsFinder = find.descendant(
      of: find.byType(CardActionButtons),
      matching: find.byType(IconButton),
    );
    final actionRects = [
      for (var index = 0; index < actionsFinder.evaluate().length; index++)
        tester.getRect(actionsFinder.at(index)),
    ];
    expect(actionRects, hasLength(6));
    expect(actionRects.map((rect) => rect.left.round()).toSet(), hasLength(2));
    expect(actionRects.map((rect) => rect.top.round()).toSet(), hasLength(3));
    for (final rect in actionRects) {
      expect(cardRect.contains(rect.topLeft), isTrue);
      expect(cardRect.contains(rect.bottomRight), isTrue);
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Android 触屏菜单提供水印操作', (tester) async {
    final tempDirectory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('nai_local_card_watermark_'),
    ))!;
    addTearDown(() async {
      PlatformCapabilities.debugOverride = null;
      LocalGalleryThumbnailMemoryCache.instance.clear();
      await tempDirectory.delete(recursive: true);
    });
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    await tester.runAsync(
      () => storage.setSetting(
        StorageKeys.watermarkConfigV1,
        const WatermarkSettings(enabled: true).encode(),
      ),
    );
    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}source.png',
    );
    await tester.runAsync(
      () => file.writeAsBytes(
        img.encodePng(img.Image(width: 64, height: 64)),
        flush: true,
      ),
    );
    final stat = (await tester.runAsync(file.stat))!;
    final actions = <LocalImageContextAction>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InteractionPolicyScope(
            child: Scaffold(
              body: Center(
                child: LocalImageCard3D(
                  record: LocalImageRecord(
                    path: file.path,
                    size: stat.size,
                    modifiedAt: stat.modified,
                  ),
                  width: 160,
                  height: 200,
                  onTap: () {},
                  onSendAction: (action) async => actions.add(action),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _observeTouch(tester);
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Create watermarked copy…'), findsOneWidget);
    expect(find.text('Send to Agent'), findsOneWidget);
    final menu = tester.widget<PopupMenuButton<Object>>(
      find.byType(PopupMenuButton<Object>),
    );
    menu.onSelected!(LocalImageContextAction.createWatermark);
    Navigator.of(tester.element(find.byType(PopupMenuButton<Object>))).pop();
    await tester.pump();
    expect(actions, contains(LocalImageContextAction.createWatermark));
  });

  testWidgets('Android 窄卡片不显示图片元数据信息层', (tester) async {
    final tempDirectory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('nai_local_card_layout_'),
    ))!;
    addTearDown(() async {
      PlatformCapabilities.debugOverride = null;
      LocalGalleryThumbnailMemoryCache.instance.clear();
      await tempDirectory.delete(recursive: true);
    });
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );

    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}narrow.png',
    );
    await tester.runAsync(
      () => file.writeAsBytes(
        img.encodePng(img.Image(width: 320, height: 480)),
        flush: true,
      ),
    );
    final stat = (await tester.runAsync(file.stat))!;
    final record = LocalImageRecord(
      path: file.path,
      size: stat.size,
      modifiedAt: stat.modified,
      metadataStatus: MetadataStatus.success,
      metadata: const NaiImageMetadata(width: 832, height: 1216),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InteractionPolicyScope(
            child: Scaffold(
              body: Center(
                child: LocalImageCard3D(
                  record: record,
                  width: 132,
                  height: 184,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _observeTouch(tester);

    expect(
      find.byKey(const ValueKey('local-image-card-actions')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    expect(
      find.byKey(const ValueKey('local-image-card-source-status-badge')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('local-image-card-metadata-safe-area')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('local-image-card-resolution')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('local-image-card-file-size')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Android 卡片更多操作可保存到系统相册', (tester) async {
    final tempDirectory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('nai_local_card_menu_'),
    ))!;
    addTearDown(() async {
      PlatformCapabilities.debugOverride = null;
      LocalGalleryThumbnailMemoryCache.instance.clear();
      await tempDirectory.delete(recursive: true);
    });
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    final file = File('${tempDirectory.path}${Platform.pathSeparator}menu.png');
    await tester.runAsync(
      () => file.writeAsBytes(
        img.encodePng(img.Image(width: 32, height: 32)),
        flush: true,
      ),
    );
    final stat = (await tester.runAsync(file.stat))!;
    LocalImageContextAction? selected;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InteractionPolicyScope(
            child: Scaffold(
              body: Center(
                child: LocalImageCard3D(
                  record: LocalImageRecord(
                    path: file.path,
                    size: stat.size,
                    modifiedAt: stat.modified,
                  ),
                  width: 132,
                  height: 184,
                  onTap: () {},
                  onSendAction: (action) async => selected = action,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _observeTouch(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('保存到系统相册'), findsOneWidget);
    final saveItem = find.byWidgetPredicate(
      (widget) =>
          widget is PopupMenuItem<Object> &&
          widget.value == LocalImageContextAction.saveToSystemGallery,
    );
    expect(saveItem, findsOneWidget);

    await tester.tap(saveItem);
    await tester.pump();
    expect(selected, LocalImageContextAction.saveToSystemGallery);
  });
}

Future<void> _observeTouch(WidgetTester tester) async {
  final position =
      tester.getBottomRight(find.byType(Scaffold)) - const Offset(1, 1);
  final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
  await touch.addPointer(location: position);
  await touch.down(position);
  await tester.pump();
  await touch.up();
  await tester.pump();
}
