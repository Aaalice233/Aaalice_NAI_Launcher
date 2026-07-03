import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_models.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_generation_notifier.dart';

void main() {
  group('StreamGenerationState', () {
    test('copyWith can explicitly clear result', () {
      final generatedImage = GeneratedImage(
        id: 'result',
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 1,
        height: 1,
      );
      final state = StreamGenerationState(
        status: StreamGenerationStatus.completed,
        result: generatedImage,
      );

      final cleared = state.copyWith(
        status: StreamGenerationStatus.idle,
        clearResult: true,
      );

      expect(cleared.status, StreamGenerationStatus.idle);
      expect(cleared.result, isNull);
      expect(cleared.hasResult, isFalse);
    });
  });
}
