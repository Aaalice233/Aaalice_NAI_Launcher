import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/incoming_image_share_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/services/incoming_image_share_reader.dart';
import 'package:nai_launcher/presentation/utils/dropped_file_reader.dart';
import 'package:nai_launcher/presentation/widgets/drop/incoming_image_share_handler.dart';

class _Shares extends IncomingImageShareService {
  final events = StreamController<void>.broadcast();
  final pending = Queue<Object>();
  int reads = 0;
  @override
  Stream<void> get available => events.stream;
  @override
  void start() {}
  @override
  Future<Map<Object?, Object?>?> takeNext() async {
    reads++;
    if (pending.isEmpty) return null;
    final item = pending.removeFirst();
    if (item is Exception) throw item;
    return item as Map<Object?, Object?>;
  }

  @override
  void dispose() {
    unawaited(events.close());
  }

  void add(String name) {
    pending.add({
      'fileName': name,
      'bytes': Uint8List.fromList([1]),
    });
    events.add(null);
  }
}

Widget _app(
  _Shares shares,
  Future<void> Function(DroppedFileData) process, {
  IncomingImageShareReader? reader,
  double scale = 1,
}) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: IncomingImageShareHandler(
          service: shares,
          reader: reader,
          processImage: process,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('cold share and warm shares run once and sequentially', (
    tester,
  ) async {
    final shares = _Shares()..add('cold.png');
    final first = Completer<void>();
    final processed = <String>[];
    await tester.pumpWidget(
      _app(shares, (image) async {
        processed.add(image.fileName);
        if (image.fileName == 'cold.png') await first.future;
      }),
    );
    await tester.pump();
    shares.add('warm.png');
    shares.events.add(null);
    await tester.pump();
    expect(processed, ['cold.png']);
    first.complete();
    await tester.pumpAndSettle();
    expect(processed, ['cold.png', 'warm.png']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unmount during download never invokes image workflow', (
    tester,
  ) async {
    final shares = _Shares()
      ..pending.add({'text': 'https://example.com/a.png'});
    final download = Completer<DroppedFileData?>();
    var processed = false;
    await tester.pumpWidget(
      _app(shares, (_) async {
        processed = true;
      }, reader: IncomingImageShareReader(download: (_) => download.future)),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    download.complete(
      DroppedFileData(fileName: 'a.png', bytes: Uint8List.fromList([1])),
    );
    await tester.pump();
    expect(processed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background download waits for resume before opening workflow', (
    tester,
  ) async {
    final shares = _Shares()
      ..pending.add({'text': 'https://example.com/a.png'});
    final download = Completer<DroppedFileData?>();
    var processed = false;
    await tester.pumpWidget(
      _app(shares, (_) async {
        processed = true;
      }, reader: IncomingImageShareReader(download: (_) => download.future)),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    download.complete(
      DroppedFileData(fileName: 'a.png', bytes: Uint8List.fromList([1])),
    );
    await tester.pump();
    expect(processed, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(processed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('native read failure does not strand the next share', (
    tester,
  ) async {
    final shares = _Shares()
      ..pending.add(PlatformException(code: 'image_share_read_failed'))
      ..add('next.png');
    final processed = <String>[];
    await tester.pumpWidget(
      _app(shares, (image) async {
        processed.add(image.fileName);
      }),
    );
    await tester.pumpAndSettle();
    expect(processed, ['next.png']);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets('loading fits width $width at 3x text and short height', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 320);
      addTearDown(tester.view.reset);
      final shares = _Shares()
        ..pending.add({'text': 'https://example.com/a.png'});
      final download = Completer<DroppedFileData?>();
      await tester.pumpWidget(
        _app(
          shares,
          (_) async {},
          reader: IncomingImageShareReader(download: (_) => download.future),
          scale: 3,
        ),
      );
      await tester.pump();
      expect(find.text('正在解析图片...'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      download.complete(null);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
