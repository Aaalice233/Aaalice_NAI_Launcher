import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/precise_ref/precise_ref_library_entry.dart';
import 'package:nai_launcher/data/services/precise_ref_library_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/precise_ref_library/widgets/precise_ref_card.dart';
import 'package:nai_launcher/presentation/screens/precise_ref_library/widgets/precise_ref_hover_preview.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_actions.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_hover_motion.dart';
import 'package:nai_launcher/presentation/widgets/common/library_card_badges.dart';

class _FakeStorage extends PreciseRefLibraryStorageService {
  _FakeStorage({this.imageBytes});

  final Uint8List? imageBytes;

  @override
  Future<Uint8List?> getDisplayThumbnail(
    String id, {
    bool Function()? isCancelled,
  }) async => imageBytes;

  @override
  Future<Uint8List?> readImageBytes(String id) async => imageBytes;
}

void main() {
  final entry = PreciseRefLibraryEntry(
    id: 'entry-1',
    name: '银发少女',
    imagePath: r'C:\refs\entry-1.png',
    typeIndex: PreciseRefType.character.index,
    strength: 1.0,
    fidelity: 0.85,
    isFavorite: true,
    createdAt: DateTime(2026, 8, 1),
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    InteractionPolicy initialPolicy = InteractionPolicy.neutral,
    VoidCallback? onSendToPreciseRef,
    VoidCallback? onSendToImg2Img,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onToggleFavorite,
    VoidCallback? onClassify,
    VoidCallback? onAddToAgent,
  }) async {
    final card = PreciseRefCard(
      entry: entry,
      onSendToPreciseRef: onSendToPreciseRef,
      onSendToImg2Img: onSendToImg2Img,
      onEdit: onEdit,
      onDelete: onDelete,
      onToggleFavorite: onToggleFavorite,
      onClassify: onClassify,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preciseRefLibraryStorageServiceProvider.overrideWithValue(
            _FakeStorage(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InteractionPolicyScope(
            initialPolicy: initialPolicy,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 250,
                  child: onAddToAgent == null
                      ? card
                      : ImageCardActionScope(
                          onAddToAgent: onAddToAgent,
                          child: card,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('显示名称、参数与类型徽标', (tester) async {
    await pumpCard(tester);

    expect(find.text('银发少女'), findsOneWidget);
    expect(find.text('S 1.0 · F 0.85'), findsOneWidget);
    // 触控布局收起徽标文字，但仍保留可访问名称。
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.semanticLabel == '角色',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('precise-ref-card-favorite-badge-entry-1')),
      findsOneWidget,
    );
    expect(find.byType(LibraryCardFavoriteBadge), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(PreciseRefCard)),
    );
    await tester.pump();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(
      tester
          .widget<ImageCardHoverMotion>(find.byType(ImageCardHoverMotion))
          .hovered,
      isTrue,
    );
  });

  testWidgets('悬浮预览读取原图、展示参数并避让窗口边缘', (tester) async {
    tester.view.physicalSize = const Size(700, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final imageBytes = Uint8List.fromList(_onePixelPng);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preciseRefLibraryStorageServiceProvider.overrideWithValue(
            _FakeStorage(imageBytes: imageBytes),
          ),
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
                  width: 160,
                  height: 200,
                  child: PreciseRefCard(entry: entry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(PreciseRefCard)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 281));
    await tester.pump();

    const previewKey = ValueKey('precise-ref-hover-preview');
    expect(find.byKey(previewKey), findsOneWidget);
    final previewRect = tester.getRect(find.byKey(previewKey));
    expect(previewRect.left, greaterThanOrEqualTo(10));
    expect(previewRect.top, greaterThanOrEqualTo(10));
    expect(previewRect.right, lessThanOrEqualTo(690));
    expect(previewRect.bottom, lessThanOrEqualTo(510));
    expect(find.text('银发少女'), findsWidgets);
    expect(find.text('角色'), findsOneWidget);
    expect(find.text('参考强度 1.0'), findsOneWidget);
    expect(find.text('保真度 0.85'), findsOneWidget);
    expect(find.text('使用次数 0'), findsOneWidget);

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('precise-ref-hover-media')),
        matching: find.byType(Image),
      ),
    );
    final resized = image.image as ResizeImage;
    expect((resized.imageProvider as MemoryImage).bytes, same(imageBytes));
    expect(tester.takeException(), isNull);
  });

  test('悬浮预览按比例适配且有最大尺寸', () {
    expect(
      computePreciseRefHoverPreviewBounds(const Size(700, 520)),
      const Size(380, 500),
    );
    expect(
      computePreciseRefHoverPreviewBounds(const Size(1200, 1000)),
      const Size(380, 680),
    );
    expect(
      computePreciseRefHoverImageSize(
        aspectRatio: 2,
        maxWidth: 380,
        maxHeight: 500,
      ),
      const Size(380, 190),
    );
  });

  testWidgets('点击卡片触发发送回调，点击爱心触发收藏回调', (tester) async {
    var sendCount = 0;
    var favoriteCount = 0;
    await pumpCard(
      tester,
      onSendToPreciseRef: () => sendCount++,
      onToggleFavorite: () => favoriteCount++,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(PreciseRefCard)),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('precise-ref-card-favorite-entry-1')),
    );
    expect(favoriteCount, 1);

    await tester.tap(find.text('银发少女'));
    expect(sendCount, 1);
  });

  testWidgets('Android touch 无需 hover 可从更多菜单触发全部卡片命令', (tester) async {
    var sendCount = 0;
    var img2imgCount = 0;
    var editCount = 0;
    var deleteCount = 0;
    var favoriteCount = 0;
    var classifyCount = 0;
    await pumpCard(
      tester,
      initialPolicy: const InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: false,
      ),
      onSendToPreciseRef: () => sendCount++,
      onSendToImg2Img: () => img2imgCount++,
      onEdit: () => editCount++,
      onDelete: () => deleteCount++,
      onToggleFavorite: () => favoriteCount++,
      onClassify: () => classifyCount++,
    );

    await tester.tap(
      find.byKey(const Key('precise-ref-card-favorite-entry-1')),
      kind: PointerDeviceKind.touch,
    );
    expect(favoriteCount, 1);
    expect(
      find.byKey(const Key('precise-ref-card-more-entry-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('precise-ref-card-img2img-entry-1')),
      findsNothing,
    );

    Future<void> selectAction(String label) async {
      await tester.tap(
        find.byKey(const Key('precise-ref-card-more-entry-1')),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last, kind: PointerDeviceKind.touch);
      await tester.pumpAndSettle();
    }

    await selectAction('发送到精准参考');
    await selectAction('发送到图生图');
    await selectAction('编辑参数');
    await selectAction('参考类型');
    await selectAction('删除');

    expect(sendCount, 1);
    expect(img2imgCount, 1);
    expect(editCount, 1);
    expect(classifyCount, 1);
    expect(deleteCount, 1);
  });

  testWidgets('Windows mouse 保留 hover 快捷操作且全部回调可达', (tester) async {
    var sendCount = 0;
    var img2imgCount = 0;
    var editCount = 0;
    var deleteCount = 0;
    var favoriteCount = 0;
    await pumpCard(
      tester,
      initialPolicy: const InteractionPolicy(
        modality: InteractionModality.pointer,
        touchAvailable: false,
        precisePointerAvailable: true,
      ),
      onSendToPreciseRef: () => sendCount++,
      onSendToImg2Img: () => img2imgCount++,
      onEdit: () => editCount++,
      onDelete: () => deleteCount++,
      onToggleFavorite: () => favoriteCount++,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(PreciseRefCard)),
    );
    await tester.pump();
    await mouse.down(
      tester.getCenter(
        find.byKey(const Key('precise-ref-card-favorite-entry-1')),
      ),
    );
    await mouse.up();
    expect(favoriteCount, 1);
    expect(
      find.byKey(const Key('precise-ref-card-more-entry-1')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('precise-ref-card-img2img-entry-1')),
      findsOneWidget,
    );

    await mouse.moveTo(tester.getCenter(find.byType(PreciseRefCard)));
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('precise-ref-card-send-entry-1')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.tap(
      find.byKey(const Key('precise-ref-card-img2img-entry-1')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.tap(
      find.byKey(const Key('precise-ref-card-edit-entry-1')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.tap(
      find.byKey(const Key('precise-ref-card-delete-entry-1')),
      kind: PointerDeviceKind.mouse,
    );

    expect(sendCount, 1);
    expect(img2imgCount, 1);
    expect(editCount, 1);
    expect(deleteCount, 1);
  });

  testWidgets('桌面与触屏操作均可发送到智能体', (tester) async {
    var addCount = 0;
    await pumpCard(tester, onAddToAgent: () => addCount++);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(PreciseRefCard)),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('precise-ref-card-agent-entry-1')),
      kind: PointerDeviceKind.mouse,
    );
    expect(addCount, 1);

    await pumpCard(
      tester,
      initialPolicy: const InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: false,
      ),
      onAddToAgent: () => addCount++,
    );
    await tester.tap(
      find.byKey(const Key('precise-ref-card-more-entry-1')),
      kind: PointerDeviceKind.touch,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送到智能体'), kind: PointerDeviceKind.touch);
    expect(addCount, 2);
  });
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
