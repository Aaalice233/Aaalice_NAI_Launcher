import 'dart:async';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/request_builders/nai_image_request_builder.dart';
import 'package:nai_launcher/data/datasources/remote/nai_generation_response_processor.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';

import '../../../helpers/shared_compute_gate.dart';

void main() {
  final processor = NaiGenerationResponseProcessor();
  final context = NaiGenerationResponseContext(
    originalParams: const ImageParams(prompt: 'zip response', nSamples: 2),
    focusedRequest: null,
    requestBuildResult: NAIImageRequestBuildResult(
      seed: 1,
      effectivePrompt: 'zip response',
      effectiveNegativePrompt: '',
      requestParameters: const {},
      requestData: const {},
    ),
  );
  final first = Uint8List.fromList([1, 2, 3, 4]);
  final second = Uint8List.fromList([5, 6, 7]);
  final zipBytes = _zipOf({'image_0.png': first, 'image_1.png': second});

  test('zip responses are extracted behind the shared gate', () async {
    final artifacts = await expectQueuedBehindSharedComputeGate(
      () => processor.processZip(zipBytes, context),
    );

    expect(
      artifacts.map((artifact) => artifact.displayImageBytes).toList(),
      equals([first, second]),
    );
  });

  test('an empty zip response still reports missing images', () async {
    await expectLater(
      processor.processZip(_zipOf(const {}), context),
      throwsA(
        isA<Exception>().having(
          (error) => '$error',
          'message',
          contains('No images found in response'),
        ),
      ),
    );
  });

  test('a zip stream tail yields every sample in order', () async {
    final chunks = await expectQueuedBehindSharedComputeGate(
      () => processor
          .processMessagePackStream(
            Stream.value(zipBytes),
            context,
            cancelToken: CancelToken(),
          )
          .toList(),
    );

    expect(chunks.map((chunk) => chunk.isComplete), everyElement(isTrue));
    expect(chunks.map((chunk) => chunk.sampleIndex), orderedEquals([0, 1]));
    expect(
      chunks.map((chunk) => chunk.finalImage).toList(),
      equals([first, second]),
    );
  });

  test('cancelling while the zip tail extracts ends as cancelled', () async {
    final cancelToken = CancelToken();
    final release = holdSharedComputeGate();
    late Future<List<ImageStreamChunk>> pending;
    try {
      pending = processor
          .processMessagePackStream(
            Stream.value(zipBytes),
            context,
            cancelToken: cancelToken,
          )
          .toList();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      cancelToken.cancel('user cancelled');
    } finally {
      await release();
    }

    final chunks = await pending;
    expect(chunks, hasLength(1));
    expect(chunks.single.error, 'Cancelled');
    expect(chunks.single.finalImage, isNull);
  });
}

Uint8List _zipOf(Map<String, Uint8List> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
