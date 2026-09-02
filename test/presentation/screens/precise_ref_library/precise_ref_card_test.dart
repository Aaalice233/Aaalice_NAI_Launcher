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
import 'package:nai_launcher/presentation/widgets/common/image_card_hover_motion.dart';

class _FakeStorage extends PreciseRefLibraryStorageService {
  @override
  Future<Uint8List?> getDisplayThumbnail(
    String id, {
    bool Function()? isCancelled,
  }) async => null;
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
  }) async {
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
                  child: PreciseRefCard(
                    entry: entry,
                    onSendToPreciseRef: onSendToPreciseRef,
                    onSendToImg2Img: onSendToImg2Img,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onToggleFavorite: onToggleFavorite,
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
    // 精确指针下操作只在悬浮时出现，避免常驻按钮遮挡图像。
    expect(find.byIcon(Icons.star), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(PreciseRefCard)),
    );
    await tester.pump();
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(
      tester
          .widget<ImageCardHoverMotion>(find.byType(ImageCardHoverMotion))
          .hovered,
      isTrue,
    );
  });

  testWidgets('点击卡片触发发送回调，点击星标触发收藏回调', (tester) async {
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
    await selectAction('删除');

    expect(sendCount, 1);
    expect(img2imgCount, 1);
    expect(editCount, 1);
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
}
