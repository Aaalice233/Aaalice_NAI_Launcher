import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;
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

  test('zip responses yield every image in order', () async {
    final artifacts = await processor.processZip(zipBytes, context);

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
    final chunks = await processor
        .processMessagePackStream(
          Stream.value(zipBytes),
          context,
          cancelToken: CancelToken(),
        )
        .toList();

    expect(chunks.map((chunk) => chunk.isComplete), everyElement(isTrue));
    expect(chunks.map((chunk) => chunk.sampleIndex), orderedEquals([0, 1]));
    expect(
      chunks.map((chunk) => chunk.finalImage).toList(),
      equals([first, second]),
    );
  });

  test('cancelling while the zip tail extracts ends as cancelled', () async {
    final cancelToken = CancelToken();

    // 解压已排进闸门、流已读完时才取消，验证的是解压之后的取消检查
    final chunks = await expectQueuedBehindSharedComputeGate(
      () => processor
          .processMessagePackStream(
            Stream.value(zipBytes),
            context,
            cancelToken: cancelToken,
          )
          .toList(),
      whileQueued: () => cancelToken.cancel('user cancelled'),
    );

    expect(chunks, hasLength(1));
    expect(chunks.single.error, 'Cancelled');
    expect(chunks.single.finalImage, isNull);
  });

  group('length-prefixed stream frames', () {
    final streamContext = NaiGenerationResponseContext(
      originalParams: const ImageParams(
        prompt: 'frames',
        nSamples: 2,
        steps: 10,
      ),
      focusedRequest: null,
      requestBuildResult: NAIImageRequestBuildResult(
        seed: 1,
        effectivePrompt: 'frames',
        effectiveNegativePrompt: '',
        requestParameters: const {},
        requestData: const {},
      ),
    );
    final random = Random(20260930);
    Uint8List bytesOf(int length) => Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
    final messages = <Map<String, Object?>>[
      for (var step = 0; step < 3; step++)
        {
          'event_type': 'intermediate',
          'samp_ix': 0,
          'step_ix': step,
          'image': bytesOf(37 + step),
        },
      {'event_type': 'final', 'samp_ix': 0, 'image': bytesOf(301)},
      {
        'event_type': 'intermediate',
        'samp_ix': 1,
        'step_ix': 0,
        'image': bytesOf(5),
      },
      {'event_type': 'final', 'samp_ix': 1, 'image': bytesOf(4)},
    ];
    final body = _framed(messages);

    Future<List<String>> parse(List<Uint8List> chunks) async {
      final parsed = await processor
          .processMessagePackStream(
            Stream.fromIterable(chunks),
            streamContext,
            cancelToken: CancelToken(),
          )
          .toList();
      return parsed.map(_describe).toList();
    }

    test('glued frames match the messages in order', () async {
      final parsed = await parse([body]);

      expect(parsed, [
        for (var step = 0; step < 3; step++)
          _describeMessage(messages[step], steps: 10),
        _describeMessage(messages[3], steps: 10),
        _describeMessage(messages[4], steps: 10),
        _describeMessage(messages[5], steps: 10),
      ]);
    });

    test('split and boundary-crossing chunks parse identically', () async {
      final expected = await parse([body]);

      expect(await parse(_chunked(body, const [1])), expected);
      expect(await parse(_chunked(body, const [2, 3])), expected);
      expect(await parse(_chunked(body, const [3, 7, 11, 64])), expected);
      final headerSplit = 4 + msgpack.serialize(messages.first).length + 2;
      expect(
        await parse([
          Uint8List.sublistView(body, 0, headerSplit),
          Uint8List(0),
          Uint8List.sublistView(body, headerSplit),
        ]),
        expected,
      );
    });

    test(
      'an incomplete trailing frame ends as a missing final image',
      () async {
        final expected = await parse([body]);

        final parsed = await parse([
          Uint8List.sublistView(body, 0, body.length - 1),
        ]);

        expect(parsed, [
          ...expected.take(expected.length - 1),
          'error:No final image received from stream',
        ]);
      },
    );

    test('a multi-megabyte frame arrives intact from small chunks', () async {
      final large = bytesOf(6 * 1024 * 1024 + 17);
      final frame = _framed([
        {'event_type': 'final', 'samp_ix': 0, 'image': large},
      ]);
      final oneSample = NaiGenerationResponseContext(
        originalParams: const ImageParams(prompt: 'large'),
        focusedRequest: null,
        requestBuildResult: streamContext.requestBuildResult,
      );

      final parsed = await processor
          .processMessagePackStream(
            Stream.fromIterable(_chunked(frame, const [64 * 1024])),
            oneSample,
            cancelToken: CancelToken(),
          )
          .toList();

      expect(parsed, hasLength(1));
      expect(parsed.single.isComplete, isTrue);
      expect(parsed.single.finalImage, orderedEquals(large));
    });

    test('a zip tail split across chunks is still recognised', () async {
      final chunks = await processor
          .processMessagePackStream(
            Stream.fromIterable(_chunked(zipBytes, const [2, 9, 40])),
            context,
            cancelToken: CancelToken(),
          )
          .toList();

      expect(
        chunks.map((chunk) => chunk.finalImage).toList(),
        equals([first, second]),
      );
    });
  });
}

Uint8List _framed(List<Map<String, Object?>> messages) {
  final framed = BytesBuilder(copy: false);
  for (final message in messages) {
    final encoded = msgpack.serialize(message);
    final length = encoded.length;
    framed
      ..add([
        (length >> 24) & 0xFF,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF,
      ])
      ..add(encoded);
  }
  return framed.takeBytes();
}

/// 按 [sizes] 循环切块，覆盖帧头与帧体跨块的各种位置。
List<Uint8List> _chunked(Uint8List bytes, List<int> sizes) {
  final chunks = <Uint8List>[];
  var offset = 0;
  for (var index = 0; offset < bytes.length; index++) {
    final end = min(offset + sizes[index % sizes.length], bytes.length);
    chunks.add(Uint8List.sublistView(bytes, offset, end));
    offset = end;
  }
  return chunks;
}

String _describe(ImageStreamChunk chunk) {
  if (chunk.hasError) return 'error:${chunk.error}';
  if (chunk.isComplete) {
    return 'final:${chunk.sampleIndex}:${chunk.finalImage}';
  }
  return 'preview:${chunk.sampleIndex}:${chunk.currentStep}/'
      '${chunk.totalSteps}:${chunk.progress}:${chunk.previewImage}';
}

String _describeMessage(Map<String, Object?> message, {required int steps}) {
  final sample = message['samp_ix']! as int;
  if (message['event_type'] == 'final') {
    return 'final:$sample:${message['image']}';
  }
  final step = (message['step_ix']! as int) + 1;
  return 'preview:$sample:$step/$steps:${(step / steps).clamp(0.0, 0.99)}:'
      '${message['image']}';
}

Uint8List _zipOf(Map<String, Uint8List> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
