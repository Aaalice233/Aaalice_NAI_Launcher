import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/bulk_operation_provider.dart';
import 'package:nai_launcher/presentation/providers/selection_mode_provider.dart';
import 'package:nai_launcher/presentation/widgets/bulk_metadata_edit_dialog.dart';
import 'package:nai_launcher/presentation/widgets/bulk_progress_dialog.dart';
import 'package:nai_launcher/presentation/widgets/gallery/zip_export_metadata_dialog.dart';

void main() {
  const widths = [320.0, 600.0, 840.0, 1180.0, 1600.0];

  for (final width in widths) {
    testWidgets(
      'ZIP and metadata dialogs remain operable at 3x and ${width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pump(
          tester,
          width: width,
          child: const ZipExportMetadataDialog(),
        );
        await _scrollUntilFound(tester, 'Keep metadata');
        expect(find.text('Keep metadata'), findsOneWidget);
        await _scrollUntilFound(tester, 'Remove all metadata');
        expect(find.text('Remove all metadata'), findsOneWidget);
        await _scrollUntilFound(tester, 'Export');
        expect(find.text('Export'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _pump(
          tester,
          width: width,
          child: const BulkMetadataEditDialog(),
        );
        expect(find.text('Apply'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('批量元数据表单在 320px、3x、IME 与 SafeArea 下可编辑并关闭', (tester) async {
    const size = Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: size,
              textScaler: const TextScaler.linear(3),
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              viewPadding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              viewInsets: const EdgeInsets.only(bottom: 300),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const ValueKey('open-bulk-metadata-edit'),
                  onPressed: () => showBulkMetadataEditDialog(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('open-bulk-metadata-edit'))),
    );
    container.read(localGallerySelectionNotifierProvider.notifier).select('1');

    await tester.tap(find.byKey(const ValueKey('open-bulk-metadata-edit')));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-full-screen-form'));
    expect(surface, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.getTopLeft(surface).dy, greaterThanOrEqualTo(24));
    expect(tester.getBottomRight(surface).dy, lessThanOrEqualTo(600));

    final addButtons = find.byIcon(Icons.add);
    expect(addButtons, findsNWidgets(2));
    await tester.tap(addButtons.first);
    await tester.pump();

    final cancel = find.widgetWithText(OutlinedButton, '取消');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bulk progress fits running, completed and error states at 320px',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(
        tester,
        width: 320,
        state: const BulkOperationState(
          currentOperation: BulkOperationType.export,
          isOperationInProgress: true,
          currentProgress: 3,
          totalItems: 12,
          currentItem: 'a/very/long/path/to/the/current/image.png',
        ),
        child: const BulkProgressDialog(),
      );
      expect(find.text('Continue in background'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _pump(
        tester,
        width: 320,
        state: const BulkOperationState(
          currentOperation: BulkOperationType.metadataEdit,
          isCompleted: true,
          error: BulkOperationError(BulkOperationErrorCode.metadataEditFailed),
          lastResult: (
            success: 3,
            failed: 2,
            errors: ['first error', 'second error'],
          ),
        ),
        child: const BulkProgressDialog(),
      );
      expect(find.text('Close'), findsWidgets);
      expect(find.textContaining('3'), findsWidgets);
      expect(find.textContaining('2'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _scrollUntilFound(WidgetTester tester, String text) async {
  final list = find.byKey(const ValueKey('zip-export-metadata-options'));
  for (
    var attempt = 0;
    attempt < 20 && find.text(text).evaluate().isEmpty;
    attempt++
  ) {
    await tester.drag(list, const Offset(0, -300));
    await tester.pump();
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required Widget child,
  BulkOperationState state = const BulkOperationState(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        bulkOperationNotifierProvider.overrideWith(
          () => _StaticBulkOperationNotifier(state),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pump();
}

class _StaticBulkOperationNotifier extends BulkOperationNotifier {
  _StaticBulkOperationNotifier(this.initialState);

  final BulkOperationState initialState;

  @override
  BulkOperationState build() => initialState;
}
