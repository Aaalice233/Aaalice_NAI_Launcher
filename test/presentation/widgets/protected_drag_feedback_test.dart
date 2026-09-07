import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/drag_drop_utils.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/core/database/database_providers.dart';
import 'package:nai_launcher/presentation/providers/copy_drag_watermark_provider.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/share_image_settings_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/draggable_memory_image.dart';
import 'package:nai_launcher/presentation/widgets/gallery/draggable_image_card.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class _TestShareImageSettingsNotifier extends ShareImageSettingsNotifier {
  _TestShareImageSettingsNotifier(this.initialSettings);

  final ShareImageSettings initialSettings;

  @override
  ShareImageSettings build() => initialSettings;

  void replace(ShareImageSettings value) => state = value;
}

void main() {
  testWidgets(
    'memory drag feedback reads the latest effective protection state',
    (tester) async {
      late _TestShareImageSettingsNotifier notifier;
      await tester.pumpWidget(
        _app(
          settings: const ShareImageSettings(protectionMode: false),
          onNotifier: (value) => notifier = value,
          child: DraggableMemoryImage(
            imageId: 'image-1',
            imageBytes: Uint8List.fromList(const [1, 2, 3]),
            feedbackPixelWidth: 832,
            feedbackPixelHeight: 1216,
            feedbackFormat: 'PNG',
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final dragWidget = tester.widget<DragItemWidget>(
        find.byType(DragItemWidget),
      );
      final dragContext = tester.element(find.byType(DragItemWidget));
      final unprotected = dragWidget.dragBuilder!(
        dragContext,
        const SizedBox(),
      );
      expect(unprotected?.key, isNot(protectedDragFeedbackMarkerKey));

      notifier.replace(
        const ShareImageSettings(
          protectionMode: true,
          stripMetadataForCopyAndDrag: true,
        ),
      );
      final protected = dragWidget.dragBuilder!(dragContext, const SizedBox());
      expect(protected?.key, protectedDragFeedbackMarkerKey);
    },
  );

  testWidgets('protection without copy-drag stripping keeps current feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        settings: const ShareImageSettings(
          protectionMode: true,
          stripMetadataForCopyAndDrag: false,
        ),
        child: DraggableMemoryImage(
          imageBytes: Uint8List.fromList(const [1, 2, 3]),
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );

    final dragWidget = tester.widget<DragItemWidget>(
      find.byType(DragItemWidget),
    );
    final feedback = dragWidget.dragBuilder!(
      tester.element(find.byType(DragItemWidget)),
      const SizedBox(),
    );
    expect(feedback?.key, isNot(protectedDragFeedbackMarkerKey));
  });

  testWidgets('public gallery card always uses placeholder when protected', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        settings: const ShareImageSettings(protectionMode: true),
        child: DraggableImageCard(
          record: _record,
          enableFeedback: false,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );

    expect(_feedbackKey(tester), protectedDragFeedbackMarkerKey);
  });

  testWidgets('gallery production wrapper uses placeholder when protected', (
    tester,
  ) async {
    final wrapper = DraggableImageCard.createDragWrapper(
      record: _record,
      enableFeedback: false,
    );
    await tester.pumpWidget(
      _app(
        settings: const ShareImageSettings(protectionMode: true),
        child: wrapper(const SizedBox(width: 100, height: 100)),
      ),
    );

    expect(_feedbackKey(tester), protectedDragFeedbackMarkerKey);
  });

  testWidgets('memory drag rejects a prepared file from an old watermark', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        settings: const ShareImageSettings(),
        transform: ShareImageTransform(
          cacheKey: 'new-default',
          apply: (image, {required stripMetadata}) async => image,
        ),
        child: DraggableMemoryImage(
          imageBytes: _validPreviewBytes,
          requirePreparedDragFile: true,
          preparedDragFile: File('tool/.tmp/not-exported.png'),
          preparedDragStripMetadata: false,
          preparedDragTransformKey: 'old-default',
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );
    final session = _FakeDragSession();
    addTearDown(session.dispose);
    final dragWidget = tester.widget<DragItemWidget>(
      find.byType(DragItemWidget),
    );
    await expectLater(
      dragWidget.dragItemProvider(
        DragItemRequest(location: Offset.zero, session: session),
      ),
      throwsStateError,
    );
  });

  for (final entry in <String, Widget Function(LocalImageRecord, Uint8List)>{
    'public gallery card': (record, bytes) => DraggableImageCard(
      record: record,
      previewBytes: bytes,
      child: const SizedBox(width: 100, height: 100),
    ),
    'gallery production wrapper': (record, bytes) =>
        DraggableImageCard.createDragWrapper(
          record: record,
          previewBytes: bytes,
        )(const SizedBox(width: 100, height: 100)),
  }.entries) {
    testWidgets(
      '${entry.key} invokes watermark even when metadata stripping is off',
      (tester) async {
        var invoked = false;
        final transform = ShareImageTransform(
          cacheKey: 'missing-logo',
          apply: (image, {required stripMetadata}) async {
            invoked = true;
            expect(stripMetadata, isFalse);
            expect(image.bytes, orderedEquals(_validPreviewBytes));
            throw StateError('missing logo');
          },
        );
        final record = LocalImageRecord(
          path: '',
          size: _validPreviewBytes.length,
          modifiedAt: DateTime(2026),
        );
        await tester.pumpWidget(
          _app(
            settings: const ShareImageSettings(),
            transform: transform,
            child: entry.value(record, _validPreviewBytes),
          ),
        );
        final session = _FakeDragSession();
        addTearDown(session.dispose);
        final dragWidget = tester.widget<DragItemWidget>(
          find.byType(DragItemWidget),
        );
        await expectLater(
          dragWidget.dragItemProvider(
            DragItemRequest(location: Offset.zero, session: session),
          ),
          throwsStateError,
        );
        expect(invoked, isTrue);
      },
    );

    testWidgets('${entry.key} hover preparation never writes temporary files', (
      tester,
    ) async {
      final previous = PathProviderPlatform.instance;
      final paths = _NoHoverTemporaryDirectory();
      PathProviderPlatform.instance = paths;
      addTearDown(() => PathProviderPlatform.instance = previous);
      var renders = 0;
      await tester.pumpWidget(
        _app(
          settings: const ShareImageSettings(),
          transform: ShareImageTransform(
            cacheKey: 'hover',
            apply: (image, {required stripMetadata}) async {
              renders++;
              return image;
            },
          ),
          child: entry.value(
            LocalImageRecord(
              path: '',
              size: _validPreviewBytes.length,
              modifiedAt: DateTime(2026),
            ),
            _validPreviewBytes,
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(300, 300));
      for (var i = 0; i < 2; i++) {
        await mouse.moveTo(const Offset(50, 50));
        await tester.pump(const Duration(milliseconds: 300));
        await mouse.moveTo(const Offset(300, 300));
        await tester.pump();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(renders, 2);
      expect(paths.requests, 0);
      expect(tester.takeException(), isNull);
    });
    testWidgets('${entry.key} shares concurrent preparation work', (
      tester,
    ) async {
      var calls = 0;
      final pending = Completer<SanitizedShareImage>();
      final transform = ShareImageTransform(
        cacheKey: 'same-preset',
        apply: (image, {required stripMetadata}) {
          calls++;
          return pending.future;
        },
      );
      final record = LocalImageRecord(
        path: '',
        size: _validPreviewBytes.length,
        modifiedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        _app(
          settings: const ShareImageSettings(),
          transform: transform,
          child: entry.value(record, _validPreviewBytes),
        ),
      );
      final session = _FakeDragSession();
      addTearDown(session.dispose);
      final drag = tester.widget<DragItemWidget>(find.byType(DragItemWidget));
      final failures = <Object>[];
      Future<void> request() async {
        try {
          await drag.dragItemProvider(
            DragItemRequest(location: Offset.zero, session: session),
          );
        } catch (error) {
          failures.add(error);
        }
      }

      final first = request();
      final second = request();
      await tester.pump();
      expect(calls, 1);
      pending.completeError(StateError('synthetic render failure'));
      await Future.wait([first, second]);
      expect(failures, hasLength(2));
      expect(failures, everyElement(isA<StateError>()));
    });

    testWidgets('${entry.key} fails closed for malformed protected bytes', (
      tester,
    ) async {
      final directory = Directory.systemTemp.createTempSync(
        'protected_gallery_drag_',
      );
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final source = File('${directory.path}${Platform.pathSeparator}bad.png')
        ..writeAsBytesSync(const [1, 2, 3], flush: true);
      final record = LocalImageRecord(
        path: source.path,
        size: 3,
        modifiedAt: DateTime(2026),
      );
      final session = _FakeDragSession();
      addTearDown(session.dispose);

      await tester.pumpWidget(
        _app(
          settings: const ShareImageSettings(protectionMode: true),
          child: entry.value(record, _validPreviewBytes),
        ),
      );
      final dragWidget = tester.widget<DragItemWidget>(
        find.byType(DragItemWidget),
      );

      Object? dragError;
      await tester.runAsync(() async {
        try {
          await dragWidget.dragItemProvider(
            DragItemRequest(location: Offset.zero, session: session),
          );
        } catch (error) {
          dragError = error;
        }
      });
      expect(dragError, isA<ImageSanitizeException>());
      expect(_feedbackKey(tester), protectedDragFeedbackMarkerKey);
    });
  }
}

Key? _feedbackKey(WidgetTester tester) {
  final dragWidget = tester.widget<DragItemWidget>(find.byType(DragItemWidget));
  return dragWidget
      .dragBuilder!(
        tester.element(find.byType(DragItemWidget)),
        const SizedBox(),
      )
      ?.key;
}

Widget _app({
  required ShareImageSettings settings,
  required Widget child,
  ValueChanged<_TestShareImageSettingsNotifier>? onNotifier,
  ShareImageTransform? transform,
}) {
  return ProviderScope(
    overrides: [
      databaseManagerProvider.overrideWith(
        (ref) => throw StateError('No database in drag tests'),
      ),
      copyDragWatermarkProvider.overrideWithValue(transform),
      shareImageSettingsProvider.overrideWith(() {
        final notifier = _TestShareImageSettingsNotifier(settings);
        onNotifier?.call(notifier);
        return notifier;
      }),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

final _record = LocalImageRecord(
  path: r'C:\sentinel\original.png',
  size: 987654,
  modifiedAt: DateTime(2026),
);

final _validPreviewBytes = Uint8List.fromList(
  img.encodePng(img.Image(width: 2, height: 2, numChannels: 4)),
);

final class _FakeDragSession extends DragSession {
  final _dragging = ValueNotifier(false);
  final _completed = ValueNotifier<DropOperation?>(null);
  final _location = ValueNotifier<Offset?>(null);

  @override
  ValueListenable<bool> get dragging => _dragging;

  @override
  ValueListenable<DropOperation?> get dragCompleted => _completed;

  @override
  ValueListenable<Offset?> get lastScreenLocation => _location;

  @override
  Future<List<Object?>?> getLocalData() async => null;

  void dispose() {
    _dragging.dispose();
    _completed.dispose();
    _location.dispose();
  }
}

class _NoHoverTemporaryDirectory extends PathProviderPlatform {
  int requests = 0;
  @override
  Future<String?> getTemporaryPath() async {
    requests++;
    throw StateError(
      'Hover preparation must not request a temporary directory',
    );
  }
}
