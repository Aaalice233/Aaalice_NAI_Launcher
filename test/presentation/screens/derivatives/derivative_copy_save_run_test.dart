import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/derivatives/derivative_registry.dart';
import 'package:nai_launcher/core/derivatives/derivative_render.dart';
import 'package:nai_launcher/presentation/screens/derivatives/derivative_copy_save_run.dart';

import '../../../helpers/pending_derivative_copy_saver.dart';

void main() {
  final sourceBytes = Uint8List.fromList([1, 2, 3]);
  final copy = _Copy(Uint8List.fromList([4, 5, 6]), 'source_watermarked.png');

  late PendingDerivativeCopySaver pending;
  late DerivativeCopySaveRun run;
  late String output;
  DerivativeCopySaveOutcome? outcome;
  DerivativeRenderCancellationToken? cancellationToken;

  void prepare({
    bool holdGalleryRoot = false,
    bool holdWrites = false,
    String? galleryRootPath = PendingDerivativeCopySaver.galleryRoot,
    OverlayState? overlay,
  }) {
    pending = PendingDerivativeCopySaver(
      DerivativeKind.watermark,
      holdGalleryRoot: holdGalleryRoot,
      holdWrites: holdWrites,
      galleryRootPath: galleryRootPath,
    );
    addTearDown(pending.releaseAll);
    run = DerivativeCopySaveRun(
      saver: pending.saver,
      notices: DerivativeCopySaveNotices(
        overlay: overlay,
        saveDirectoryNotSet: 'Save folder is not set',
        saved: 'Copy saved',
        failed: 'Copy failed',
        systemGalleryFailed: 'System gallery failed',
        galleryIndexFailed: 'Gallery index failed',
      ),
    );
    output = pending.outputPathFor(copy.fileName);
    outcome = null;
    cancellationToken = null;
  }

  void start(Future<DerivativeRenderedCopy> Function() render) {
    unawaited(
      run
          .save(
            render: (token) {
              cancellationToken = token;
              return render();
            },
            sourceBytes: sourceBytes,
            sourcePath: 'source.png',
          )
          .then((value) => outcome = value),
    );
  }

  test(
    'closing while rendering ends the save at once and never writes',
    () async {
      prepare();
      final rendering = Completer<DerivativeRenderedCopy>();
      start(() => rendering.future);
      await pumpEventQueue();
      expect(outcome, isNull);

      run.close();
      await pumpEventQueue();

      expect(outcome, isA<DerivativeCopyCancelled>());
      expect(cancellationToken!.isCancelled, isTrue);
      rendering.complete(copy);
      await pumpEventQueue();
      expect(pending.writeRequests, isEmpty);
    },
  );

  test('closing while the gallery folder resolves still cancels', () async {
    prepare(holdGalleryRoot: true);
    start(() async => copy);
    await pumpEventQueue();
    expect(outcome, isNull);

    run.close();
    await pumpEventQueue();

    expect(outcome, isA<DerivativeCopyCancelled>());
    pending.resolvingRoot.complete();
    await pumpEventQueue();
    expect(pending.writeRequests, isEmpty);
  });

  test('closing once writing started lets the copy finish saving', () async {
    prepare(holdWrites: true);
    start(() async => copy);
    await pumpEventQueue();
    expect(pending.writeRequests, [output]);

    run.close();
    await pumpEventQueue();
    expect(outcome, isNull);
    expect(cancellationToken!.isCancelled, isFalse);

    pending.writing.complete();
    await pumpEventQueue();

    expect(
      outcome,
      isA<DerivativeCopySaved>().having((o) => o.outputPath, 'path', output),
    );
    expect(pending.writes, [output]);
    expect(pending.admissions, [
      [output],
    ]);
    expect(run.isClosed, isTrue);
  });

  test(
    'a saved copy carries the rendered bytes and starts follow-up',
    () async {
      prepare();
      start(() async => copy);
      await pumpEventQueue();

      expect(
        outcome,
        isA<DerivativeCopySaved>()
            .having((o) => o.copy, 'copy', same(copy))
            .having((o) => o.outputPath, 'path', output),
      );
      expect(pending.writes, [output]);
      expect(pending.admissions, [
        [output],
      ]);
      expect(run.isClosed, isFalse);

      run
        ..close()
        ..close();
      expect(run.isClosed, isTrue);
    },
  );

  test('a cancellation raised by the renderer is a cancellation', () async {
    prepare();
    start(() async => throw const DerivativeRenderCancelledException());
    await pumpEventQueue();

    expect(outcome, isA<DerivativeCopyCancelled>());
    expect(run.isClosed, isFalse);
    expect(pending.writeRequests, isEmpty);
  });

  test('a failed render reports its error and writes nothing', () async {
    prepare();
    final error = StateError('decode failed');
    start(() async => throw error);
    await pumpEventQueue();

    expect(
      outcome,
      isA<DerivativeCopyFailed>().having((o) => o.error, 'error', same(error)),
    );
    expect(pending.writeRequests, isEmpty);
  });

  test('a missing gallery folder fails with the captured message', () async {
    prepare(galleryRootPath: null);
    start(() async => copy);
    await pumpEventQueue();

    expect(
      outcome,
      isA<DerivativeCopyFailed>().having(
        (o) => o.error,
        'error',
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Save folder is not set',
        ),
      ),
    );
    expect(pending.writeRequests, isEmpty);
  });

  testWidgets('a write failing after the editor closed is announced', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    prepare(
      holdWrites: true,
      overlay: tester.state<OverlayState>(find.byType(Overlay).first),
    );
    start(() async => copy);
    await tester.pump();
    expect(pending.writeRequests, [output]);

    run.close();
    pending.writing.completeError(const FileSystemException('disk full'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(outcome, isA<DerivativeCopyFailed>());
    expect(find.text('Copy failed'), findsOneWidget);
    expect(find.text('Copy saved'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _Copy implements DerivativeRenderedCopy {
  _Copy(this.bytes, this.fileName);

  @override
  final Uint8List bytes;
  @override
  final String fileName;
}
