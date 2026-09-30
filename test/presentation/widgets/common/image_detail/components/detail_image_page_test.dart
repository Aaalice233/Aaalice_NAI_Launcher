import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/cache/local_file_image.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_image_page.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/file_image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';

import '../../../../../helpers/real_async_pump.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('nai_detail_image_page_');
  });

  tearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    tempDir.deleteSync(recursive: true);
  });

  String pathOf(String name) => '${tempDir.path}${Platform.pathSeparator}$name';

  void writePng(
    String path, {
    required int width,
    required int height,
    required DateTime modifiedAt,
  }) {
    File(path)
      ..writeAsBytesSync(img.encodePng(img.Image(width: width, height: height)))
      ..setLastModifiedSync(modifiedAt);
  }

  LocalImageRecord recordOf(String path) {
    final stat = File(path).statSync();
    return LocalImageRecord(
      path: path,
      size: stat.size,
      modifiedAt: stat.modified,
    );
  }

  Future<void> pumpPage(WidgetTester tester, ImageDetailData data) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DetailImagePage(data: data)),
      ),
    );
  }

  (int, int)? displayedSize(WidgetTester tester) {
    final image = tester.widget<RawImage>(find.byType(RawImage)).image;
    return image == null ? null : (image.width, image.height);
  }

  testWidgets('同一路径被原地改写后重新打开详情显示新图而不是旧缓存', (tester) async {
    final path = pathOf('overwritten.png');
    writePng(path, width: 4, height: 4, modifiedAt: DateTime(2026, 1, 1, 12));

    await pumpPage(tester, LocalImageDetailData(recordOf(path)));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(image.frameBuilder, isNotNull);
    expect(image.errorBuilder, isNotNull);
    expect((image.image as ResizeImage).imageProvider, LocalFileImage(path));
    await pumpUntilRealAsync(tester, () => displayedSize(tester) != null);
    expect(displayedSize(tester), (4, 4));

    writePng(
      path,
      width: 8,
      height: 6,
      modifiedAt: DateTime(2026, 1, 1, 12, 0, 1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpPage(tester, LocalImageDetailData(recordOf(path)));
    await pumpUntilRealAsync(tester, () => displayedSize(tester) == (8, 6));

    expect(tester.takeException(), isNull);
  });

  testWidgets('文件缺失时详情页照常进入 errorBuilder', (tester) async {
    final path = pathOf('missing.png');

    await pumpPage(tester, FileImageDetailData(filePath: path));
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      LocalFileImage(path),
    );
    await pumpUntilRealAsync(
      tester,
      () => find.text('Failed to load image').evaluate().isNotEmpty,
    );
    await tester.pump();

    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
