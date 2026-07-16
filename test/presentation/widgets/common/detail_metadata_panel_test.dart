import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_metadata_panel.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';

void main() {
  testWidgets(
    'resolution uses encoded image size instead of request metadata',
    (tester) async {
      final image = img.Image(width: 640, height: 960);
      final detail = GeneratedImageDetailData(
        imageBytes: Uint8List.fromList(img.encodePng(image)),
        metadata: const NaiImageMetadata(seed: 123, width: 1792, height: 896),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DetailMetadataPanel(
                currentImage: detail,
                expandedWidth: 600,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var attempt = 0; attempt < 20; attempt++) {
        if (find.text('640 × 960').evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('640 × 960'), findsOneWidget);
      expect(find.text('1792 × 896'), findsNothing);
    },
  );
}
