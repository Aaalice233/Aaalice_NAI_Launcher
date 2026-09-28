import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_card_3d.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_hover_preview.dart';

/// 必保定制 #28 的第三部分：本地图库卡片的 hover 呈现按指针类型门控。
///
/// 上游的 `MouseRegion` 与 `LocalImageHoverPreview` 都没有任何指针类型判断，
/// 而 Flutter 的 MouseTracker 对 stylus 同样下发 enter/exit，iPad + Apple Pencil
/// 悬停会触发卡片缩放与悬浮预览卡。
void main() {
  testWidgets('触屏策略下卡片不挂 hover 监听且关闭悬浮预览', (tester) async {
    await tester.pumpWidget(_wrap(InteractionPolicy.touchFirst));
    await tester.pump();

    expect(
      tester
          .widget<LocalImageHoverPreview>(find.byType(LocalImageHoverPreview))
          .enabled,
      isFalse,
    );
    expect(tester.widget<MouseRegion>(_cardHoverRegion).onEnter, isNull);
    expect(tester.widget<MouseRegion>(_cardHoverRegion).onExit, isNull);
    expect(
      tester.widget<MouseRegion>(_cardHoverRegion).cursor,
      MouseCursor.defer,
    );
  });

  testWidgets('观察到精确指针后恢复上游的 hover 呈现', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const InteractionPolicy(
          modality: InteractionModality.pointer,
          touchAvailable: false,
          precisePointerAvailable: true,
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<LocalImageHoverPreview>(find.byType(LocalImageHoverPreview))
          .enabled,
      isTrue,
    );
    expect(tester.widget<MouseRegion>(_cardHoverRegion).onEnter, isNotNull);
    expect(
      tester.widget<MouseRegion>(_cardHoverRegion).cursor,
      SystemMouseCursors.click,
    );
  });
}

/// 卡片自己那层 `MouseRegion`，区别于 `LocalImageHoverPreview` 内部那层
/// 以及 IconButton/InkWell 各自带的光标层。
final Finder _cardHoverRegion = find.byKey(
  const ValueKey('local-image-card-hover-region'),
);

Widget _wrap(InteractionPolicy policy) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: InteractionPolicyScope(
        initialPolicy: policy,
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: LocalImageCard3D(
              record: LocalImageRecord(
                path: 'G:/gallery/hover-gating.png',
                size: 42,
                modifiedAt: DateTime(2026, 9, 20),
              ),
              width: 160,
              height: 220,
              onTap: () {},
            ),
          ),
        ),
      ),
    ),
  );
}
