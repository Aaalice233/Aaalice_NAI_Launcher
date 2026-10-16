import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/gallery_image_request.dart';
import 'package:nai_launcher/core/cache/local_file_image.dart';
import 'package:nai_launcher/presentation/widgets/queue/queue_task_thumbnail.dart';

void main() {
  testWidgets('renders persisted local and legacy remote thumbnail sources', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QueueTaskThumbnail(
          source: 'C:/app/cache/quick-tag-cloud.webp',
          width: 44,
          height: 44,
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: QueueTaskThumbnail(
          source: 'https://example.test/legacy.webp',
          width: 44,
          height: 44,
        ),
      ),
    );
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('local sources keep size hints and an error fallback', (
    tester,
  ) async {
    const source = 'C:/app/cache/missing.webp';

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: QueueTaskThumbnail(
            source: source,
            width: 120,
            height: 80,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final resized = image.image as ResizeImage;
    expect(resized.imageProvider, const LocalFileImage(source));
    expect(
      resized.width,
      GalleryImageSizing.gridTargetWidth(
        layoutWidth: 120,
        devicePixelRatio: tester.view.devicePixelRatio,
      ),
    );
    expect(resized.height, isNull);
    expect((image.width, image.height, image.fit), (120, 80, BoxFit.contain));
    expect(image.errorBuilder, isNotNull);
  });
}
