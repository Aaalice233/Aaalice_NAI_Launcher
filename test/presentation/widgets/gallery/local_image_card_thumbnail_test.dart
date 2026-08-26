import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/cache/local_gallery_thumbnail_provider.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_hover_motion.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_card_3d.dart';

void main() {
  testWidgets('卡片按实际 DPR 更新动态解码目标', (tester) async {
    final tempDirectory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('nai_local_card_thumbnail_'),
    ))!;
    addTearDown(() async {
      LocalGalleryThumbnailMemoryCache.instance.clear();
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
}
