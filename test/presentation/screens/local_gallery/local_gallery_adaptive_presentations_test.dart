import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/zip_utils.dart';
import 'package:nai_launcher/data/models/gallery/gallery_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_action_coordinator.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_move_target.dart';
import 'package:nai_launcher/presentation/widgets/gallery/zip_export_metadata_dialog.dart';

void main() {
  for (final size in [const Size(400, 800), const Size(1180, 800)]) {
    testWidgets(
      'local gallery selectors and failure details share adaptive presentation at ${size.width}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    TextButton(
                      onPressed: () => showLocalGalleryMoveTargetDialog(
                        context: context,
                        targets: [
                          LocalGalleryMoveTarget(
                            category: _category,
                            label: 'Root / Target',
                          ),
                        ],
                      ),
                      child: const Text('move'),
                    ),
                    TextButton(
                      onPressed: () => ZipExportMetadataDialog.show(context),
                      child: const Text('zip'),
                    ),
                    TextButton(
                      onPressed: () => showLocalGalleryZipFailureDetails(
                        context,
                        const ZipCreationResult(
                          requestedCount: 2,
                          exportedCount: 1,
                          failures: [
                            ZipCreationFailure(
                              path: 'gallery/failed.png',
                              error: 'permission denied',
                            ),
                          ],
                        ),
                      ),
                      child: const Text('failures'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final expectedSurface = size.width < 840
            ? const ValueKey('adaptive-bottom-sheet')
            : const ValueKey('adaptive-centered-form');

        await tester.tap(find.text('move'));
        await tester.pumpAndSettle();
        expect(find.byKey(expectedSurface), findsOneWidget);
        expect(
          find.byKey(const ValueKey('local-gallery-move-target-list')),
          findsOneWidget,
        );
        expect(find.byType(Dialog), findsNothing);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('zip'));
        await tester.pumpAndSettle();
        expect(find.byKey(expectedSurface), findsOneWidget);
        expect(
          find.byKey(const ValueKey('zip-export-metadata-options')),
          findsOneWidget,
        );
        expect(find.byType(Dialog), findsNothing);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('failures'));
        await tester.pumpAndSettle();
        final failureSurface = size.width < 600
            ? const ValueKey('adaptive-bottom-sheet')
            : const ValueKey('adaptive-centered-form');
        expect(find.byKey(failureSurface), findsOneWidget);
        expect(
          find.byKey(const ValueKey('local-gallery-zip-failure-list')),
          findsOneWidget,
        );
        expect(find.text('failed.png'), findsOneWidget);
        expect(find.text('permission denied'), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

final GalleryCategory _category = GalleryCategory(
  id: 'target',
  name: 'Target',
  folderPath: 'Target',
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);
