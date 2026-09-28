import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_top_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';

/// 顶栏上的三条 iOS 偏好定制：
/// - 必保 #2 复制不带元数据常驻、含元数据降级
/// - 必保 #3 保存到相册是显式动作
/// - 必保 #27 按钮显隐接兜底元数据
///
/// 上游 `detail_top_bar.dart` 只有单个 `onCopyImage`（默认带元数据）、
/// 没有相册入口、且只读 `currentImage.metadata` 这个数据库快照。
void main() {
  Future<void> pumpTopBar(
    WidgetTester tester, {
    required double width,
    VoidCallback? onCopyImage,
    VoidCallback? onCopyImageClean,
    VoidCallback? onSaveToAlbum,
    VoidCallback? onReuseMetadata,
    NaiImageMetadata? metadataOverride,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: DetailTopBar(
                  currentImage: GeneratedImageDetailData(
                    imageBytes: Uint8List(0),
                  ),
                  currentIndex: 0,
                  totalImages: 1,
                  onClose: () {},
                  onCopyImage: onCopyImage,
                  onCopyImageClean: onCopyImageClean,
                  onSaveToAlbum: onSaveToAlbum,
                  onReuseMetadata: onReuseMetadata,
                  metadataOverride: metadataOverride,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'clean copy stays on the bar while the metadata-bearing copy is demoted',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var cleanCopies = 0;
      var plainCopies = 0;
      await pumpTopBar(
        tester,
        width: 360,
        onCopyImage: () => plainCopies++,
        onCopyImageClean: () => cleanCopies++,
      );

      // 常驻：不需要展开任何菜单就能点到去元数据复制。
      expect(find.byIcon(Icons.copy), findsOneWidget);
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();
      expect(cleanCopies, 1);
      expect(plainCopies, 0);

      // 降级：含元数据的复制只在溢出菜单里。
      expect(find.byIcon(Icons.copy_all_outlined), findsNothing);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.copy_all_outlined));
      await tester.pumpAndSettle();
      expect(plainCopies, 1);
      expect(cleanCopies, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('save to album is an explicit overflow action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var saves = 0;
    await pumpTopBar(tester, width: 360, onSaveToAlbum: () => saves++);

    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    expect(saves, 1);

    // 没有相册回调时不留死条目。
    await pumpTopBar(tester, width: 360, onCopyImage: () {});
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reuse params survives a stale database metadata snapshot', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // GeneratedImageDetailData(metadata: null) 模拟 iOS 覆盖安装后
    // 数据库快照里的绝对路径失效、同步元数据读回 null 的情形。
    await pumpTopBar(tester, width: 900, onReuseMetadata: () {});
    expect(find.byIcon(Icons.input), findsNothing);

    await pumpTopBar(
      tester,
      width: 900,
      onReuseMetadata: () {},
      metadataOverride: const NaiImageMetadata(prompt: '1girl'),
    );
    expect(find.byIcon(Icons.input), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
