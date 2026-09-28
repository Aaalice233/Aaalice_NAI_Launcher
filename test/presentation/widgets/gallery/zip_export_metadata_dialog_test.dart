import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/gallery/zip_export_metadata_dialog.dart';

void main() {
  testWidgets('returns the selected metadata export option', (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ZipExportMetadataDialog.show(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('原始图片文件不会被修改'), findsOneWidget);
    await tester.tap(find.text('移除全部元数据'));
    await tester.tap(find.text('导出'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
