import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/utils/clipboard_image.dart';
import 'package:super_clipboard/super_clipboard.dart';

void main() {
  group('clipboardDefersToText', () {
    test('text priority yields to text copied together with an image', () {
      final officeRange = _Reader([Formats.plainText, Formats.png]);

      expect(
        clipboardDefersToText(officeRange, ClipboardContentPriority.text),
        isTrue,
      );
      expect(
        clipboardDefersToText(officeRange, ClipboardContentPriority.image),
        isFalse,
      );
    });

    test('a copied file wins over the file name text beside it', () {
      final finderCopy = _Reader([Formats.plainText, Formats.fileUri]);

      expect(
        clipboardDefersToText(finderCopy, ClipboardContentPriority.text),
        isFalse,
      );
    });

    test('an image without text is never handed to text paste', () {
      final screenshot = _Reader([Formats.png]);

      expect(
        clipboardDefersToText(screenshot, ClipboardContentPriority.text),
        isFalse,
      );
    });
  });
}

class _Reader extends Fake implements DataReader {
  _Reader(this.formats);

  final List<DataFormat> formats;

  @override
  bool canProvide(DataFormat format) => formats.contains(format);
}
