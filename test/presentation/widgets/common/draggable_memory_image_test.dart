import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/widgets/common/decoded_memory_image.dart';
import 'package:nai_launcher/presentation/widgets/common/draggable_memory_image.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_stream_preview.dart';
import 'package:nai_launcher/presentation/widgets/common/selectable_image_card.dart';
import 'package:nai_launcher/presentation/widgets/common/transparency_background.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

void main() {
  group('prepareDragImageForTransfer', () {
    test('should prefer saved file bytes when metadata is retained', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'draggable_memory_image_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final file = File('${tempDir.path}/sample.png');
      await file.writeAsBytes(const [1, 2, 3, 4]);

      final result = await prepareDragImageForTransfer(
        imageBytes: Uint8List.fromList(const [9, 9, 9]),
        fileName: 'memory.png',
        stripMetadata: false,
        sourceFilePath: file.path,
      );

      expect(result.fileName, equals('sample.png'));
      expect(result.bytes, equals(const [1, 2, 3, 4]));
    });
  });

  group('DraggableMemoryImage', () {
    testWidgets(
        'should not register drag widget when prepared file is required but unavailable',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DraggableMemoryImage(
                imageBytes: Uint8List.fromList(const [1, 2, 3]),
                requirePreparedDragFile: true,
                child: const Text('preview'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('preview'), findsOneWidget);
      expect(find.byType(DragItemWidget), findsNothing);
    });
  });

  group('ShareImagePreparationService metadata safety', () {
    test('does not expose an unstripped fallback while strip variant prepares',
        () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'share_image_preparation_no_fallback_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final sourceFile = File('${tempDir.path}/source.png');
      await sourceFile.writeAsBytes(const [1, 2, 3, 4]);
      final allowPrepare = Completer<void>();
      var prepareStripValue = false;

      final service = ShareImagePreparationService(
        prepareImage: (
          bytes, {
          required fileName,
          required stripMetadata,
        }) async {
          prepareStripValue = stripMetadata;
          await allowPrepare.future;
          return SanitizedShareImage(
            bytes: Uint8List.fromList(
              stripMetadata ? const [9, 9, 9] : const [1, 2, 3, 4],
            ),
            fileName: fileName,
            mimeType: 'image/png',
          );
        },
        writePreparedFile: (cacheKey, image) async {
          final file = File('${tempDir.path}/$cacheKey.png');
          await file.writeAsBytes(image.bytes);
          return file;
        },
      );
      addTearDown(service.clearAll);

      service.enqueue(
        imageId: 'image-a',
        imageBytes: Uint8List.fromList(const [1, 2, 3, 4]),
        fileName: 'image-a.png',
        sourceFilePath: sourceFile.path,
        stripMetadata: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(prepareStripValue, isTrue);
      expect(
        service.readyFileFor('image-a', stripMetadata: true),
        isNull,
      );
      expect(
        service.snapshotFor('image-a', stripMetadata: true).status,
        ShareImagePreparationStatus.preparing,
      );

      allowPrepare.complete();
      final readyFile = await service.waitUntilReady(
        'image-a',
        stripMetadata: true,
      );

      expect(readyFile, isNotNull);
      expect(await readyFile!.readAsBytes(), equals(const [9, 9, 9]));
      expect(readyFile.path, isNot(equals(sourceFile.path)));
    });

    test('keeps strip and original variants isolated', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'share_image_preparation_variants_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final sourceFile = File('${tempDir.path}/source.png');
      await sourceFile.writeAsBytes(const [1, 2, 3, 4]);

      final service = ShareImagePreparationService(
        prepareImage: (
          bytes, {
          required fileName,
          required stripMetadata,
        }) async {
          return SanitizedShareImage(
            bytes: Uint8List.fromList(
              stripMetadata ? const [7, 7, 7] : const [5, 5, 5],
            ),
            fileName: fileName,
            mimeType: 'image/png',
          );
        },
        writePreparedFile: (cacheKey, image) async {
          final file = File('${tempDir.path}/$cacheKey.png');
          await file.writeAsBytes(image.bytes);
          return file;
        },
      );
      addTearDown(service.clearAll);

      service.enqueue(
        imageId: 'image-a',
        imageBytes: Uint8List.fromList(const [9, 9, 9]),
        fileName: 'image-a.png',
        sourceFilePath: sourceFile.path,
        stripMetadata: false,
      );
      final originalReady = await service.waitUntilReady(
        'image-a',
        stripMetadata: false,
      );

      expect(originalReady!.path, equals(sourceFile.path));
      expect(
        service.readyFileFor('image-a', stripMetadata: true),
        isNull,
      );

      service.enqueue(
        imageId: 'image-a',
        imageBytes: Uint8List.fromList(const [9, 9, 9]),
        fileName: 'image-a.png',
        sourceFilePath: sourceFile.path,
        stripMetadata: true,
      );
      final strippedReady = await service.waitUntilReady(
        'image-a',
        stripMetadata: true,
      );

      expect(strippedReady!.path, isNot(equals(sourceFile.path)));
      expect(await strippedReady.readAsBytes(), equals(const [7, 7, 7]));
      expect(
        service.readyFileFor('image-a', stripMetadata: false)!.path,
        equals(sourceFile.path),
      );
    });

    test('retains prepared files until image leaves history', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'share_image_preparation_retention_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = ShareImagePreparationService(
        prepareImage: (
          bytes, {
          required fileName,
          required stripMetadata,
        }) async {
          return SanitizedShareImage(
            bytes: bytes,
            fileName: fileName,
            mimeType: 'image/png',
          );
        },
        writePreparedFile: (cacheKey, image) async {
          final file = File('${tempDir.path}/$cacheKey.png');
          await file.writeAsBytes(image.bytes);
          return file;
        },
      );
      addTearDown(service.clearAll);

      for (final id in const ['image-a', 'image-b']) {
        service.enqueue(
          imageId: id,
          imageBytes: Uint8List.fromList(
            id == 'image-a' ? const [1, 1, 1] : const [2, 2, 2],
          ),
          fileName: '$id.png',
          stripMetadata: true,
        );
      }

      final imageA = await service.waitUntilReady(
        'image-a',
        stripMetadata: true,
      );
      final imageB = await service.waitUntilReady(
        'image-b',
        stripMetadata: true,
      );

      expect(await imageA!.exists(), isTrue);
      expect(await imageB!.exists(), isTrue);

      await service.retainHistoryImageIds({'image-a'});

      expect(await imageA.exists(), isTrue);
      expect(await imageB.exists(), isFalse);
      expect(
        service.snapshotFor('image-b', stripMetadata: true).status,
        ShareImagePreparationStatus.notQueued,
      );
    });
  });

  group('SelectableImageCard hover gating', () {
    testWidgets(
        'keeps the completion preview until the completed image draws a frame',
        (tester) async {
      final imageBytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 40, height: 40)),
      );
      final previewBytes = base64Decode(_oneByOnePngBase64);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 160,
                height: 160,
                child: SelectableImageCard(
                  imageBytes: imageBytes,
                  completionPreview: StreamPreviewFrame(bytes: previewBytes),
                  underlay: const TransparencyBackgroundLayer(
                    style: TransparencyBackgrounds.checker,
                  ),
                  enableSelection: false,
                ),
              ),
            ),
          ),
        ),
      );

      final contentFinder = find.byKey(
        const ValueKey('selectable-image-content'),
      );
      expect(contentFinder, findsOneWidget);
      expect(find.byType(DecodedMemoryImage), findsOneWidget);
      expect(find.byType(ImageCardStreamPreview), findsOneWidget);
      expect(find.byType(TransparencyBackgroundLayer), findsNothing);

      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(ImageCardStreamPreview), findsOneWidget);
      expect(find.byType(TransparencyBackgroundLayer), findsNothing);

      // 解码只在真实事件循环里推进，pump 之间必须放行 runAsync。
      for (var attempt = 0; attempt < 50; attempt++) {
        if (find.byType(TransparencyBackgroundLayer).evaluate().isNotEmpty) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      expect(find.byType(ImageCardStreamPreview), findsNothing);
      expect(find.byType(TransparencyBackgroundLayer), findsOneWidget);
      expect(contentFinder, findsOneWidget);
      expect(find.byType(DecodedMemoryImage), findsOneWidget);
    });

    testWidgets('reuses stream preview when the same card becomes completed',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 160,
                height: 160,
                child: SelectableImageCard(
                  isGenerating: true,
                  progress: 0.9,
                  currentImage: 1,
                  totalImages: 1,
                  streamPreview: base64Decode(_oneByOnePngBase64),
                  imageWidth: 1,
                  imageHeight: 1,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 160,
                height: 160,
                child: SelectableImageCard(
                  imageBytes: base64Decode(_oneByOnePngBase64),
                  enableSelection: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('selectable-image-content')),
        findsOneWidget,
      );
      expect(find.byType(DecodedMemoryImage), findsOneWidget);
      expect(find.byType(ImageCardStreamPreview), findsOneWidget);
    });

    testWidgets(
        'keeps the preview visible with bottom preview progress until drag preparation is ready',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 160,
                height: 160,
                child: SelectableImageCard(
                  imageBytes: base64Decode(_oneByOnePngBase64),
                  index: 0,
                  enableSelection: false,
                  dragPreparationReady: false,
                ),
              ),
            ),
          ),
        ),
      );

      var preview = tester.widget<DecodedMemoryImage>(
        find.byType(DecodedMemoryImage).first,
      );
      expect(preview.decodeScale, equals(1.0));
      expect(
        find.byKey(const ValueKey('drag-preparation-progress')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('drag-preparation-circular-progress')),
        findsNothing,
      );
      final progressFinder = find.byKey(
        const ValueKey('drag-preparation-preview-progress-ring'),
      );
      final percentageFinder = find.byKey(
        const ValueKey('drag-preparation-preview-progress-percent'),
      );
      final indexBadgeFinder = find.byKey(
        const ValueKey('selectable-image-index-badge-offstage'),
        skipOffstage: false,
      );
      expect(progressFinder, findsOneWidget);
      expect(percentageFinder, findsOneWidget);
      expect(find.text('96%'), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(indexBadgeFinder, findsOneWidget);
      expect(tester.widget<Offstage>(indexBadgeFinder).offstage, isTrue);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(
                const ValueKey('drag-preparation-preview-overlay-opacity'),
              ),
            )
            .opacity,
        equals(1),
      );
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(
                const ValueKey('drag-preparation-preview-overlay-opacity'),
              ),
            )
            .duration,
        equals(const Duration(milliseconds: 140)),
      );
      expect(
        tester.widget<CircularProgressIndicator>(progressFinder).value,
        equals(0.96),
      );

      final progressTopLeft = tester.getTopLeft(progressFinder);
      final cardTopLeft = tester.getTopLeft(
        find.byType(SelectableImageCard),
      );
      final cardBottomRight = tester.getBottomRight(
        find.byType(SelectableImageCard),
      );
      expect(progressTopLeft.dx, lessThan(cardTopLeft.dx + 40));
      expect(progressTopLeft.dy, greaterThan(cardBottomRight.dy - 40));

      final oldProgressFinder = find.byKey(
        const ValueKey('drag-preparation-circular-progress'),
      );
      expect(oldProgressFinder, findsNothing);
      final previewElementBefore = tester.element(
        find.byType(DecodedMemoryImage).first,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 160,
                height: 160,
                child: SelectableImageCard(
                  imageBytes: base64Decode(_oneByOnePngBase64),
                  index: 0,
                  enableSelection: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.widget<Offstage>(indexBadgeFinder).offstage, isTrue);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(
                const ValueKey('drag-preparation-preview-overlay-opacity'),
              ),
            )
            .opacity,
        equals(0),
      );

      await tester.pumpAndSettle();

      preview = tester.widget<DecodedMemoryImage>(
        find.byType(DecodedMemoryImage).first,
      );
      expect(preview.decodeScale, equals(1.0));
      expect(
        tester.element(find.byType(DecodedMemoryImage).first),
        same(previewElementBefore),
      );
      expect(progressFinder, findsOneWidget);
      expect(percentageFinder, findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(indexBadgeFinder, findsOneWidget);
      expect(tester.widget<Offstage>(indexBadgeFinder).offstage, isFalse);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(
                const ValueKey('drag-preparation-preview-overlay-opacity'),
              ),
            )
            .opacity,
        equals(0),
      );
    });

    testWidgets(
        'should not expose hover action bar when hover effects disabled',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 160,
                height: 160,
                child: SelectableImageCard(
                  imageBytes: base64Decode(_oneByOnePngBase64),
                  enableSelection: false,
                  hoverEffectsEnabled: false,
                  shareWarmupEnabled: false,
                  onUpscale: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(find.byType(SelectableImageCard)));
      await tester.pumpAndSettle();

      expect(find.byTooltip('放大'), findsNothing);
    });
  });
}

const _oneByOnePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=';
