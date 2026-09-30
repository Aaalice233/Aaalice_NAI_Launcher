import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

/// Builds a PNG whose NovelAI metadata lives only in the alpha stealth payload,
/// which forces the parser through its full pixel decode.
Future<Uint8List> stealthOnlyNovelAiPng(String prompt) async {
  final image = img.Image(width: 64, height: 64, numChannels: 4);
  final embedded = await UnifiedMetadataParser.embedMetadata(
    Uint8List.fromList(img.encodePng(image)),
    jsonEncode({
      'prompt': prompt,
      'uc': '',
      'width': 64,
      'height': 64,
      'seed': 1,
      'steps': 28,
      'scale': 5.0,
      'sampler': 'k_euler',
    }),
    useStealth: true,
  );
  return _withoutPngTextChunks(embedded);
}

Uint8List _withoutPngTextChunks(Uint8List png) {
  final output = BytesBuilder(copy: false)..add(png.sublist(0, 8));
  var offset = 8;
  while (offset + 12 <= png.length) {
    final length = ByteData.sublistView(png, offset, offset + 4).getUint32(0);
    final end = offset + 12 + length;
    if (end > png.length) break;
    final type = latin1.decode(png.sublist(offset + 4, offset + 8));
    if (type != 'tEXt' && type != 'zTXt' && type != 'iTXt') {
      output.add(png.sublist(offset, end));
    }
    offset = end;
  }
  return output.takeBytes();
}
