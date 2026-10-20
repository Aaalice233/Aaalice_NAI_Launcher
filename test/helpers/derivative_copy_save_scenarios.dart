import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/derivatives/derivative_registry.dart';
import 'package:nai_launcher/core/derivatives/derivative_render.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/derivatives/derivative_copy_saver.dart';

import 'editor_exit.dart';
import 'pending_derivative_copy_saver.dart';

typedef DerivativeCopyRender<R extends DerivativeRenderedCopy> =
    Future<R> Function(Uint8List sourceBytes);

/// 水印、打码编辑器共用的保存副本用例：写入之后的步骤不拖住编辑器，渲染期退出不写入，写盘期退出仍写完。
/// [expectEditorEffects] 断言编辑器自身随写入发生的附带效果，[written] 表示副本是否已写入。
void defineDerivativeCopySaveTests<R extends DerivativeRenderedCopy>({
  required DerivativeKind kind,
  required Type editorType,
  required Size surfaceSize,
  required Finder saveButton,
  required String Function(AppLocalizations l10n) savingLabel,
  required String Function(AppLocalizations l10n) savedLabel,
  required String Function(AppLocalizations l10n) galleryIndexFailedLabel,
  required String Function(AppLocalizations l10n) systemGalleryFailedLabel,
  required List<Override> Function() overrides,
  required R Function(Uint8List bytes, String fileName) renderResult,
  required Widget Function(DerivativeCopyRender<R> render) buildEditor,
  void Function({required bool written})? expectEditorEffects,
}) {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final fileName = kind.outputFileName('source.png');
  final editor = find.byType(editorType);

  Future<Completer<String?>> open(
    WidgetTester tester,
    PendingDerivativeCopySaver pending, {
    DerivativeCopyRender<R>? render,
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final closed = Completer<String?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides(),
          derivativeCopySaverProvider(kind).overrideWithValue(pending.saver),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context)
                    .push<String>(
                      MaterialPageRoute(
                        builder: (_) => buildEditor(
                          render ??
                              (sourceBytes) async =>
                                  renderResult(sourceBytes, fileName),
                        ),
                      ),
                    )
                    .then(closed.complete),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 20),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(saveButton, findsOneWidget);
    return closed;
  }

  Future<void> closeSavedDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, l10n.common_close));
    await tester.pumpAndSettle();
  }

  testWidgets('stalled follow-up steps never hold the editor once written', (
    tester,
  ) async {
    final pending = PendingDerivativeCopySaver(kind);
    addTearDown(pending.releaseAll);
    final closed = await open(tester, pending);
    final output = pending.outputPathFor(fileName);

    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(savedLabel(l10n)), findsOneWidget);
    expect(pending.writes, [output]);
    expect(pending.admissions, [
      [output],
    ]);
    expect(pending.indexing.isCompleted, isFalse);
    expectEditorEffects?.call(written: true);

    await closeSavedDialog(tester);

    expect(editor, findsNothing);
    expect(closed.isCompleted, isTrue);
    expect(await closed.future, output);
    expect(tester.takeException(), isNull);
  });

  testWidgets('follow-up failures still surface after the editor closed', (
    tester,
  ) async {
    final pending = PendingDerivativeCopySaver(kind);
    addTearDown(pending.releaseAll);
    await open(tester, pending);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await closeSavedDialog(tester);
    expect(editor, findsNothing);

    pending.indexing.complete(GalleryIndexAdmission.failed);
    pending.rescanning.complete('refreshFailed');
    pending.publishing.completeError(StateError('media store'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(galleryIndexFailedLabel(l10n)), findsOneWidget);
    expect(find.text(systemGalleryFailedLabel(l10n)), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final exit in EditorExit.values) {
    testWidgets('${exit.name} during a stalled render leaves and writes '
        'nothing', (tester) async {
      final pending = PendingDerivativeCopySaver(kind);
      addTearDown(pending.releaseAll);
      final rendering = Completer<R>();
      final closed = await open(
        tester,
        pending,
        render: (_) => rendering.future,
      );

      await tester.tap(saveButton);
      await tester.pump();
      expect(find.text(savingLabel(l10n)), findsOneWidget);

      await exit.perform(tester);
      await tester.pump();
      expect(closed.isCompleted, isTrue);
      await settleWithin(tester, const Duration(seconds: 2));
      expect(editor, findsNothing);
      expect(await closed.future, isNull);

      rendering.complete(renderResult(Uint8List.fromList([1, 2, 3]), fileName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(pending.writes, isEmpty);
      expectEditorEffects?.call(written: false);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${exit.name} once writing started leaves and still saves', (
      tester,
    ) async {
      final pending = PendingDerivativeCopySaver(kind, holdWrites: true);
      addTearDown(pending.releaseAll);
      final closed = await open(tester, pending);
      final output = pending.outputPathFor(fileName);

      await tester.tap(saveButton);
      await tester.pump();
      expect(pending.writeRequests, [output]);

      await exit.perform(tester);
      await tester.pump();
      expect(closed.isCompleted, isTrue);
      await settleWithin(tester, const Duration(seconds: 2));
      expect(editor, findsNothing);
      expect(await closed.future, isNull);

      pending.writing.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(pending.writes, [output]);
      expect(pending.admissions, [
        [output],
      ]);
      expectEditorEffects?.call(written: true);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('${savedLabel(l10n)}\n$fileName'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
