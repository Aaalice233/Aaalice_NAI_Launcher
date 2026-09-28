import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/media_mime_type.dart';

void main() {
  group('mediaMimeTypeForExtension', () {
    test('normalizes common image and video extensions', () {
      expect(mediaMimeTypeForExtension('.JPEG'), 'image/jpeg');
      expect(mediaMimeTypeForExtension('webp'), 'image/webp');
      expect(mediaMimeTypeForExtension('MP4'), 'video/mp4');
      expect(mediaMimeTypeForExtension('.mov'), 'video/quicktime');
    });

    test('uses the provided fallback for unknown extensions', () {
      expect(mediaMimeTypeForExtension('bin'), 'application/octet-stream');
      expect(
        mediaMimeTypeForExtension('nai', fallback: 'application/x-nai'),
        'application/x-nai',
      );
    });
  });
}
