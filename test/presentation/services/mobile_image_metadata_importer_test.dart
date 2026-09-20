import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/services/mobile_image_metadata_importer.dart';

void main() {
  testWidgets('来源面板同时给出文件与剪贴板两条来源', (tester) async {
    await _pumpAction(
      tester,
      action: (context, ref) =>
          showMobileImageMetadataImportSheet(context: context, ref: ref),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-metadata-import-file')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-metadata-import-clipboard')),
      findsOneWidget,
    );
  });

  testWidgets('取不到图时报告而不是静默返回', (tester) async {
    var reportedNothing = false;
    var processed = false;
    final importer = MobileImageMetadataImporter(
      imageBytesPicker: () async => null,
      imageProcessor: (context, ref, image) async {
        processed = true;
      },
    );

    await _pumpAction(
      tester,
      action: (context, ref) => importer.run(
        context: context,
        ref: ref,
        onNothingPicked: () => reportedNothing = true,
      ),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(reportedNothing, isTrue);
    expect(processed, isFalse);
  });
}

typedef _TestAction =
    Future<Object?> Function(BuildContext context, WidgetRef ref);

Future<void> _pumpAction(
  WidgetTester tester, {
  required _TestAction action,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Consumer(
          builder: (context, ref, child) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => action(context, ref),
              child: const Text('run'),
            ),
          ),
        ),
      ),
    ),
  );
}
