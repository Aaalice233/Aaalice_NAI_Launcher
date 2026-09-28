import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
