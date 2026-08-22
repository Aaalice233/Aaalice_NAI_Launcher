import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/metadata/metadata_import_dialog.dart';

void main() {
  testWidgets('generation option labels omit localized value separators', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MetadataImportDialog(
            metadata: NaiImageMetadata(steps: 28, scale: 5),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('步数'), findsOneWidget);
    expect(find.text('CFG 强度'), findsOneWidget);
    expect(find.text('CFG 强度：'), findsNothing);
  });
}
