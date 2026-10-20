import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/utils/dropped_file_reader.dart';
import 'package:nai_launcher/presentation/widgets/drop/dropped_image_inspector.dart';

import '../../../helpers/unreachable_loopback.dart';

void main() {
  test(
    'an original downloaded for its metadata is not fetched again',
    () async {
      final refusing = await RefusingLoopbackPort.reserve();
      addTearDown(refusing.release);
      final original = Uint8List.fromList(List.filled(32, 7));

      final resolved = await const DroppedImageInspector().resolveOriginalBytes(
        DroppedFileData(
          fileName: 'attachment.webp',
          bytes: Uint8List.fromList(const [1, 2, 3]),
          sourceUri: Uri.parse('http://127.0.0.1:${refusing.port}/a.webp'),
          metadataBytes: original,
          metadataBytesAreOriginal: true,
          imageBytesArePreview: true,
        ),
      );

      expect(resolved, same(original));
    },
  );
}
