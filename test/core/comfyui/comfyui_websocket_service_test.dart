import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/comfyui/comfyui_websocket_service.dart';

void main() {
  group('ComfyUIBinaryFrameDecoder', () {
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 7, 2, 12);
    });

    test('throttles preview frames without dropping final frames', () {
      final decoder = ComfyUIBinaryFrameDecoder(
        previewMinInterval: const Duration(milliseconds: 200),
        now: () => now,
      );

      final firstPreview = decoder.decode(_frame(eventType: 1, payloadSize: 4));
      expect(firstPreview, isNotNull);
      expect(firstPreview!.isPreview, isTrue);

      now = now.add(const Duration(milliseconds: 50));
      expect(decoder.decode(_frame(eventType: 1, payloadSize: 4)), isNull);

      final finalFrame = decoder.decode(_frame(eventType: 2, payloadSize: 4));
      expect(finalFrame, isNotNull);
      expect(finalFrame!.isPreview, isFalse);

      now = now.add(const Duration(milliseconds: 200));
      final nextPreview = decoder.decode(_frame(eventType: 1, payloadSize: 4));
      expect(nextPreview, isNotNull);
      expect(nextPreview!.isPreview, isTrue);
    });

    test('returns a payload view instead of copying image bytes', () {
      final decoder = ComfyUIBinaryFrameDecoder(
        previewMinInterval: Duration.zero,
        now: () => now,
      );
      final raw = _frame(eventType: 2, payloadSize: 16);

      final frame = decoder.decode(raw);

      expect(frame, isNotNull);
      frame!.data[0] = 0x7f;
      expect(raw[8], 0x7f);
      expect(frame.data.offsetInBytes, raw.offsetInBytes + 8);
      expect(frame.data.length, 16);
    });
  });
}

Uint8List _frame({required int eventType, required int payloadSize}) {
  final data = Uint8List(8 + payloadSize);
  final header = ByteData.sublistView(data, 0, 8);
  header.setUint32(0, eventType, Endian.big);
  header.setUint32(4, 2, Endian.big);
  for (var i = 8; i < data.length; i++) {
    data[i] = i & 0xff;
  }
  return data;
}
